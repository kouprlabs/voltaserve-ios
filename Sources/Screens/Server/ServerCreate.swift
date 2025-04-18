// Copyright (c) 2024 Anass Bouassaba.
//
// Use of this software is governed by the Business Source License
// included in the file LICENSE in the root of this repository.
//
// As of the Change Date specified in that file, in accordance with
// the Business Source License, use of this software will be governed
// by the GNU Affero General Public License v3.0 only, included in the file
// AGPL-3.0-only in the root of this repository.

import SwiftData
import SwiftUI

public struct ServerCreate: View, FormValidatable {
    @EnvironmentObject private var sessionStore: SessionStore
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) var dismiss
    @Query private var servers: [Server]
    @State private var name = ""
    @State private var apiURL = ""
    @State private var idpURL = ""
    @State private var murphURL = ""
    @State private var signInStrategy = SignInStrategy.apple
    @State private var isProcessing = false

    struct Option: Hashable {
        public var name: String
        public var value: SignInStrategy
    }

    public var body: some View {
        VStack {
            HStack {
                Image(systemName: "info.circle")
                    .foregroundStyle(.tint)
                Link(
                    "Learn how to host your own Voltaserve instance.",
                    destination: URL(string: "https://github.com/kouprlabs/voltaserve")!
                )
            }
            .padding(.horizontal)
            Form {
                Section(header: VOSectionHeader("Details")) {
                    TextField("Name", text: $name)
                        .disabled(isProcessing)
                }
                Section(header: VOSectionHeader("URLs")) {
                    TextField("API URL", text: $apiURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .disabled(isProcessing)
                    TextField("Identity Provider URL", text: $idpURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .disabled(isProcessing)
                    TextField("Murph URL", text: $murphURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .disabled(isProcessing)
                }
                SignInStrategyPicker(selected: $signInStrategy)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("New Server")
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
    }

    private var normalizedName: String {
        name.trimmingCharacters(in: .whitespaces)
    }

    private func performSave() {
        isProcessing = true
        Task {
            let server = Server(
                id: UUID().uuidString,
                name: normalizedName,
                apiURL: apiURL,
                idpURL: idpURL,
                murphURL: murphURL,
                signInStrategy: signInStrategy.rawValue,
                isActive: servers.count == 0
            )
            context.insert(server)
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
        !normalizedName.isEmpty && apiURL.isValidURL() && idpURL.isValidURL()
            && (murphURL.isEmpty || murphURL.isValidURL())
    }
}
