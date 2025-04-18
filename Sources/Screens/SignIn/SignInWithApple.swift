// Copyright (c) 2024 Anass Bouassaba.
//
// Use of this software is governed by the Business Source License
// included in the file LICENSE in the root of this repository.
//
// As of the Change Date specified in that file, in accordance with
// the Business Source License, use of this software will be governed
// by the GNU Affero General Public License v3.0 only, included in the file
// AGPL-3.0-only in the root of this repository.

import AuthenticationServices
import SwiftUI

public struct SignInWithApple: View, ErrorPresentable {
    @EnvironmentObject private var sessionStore: SessionStore
    @State private var isProcessing = false
    @Environment(\.colorScheme) private var colorScheme
    private let extensions: () -> AnyView
    private let onCompletion: (() -> Void)?

    public init(
        @ViewBuilder extensions: @escaping () -> AnyView = { AnyView(EmptyView()) },
        onCompletion: (() -> Void)? = nil
    ) {
        self.extensions = extensions
        self.onCompletion = onCompletion
    }

    public var body: some View {
        VStack(spacing: VOMetrics.spacingXl) {
            VOLogo(isGlossy: true, size: .init(width: 100, height: 100))
            SignInWithAppleButton(
                .signIn,
                onRequest: { request in
                    request.requestedScopes = [.email, .fullName]
                },
                onCompletion: { result in
                    switch result {
                    case .success(let authResults):
                        if let credential = authResults.credential as? ASAuthorizationAppleIDCredential,
                            let identityKey = credential.identityToken,
                            let appleKey = String(data: identityKey, encoding: .utf8)
                        {
                            Task {
                                await performSignIn(
                                    appleKey,
                                    fullName: [credential.fullName?.givenName, credential.fullName?.familyName]
                                        .compactMap { $0 }
                                        .joined(separator: " ")
                                )
                            }
                        } else {
                            errorMessage = "Failed to parse Apple credentials."
                            errorIsPresented = true
                        }
                    case .failure(let error):
                        errorMessage = error.localizedDescription
                        errorIsPresented = true
                    }
                }
            )
            .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
            .frame(width: VOMetrics.formWidth, height: VOButtonMetrics.height)
            .clipShape(RoundedRectangle(cornerRadius: VOButtonMetrics.height / 2))
            .disabled(isProcessing)
            self.extensions()
        }
        .padding()
        .voErrorSheet(isPresented: $errorIsPresented, message: errorMessage)
    }

    private func performSignIn(_ appleKey: String, fullName: String?) async {
        var session: VOSession.Value?
        withErrorHandling {
            session = try await sessionStore.signInWithApple(appleKey: appleKey, fullName: fullName)
            return true
        } before: {
            isProcessing = true
        } success: {
            if let session {
                sessionStore.session = session
                sessionStore.saveInKeychain(session)
                onCompletion?()
            }
        } failure: { message in
            errorMessage = message
            errorIsPresented = true
        } anyways: {
            isProcessing = false
        }
    }

    // MARK: - ErrorPresentable

    @State public var errorIsPresented = false
    @State public var errorMessage: String?
}

#Preview {
    SignInWithApple()
}
