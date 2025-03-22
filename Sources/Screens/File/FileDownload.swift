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

public struct FileDownload: View {
    @ObservedObject private var fileStore: FileStore
    @Environment(\.dismiss) private var dismiss
    @State private var urls: [URL] = []
    @State private var isProcessing = true
    @State private var errorIsPresented = false
    @State private var errorSeverity: ErrorSeverity?
    @State private var errorMessage: String?
    private let onCompletion: (([URL]) -> Void)?

    public init(fileStore: FileStore, onCompletion: (([URL]) -> Void)? = nil) {
        self.fileStore = fileStore
        self.onCompletion = onCompletion
    }

    public var body: some View {
        VStack {
            if isProcessing, !errorIsPresented {
                VOSheetProgressView()
                if fileStore.selectionFiles.count > 1 {
                    Text("Downloading (\(fileStore.selectionFiles.count)) items.")
                } else {
                    Text("Downloading item.")
                }
            } else if errorIsPresented, errorSeverity == .full {
                VOErrorIcon()
                if let errorMessage {
                    Text(errorMessage)
                }
                Button {
                    dismiss()
                } label: {
                    VOButtonLabel("Done")
                }
                .voSecondaryButton()
                .padding(.horizontal)
            } else if errorIsPresented, errorSeverity == .partial {
                VOWarningIcon()
                if let errorMessage {
                    Text(errorMessage)
                }
                Button {
                    onCompletion?(urls)
                    dismiss()
                } label: {
                    VOButtonLabel("Continue")
                }
                .voPrimaryButton()
                .padding(.horizontal)
                Button {
                    dismiss()
                } label: {
                    VOButtonLabel("Done")
                }
                .voSecondaryButton()
                .padding(.horizontal)
            }
        }
        .onAppear {
            performDownload()
        }
        .presentationDetents([.fraction(0.25)])
    }

    // swiftlint:disable:next function_body_length
    private func performDownload() {
        let dispatchGroup = DispatchGroup()
        urls.removeAll()
        for file in fileStore.selectionFiles {
            if let snapshot = file.snapshot,
                let fileExtension = snapshot.original.fileExtension,
                let url = fileStore.urlForOriginal(file.id, fileExtension: String(fileExtension.dropFirst()))
            {
                dispatchGroup.enter()
                URLSession.shared.downloadTask(with: url) { localURL, _, error in
                    if let localURL, error == nil {
                        let fileManager = FileManager.default
                        let directoryURL = try? fileManager.url(
                            for: .itemReplacementDirectory,
                            in: .userDomainMask,
                            appropriateFor: localURL,
                            create: true
                        )
                        if let directoryURL {
                            let newLocalURL = directoryURL.appendingPathComponent(file.name)
                            do {
                                try fileManager.moveItem(at: localURL, to: newLocalURL)
                                urls.append(newLocalURL)
                            } catch {}
                        }
                    }
                    dispatchGroup.leave()
                }.resume()
            }
        }
        dispatchGroup.notify(queue: .main) {
            if urls.count == fileStore.selection.count {
                errorIsPresented = false
                isProcessing = false
                onCompletion?(urls)
                dismiss()
            } else {
                let count = fileStore.selection.count - urls.count
                if count > 1 {
                    errorMessage = "Failed to download (\(count)) items."
                } else {
                    errorMessage = "Failed to download item."
                }
                if count < fileStore.selection.count {
                    errorSeverity = .partial
                } else {
                    errorSeverity = .full
                }
                errorIsPresented = true
                isProcessing = false
            }
        }
    }

    private enum ErrorSeverity {
        case full
        case partial
    }
}
