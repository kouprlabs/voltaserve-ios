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

struct InsightsSettings: View, TimerLifecycle, SessionDistributing, ErrorPresentable {
    @EnvironmentObject private var sessionStore: SessionStore
    @StateObject private var insightsStore = InsightsStore()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var isPatching = false
    @State private var isDeleting = false
    private let file: VOFile.Entity

    public init(_ file: VOFile.Entity) {
        self.file = file
    }

    public var body: some View {
        NavigationView {
            VStack {
                VStack(spacing: VOMetrics.spacingLg) {
                    if let snapshot = file.snapshot {
                        if snapshot.capabilities.entities {
                            VStack {
                                VStack {
                                    Text("Delete entities from the active snapshot.")
                                    Button {
                                        performDelete()
                                    } label: {
                                        VOButtonLabel("Delete Entities", systemImage: "trash", isLoading: isDeleting)
                                    }
                                    .voDangerButton(isDisabled: isProcessing || !canDelete)
                                }
                                .padding()
                            }
                            .overlay {
                                RoundedRectangle(cornerRadius: VOMetrics.borderRadius)
                                    .strokeBorder(Color.borderColor(colorScheme: colorScheme), lineWidth: 1)
                            }
                        } else {
                            VStack {
                                VStack {
                                    Text("Collect entities for the active snapshot.")
                                    Button {
                                        performCreate()
                                    } label: {
                                        VOButtonLabel("Collect Entities", systemImage: "bolt", isLoading: isPatching)
                                    }
                                    .voSecondaryButton(isDisabled: isProcessing || !canCreate)
                                }
                                .padding()
                            }
                            .overlay {
                                RoundedRectangle(cornerRadius: VOMetrics.borderRadius)
                                    .strokeBorder(Color.borderColor(colorScheme: colorScheme), lineWidth: 1)
                            }
                        }
                    }
                }
                .padding(.horizontal)
                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("Insights")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .disabled(isProcessing)
                }
            }
        }
        .onAppear {
            insightsStore.file = file
            if let session = sessionStore.session {
                assignSessionToStores(session)
                startTimers()
            }
        }
        .onDisappear {
            stopTimers()
        }
        .onChange(of: sessionStore.session) { _, newSession in
            if let newSession {
                assignSessionToStores(newSession)
            }
        }
        .voErrorSheet(isPresented: $errorIsPresented, message: errorMessage)
    }

    private var canCreate: Bool {
        !(file.snapshot?.task?.isPending ?? false) && file.permission.ge(.editor) && file.snapshot?.intent == .document
            && file.snapshot?.language != nil
    }

    private var canDelete: Bool {
        !(file.snapshot?.task?.isPending ?? false) && file.permission.ge(.owner)
    }

    private var isProcessing: Bool {
        isDeleting || isPatching
    }

    private func performCreate() {
        guard let snapshot = file.snapshot else { return }
        guard let language = snapshot.language else { return }
        withErrorHandling {
            _ = try await insightsStore.create(language: language)
            return true
        } before: {
            isPatching = true
        } success: {
            dismiss()
        } failure: { message in
            errorMessage = message
            errorIsPresented = true
        } anyways: {
            isPatching = false
        }
    }

    private func performDelete() {
        withErrorHandling {
            _ = try await insightsStore.delete()
            return true
        } before: {
            isDeleting = true
        } success: {
            dismiss()
        } failure: { message in
            errorMessage = message
            errorIsPresented = true
        } anyways: {
            isDeleting = false
        }
    }

    // MARK: - ErrorPresentable

    @State public var errorIsPresented = false
    @State public var errorMessage: String?

    // MARK: - TimerLifecycle

    public func startTimers() {
        insightsStore.startTimer()
    }

    public func stopTimers() {
        insightsStore.stopTimer()
    }

    // MARK: - SessionDistributing

    public func assignSessionToStores(_ session: VOSession.Value) {
        insightsStore.session = session
    }
}
