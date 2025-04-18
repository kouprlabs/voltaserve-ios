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

public struct MosaicCreate: View, ErrorPresentable, SessionDistributing {
    @EnvironmentObject private var sessionStore: SessionStore
    @StateObject private var mosaicStore = MosaicStore()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var isCreating = false
    private let fileID: String

    public init(_ fileID: String) {
        self.fileID = fileID
    }

    public var body: some View {
        NavigationStack {
            VStack {
                VStack {
                    ScrollView {
                        // swift-format-ignore
                        // swiftlint:disable:next line_length
                        Text("Create a mosaic to enhance view performance of a large image by splitting it into smaller, manageable tiles. This makes browsing a high-resolution image faster and more efficient.")
                    }
                    Button {
                        performCreate()
                    } label: {
                        VOButtonLabel("Create", isLoading: isCreating)
                    }
                    .voPrimaryButton(isDisabled: isCreating)
                }
                .padding()
            }
            .overlay {
                RoundedRectangle(cornerRadius: VOMetrics.borderRadius)
                    .strokeBorder(Color.borderColor(colorScheme: colorScheme), lineWidth: 1)
            }
            .padding(.horizontal)
            .modifierIfPad {
                $0.padding(.bottom)
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("Mosaic")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .disabled(isCreating)
                }
            }
        }
        .onAppear {
            mosaicStore.fileID = fileID
            if let session = sessionStore.session {
                assignSessionToStores(session)
            }
        }
        .onChange(of: sessionStore.session) { _, newSession in
            if let newSession {
                assignSessionToStores(newSession)
            }
        }
        .presentationDetents([.fraction(0.35)])
        .voErrorSheet(isPresented: $errorIsPresented, message: errorMessage)
    }

    private func performCreate() {
        withErrorHandling {
            _ = try await mosaicStore.create()
            return true
        } before: {
            isCreating = true
        } success: {
            dismiss()
        } failure: { message in
            errorMessage = message
            errorIsPresented = true
        } anyways: {
            isCreating = false
        }
    }

    // MARK: - ErrorPresentable

    @State public var errorIsPresented = false
    @State public var errorMessage: String?

    // MARK: - SessionDistributing

    public func assignSessionToStores(_ session: VOSession.Value) {
        mosaicStore.session = session
    }
}
