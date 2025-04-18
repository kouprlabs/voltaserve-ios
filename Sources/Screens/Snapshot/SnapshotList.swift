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

public struct SnapshotList: View, ViewDataProvider, LoadStateProvider, TimerLifecycle, SessionDistributing,
    ListItemScrollable
{
    @EnvironmentObject private var sessionStore: SessionStore
    @StateObject private var snapshotStore = SnapshotStore()
    @Environment(\.dismiss) private var dismiss
    private let fileID: String

    public init(fileID: String) {
        self.fileID = fileID
    }

    public var body: some View {
        NavigationStack {
            VStack {
                if isLoading {
                    ProgressView()
                } else if let error {
                    VOErrorMessage(error)
                } else {
                    if let entities = snapshotStore.entities {
                        Group {
                            if entities.count == 0 {
                                Text("There are no items.")
                                    .foregroundStyle(.secondary)
                            } else {
                                List(entities, id: \.displayID) { snapshot in
                                    NavigationLink {
                                        SnapshotOverview(
                                            snapshot, snapshotStore: snapshotStore)
                                    } label: {
                                        SnapshotRow(snapshot)
                                            .onAppear {
                                                onListItemAppear(snapshot.id)
                                            }
                                    }
                                    .tag(snapshot.id)
                                }
                            }
                        }
                        .refreshable {
                            snapshotStore.fetchNextPage(replace: true)
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("Snapshots")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            snapshotStore.fileID = fileID
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
    }

    // MARK: - LoadStateProvider

    public var isLoading: Bool {
        snapshotStore.entitiesIsLoadingFirstTime
    }

    public var error: String? {
        snapshotStore.entitiesError
    }

    // MARK: - ViewDataProvider

    public func onAppearOrChange() {
        fetchData()
    }

    public func fetchData() {
        snapshotStore.fetchNextPage(replace: true)
    }

    // MARK: - TimerLifecycle

    public func startTimers() {
        snapshotStore.startTimer()
    }

    public func stopTimers() {
        snapshotStore.stopTimer()
    }

    // MARK: - SessionDistributing

    public func assignSessionToStores(_ session: VOSession.Value) {
        snapshotStore.session = session
    }

    // MARK: - ListItemScrollable

    public func onListItemAppear(_ id: String) {
        if snapshotStore.isEntityThreshold(id) {
            snapshotStore.fetchNextPage()
        }
    }
}
