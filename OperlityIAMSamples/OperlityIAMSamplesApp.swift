import SwiftUI

@main
struct OperlityIAMSamplesApp: App {
    @StateObject private var oidcClient = OIDCClient(configuration: .demo)

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(oidcClient)
        }
    }
}
