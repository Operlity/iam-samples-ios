import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var oidcClient: OIDCClient
    @State private var showingProfile = false

    var body: some View {
        NavigationStack {
            ZStack {
                background

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        masthead

                        if oidcClient.isAuthenticated {
                            signedInHome
                        } else {
                            signInPanel
                        }

                        if let errorMessage = oidcClient.errorMessage {
                            errorBanner(errorMessage)
                        }
                    }
                    .padding(22)
                }
            }
            .navigationTitle("Operlity IAM")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if oidcClient.isAuthenticated {
                    Button("Logout") {
                        oidcClient.signOut()
                    }
                    .disabled(oidcClient.isLoading)
                }
            }
            .sheet(isPresented: $showingProfile) {
                ProfileDetailView(
                    displayName: displayName,
                    profile: oidcClient.profile,
                    tokens: oidcClient.tokens,
                    isLoading: oidcClient.isLoading,
                    refreshAction: oidcClient.loadUserProfile,
                    clearAction: {
                        showingProfile = false
                        oidcClient.clearLocalSession()
                    }
                )
            }
        }
    }

    private var background: some View {
        LinearGradient(
            colors: [
                Color(red: 0.94, green: 0.98, blue: 0.96),
                Color(red: 0.91, green: 0.95, blue: 1.00),
                Color(red: 0.99, green: 0.97, blue: 0.92)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var masthead: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(red: 0.09, green: 0.45, blue: 0.34))
                    Image(systemName: "checkmark.shield.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                }
                .frame(width: 48, height: 48)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Operlity Identity")
                        .font(.title2.weight(.bold))
                    Text("iOS native authentication sample")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Text(oidcClient.isAuthenticated ? "Your secure session is active." : "Sign in with Identity Hub to complete the native OIDC flow.")
                .font(.headline)
                .foregroundStyle(.primary.opacity(0.78))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var signInPanel: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Authorization Code + PKCE")
                    .font(.title3.weight(.semibold))
                Text("The app opens a secure system browser, receives the custom-scheme callback, and stores the auth state in Keychain.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 10) {
                capabilityRow(icon: "safari.fill", title: "System browser", value: "AppAuth")
                capabilityRow(icon: "key.fill", title: "Token storage", value: "Keychain")
                capabilityRow(icon: "arrow.triangle.2.circlepath", title: "Refresh", value: "offline_access")
            }

            Button {
                oidcClient.signIn()
            } label: {
                HStack(spacing: 10) {
                    if oidcClient.isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "lock.open.fill")
                    }

                    Text(oidcClient.isLoading ? "Connecting..." : "Login with Identity Hub")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 48)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(red: 0.09, green: 0.45, blue: 0.34))
            .disabled(oidcClient.isLoading)
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.white.opacity(0.55), lineWidth: 1)
        )
    }

    private var signedInHome: some View {
        VStack(alignment: .leading, spacing: 18) {
            Button {
                showingProfile = true
            } label: {
                HStack(spacing: 14) {
                    avatar

                    VStack(alignment: .leading, spacing: 5) {
                        Text(displayName)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        Text(oidcClient.profile?.email ?? "Profile details available")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                .padding(16)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(.white.opacity(0.55), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            HStack(spacing: 12) {
                statusTile(icon: "person.crop.circle.badge.checkmark", title: "Profile", value: profileStatus)
                statusTile(icon: "clock.badge.checkmark", title: "Token", value: tokenStatus)
            }

            Button {
                oidcClient.loadUserProfile()
            } label: {
                Label(oidcClient.isLoading ? "Refreshing..." : "Refresh Profile", systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
            }
            .buttonStyle(.bordered)
            .disabled(oidcClient.isLoading)
        }
    }

    private var avatar: some View {
        ZStack {
            Circle()
                .fill(Color(red: 0.09, green: 0.45, blue: 0.34))
            Text(initials)
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
        }
        .frame(width: 54, height: 54)
    }

    private var displayName: String {
        oidcClient.profile?.name
            ?? oidcClient.profile?.email
            ?? oidcClient.profile?.preferredUsername
            ?? "Signed in user"
    }

    private var initials: String {
        let pieces = displayName
            .split(separator: " ")
            .prefix(2)
            .compactMap(\.first)

        let value = String(pieces).uppercased()
        return value.isEmpty ? "OI" : value
    }

    private var profileStatus: String {
        oidcClient.profile?.subject == nil ? "Pending" : "Loaded"
    }

    private var tokenStatus: String {
        guard let expiresIn = oidcClient.tokens?.expiresIn else {
            return "Active"
        }

        return expiresIn > 0 ? "\(expiresIn / 60)m" : "Renewing"
    }

    private func capabilityRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .frame(width: 28, height: 28)
                .foregroundStyle(Color(red: 0.09, green: 0.45, blue: 0.34))

            Text(title)
                .font(.subheadline.weight(.medium))

            Spacer()

            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(.background.opacity(0.7), in: RoundedRectangle(cornerRadius: 8))
    }

    private func statusTile(icon: String, title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Color(red: 0.09, green: 0.45, blue: 0.34))

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.headline)
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.white.opacity(0.55), lineWidth: 1)
        )
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
            Text(message)
                .font(.footnote)
                .foregroundStyle(.red)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct ProfileDetailView: View {
    let displayName: String
    let profile: UserProfile?
    let tokens: TokenResponse?
    let isLoading: Bool
    let refreshAction: () -> Void
    let clearAction: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    profileHeader

                    detailSection("Profile", rows: [
                        ("Subject", profile?.subject),
                        ("Name", profile?.name),
                        ("Email", profile?.email),
                        ("Username", profile?.preferredUsername)
                    ])

                    detailSection("Session", rows: [
                        ("Token Type", tokens?.tokenType),
                        ("Expires In", tokens?.expiresIn.map { "\($0) seconds" }),
                        ("Refresh Token", tokens?.refreshToken == nil ? nil : "Issued")
                    ])

                    Button(role: .destructive) {
                        clearAction()
                    } label: {
                        Label("Clear Local Session", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(22)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        refreshAction()
                    } label: {
                        Image(systemName: isLoading ? "hourglass" : "arrow.clockwise")
                    }
                    .disabled(isLoading)
                }
            }
        }
    }

    private var profileHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(red: 0.09, green: 0.45, blue: 0.34))
                Image(systemName: "person.fill")
                    .font(.title)
                    .foregroundStyle(.white)
            }
            .frame(width: 64, height: 64)

            Text(displayName)
                .font(.title2.weight(.bold))

            Text(profile?.email ?? "Authenticated with Operlity Identity Hub")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.background, in: RoundedRectangle(cornerRadius: 8))
    }

    private func detailSection(_ title: String, rows: [(String, String?)]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            ForEach(rows, id: \.0) { row in
                VStack(alignment: .leading, spacing: 4) {
                    Text(row.0)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(row.1?.isEmpty == false ? row.1! : "Not returned")
                        .font(.body.monospaced())
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if row.0 != rows.last?.0 {
                    Divider()
                }
            }
        }
        .padding(18)
        .background(.background, in: RoundedRectangle(cornerRadius: 8))
    }
}
