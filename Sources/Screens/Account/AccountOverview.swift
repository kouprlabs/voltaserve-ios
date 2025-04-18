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
import UniformTypeIdentifiers

public struct AccountOverview: View, ViewDataProvider, LoadStateProvider, TimerLifecycle, SessionDistributing {
    @EnvironmentObject private var sessionStore: SessionStore
    @StateObject private var accountStore = AccountStore()
    @StateObject private var invitationStore = InvitationStore()
    @Environment(\.dismiss) private var dismiss
    @State private var picturePickerIsPresented = false
    @State private var pictureUploadIsLoading = false
    @State private var pictureErrorIsPresented = false
    @State private var pictureErrorMessage: String?

    public var body: some View {
        NavigationStack {
            VStack {
                if isLoading {
                    ProgressView()
                } else if let error {
                    VStack {
                        VOErrorMessage(error)
                        Button {
                            performSignOut()
                        } label: {
                            VOButtonLabel("Sign Out")
                        }
                        .voButton(color: .red500)
                        .fixedSize()
                        .padding(.horizontal)
                    }
                } else {
                    if let identityUser = accountStore.identityUser {
                        if pictureUploadIsLoading {
                            ProgressView()
                        } else {
                            if identityUser.picture == nil {
                                Button {
                                    picturePickerIsPresented = true
                                } label: {
                                    VOAvatar(
                                        name: identityUser.fullName,
                                        size: 100,
                                        url: accountStore.urlForUserPicture(
                                            identityUser.id,
                                            fileExtension: identityUser.picture?.fileExtension
                                        )
                                    )
                                    .padding()
                                }
                                .buttonStyle(.plain)
                            } else {
                                Menu {
                                    Button {
                                        picturePickerIsPresented = true
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    Button(role: .destructive) {
                                        performDeletePicture()
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                } label: {
                                    VOAvatar(
                                        name: identityUser.fullName,
                                        size: 100,
                                        url: accountStore.urlForUserPicture(
                                            identityUser.id,
                                            fileExtension: identityUser.picture?.fileExtension
                                        )
                                    )
                                    .padding()
                                }
                            }
                        }
                    }
                    Form {
                        Section(header: VOSectionHeader("Storage Usage")) {
                            VStack(alignment: .leading) {
                                if let storageUsage = accountStore.storageUsage {
                                    // swift-format-ignore
                                    // swiftlint:disable:next line_length
                                    Text("\(storageUsage.bytes.prettyBytes()) of \(storageUsage.maxBytes.prettyBytes()) used")
                                    ProgressView(value: Double(storageUsage.percentage) / 100.0)
                                }
                            }
                        }
                        Section {
                            NavigationLink(
                                destination: AccountSettings(accountStore: accountStore) {
                                    dismiss()
                                    performSignOut()
                                }
                            ) {
                                Label("Settings", systemImage: "gear")
                            }
                            NavigationLink(destination: InvitationIncomingList()) {
                                HStack {
                                    Label("Invitations", systemImage: "paperplane")
                                    Spacer()
                                    if let incomingCount = invitationStore.incomingCount, incomingCount > 0 {
                                        VONumberBadge(incomingCount)
                                    }
                                }
                            }
                        }
                        Section {
                            Button("Sign Out", role: .destructive) {
                                performSignOut()
                            }
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("Account")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $picturePickerIsPresented) {
                AccountPhotoPicker { (data: Data, filename: String, mimeType: String) in
                    performUpdatePicture(data: data, filename: filename, mimeType: mimeType)
                }
            }
        }
        .onAppear {
            accountStore.sessionStore = sessionStore
            if let session = sessionStore.session {
                assignSessionToStores(session)
                startTimers()
                onAppearOrChange()
            }
        }
        .onDisappear {
            stopTimers()
        }
        .onChange(of: sessionStore.session) { _, newSession in
            if let newSession {
                assignSessionToStores(newSession)
                onAppearOrChange()
            }
        }
        .voErrorSheet(isPresented: $pictureErrorIsPresented, message: pictureErrorMessage)
    }

    private func performSignOut() {
        sessionStore.session = nil
        sessionStore.deleteFromKeychain()
        dismiss()
    }

    private func performUpdatePicture(data: Data, filename: String, mimeType: String) {
        pictureUploadIsLoading = true
        withErrorHandling {
            _ = try await accountStore.updatePicture(data: data, filename: filename, mimeType: mimeType)
            return true
        } before: {
        } success: {
            accountStore.fetchIdentityUser()
        } failure: { message in
            pictureErrorMessage = message
            pictureErrorIsPresented = true
        } anyways: {
            pictureUploadIsLoading = false
        }
    }

    private func performDeletePicture() {
        pictureUploadIsLoading = true
        withErrorHandling {
            _ = try await accountStore.deletePicture()
            return true
        } before: {
        } success: {
            accountStore.fetchIdentityUser()
        } failure: { message in
            pictureErrorMessage = message
            pictureErrorIsPresented = true
        } anyways: {
            pictureUploadIsLoading = false
        }
    }

    // MARK: - LoadStateProvider

    public var isLoading: Bool {
        accountStore.identityUserIsLoading || accountStore.storageUsageIsLoading
            || invitationStore.incomingCountIsLoading
    }

    public var error: String? {
        accountStore.identityUserError ?? accountStore.storageUsageError ?? invitationStore.incomingCountError
            ?? pictureErrorMessage
    }

    // MARK: - ViewDataProvider

    public func onAppearOrChange() {
        fetchData()
    }

    public func fetchData() {
        accountStore.fetchIdentityUser()
        accountStore.fetchAccountStorageUsage()
        invitationStore.fetchIncomingCount()
    }

    // MARK: - TimerLifecycle

    public func startTimers() {
        accountStore.startTimer()
        invitationStore.startTimer()
    }

    public func stopTimers() {
        accountStore.stopTimer()
        invitationStore.stopTimer()
    }

    // MARK: - SessionDistributing

    public func assignSessionToStores(_ session: VOSession.Value) {
        accountStore.session = session
        invitationStore.session = session
    }
}
