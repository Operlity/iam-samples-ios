# Operlity IAM iOS Sample

Sample native iOS application showing how to authenticate with Operlity Identity Hub using AppAuth, OpenID Connect Authorization Code, and PKCE.

The app uses:

- SwiftUI for the sample UI
- AppAuth for discovery, PKCE, browser presentation, redirect handling, token exchange, and refresh
- Keychain for `OIDAuthState` persistence
- `URLSession` for the userinfo call

## Prerequisites

- macOS with Xcode 16 or newer installed
- An Operlity Identity Hub application configured as a Native / Mobile public client
- iOS 16 or newer simulator or device

After installing Xcode, make sure the command line tools point to Xcode:

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

## Quick Start

1. Open `OperlityIAMSamples.xcodeproj` in Xcode.
2. Xcode should resolve the `https://github.com/openid/AppAuth-iOS.git` package automatically.
3. Update the sample values in `OperlityIAMSamples/Auth/IdentityHubConfiguration.swift` if your Identity Hub issuer or API scope differs.
3. Select a simulator or a signing team for a physical device.
4. Build and run.
5. Tap **Login with Identity Hub**.

The default issuer is:

```text
https://ogsiamapp.azurewebsites.net
```

The default redirect values are:

```text
com.operlity.iam.samples.ios:/oauthredirect
com.operlity.iam.samples.ios:/signout-callback
```

## Identity Hub Configuration

Create an application in Operlity Identity Hub with these settings:

| Setting | Value |
| --- | --- |
| Client ID | `replace-with-your-client-id` |
| Application type | Native / Mobile |
| Grant type | Authorization Code |
| PKCE | Required, S256 |
| Client secret | Disabled / not required |
| Redirect URI | `com.operlity.iam.samples.ios:/oauthredirect` |
| Post logout redirect URI | `com.operlity.iam.samples.ios:/signout-callback` |
| Allow offline access | Enabled |
| Refresh token usage | One time only |
| Access token lifetime | `3600` seconds |
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
  Assets.xcassets
  AppDelegate.swift
  ContentView.swift
  Info.plist
  OperlityIAMSamplesApp.swift
```

## Authentication Flow

1. AppAuth discovers Identity Hub endpoints from `/.well-known/openid-configuration`.
2. AppAuth creates the authorization request with PKCE.
3. AppAuth opens the system browser login session.
4. Identity Hub redirects back to `com.operlity.iam.samples.ios:/oauthredirect`.
5. The app forwards that URL to AppAuth with `resumeExternalUserAgentFlow` from both `AppDelegate` and SwiftUI `.onOpenURL`.
6. AppAuth validates state and exchanges the authorization code for tokens.
7. `OIDAuthState` is stored in Keychain and can refresh access tokens with one-time refresh tokens.
8. Logout opens the end-session endpoint and clears local Keychain state.

## Configuration

Edit `OperlityIAMSamples/Auth/IdentityHubConfiguration.swift`:

```swift
static let demo = IdentityHubConfiguration(
    issuer: URL(string: "https://ogsiamapp.azurewebsites.net")!,
    clientID: "replace-with-your-client-id",
    redirectURI: URL(string: "com.operlity.iam.samples.ios:/oauthredirect")!,
    postLogoutRedirectURI: URL(string: "com.operlity.iam.samples.ios:/signout-callback")!,
    scopes: ["openid", "profile", "email", "offline_access"]
)
```

If you change the redirect scheme, also update `CFBundleURLTypes` in `OperlityIAMSamples/Info.plist`.

## Notes for Open Source Consumers

- Native iOS apps are public clients. Do not configure or ship a client secret.
- PKCE is required and is handled by AppAuth.
- The client ID is not sensitive, but it must match your Identity Hub application.
- Use Universal Links for production apps when possible. Custom schemes are convenient for samples and demos.
- Token lifetimes, refresh token rotation, and logout behavior are controlled by your Identity Hub application policy.
- Request `offline_access` only when you want Identity Hub to issue refresh tokens.

## Troubleshooting

### `invalid_redirect_uri`

The redirect URI in Identity Hub must exactly match:

```text
com.operlity.iam.samples.ios:/oauthredirect
```

### The app does not reopen after login

Confirm `Info.plist` contains the same URL scheme as the redirect URI:

```text
com.operlity.iam.samples.ios
```

### Issuer mismatch

The app validates that discovery returns the same issuer configured in `IdentityHubConfiguration.swift`. Update the issuer if you point the sample to another Identity Hub environment.

### Xcode command line tools error

If `xcodebuild` reports that only Command Line Tools are active, run:

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```
