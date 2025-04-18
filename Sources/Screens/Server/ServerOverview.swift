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

public struct ServerOverview: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var servers: [Server]
    @State private var activateConfirmationIsPresented = false
    @State private var deleteConfirmationsIsPresented = false
    @State private var isActivating = false
    @State private var isDeleting = false
    private let server: Server

    public init(_ server: Server) {
        self.server = server
    }

    public var body: some View {
        Form {
            Section(header: VOSectionHeader("Name")) {
                NavigationLink(destination: ServerEditName(server)) {
                    HStack {
                        Text("Name")
                        Spacer()
                        Text(server.name)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Section(header: VOSectionHeader("URLs")) {
                NavigationLink(destination: ServerEditAPIURL(server)) {
                    HStack {
                        Text("API")
                        Spacer()
                        Text(server.apiURL)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .foregroundStyle(.secondary)
                    }
                }
                NavigationLink(destination: ServerEditIdentityProviderURL(server)) {
                    HStack {
                        Text("Identity Provider")
                        Spacer()
                        Text(server.idpURL)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .foregroundStyle(.secondary)
                    }
                }
                NavigationLink(destination: ServerEditIdentityProviderURL(server)) {
                    HStack {
                        Text("Murph")
                        Spacer()
                        Text(server.murphURL)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            NavigationLink(destination: ServerEditSignInStrategy(server)) {
                HStack {
                    Text("Sign In Strategy")
                    Spacer()
                    Text(SignInStrategy(rawValue: server.signInStrategy)!.label)
                        .foregroundStyle(.secondary)
                }
            }
            Section(header: VOSectionHeader("Advanced")) {
                if !server.isActive {
                    Button {
                        activateConfirmationIsPresented = true
                    } label: {
                        HStack {
                            Text("Activate Server")
                            if isActivating {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isProcessing)
                    .confirmationDialog("Activate Server", isPresented: $activateConfirmationIsPresented) {
                        Button("Activate") {
                            performActivate()
                        }
                    } message: {
                        Text("Are you sure you want to activate this server?")
                    }
                }
                Button(role: .destructive) {
                    deleteConfirmationsIsPresented = true
                } label: {
                    HStack {
                        Text("Delete Server")
                        if isDeleting {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .disabled(isProcessing)
                .confirmationDialog("Delete Server", isPresented: $deleteConfirmationsIsPresented) {
                    Button("Delete", role: .destructive) {
                        performDelete()
                        dismiss()
                    }
                } message: {
                    Text("Are you sure you want to delete this server?")
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(server.name)
    }

    private var isProcessing: Bool {
        isDeleting || isActivating
    }

    private func performActivate() {
        isActivating = true
        Task {
            for server in servers.filter({ $0.id != server.id }) {
                server.isActive = false
            }
            servers.first(where: { $0.id == server.id })?.isActive = true
            try? context.save()

            sessionStore.recreateClient()

            DispatchQueue.main.async {
                isActivating = false
                dismiss()
            }
        }
    }

    private func performDelete() {
        isDeleting = true
        Task {
            try? context.delete(model: Server.self, where: #Predicate { $0.id == server.id })
            if server.isActive {
                servers.first?.isActive = true
            }
            try? context.save()
            DispatchQueue.main.async {
                isDeleting = false
                dismiss()
            }
        }
    }
}

#Preview {
    ServerOverview(
        Server(
            id: UUID().uuidString,
            name: "Localhost",
            apiURL: "http://localhost:8080",
            idpURL: "http://localhost:8081",
            murphURL: "http://localhost:8087",
            signInStrategy: SignInStrategy.local.rawValue,
            isActive: true
        ))
}
