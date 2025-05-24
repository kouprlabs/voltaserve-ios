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

public struct FileSheetSharing: ViewModifier {
    @ObservedObject private var fileStore: FileStore

    public init(fileStore: FileStore) {
        self.fileStore = fileStore
    }

    public func body(content: Content) -> some View {
        content
            .sheet(isPresented: $fileStore.sharingIsPresented) {
                if let file {
                    SharingOverview(file, fileStore: fileStore)
                } else if fileStore.selection.count > 1,
                    let organization = fileStore.selectionFiles.first?.workspace.organization
                {
                    SharingBatch(Array(fileStore.selection), organization: organization, fileStore: fileStore)
                }
            }
    }

    private var file: VOFile.Entity? {
        if fileStore.selection.count == 1, let file = fileStore.selectionFiles.first {
            return file
        }
        return nil
    }
}

extension View {
    public func fileSheetSharing(fileStore: FileStore) -> some View {
        modifier(FileSheetSharing(fileStore: fileStore))
    }
}
