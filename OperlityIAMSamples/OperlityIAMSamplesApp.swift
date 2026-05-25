import SwiftUI
import UIKit

@main
struct OperlityIAMSamplesApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var oidcClient = OIDCClient(configuration: .demo)

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(oidcClient)
                .onOpenURL { url in
                    _ = AuthorizationFlowCoordinator.shared.resumeExternalUserAgentFlow(with: url)
                }
        }
    }
}
