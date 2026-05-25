import Foundation

struct IdentityHubConfiguration {
    let issuer: URL
    let clientID: String
    let redirectURI: URL
    let postLogoutRedirectURI: URL
    let scopes: [String]

    var callbackScheme: String {
        redirectURI.scheme ?? ""
    }

    static let demo = IdentityHubConfiguration(
        issuer: URL(string: "https://ogsiamapp.azurewebsites.net")!,
        clientID: "replace-with-your-client-id",
        redirectURI: URL(string: "com.operlity.iam.samples.ios:/oauthredirect")!,
        postLogoutRedirectURI: URL(string: "com.operlity.iam.samples.ios:/signout-callback")!,
        scopes: ["openid", "profile", "email", "offline_access"]
    )
}
