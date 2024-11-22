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

struct TaskList: View {
    @EnvironmentObject private var tokenStore: TokenStore
    @ObservedObject private var fileStore: FileStore
    @StateObject private var taskStore = TaskStore()
    @Environment(\.dismiss) private var dismiss
    @State private var isDismissingAll = false
    @State private var showError = false
    @State private var errorTitle: String?
    @State private var errorMessage: String?

    init(fileStore: FileStore) {
        self.fileStore = fileStore
    }

    var body: some View {
        NavigationStack {
            if let entities = taskStore.entities {
                Group {
                    if entities.count == 0 {
                        Text("There are no tasks.")
                    } else {
                        List {
                            ForEach(entities, id: \.id) { task in
                                NavigationLink {
                                    TaskOverview(task, taskStore: taskStore, fileStore: fileStore)
                                } label: {
                                    TaskRow(task)
                                        .onAppear {
                                            onListItemAppear(task.id)
                                        }
                                }
                            }
                        }
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
                .navigationTitle("Tasks")
                .refreshable {
                    taskStore.fetchNextPage(replace: true)
                }
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        if isDismissingAll {
                            ProgressView()
                        } else {
                            Button("Dismiss All") {
                                performDismissAll()
                            }
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                    ToolbarItem(placement: .topBarLeading) {
                        if taskStore.isLoading, taskStore.entities != nil {
                            ProgressView()
                        }
                    }
                }
            } else {
                ProgressView()
            }
        }
        .voErrorAlert(
            isPresented: $showError,
            title: taskStore.errorTitle,
            message: taskStore.errorMessage
        )
        .onAppear {
            if let token = tokenStore.token {
                assignTokenToStores(token)
                startTimers()
                onAppearOrChange()
            }
        }
        .onDisappear {
            stopTimers()
        }
        .onChange(of: tokenStore.token) { _, newToken in
            if let newToken {
                assignTokenToStores(newToken)
                onAppearOrChange()
            }
        }
        .sync($taskStore.showError, with: $showError)
    }

    private func onAppearOrChange() {
        fetchData()
    }

    private func fetchData() {
        taskStore.fetchNextPage(replace: true)
    }

    private func assignTokenToStores(_ token: VOToken.Value) {
        taskStore.token = token
    }

    private func startTimers() {
        taskStore.startTimer()
    }

    private func stopTimers() {
        taskStore.stopTimer()
    }

    private func onListItemAppear(_ id: String) {
        if taskStore.isEntityThreshold(id) {
            taskStore.fetchNextPage()
        }
    }

    private func performDismissAll() {
        isDismissingAll = true
        withErrorHandling {
            let result = try await taskStore.dismiss()
            if let result {
                if !result.succeeded.isEmpty {
                    fileStore.fetchTaskCount()
                }
            }
            return true
        } success: {
            taskStore.fetchNextPage(replace: true)
            dismiss()
        } failure: { message in
            errorTitle = "Error: Dismissing All Tasks"
            errorMessage = message
            showError = true
        } anyways: {
            isDismissingAll = false
        }
    }
}
