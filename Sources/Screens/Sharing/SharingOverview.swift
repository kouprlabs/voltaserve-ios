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

public struct SharingOverview: View, ViewDataProvider, LoadStateProvider, TimerLifecycle, SessionDistributing {
    @EnvironmentObject private var sessionStore: SessionStore
    @StateObject private var sharingStore = SharingStore()
    @ObservedObject private var fileStore: FileStore
    @Environment(\.dismiss) private var dismiss
    @State private var selection: Tag = .users
    @State private var user: VOUser.Entity?
    @State private var group: VOGroup.Entity?
    @State private var permission: VOPermission.Value?
    @State private var userPermissionCount = 0
    @State private var groupPermissionCount = 0
    private let file: VOFile.Entity

    public init(_ file: VOFile.Entity, fileStore: FileStore) {
        self.file = file
        self.fileStore = fileStore
    }

    public var body: some View {
        NavigationStack {
            if #available(iOS 18.0, macOS 15.0, *) {
                TabView(selection: $selection) {
                    Tab("Users", systemImage: "person", value: Tag.users) {
                        SharingUserPermissions(
                            file.id,
                            organization: file.workspace.organization,
                            sharingStore: sharingStore,
                            fileStore: fileStore
                        )
                    }
                    .badge(userPermissionCount)
                    Tab("Groups", systemImage: "person.2", value: Tag.groups) {
                        SharingGroupPermissions(
                            file.id,
                            organization: file.workspace.organization,
                            sharingStore: sharingStore,
                            fileStore: fileStore
                        )
                    }
                    .badge(groupPermissionCount)
                }
                .navigationBarTitleDisplayMode(.inline)
                .navigationTitle("Sharing")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        NavigationLink {
                            if selection == .users {
                                SharingUserForm(
                                    fileIDs: [file.id],
                                    organization: file.workspace.organization,
                                    sharingStore: sharingStore,
                                    fileStore: fileStore
                                )
                            } else if selection == .groups {
                                SharingGroupForm(
                                    fileIDs: [file.id],
                                    organization: file.workspace.organization,
                                    sharingStore: sharingStore,
                                    fileStore: fileStore
                                )
                            }
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
            }
        }
        .onAppear {
            sharingStore.fileID = file.id
            if let session = sessionStore.session {
                assignSessionToStores(session)
                startTimers()
                onAppearOrChange()
            }
        }
        .onDisappear {
            stopTimers()
        }
        .onChange(of: sharingStore.session) { _, newSession in
            if let newSession {
                assignSessionToStores(newSession)
                onAppearOrChange()
            }
        }
        .onChange(of: sharingStore.userPermissions) { _, newUserPermissions in
            if let newUserPermissions, newUserPermissions.count > 0 {
                userPermissionCount = newUserPermissions.count
            } else {
                userPermissionCount = 0
            }
        }
        .onChange(of: sharingStore.groupPermissions) { _, newGroupPermissions in
            if let newGroupPermissions, newGroupPermissions.count > 0 {
                groupPermissionCount = newGroupPermissions.count
            } else {
                groupPermissionCount = 0
            }
        }
    }

    private enum Tag {
        case users
        case groups
    }

    // MARK: - LoadStateProvider

    public var isLoading: Bool {
        sharingStore.userPermissionsIsLoadingFirstTime || sharingStore.groupPermissionsIsLoadingFirstTime
    }

    public var error: String? {
        sharingStore.userPermissionsError ?? sharingStore.groupPermissionsError
    }

    // MARK: - ViewDataProvider

    public func onAppearOrChange() {
        fetchData()
    }

    public func fetchData() {
        sharingStore.fetchUserPermissions()
        sharingStore.fetchGroupPermissions()
    }

    // MARK: - TimerLifecycle

    public func startTimers() {
        sharingStore.startTimer()
    }

    public func stopTimers() {
        sharingStore.stopTimer()
    }

    // MARK: - SessionDistributing

    public func assignSessionToStores(_ session: VOSession.Value) {
        sharingStore.session = session
    }
}
