import SwiftUI
import VoltaserveCore

struct SharingOverview: View {
    @StateObject private var sharingStore = SharingStore()
    @EnvironmentObject private var tokenStore: TokenStore
    @Environment(\.dismiss) private var dismiss
    @State private var selection: Tag = .users
    @State private var user: VOUser.Entity?
    @State private var group: VOGroup.Entity?
    @State private var permission: VOPermission.Value?
    @State private var userPermissionCount = 0
    @State private var groupPermissionCount = 0
    private let file: VOFile.Entity

    init(_ file: VOFile.Entity) {
        self.file = file
    }

    var body: some View {
        NavigationStack {
            TabView(selection: $selection) {
                Tab("Users", systemImage: "person", value: Tag.users) {
                    SharingUserList(file)
                }
                .badge(userPermissionCount)
                Tab("Groups", systemImage: "person.2", value: Tag.groups) {
                    SharingGroupList(file)
                }
                .badge(groupPermissionCount)
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("Sharing")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        if selection == .users {
                            SharingUserPermission(files: [file])
                        } else if selection == .groups {
                            SharingGroupPermission(files: [file])
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
            .onAppear {
                if let token = tokenStore.token {
                    sharingStore.token = token
                    sharingStore.file = file
                    onAppearOrChange()
                }
            }
            .onDisappear {
                sharingStore.stopTimer()
            }
            .onChange(of: sharingStore.token) { _, newToken in
                if let newToken {
                    sharingStore.token = newToken
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
        .environmentObject(sharingStore)
    }

    private func onAppearOrChange() {
        sharingStore.fetchUserPermissions()
        sharingStore.fetchGroupPermissions()
        sharingStore.startTimer()
    }

    enum Tag {
        case users
        case groups
    }
}