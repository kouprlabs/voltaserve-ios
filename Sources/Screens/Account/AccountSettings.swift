// Copyright (c) 2024 Anass Bouassaba.
//
// Use of this software is governed by the Business Source License
// included in the file LICENSE in the root of this repository.
//
// As of the Change Date specified in that file, in accordance with
// the Business Source License, use of this software will be governed
// by the GNU Affero General Public License v3.0 only, included in the file
// AGPL-3.0-only in the root of this repository.

import SwiftUI

public struct AccountSettings: View, ViewDataProvider, LoadStateProvider {
    @EnvironmentObject private var sessionStore: SessionStore
    @EnvironmentObject private var appearanceStore: AppearanceStore
    @ObservedObject private var accountStore: AccountStore
    @Environment(\.dismiss) private var dismiss
    private let onDelete: (() -> Void)?

    public init(accountStore: AccountStore, onDelete: (() -> Void)? = nil) {
        self.accountStore = accountStore
        self.onDelete = onDelete
    }

    public var body: some View {
        VStack {
            if isLoading {
                ProgressView()
            } else if let error {
                VOErrorMessage(error)
            } else if let identityUser = accountStore.identityUser {
                Form {
                    Section(header: VOSectionHeader("Basics")) {
                        NavigationLink(destination: AccountEditFullName(accountStore: accountStore)) {
                            HStack {
                                Text("Full name")
                                Spacer()
                                Text(identityUser.fullName)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    if Config.shared.isLocalSignIn() {
                        Section(header: VOSectionHeader("Credentials")) {
                            NavigationLink(destination: AccountEditEmail(accountStore: accountStore)) {
                                HStack {
                                    Text("Email")
                                    Spacer()
                                    Text(identityUser.pendingEmail ?? identityUser.email)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            if identityUser.pendingEmail != nil {
                                HStack(spacing: VOMetrics.spacingXs) {
                                    Image(systemName: "exclamationmark.triangle")
                                        .foregroundStyle(Color.yellow400)
                                    Text("Please check your inbox to confirm your email.")
                                        .foregroundStyle(.secondary)
                                }
                                .font(.footnote)
                            }
                            NavigationLink(destination: AccountEditPassword(accountStore: accountStore)) {
                                HStack {
                                    Text("Password")
                                    Spacer()
                                    Text(String(repeating: "•", count: 10))
                                }
                            }
                        }
                    }
                    Section(header: VOSectionHeader("Appearance")) {
                        NavigationLink(
                            destination: AppearanceAccentColorPicker(appearanceStore: appearanceStore)
                        ) {
                            HStack {
                                Text("Accent color")
                                Spacer()
                                AppearanceAccentColorCircle(appearanceStore.accentColor, size: 18)
                            }
                        }
                    }
                    Section(header: VOSectionHeader("Advanced")) {
                        AccountDelete(accountStore: accountStore, onDelete: onDelete)
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("Settings")
        .onAppear {
            accountStore.sessionStore = sessionStore
            if sessionStore.session != nil {
                onAppearOrChange()
            }
        }
        .onChange(of: sessionStore.session) { _, newSession in
            if newSession != nil {
                onAppearOrChange()
            }
        }
    }

    // MARK: - LoadStateProvider

    public var isLoading: Bool {
        accountStore.identityUserIsLoading
    }

    public var error: String? {
        accountStore.identityUserError
    }

    // MARK: - ViewDataProvider

    public func onAppearOrChange() {
        fetchData()
    }

    public func fetchData() {
        accountStore.fetchIdentityUser()
    }
}
