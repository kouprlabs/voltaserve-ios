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

struct FileSheetCreateFolder: ViewModifier {
    @ObservedObject private var fileStore: FileStore
    @ObservedObject private var workspaceStore: WorkspaceStore
    @State private var showCreate = false

    init(fileStore: FileStore, workspaceStore: WorkspaceStore) {
        self.fileStore = fileStore
        self.workspaceStore = workspaceStore
    }

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $showCreate) {
                if let parent = fileStore.current, let workspace = workspaceStore.current {
                    FolderCreate(parentID: parent.id, workspaceId: workspace.id, fileStore: fileStore)
                }
            }
            .sync($fileStore.showCreateFolder, with: $showCreate)
    }
}

extension View {
    func fileSheetCreateFolder(fileStore: FileStore, workspaceStore: WorkspaceStore) -> some View {
        modifier(FileSheetCreateFolder(fileStore: fileStore, workspaceStore: workspaceStore))
    }
}