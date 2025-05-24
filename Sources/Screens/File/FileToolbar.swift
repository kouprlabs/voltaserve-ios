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

public struct FileToolbar: ViewModifier {
    @ObservedObject private var fileStore: FileStore
    @Environment(\.editMode) private var editMode

    public init(fileStore: FileStore) {
        self.fileStore = fileStore
    }

    public func body(content: Content) -> some View {
        content
            .toolbar {
                if fileStore.viewMode == .list {
                    ToolbarItem(placement: .topBarTrailing) {
                        EditButton()
                    }
                    if editMode?.wrappedValue.isEditing == true, fileStore.selection.count > 0 {
                        ToolbarItem(placement: .bottomBar) {
                            fileMenu
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    tasksButton
                }
                if UIDevice.current.userInterfaceIdiom == .phone {
                    ToolbarItem(placement: .bottomBar) {
                        Menu {
                            ForEach(VOFile.SortBy.allCases, id: \.self) { sortBy in
                                Button {
                                    fileStore.sortBy = sortBy
                                    Task.detached {
                                        await try fileStore.syncEntities()
                                    }
                                } label: {
                                    Label(
                                        sortBy.label,
                                        systemImage: fileStore.sortBy == sortBy ? "checkmark" : String()
                                    )
                                }
                            }
                        } label: {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                        }
                    }
                    ToolbarItem(placement: .bottomBar) {
                        Menu {
                            ForEach(VOFile.SortOrder.allCases, id: \.self) { sortOrder in
                                Button {
                                    fileStore.sortOrder = sortOrder
                                    Task.detached {
                                        await try fileStore.syncEntities()
                                    }
                                } label: {
                                    Label(
                                        sortOrder.label,
                                        systemImage: fileStore.sortOrder == sortOrder ? "checkmark" : String()
                                    )
                                }
                            }
                        } label: {
                            Image(systemName: "arrow.up.arrow.down.square")
                        }
                    }
                } else {
                    ToolbarItem(placement: .bottomBar) {
                        Picker(
                            selection: $fileStore.sortBy,
                            label: Image(systemName: "line.3.horizontal.decrease.circle")
                        ) {
                            ForEach(VOFile.SortBy.allCases, id: \.self) { sortBy in
                                Text(sortBy.label).tag(sortBy)
                            }
                        }
                        .pickerStyle(.menu)
                        .onChange(of: fileStore.sortBy) { _ in
                            Task.detached {
                                await try fileStore.syncEntities()
                            }
                        }
                    }
                    ToolbarItem(placement: .bottomBar) {
                        Picker(
                            selection: $fileStore.sortOrder,
                            label: Image(systemName: "arrow.up.arrow.down.square")
                        ) {
                            ForEach(VOFile.SortOrder.allCases, id: \.self) { sortOrder in
                                Text(sortOrder.label).tag(sortOrder)
                            }
                        }
                        .pickerStyle(.menu)
                        .onChange(of: fileStore.sortOrder) { _ in
                            Task.detached {
                                await try fileStore.syncEntities()
                            }
                        }
                    }
                }
                ToolbarItem(placement: .bottomBar) {
                    viewModeToggleButton
                }
                if let file = fileStore.file, file.permission.ge(.editor) {
                    ToolbarItem(placement: .topBarLeading) {
                        FileUploadMenu(fileStore: fileStore) {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
    }

    private var viewModeToggleButton: some View {
        Button {
            fileStore.toggleViewMode()
        } label: {
            Image(systemName: fileStore.viewMode == .list ? "square.grid.2x2" : "list.bullet")
        }
    }

    private var tasksButton: some View {
        ZStack {
            Button {
                fileStore.tasksIsPresented = true
            } label: {
                Image(systemName: "square.3.layers.3d")
            }
            if let taskCount = fileStore.taskCount, taskCount > 0 {
                Circle()
                    .fill(.red)
                    .frame(width: 10, height: 10)
                    .offset(x: 12, y: -10)
            }
        }
    }

    private var fileMenu: some View {
        FileMenu(
            fileStore: fileStore,
            onSharing: {
                fileStore.sharingIsPresented = true
            },
            onUpload: {
                fileStore.uploadDocumentPickerIsPresented = true
            },
            onDownload: {
                fileStore.downloadIsPresented = true
            },
            onDelete: {
                fileStore.deleteConfirmationIsPresented = true
            },
            onRename: {
                fileStore.renameIsPresented = true
            },
            onMove: {
                fileStore.browserForMoveIsPresented = true
            },
            onCopy: {
                fileStore.browserForCopyIsPresented = true
            }
        )
    }
}

extension View {
    public func fileToolbar(fileStore: FileStore) -> some View {
        modifier(FileToolbar(fileStore: fileStore))
    }
}
