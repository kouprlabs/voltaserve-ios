import SwiftUI
import VoltaserveCore

struct FileMove: View {
    @ObservedObject private var fileStore: FileStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var isProcessing = true
    @State private var showError = false
    @State private var errorSeverity: ErrorSeverity?
    @State private var errorMessage: String?
    private let destinationID: String

    init(fileStore: FileStore, to destinationID: String) {
        self.fileStore = fileStore
        self.destinationID = destinationID
    }

    var body: some View {
        VStack {
            if isProcessing, !showError {
                VOSheetProgressView()
                Text("Moving \(fileStore.selection.count) item(s).")
            } else if showError, errorSeverity == .full {
                VOSheetErrorIcon()
                if let errorMessage {
                    Text(errorMessage)
                }
                Button {
                    dismiss()
                } label: {
                    VOButtonLabel("Done")
                }
                .voSecondaryButton(colorScheme: colorScheme)
                .padding(.horizontal)
            } else if showError, errorSeverity == .partial {
                SheetWarningIcon()
                if let errorMessage {
                    Text(errorMessage)
                }
                Button {
                    dismiss()
                } label: {
                    VOButtonLabel("Done")
                }
                .voSecondaryButton(colorScheme: colorScheme)
                .padding(.horizontal)
            }
        }
        .onAppear {
            performMove()
        }
        .presentationDetents([.fraction(0.25)])
    }

    private func performMove() {
        var result: VOFile.MoveResult?
        withErrorHandling {
            result = try await fileStore.move(Array(fileStore.selection), to: destinationID)
            errorSeverity = .full
            if let result {
                if result.failed.isEmpty {
                    return true
                } else {
                    errorMessage = "Failed to move \(result.failed.count) item(s)."
                    if result.failed.count < fileStore.selection.count {
                        errorSeverity = .partial
                    }
                    showError = true
                }
            }
            return false
        } success: {
            showError = false
            dismiss()
        } failure: { _ in
            errorMessage = "Failed to move \(fileStore.selection.count) item(s)."
            errorSeverity = .full
            showError = true
        } anyways: {
            isProcessing = false
        }
    }

    private enum ErrorSeverity {
        case full
        case partial
    }
}