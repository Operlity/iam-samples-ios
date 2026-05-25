import AppAuth
import UIKit

final class AuthorizationFlowCoordinator {
    static let shared = AuthorizationFlowCoordinator()

    var currentAuthorizationFlow: OIDExternalUserAgentSession?

    private init() {}

    func resumeExternalUserAgentFlow(with url: URL) -> Bool {
        #if DEBUG
        print("OIDC callback URL received: \(url.absoluteString)")
        #endif

        if let flow = currentAuthorizationFlow,
           flow.resumeExternalUserAgentFlow(with: url) {
            currentAuthorizationFlow = nil
            #if DEBUG
            print("OIDC callback resumed AppAuth flow.")
            #endif
            return true
        }

        #if DEBUG
        print("OIDC callback did not match an active AppAuth flow.")
        #endif
        return false
    }

    func cancel() {
        currentAuthorizationFlow?.cancel()
        currentAuthorizationFlow = nil
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        AuthorizationFlowCoordinator.shared.resumeExternalUserAgentFlow(with: url)
    }
}
