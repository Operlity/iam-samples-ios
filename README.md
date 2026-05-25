# Operlity IAM iOS Sample

Sample native iOS application showing how to authenticate with Operlity Identity Hub using OpenID Connect Authorization Code + PKCE.

The app intentionally has no third-party dependencies. It uses:

- SwiftUI for the sample UI
- `ASWebAuthenticationSession` for the system browser login flow
- PKCE with SHA-256
- `URLSession` for discovery, token exchange, and userinfo
- Keychain for local token persistence

## Prerequisites

- macOS with Xcode 16 or newer installed
- An Operlity Identity Hub application configured as a public/native client
- iOS 16 or newer simulator or device

After installing Xcode, make sure the command line tools point to Xcode:

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

## Quick Start

1. Open `OperlityIAMSamples.xcodeproj` in Xcode.
2. Update the sample client ID and client secret in `OperlityIAMSamples/Auth/IdentityHubConfiguration.swift`.
3. Select a simulator or a signing team for a physical device.
4. Build and run.
5. Tap **Login with Identity Hub**.

The default issuer is:

```text
https://id.demo.operlity.com
```

The default redirect values are:

```text
operlity-ios-sample://auth/callback
operlity-ios-sample://auth/logout
```

## Identity Hub Configuration

Create an application in Operlity Identity Hub with these settings:

| Setting | Value |
| --- | --- |
| Application type | Web / Confidential Client, if your Identity Hub requires a secret |
| Grant type | Authorization Code |
| PKCE | Required, S256 |
| Client secret | Required |
| Redirect URI | `operlity-ios-sample://auth/callback` |
| Post logout redirect URI | `operlity-ios-sample://auth/logout` |
| Allow offline access | Enabled |
| Scopes | `openid profile email offline_access` |

For a real application, replace the custom URL scheme with one you own and keep it unique to your bundle.

## Project Structure

```text
OperlityIAMSamples.xcodeproj
OperlityIAMSamples/
  Auth/
    IdentityHubConfiguration.swift
    KeychainTokenStore.swift
    OIDCClient.swift
    OIDCModels.swift
    PKCE.swift
  Assets.xcassets
  ContentView.swift
  Info.plist
  OperlityIAMSamplesApp.swift
```

## Authentication Flow

1. The app fetches `/.well-known/openid-configuration` from Identity Hub.
2. The app generates a PKCE verifier, challenge, and state value.
3. `ASWebAuthenticationSession` opens the Identity Hub authorization endpoint.
4. Identity Hub redirects back to `operlity-ios-sample://auth/callback`.
5. The app validates `state` and exchanges the authorization code at the token endpoint.
6. Tokens are stored in Keychain and the user profile is loaded from the userinfo endpoint when available.
7. Logout clears local tokens and opens the Identity Hub end-session endpoint when discovery exposes one.

## Configuration

Edit `OperlityIAMSamples/Auth/IdentityHubConfiguration.swift`:

```swift
static let demo = IdentityHubConfiguration(
    issuer: URL(string: "https://id.demo.operlity.com")!,
    clientID: "ios-sample-client-id",
    clientSecret: "replace-with-your-client-secret",
    redirectURI: URL(string: "operlity-ios-sample://auth/callback")!,
    postLogoutRedirectURI: URL(string: "operlity-ios-sample://auth/logout")!,
    scope: "openid profile email offline_access"
)
```

If you change the redirect scheme, also update `CFBundleURLTypes` in `OperlityIAMSamples/Info.plist`.

## Notes for Open Source Consumers

- Do not commit a real client secret to this public repository. Replace it locally while testing.
- A client secret embedded in an iOS app can be extracted from the app bundle. Use this only because this Identity Hub client requires it for the POC.
- The placeholder client ID is not sensitive, but it must match your Identity Hub application.
- Use Universal Links for production apps when possible. Custom schemes are convenient for samples and demos.
- Token lifetimes, refresh token rotation, and logout behavior are controlled by your Identity Hub application policy.
- Request `offline_access` only when you want Identity Hub to issue refresh tokens.

## Troubleshooting

### `invalid_redirect_uri`

The redirect URI in Identity Hub must exactly match:

```text
operlity-ios-sample://auth/callback
```

### The app does not reopen after login

Confirm `Info.plist` contains the same URL scheme as the redirect URI:

```text
operlity-ios-sample
```

### Issuer mismatch

The app validates that discovery returns the same issuer configured in `IdentityHubConfiguration.swift`. Update the issuer if you point the sample to another Identity Hub environment.

### Xcode command line tools error

If `xcodebuild` reports that only Command Line Tools are active, run:

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```
