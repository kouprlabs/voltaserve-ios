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

public struct SignInWithLocal: View, ErrorPresentable {
    @EnvironmentObject private var sessionStore: SessionStore
    @State private var isProcessing = false
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var signUpIsPresented = false
    @State private var forgotPasswordIsPresented = false
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
        VStack(spacing: VOMetrics.spacing) {
            VOLogo(isGlossy: true, size: .init(width: 100, height: 100))
            TextField("Email", text: $email)
                .voTextField(width: VOMetrics.formWidth)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .disabled(isProcessing)
            SecureField("Password", text: $password)
                .voTextField(width: VOMetrics.formWidth)
                .disabled(isProcessing)
            Button {
                if !email.isEmpty && !password.isEmpty {
                    performSignIn()
                }
            } label: {
                VOButtonLabel(
                    "Sign In",
                    isLoading: isProcessing,
                    progressViewTint: .white
                )
            }
            .voPrimaryButton(width: VOMetrics.formWidth, isDisabled: isProcessing)
            VStack {
                HStack {
                    Text("Don't have an account yet?")
                        .voFormHintText()
                    Button {
                        signUpIsPresented = true
                    } label: {
                        Text("Sign up")
                            .voFormHintLabel()
                    }
                    .disabled(isProcessing)
                }
                HStack {
                    Text("Cannot sign in?")
                        .voFormHintText()
                    Button {
                        forgotPasswordIsPresented = true
                    } label: {
                        Text("Reset password")
                            .voFormHintLabel()
                    }
                    .disabled(isProcessing)
                }
            }
            self.extensions()
        }
        .fullScreenCover(isPresented: $signUpIsPresented) {
            SignUp {
                signUpIsPresented = false
            } onSignIn: {
                signUpIsPresented = false
            }
        }
        .fullScreenCover(isPresented: $forgotPasswordIsPresented) {
            ForgotPassword {
                forgotPasswordIsPresented = false
            } onSignIn: {
                forgotPasswordIsPresented = false
            }
        }
        .padding()
        .voErrorSheet(isPresented: $errorIsPresented, message: errorMessage)
    }

    private func performSignIn() {
        var session: VOSession.Value?
        withErrorHandling {
            session = try await sessionStore.signInWithLocal(username: email, password: password)
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
    SignInWithLocal()
}
