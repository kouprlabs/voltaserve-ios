import SwiftUI

struct ForgotPassword: View {
    var onCompleted: (() -> Void)?
    var onSignIn: (() -> Void)?
    @State private var isLoading = false
    @State private var email: String = ""

    init(_ onCompleted: (() -> Void)? = nil, onSignIn: (() -> Void)? = nil) {
        self.onCompleted = onCompleted
        self.onSignIn = onSignIn
    }

    var body: some View {
        VStack(spacing: VOMetrics.spacing) {
            VOLogo(isGlossy: true, size: .init(width: 100, height: 100))
            Text("Forgot Password")
                .voHeading(fontSize: VOMetrics.headingFontSize)
            Text("Please provide your account Email where we can send you the password recovery instructions.")
                .voFormHintText()
                .frame(width: VOMetrics.formWidth)
                .multilineTextAlignment(.center)
            TextField("Email", text: $email)
                .voTextField(width: VOMetrics.formWidth)
                .autocapitalization(.none)
                .autocorrectionDisabled()
                .disabled(isLoading)
            Button {
                isLoading = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    isLoading = false
                    onCompleted?()
                }
            } label: {
                VOButtonLabel(
                    "Send Recovery Instructions",
                    isLoading: isLoading,
                    progressViewTint: .white
                )
            }
            .voButton(width: VOMetrics.formWidth, isDisabled: isLoading)
            HStack {
                Text("Password recovered?")
                    .voFormHintText()
                Button {
                    onSignIn?()
                } label: {
                    Text("Sign In")
                        .voFormHintLabel()
                }
                .disabled(isLoading)
            }
        }
    }
}

#Preview {
    ForgotPassword()
}