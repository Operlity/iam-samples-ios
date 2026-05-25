import Foundation

struct DiscoveryDocument: Decodable {
    let issuer: String
    let authorizationEndpoint: URL
    let tokenEndpoint: URL
    let userinfoEndpoint: URL?
    let endSessionEndpoint: URL?

    enum CodingKeys: String, CodingKey {
        case issuer
        case authorizationEndpoint = "authorization_endpoint"
        case tokenEndpoint = "token_endpoint"
        case userinfoEndpoint = "userinfo_endpoint"
        case endSessionEndpoint = "end_session_endpoint"
    }
}

struct TokenResponse: Codable {
    let accessToken: String
    let idToken: String?
    let refreshToken: String?
    let tokenType: String
    let expiresIn: Int?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case idToken = "id_token"
        case refreshToken = "refresh_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
    }
}

struct UserProfile: Decodable {
    let subject: String?
    let name: String?
    let email: String?
    let preferredUsername: String?

    enum CodingKeys: String, CodingKey {
        case subject = "sub"
        case name
        case email
        case preferredUsername = "preferred_username"
    }
}

struct AuthenticationResult {
    let tokens: TokenResponse
    let profile: UserProfile?
}
