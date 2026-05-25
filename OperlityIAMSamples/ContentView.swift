import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var oidcClient: OIDCClient

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.96, green: 0.98, blue: 0.95),
                        Color(red: 0.92, green: 0.96, blue: 0.98)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        header

                        if oidcClient.isAuthenticated {
                            signedInContent
                        } else {
                            signedOutContent
                        }

                        if let errorMessage = oidcClient.errorMessage {
                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundStyle(.red)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    .padding(24)
                }
            }
            .navigationTitle("Operlity IAM")
            .toolbar {
                if oidcClient.isAuthenticated {
                    Button("Logout") {
                        oidcClient.signOut()
                    }
                    .disabled(oidcClient.isLoading)
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("iOS OIDC Sample")
                .font(.largeTitle.bold())

            Text("Authorization Code + PKCE using ASWebAuthenticationSession.")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var signedOutContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Prove a native iOS app can authenticate with Operlity Identity Hub without storing a client secret.")
                .font(.body)
                .foregroundStyle(.secondary)

            Button {
                oidcClient.signIn()
            } label: {
                HStack {
                    if oidcClient.isLoading {
                        ProgressView()
                    }
                    Text(oidcClient.isLoading ? "Connecting..." : "Login with Identity Hub")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(oidcClient.isLoading)
        }
        .padding(20)
        .background(.background, in: RoundedRectangle(cornerRadius: 8))
    }

    private var signedInContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Authenticated")
                    .font(.title2.bold())

                Text(displayName)
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }

            Divider()

            profileRow(title: "Subject", value: oidcClient.profile?.subject)
            profileRow(title: "Email", value: oidcClient.profile?.email)
            profileRow(title: "Username", value: oidcClient.profile?.preferredUsername)
            profileRow(title: "Token Type", value: oidcClient.tokens?.tokenType)

            if let expiresIn = oidcClient.tokens?.expiresIn {
                profileRow(title: "Expires In", value: "\(expiresIn) seconds")
            }

            HStack {
                Button("Refresh Profile") {
                    oidcClient.loadUserProfile()
                }
                .disabled(oidcClient.isLoading)

                Button("Clear Local Session", role: .destructive) {
                    oidcClient.clearLocalSession()
                }
            }
            .buttonStyle(.bordered)
        }
        .padding(20)
        .background(.background, in: RoundedRectangle(cornerRadius: 8))
    }

    private var displayName: String {
        oidcClient.profile?.name
            ?? oidcClient.profile?.email
            ?? oidcClient.profile?.preferredUsername
            ?? "Signed in user"
    }

    private func profileRow(title: String, value: String?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value?.isEmpty == false ? value! : "Not returned")
                .font(.body.monospaced())
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
