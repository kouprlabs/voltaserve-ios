import SwiftUI
import VoltaserveCore

struct FolderCreate: View {
    @ObservedObject private var fileStore: FileStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var isProcessing = false
    @State private var showError = false
    @State private var errorTitle: String?
    @State private var errorMessage: String?
    private let parentID: String
    private let workspaceId: String

    init(parentID: String, workspaceId: String, fileStore: FileStore) {
        self.workspaceId = workspaceId
        self.parentID = parentID
        self.fileStore = fileStore
    }

    var body: some View {
        NavigationView {
            Form {
                TextField("Name", text: $name)
                    .disabled(isProcessing)
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("New Folder")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if isProcessing {
                        ProgressView()
                    } else {
                        Button("Create") {
                            performCreate()
                        }
                        .disabled(!isValid())
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .voErrorAlert(isPresented: $showError, title: errorTitle, message: errorMessage)
        }
    }

    private var normalizedName: String {
        name.trimmingCharacters(in: .whitespaces)
    }

    private func performCreate() {
        isProcessing = true
        withErrorHandling {
            _ = try await fileStore.createFolder(
                name: normalizedName,
                workspaceID: workspaceId,
                parentID: parentID
            )
            return true
        } success: {
            dismiss()
        } failure: { message in
            errorTitle = "Error: Creating Folder"
            errorMessage = message
            showError = true
        } anyways: {
            isProcessing = false
        }
    }

    private func isValid() -> Bool {
        !normalizedName.isEmpty
    }
}