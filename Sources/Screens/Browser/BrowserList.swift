// Copyright (c) 2024 Anass Bouassaba.
//
// Use of this software is governed by the Business Source License
// included in the file LICENSE in the root of this repository.
//
// As of the Change Date specified in that file, in accordance with
// the Business Source License, use of this software will be governed
// by the GNU Affero General Public License v3.0 only, included in the file
// AGPL-3.0-only in the root of this repository.

import Combine
import SwiftUI

public struct BrowserList: View, LoadStateProvider, ViewDataProvider, TimerLifecycle, SessionDistributing,
    ListItemScrollable
{
    @EnvironmentObject private var sessionStore: SessionStore
    @StateObject private var browserStore = BrowserStore()
    @State private var tappedItem: VOFile.Entity?
    @State private var searchText = ""
    private let folderID: String
    private let workspace: VOWorkspace.Entity
    private let confirmLabelText: String?
    private let onCompletion: ((String) -> Void)?
    private let onDismiss: (() -> Void)?

    public init(
        _ folderID: String,
        workspace: VOWorkspace.Entity,
        confirmLabelText: String?,
        onCompletion: ((String) -> Void)? = nil,
        onDismiss: (() -> Void)? = nil
    ) {
        self.folderID = folderID
        self.workspace = workspace
        self.confirmLabelText = confirmLabelText
        self.onCompletion = onCompletion
        self.onDismiss = onDismiss
    }

    public var body: some View {
        VStack {
            if isLoading {
                ProgressView()
            } else if let error {
                VOErrorMessage(error)
            } else {
                if let entities = browserStore.entities {
                    Group {
                        if entities.count == 0 {
                            Text("There are no items.")
                                .foregroundStyle(.secondary)
                        } else {
                            List(entities, id: \.displayID) { file in
                                NavigationLink {
                                    BrowserList(
                                        file.id,
                                        workspace: workspace,
                                        confirmLabelText: confirmLabelText,
                                        onCompletion: onCompletion
                                    )
                                    .navigationTitle(file.name)
                                } label: {
                                    FileRow(file)
                                }
                                .onAppear {
                                    onListItemAppear(file.id)
                                }
                                .tag(file.id)
                            }
                            .listStyle(.inset)
                            .navigationDestination(item: $tappedItem) {
                                Viewer($0)
                            }
                        }
                    }
                    .refreshable {
                        browserStore.fetchNextPage(replace: true)
                    }
                    .searchable(text: $searchText)
                    .onChange(of: searchText) {
                        browserStore.searchPublisher.send($1)
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(confirmLabelText ?? "Done") {
                    onCompletion?(folderID)
                }
            }
            if folderID == workspace.rootID {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        onDismiss?()
                    }
                }
            }
        }
        .onAppear {
            browserStore.folderID = folderID
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
        .onChange(of: browserStore.query) {
            browserStore.clear()
            browserStore.fetchNextPage()
        }
    }

    // MARK: - LoadStateProvider

    public var isLoading: Bool {
        browserStore.folderIsLoading
    }

    public var error: String? {
        browserStore.folderError
    }

    // MARK: - ViewDataProvider

    public func onAppearOrChange() {
        fetchData()
    }

    public func fetchData() {
        browserStore.fetchFolder()
        browserStore.fetchNextPage(replace: true)
    }

    // MARK: - TimerLifecycle

    public func startTimers() {
        browserStore.startTimer()
    }

    public func stopTimers() {
        browserStore.stopTimer()
    }

    // MARK: - SessionDistributing

    public func assignSessionToStores(_ session: VOSession.Value) {
        browserStore.session = session
    }

    // MARK: - ListItemScrollable

    public func onListItemAppear(_ id: String) {
        if browserStore.isEntityThreshold(id) {
            browserStore.fetchNextPage()
        }
    }
}
