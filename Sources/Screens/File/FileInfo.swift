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

public struct FileInfo: View, ViewDataProvider, LoadStateProvider, TimerLifecycle, SessionDistributing {
    @EnvironmentObject private var sessionStore: SessionStore
    @StateObject private var fileStore = FileStore()
    @Environment(\.dismiss) private var dismiss
    private let file: VOFile.Entity

    public init(_ file: VOFile.Entity) {
        self.file = file
    }

    public var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView()
                } else if let error {
                    VOErrorMessage(error)
                } else {
                    Form {
                        Section(header: VOSectionHeader("Properties")) {
                            NavigationLink {
                                Form {
                                    Text(file.name)
                                }
                                .navigationTitle(file.name)
                            } label: {
                                HStack {
                                    Text("Name")
                                    Spacer()
                                    Text(file.name)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            HStack {
                                Text("Type")
                                Spacer()
                                Text(fileType)
                                    .foregroundStyle(.secondary)
                            }
                            if let fileExtension = file.snapshot?.original.fileExtension {
                                HStack {
                                    Text("Extension")
                                    Spacer()
                                    VOColorBadge(fileExtension, color: .gray300, style: .fill)
                                }
                            }
                            HStack {
                                Text("Permission")
                                Spacer()
                                VOPermissionBadge(file.permission)
                            }
                        }
                        if let image = file.snapshot?.original.image {
                            Section(header: VOSectionHeader("Image")) {
                                HStack {
                                    Text("Dimensions")
                                    Spacer()
                                    Text("\(image.width)x\(image.height)")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        if let document = file.snapshot?.preview?.document ?? file.snapshot?.ocr?.document {
                            Section(header: VOSectionHeader("Document")) {
                                if let page = document.page {
                                    HStack {
                                        Text("Pages")
                                        Spacer()
                                        Text("\(page.count)")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                        if file.type == .folder {
                            HStack {
                                Text("Item Count")
                                Spacer()
                                if let itemCount = fileStore.itemCount {
                                    Text("\(itemCount)")
                                        .foregroundStyle(.secondary)
                                } else {
                                    Text("Calculating…")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        Section(header: VOSectionHeader("Storage")) {
                            VStack(alignment: .leading) {
                                if let storageUsage = fileStore.storageUsage {
                                    // swift-format-ignore
                                    // swiftlint:disable:next line_length
                                    Text("\(storageUsage.bytes.prettyBytes()) of \(storageUsage.maxBytes.prettyBytes()) used")
                                    ProgressView(value: Double(storageUsage.percentage) / 100.0)
                                } else {
                                    Text("Calculating…")
                                    ProgressView()
                                }
                            }
                        }
                        Section(header: VOSectionHeader("Time")) {
                            if let createTime = file.createTime.date?.pretty {
                                HStack {
                                    Text("Create time")
                                    Spacer()
                                    Text(createTime)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            if let updateTime = file.updateTime?.date?.pretty {
                                HStack {
                                    Text("Update time")
                                    Spacer()
                                    Text(updateTime)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("Info")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            fileStore.file = file
            if let session = sessionStore.session {
                assignSessionToStores(session)
                startTimers()
                onAppearOrChange()
            }
        }
        .onDisappear {
            fileStore.clear()
            stopTimers()
        }
    }

    private var fileType: String {
        switch file.type {
        case .file: "File"
        case .folder: "Folder"
        }
    }

    // MARK: - LoadStateProvider

    public var isLoading: Bool {
        fileStore.storageUsageIsLoading || fileStore.itemCountIsLoading
    }

    public var error: String? {
        fileStore.storageUsageError ?? fileStore.itemCountError
    }

    // MARK: - ViewDataProvider

    public func onAppearOrChange() {
        fetchData()
    }

    public func fetchData() {
        fileStore.fetchStorageUsage()
        if file.type == .folder {
            fileStore.fetchItemCount()
        }
    }

    // MARK: - TimerLifecycle

    public func startTimers() {
        fileStore.startTimer()
    }

    public func stopTimers() {
        fileStore.stopTimer()
    }

    // MARK: - SessionDistributing

    public func assignSessionToStores(_ session: VOSession.Value) {
        fileStore.session = session
    }
}
