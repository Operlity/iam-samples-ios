import AuthenticationServices
import Combine
import Foundation

#if canImport(UIKit)
import UIKit
#endif

@MainActor
final class OIDCClient: NSObject, ObservableObject {
    @Published private(set) var tokens: TokenResponse?
    @Published private(set) var profile: UserProfile?
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let configuration: IdentityHubConfiguration
    private let tokenStore = KeychainTokenStore()
    private var authenticationSession: ASWebAuthenticationSession?

    init(configuration: IdentityHubConfiguration) {
        self.configuration = configuration
        super.init()

        do {
            tokens = try tokenStore.load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    var isAuthenticated: Bool {
        tokens?.accessToken.isEmpty == false
    }

    func signIn() {
        Task {
            await self.runLoadingOperation {
                let discovery = try await self.fetchDiscoveryDocument()
                let result = try await self.authenticate(using: discovery)
                self.tokens = result.tokens
                self.profile = result.profile
                try self.tokenStore.save(result.tokens)
            }
        }
    }

    func loadUserProfile() {
        Task {
            await self.runLoadingOperation {
                let discovery = try await self.fetchDiscoveryDocument()
                self.profile = try await self.fetchUserProfile(discovery: discovery)
            }
        }
    }

    func signOut() {
        Task {
            await self.runLoadingOperation {
                let discovery = try? await self.fetchDiscoveryDocument()
                let idToken = self.tokens?.idToken
                self.clearLocalSession()

                if let endSessionEndpoint = discovery?.endSessionEndpoint {
                    try await self.endRemoteSession(endpoint: endSessionEndpoint, idToken: idToken)
                }
            }
        }
    }

    func clearLocalSession() {
        authenticationSession?.cancel()
        authenticationSession = nil
        tokenStore.delete()
        tokens = nil
        profile = nil
        errorMessage = nil
    }

    private func runLoadingOperation(_ operation: @escaping () async throws -> Void) async {
        isLoading = true
        errorMessage = nil

        do {
            try await operation()
        } catch is CancellationError {
            errorMessage = "Authentication was cancelled."
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func fetchDiscoveryDocument() async throws -> DiscoveryDocument {
        let url = configuration.issuer.appending(path: ".well-known/openid-configuration")
        let (data, response) = try await URLSession.shared.data(from: url)
        try validateHTTPResponse(response)

        let discovery = try JSONDecoder().decode(DiscoveryDocument.self, from: data)
        guard discovery.issuer == configuration.issuer.absoluteString else {
            throw OIDCError.issuerMismatch(expected: configuration.issuer.absoluteString, actual: discovery.issuer)
        }
        return discovery
    }

    private func authenticate(using discovery: DiscoveryDocument) async throws -> AuthenticationResult {
        let verifier = PKCE.makeVerifier()
        let state = PKCE.makeState()
        let callbackURL = try await openAuthorizationSession(
            authorizationEndpoint: discovery.authorizationEndpoint,
            verifier: verifier,
            state: state
        )

        let code = try authorizationCode(from: callbackURL, expectedState: state)
        let tokens = try await exchangeCodeForTokens(code: code, verifier: verifier, discovery: discovery)
        let profile = try await fetchUserProfile(discovery: discovery, accessToken: tokens.accessToken)

        return AuthenticationResult(tokens: tokens, profile: profile)
    }

    private func openAuthorizationSession(
        authorizationEndpoint: URL,
        verifier: String,
        state: String
    ) async throws -> URL {
        var components = URLComponents(url: authorizationEndpoint, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: configuration.clientID),
            URLQueryItem(name: "redirect_uri", value: configuration.redirectURI.absoluteString),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: configuration.scope),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "code_challenge", value: PKCE.makeChallenge(for: verifier)),
            URLQueryItem(name: "code_challenge_method", value: "S256")
        ]

        guard let authorizationURL = components?.url else {
            throw OIDCError.invalidURL
        }

        #if DEBUG
        print("OIDC authorize URL: \(authorizationURL.absoluteString)")
        #endif

        return try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: authorizationURL,
                callbackURLScheme: configuration.callbackScheme
            ) { callbackURL, error in
                if let error {
                    #if DEBUG
                    print("OIDC authorization session error: \(error)")
                    #endif
                    continuation.resume(throwing: error)
                    return
                }

                guard let callbackURL else {
                    continuation.resume(throwing: OIDCError.missingCallbackURL)
                    return
                }

                continuation.resume(returning: callbackURL)
            }

            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = true
            authenticationSession = session
            session.start()
        }
    }

    private func authorizationCode(from callbackURL: URL, expectedState: String) throws -> String {
        let queryItems = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?.queryItems ?? []

        if let error = queryItems.first(where: { $0.name == "error" })?.value {
            let description = queryItems.first(where: { $0.name == "error_description" })?.value
            throw OIDCError.authorizationFailed(error: error, description: description)
        }

        let state = queryItems.first(where: { $0.name == "state" })?.value
        guard state == expectedState else {
            throw OIDCError.invalidState
        }

        guard let code = queryItems.first(where: { $0.name == "code" })?.value, !code.isEmpty else {
            throw OIDCError.missingAuthorizationCode
        }

        return code
    }

    private func exchangeCodeForTokens(
        code: String,
        verifier: String,
        discovery: DiscoveryDocument
    ) async throws -> TokenResponse {
        var request = URLRequest(url: discovery.tokenEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var tokenParameters = [
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": configuration.redirectURI.absoluteString,
            "client_id": configuration.clientID,
            "code_verifier": verifier
        ]

        if !configuration.clientSecret.isEmpty && configuration.clientSecret != "replace-with-your-client-secret" {
            tokenParameters["client_secret"] = configuration.clientSecret
        }

        request.httpBody = formBody(tokenParameters)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateHTTPResponse(response, data: data)
        return try JSONDecoder().decode(TokenResponse.self, from: data)
    }

    private func fetchUserProfile(discovery: DiscoveryDocument) async throws -> UserProfile? {
        guard let accessToken = tokens?.accessToken else {
            return nil
        }

        return try await fetchUserProfile(discovery: discovery, accessToken: accessToken)
    }

    private func fetchUserProfile(discovery: DiscoveryDocument, accessToken: String) async throws -> UserProfile? {
        guard let userinfoEndpoint = discovery.userinfoEndpoint else {
            return nil
        }

        var request = URLRequest(url: userinfoEndpoint)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateHTTPResponse(response, data: data)
        return try JSONDecoder().decode(UserProfile.self, from: data)
    }

    private func endRemoteSession(endpoint: URL, idToken: String?) async throws {
        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "post_logout_redirect_uri", value: configuration.postLogoutRedirectURI.absoluteString)
        ]

        if let idToken {
            components?.queryItems?.append(URLQueryItem(name: "id_token_hint", value: idToken))
        }

        guard let logoutURL = components?.url else {
            throw OIDCError.invalidURL
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let session = ASWebAuthenticationSession(
                url: logoutURL,
                callbackURLScheme: configuration.callbackScheme
            ) { _, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                continuation.resume(returning: ())
            }

            session.presentationContextProvider = self
            authenticationSession = session
            session.start()
        }
    }

    private func formBody(_ parameters: [String: String]) -> Data {
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        let body = parameters
            .map { key, value in
                let encodedKey = key.addingPercentEncoding(withAllowedCharacters: allowed) ?? key
                let encodedValue = value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
                return "\(encodedKey)=\(encodedValue)"
            }
            .joined(separator: "&")

        return Data(body.utf8)
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

extension OIDCClient: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        #if canImport(UIKit)
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.flatMap(\.windows).first { $0.isKeyWindow } ?? ASPresentationAnchor()
        #else
        return ASPresentationAnchor()
        #endif
    }
}

enum OIDCError: LocalizedError {
    case authorizationFailed(error: String, description: String?)
    case http(statusCode: Int, body: String?)
    case invalidResponse
    case invalidState
    case invalidURL
    case issuerMismatch(expected: String, actual: String)
    case keychain(OSStatus)
    case missingAuthorizationCode
    case missingCallbackURL

    var errorDescription: String? {
        switch self {
        case let .authorizationFailed(error, description):
            return [error, description].compactMap { $0 }.joined(separator: ": ")
        case let .http(statusCode, body):
            return "Identity Hub returned HTTP \(statusCode). \(body ?? "")"
        case .invalidResponse:
            return "Identity Hub returned an invalid response."
        case .invalidState:
            return "The authentication state did not match. Please try signing in again."
        case .invalidURL:
            return "Unable to build a valid Identity Hub URL."
        case let .issuerMismatch(expected, actual):
            return "Issuer mismatch. Expected \(expected), got \(actual)."
        case let .keychain(status):
            return "Keychain operation failed with status \(status)."
        case .missingAuthorizationCode:
            return "Identity Hub did not return an authorization code."
        case .missingCallbackURL:
            return "The authentication session ended without a callback URL."
        }
    }
}
