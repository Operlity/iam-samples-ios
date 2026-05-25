import AppAuth
import Combine
import Foundation
import UIKit

@MainActor
final class OIDCClient: ObservableObject {
    @Published private(set) var tokens: TokenResponse?
    @Published private(set) var profile: UserProfile?
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let configuration: IdentityHubConfiguration
    private let tokenStore = KeychainTokenStore()
    private var authState: OIDAuthState?

    init(configuration: IdentityHubConfiguration) {
        self.configuration = configuration
        loadState()
        refreshPublishedTokens()
    }

    var isAuthenticated: Bool {
        authState?.isAuthorized == true
    }

    func signIn() {
        guard let presentingViewController = UIApplication.shared.topViewController else {
            errorMessage = "Unable to find a view controller to present the login session."
            return
        }

        isLoading = true
        errorMessage = nil

        OIDAuthorizationService.discoverConfiguration(forIssuer: configuration.issuer) { [weak self] serviceConfiguration, error in
            Task { @MainActor in
                guard let self else {
                    return
                }

                guard let serviceConfiguration else {
                    self.isLoading = false
                    self.errorMessage = error?.localizedDescription ?? "Discovery failed."
                    return
                }

                self.startAuthorization(
                    serviceConfiguration: serviceConfiguration,
                    presenting: presentingViewController
                )
            }
        }
    }

    func loadUserProfile() {
        guard isAuthenticated else {
            return
        }

        isLoading = true
        errorMessage = nil

        getFreshAccessToken { [weak self] token in
            Task { @MainActor in
                guard let self else {
                    return
                }

                guard let token else {
                    self.isLoading = false
                    self.errorMessage = "Unable to get an access token."
                    return
                }

                do {
                    self.profile = try await self.fetchUserProfile(accessToken: token)
                } catch {
                    self.errorMessage = error.localizedDescription
                }

                self.isLoading = false
            }
        }
    }

    func signOut() {
        guard let presentingViewController = UIApplication.shared.topViewController else {
            clearLocalSession()
            return
        }

        guard let authState,
              let idToken = authState.lastTokenResponse?.idToken else {
            clearLocalSession()
            return
        }

        isLoading = true
        errorMessage = nil

        let request = OIDEndSessionRequest(
            configuration: authState.lastAuthorizationResponse.request.configuration,
            idTokenHint: idToken,
            postLogoutRedirectURL: configuration.postLogoutRedirectURI,
            additionalParameters: nil
        )

        guard let agent = OIDExternalUserAgentIOS(presenting: presentingViewController) else {
            clearLocalSession()
            isLoading = false
            return
        }

        let flow = OIDAuthorizationService.present(request, externalUserAgent: agent) { [weak self] _, error in
            Task { @MainActor in
                if let error {
                    #if DEBUG
                    print("OIDC logout error: \(error)")
                    #endif
                }

                self?.clearLocalSession()
                self?.isLoading = false
            }
        }

        AuthorizationFlowCoordinator.shared.currentAuthorizationFlow = flow
    }

    func clearLocalSession() {
        AuthorizationFlowCoordinator.shared.cancel()
        authState = nil
        tokens = nil
        profile = nil
        errorMessage = nil
        tokenStore.delete()
    }

    private func startAuthorization(
        serviceConfiguration: OIDServiceConfiguration,
        presenting viewController: UIViewController
    ) {
        let request = OIDAuthorizationRequest(
            configuration: serviceConfiguration,
            clientId: configuration.clientID,
            clientSecret: nil,
            scopes: configuration.scopes,
            redirectURL: configuration.redirectURI,
            responseType: OIDResponseTypeCode,
            additionalParameters: nil
        )

        let flow = OIDAuthState.authState(
            byPresenting: request,
            presenting: viewController
        ) { [weak self] authState, error in
            Task { @MainActor in
                guard let self else {
                    return
                }

                self.isLoading = false

                guard let authState else {
                    self.errorMessage = error?.localizedDescription ?? "Authentication failed."
                    return
                }

                self.authState = authState
                self.persistState()
                self.refreshPublishedTokens()
                self.loadUserProfile()
            }
        }

        AuthorizationFlowCoordinator.shared.currentAuthorizationFlow = flow
    }

    private func getFreshAccessToken(completion: @escaping (String?) -> Void) {
        guard let authState else {
            completion(nil)
            return
        }

        authState.performAction { [weak self] accessToken, _, error in
            if let error {
                #if DEBUG
                print("OIDC token refresh error: \(error)")
                #endif
                completion(nil)
                return
            }

            Task { @MainActor in
                self?.persistState()
                self?.refreshPublishedTokens()
            }

            completion(accessToken)
        }
    }

    private func fetchUserProfile(accessToken: String) async throws -> UserProfile? {
        let userInfoURL = configuration.issuer.appending(path: "connect/userinfo")
        var request = URLRequest(url: userInfoURL)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateHTTPResponse(response, data: data)
        return try JSONDecoder().decode(UserProfile.self, from: data)
    }

    private func loadState() {
        guard let data = try? tokenStore.load(),
              let state = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? OIDAuthState else {
            return
        }

        authState = state
    }

    private func persistState() {
        guard let authState else {
            tokenStore.delete()
            return
        }

        do {
            let data = try NSKeyedArchiver.archivedData(
                withRootObject: authState,
                requiringSecureCoding: false
            )
            try tokenStore.save(data)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func refreshPublishedTokens() {
        guard let tokenResponse = authState?.lastTokenResponse else {
            tokens = nil
            return
        }

        tokens = TokenResponse(
            accessToken: tokenResponse.accessToken ?? "",
            idToken: tokenResponse.idToken,
            refreshToken: tokenResponse.refreshToken,
            tokenType: tokenResponse.tokenType ?? "Bearer",
            expiresIn: tokenResponse.accessTokenExpirationDate.map { Int($0.timeIntervalSinceNow) }
        )
    }

    private func validateHTTPResponse(_ response: URLResponse, data: Data = Data()) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OIDCError.invalidResponse
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            let body = String(data: data, encoding: .utf8)
            #if DEBUG
            print("OIDC HTTP \(httpResponse.statusCode): \(body ?? "")")
            #endif
            throw OIDCError.http(statusCode: httpResponse.statusCode, body: body)
        }
    }
}

private extension UIApplication {
    var topViewController: UIViewController? {
        connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }?
            .rootViewController?
            .topMostPresentedViewController
    }
}

private extension UIViewController {
    var topMostPresentedViewController: UIViewController {
        presentedViewController?.topMostPresentedViewController ?? self
    }
}

enum OIDCError: LocalizedError {
    case http(statusCode: Int, body: String?)
    case invalidResponse
    case keychain(OSStatus)

    var errorDescription: String? {
        switch self {
        case let .http(statusCode, body):
            return "Identity Hub returned HTTP \(statusCode). \(body ?? "")"
        case .invalidResponse:
            return "Identity Hub returned an invalid response."
        case let .keychain(status):
            return "Keychain operation failed with status \(status)."
        }
    }
}
