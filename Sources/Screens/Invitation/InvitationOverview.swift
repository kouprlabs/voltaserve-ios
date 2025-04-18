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

public struct InvitationOverview: View, SessionDistributing, ErrorPresentable {
    @EnvironmentObject private var sessionStore: SessionStore
    @ObservedObject private var invitationStore: InvitationStore
    @StateObject private var userStore = UserStore()
    @Environment(\.dismiss) private var dismiss
    @State private var deleteConfirmationIsPresented = false
    @State private var declineConfirmationIsPresented = false
    @State private var isAccepting = false
    @State private var isDeclining = false
    @State private var isDeleting = false
    private let invitation: VOInvitation.Entity
    private let isDeletable: Bool
    private let isAcceptableDeclinable: Bool

    public init(
        _ invitation: VOInvitation.Entity,
        invitationStore: InvitationStore,
        isDeletable: Bool = false,
        isAcceptableDeclinable: Bool = false
    ) {
        self.invitation = invitation
        self.invitationStore = invitationStore
        self.isDeletable = isDeletable
        self.isAcceptableDeclinable = isAcceptableDeclinable
    }

    public var body: some View {
        Form {
            if let owner = invitation.owner {
                Section(header: VOSectionHeader("Sender")) {
                    UserRow(
                        owner,
                        pictureURL: userStore.urlForPicture(
                            owner.id,
                            fileExtension: owner.picture?.fileExtension
                        )
                    )
                    HStack {
                        Text("When")
                        Spacer()
                        if let date = invitation.createTime.date {
                            Text(date.pretty)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            Section(header: VOSectionHeader("Receiver")) {
                HStack {
                    Text("Email")
                    Spacer()
                    Text(invitation.email)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("Status")
                    Spacer()
                    InvitationStatusBadge(invitation.status)
                }
            }
            if let organization = invitation.organization {
                Section(header: VOSectionHeader("Organization")) {
                    OrganizationRow(organization)
                }
            }
            Section {
                if isDeletable {
                    Button(role: .destructive) {
                        deleteConfirmationIsPresented = true
                    } label: {
                        HStack {
                            Text("Delete Invitation")
                            if isDeleting {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isProcessing)
                    .confirmationDialog("Delete Invitation", isPresented: $deleteConfirmationIsPresented) {
                        Button("Delete", role: .destructive) {
                            performDelete()
                        }
                    } message: {
                        Text("Are you sure you want to delete this invitation?")
                    }
                }
                if isAcceptableDeclinable {
                    Button {
                        performAccept()
                    } label: {
                        HStack {
                            Text("Accept Invitation")
                            if isAccepting {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isProcessing)
                    Button(role: .destructive) {
                        declineConfirmationIsPresented = true
                    } label: {
                        HStack {
                            Text("Decline Invitation")
                            if isDeclining {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isProcessing)
                    .confirmationDialog("Decline Invitation", isPresented: $declineConfirmationIsPresented) {
                        Button("Decline", role: .destructive) {
                            performDecline()
                        }
                    } message: {
                        Text("Are you sure you want to decline this invitation?")
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("#\(invitation.id)")
        .onAppear {
            userStore.invitationID = invitation.id
            if let session = sessionStore.session {
                assignSessionToStores(session)
            }
        }
        .onChange(of: sessionStore.session) { _, newSession in
            if let newSession {
                assignSessionToStores(newSession)
            }
        }
        .voErrorSheet(isPresented: $errorIsPresented, message: errorMessage)
    }

    private var isProcessing: Bool {
        isAccepting || isDeclining || isDeleting
    }

    private func performAccept() {
        withErrorHandling {
            try await invitationStore.accept(invitation.id)
            return true
        } before: {
            isAccepting = true
        } success: {
            dismiss()
        } failure: { message in
            errorMessage = message
            errorIsPresented = true
        } anyways: {
            isAccepting = false
        }
    }

    private func performDecline() {
        withErrorHandling {
            try await invitationStore.decline(invitation.id)
            return true
        } before: {
            isDeclining = true
        } success: {
            dismiss()
        } failure: { message in
            errorMessage = message
            errorIsPresented = true
        } anyways: {
            isDeclining = false
        }
    }

    private func performDelete() {
        withErrorHandling {
            try await invitationStore.delete(invitation.id)
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

    // MARK: - SessionDistributing

    public func assignSessionToStores(_ session: VOSession.Value) {
        userStore.session = session
    }
}
