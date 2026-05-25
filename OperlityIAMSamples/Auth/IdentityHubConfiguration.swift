import Foundation

struct IdentityHubConfiguration {
    let issuer: URL
    let clientID: String
    let clientSecret: String
    let redirectURI: URL
    let postLogoutRedirectURI: URL
    let scope: String

    var callbackScheme: String {
        redirectURI.scheme ?? ""
    }

    static let demo = IdentityHubConfiguration(
        issuer: URL(string: "https://id.demo.operlity.com")!,
        clientID: "replace-with-your-client-id",
        clientSecret: "replace-with-your-client-secret",
        redirectURI: URL(string: "operlity-ios-sample://auth/callback")!,
        postLogoutRedirectURI: URL(string: "operlity-ios-sample://auth/logout")!,
        scope: "openid profile email offline_access"
    )
}
