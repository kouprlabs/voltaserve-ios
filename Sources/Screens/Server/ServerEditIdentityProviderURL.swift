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

public struct ServerEditIdentityProviderURL: View, FormValidatable {
    @EnvironmentObject private var sessionStore: SessionStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var value = ""
    @State private var isProcessing = false
    private let server: Server

    public init(_ server: Server) {
        self.server = server
    }

    public var body: some View {
        Form {
            TextField("Identity Provider URL", text: $value)
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("Change Identity Provider URL")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if isProcessing {
                    ProgressView()
                } else {
                    Button("Save") {
                        performSave()
                    }
                    .disabled(!isValid())
                }
            }
        }
        .onAppear {
            value = server.idpURL
        }
    }

    private func performSave() {
        isProcessing = true
        Task {
            server.idpURL = value
            try? context.save()

            sessionStore.recreateClient()

            DispatchQueue.main.async {
                dismiss()
                isProcessing = false
            }
        }
    }

    // MARK: - FormValidatable

    public func isValid() -> Bool {
        value.isValidURL() && value != server.idpURL
    }
}
