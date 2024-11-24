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
import VoltaserveCore

struct WorkspaceOverview: View, ViewDataProvider, LoadStateProvider {
    @EnvironmentObject private var tokenStore: TokenStore
    @ObservedObject private var workspaceStore: WorkspaceStore
    @Environment(\.dismiss) private var dismiss
    private var workspace: VOWorkspace.Entity

    init(_ workspace: VOWorkspace.Entity, workspaceStore: WorkspaceStore) {
        self.workspace = workspace
        self.workspaceStore = workspaceStore
    }

    var body: some View {
        VStack {
            if isLoading {
                ProgressView()
            } else if let error {
                VOErrorMessage(error)
            } else {
                if let current = workspaceStore.current {
                    VStack {
                        VOAvatar(name: workspace.name, size: 100)
                            .padding()
                        Form {
                            NavigationLink {
                                if let root = workspaceStore.root {
                                    FileOverview(root, workspaceStore: workspaceStore)
                                        .navigationTitle(current.name)
                                }
                            } label: {
                                Label("Files", systemImage: "folder")
                            }
                            NavigationLink {
                                WorkspaceSettings(workspaceStore: workspaceStore) {
                                    dismiss()
                                }
                            } label: {
                                Label("Settings", systemImage: "gear")
                            }
                        }
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(workspace.name)
        .onAppear {
            workspaceStore.current = workspace
            onAppearOrChange()
        }
    }

    // MARK: - LoadStateProvider

    var isLoading: Bool {
        workspaceStore.rootIsLoading
    }

    var error: String? {
        workspaceStore.rootError
    }

    // MARK: - ViewDataProvider

    func onAppearOrChange() {
        fetchData()
    }

    func fetchData() {
        workspaceStore.fetchRoot()
    }
}
