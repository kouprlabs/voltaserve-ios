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

struct SignIn: View {
    @EnvironmentObject private var tokenStore: TokenStore
    @State private var isLoading = false
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var errorTitle: String?
    @State private var errorMessage: String?
    @State private var showSignUp = false
    @State private var showForgotPassword = false
    @State private var showError = false
    private let onCompletion: (() -> Void)?

    init(_ onCompletion: (() -> Void)? = nil) {
        self.onCompletion = onCompletion
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: VOMetrics.spacing) {
                VOLogo(isGlossy: true, size: .init(width: 100, height: 100))
                Text("Sign In to Voltaserve")
                    .voHeading(fontSize: VOMetrics.headingFontSize)
                TextField("Email", text: $email)
                    .voTextField(width: VOMetrics.formWidth)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .disabled(isLoading)
                SecureField("Password", text: $password)
                    .voTextField(width: VOMetrics.formWidth)
                    .disabled(isLoading)
                Button {
                    signIn()
                } label: {
                    VOButtonLabel(
                        "Sign In",
                        isLoading: isLoading,
                        progressViewTint: .white
                    )
                }
                .voPrimaryButton(width: VOMetrics.formWidth, isDisabled: isLoading)
                VStack {
                    HStack {
                        Text("Don't have an account yet?")
                            .voFormHintText()
                        Button {
                            showSignUp = true
                        } label: {
                            Text("Sign Up")
                                .voFormHintLabel()
                        }
                        .disabled(isLoading)
                    }
                    HStack {
                        Text("Cannot sign in?")
                            .voFormHintText()
                        Button {
                            showForgotPassword = true
                        } label: {
                            Text("Reset Password")
                                .voFormHintLabel()
                        }
                        .disabled(isLoading)
                    }
                }
            }
            .fullScreenCover(isPresented: $showSignUp) {
                SignUp {
                    showSignUp = false
                } onSignIn: {
                    showSignUp = false
                }
            }
            .fullScreenCover(isPresented: $showForgotPassword) {
                ForgotPassword {
                    showForgotPassword = false
                } onSignIn: {
                    showForgotPassword = false
                }
            }
            .voErrorAlert(isPresented: $showError, title: errorTitle, message: errorMessage)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(destination: ServerList()) {
                        Label("Server List", systemImage: "gear")
                    }
                }
            }
            .padding()
        }
    }

    private func signIn() {
        isLoading = true

        var token: VOToken.Value?

        withErrorHandling {
            token = try await tokenStore.signIn(username: email, password: password)
            return true
        } success: {
            if let token {
                tokenStore.token = token
                tokenStore.saveInKeychain(token)
                onCompletion?()
            }
        } failure: { message in
            errorTitle = "Error: Signing In"
            errorMessage = message
            showError = true
        } anyways: {
            isLoading = false
        }
    }
}

#Preview {
    SignIn()
}
