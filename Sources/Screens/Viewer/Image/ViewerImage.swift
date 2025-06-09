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

public struct ViewerImage: View, SessionDistributing {
    @EnvironmentObject private var sessionStore: SessionStore
    @StateObject private var viewerImageStore = ViewerImageStore()
    @StateObject private var downloadManager = DownloadManager()
    private let file: VOFile.Entity

    public init(_ file: VOFile.Entity) {
        self.file = file
    }

    public var body: some View {
        VStack {
            if file.type == .file,
                let snapshot = file.snapshot, !snapshot.capabilities.mosaic, !snapshot.capabilities.ocr,
                let downloadable = snapshot.preview,
                let fileExtension = downloadable.fileExtension, fileExtension.isImage(),
                let url = viewerImageStore.url
            {
                if let data = downloadManager.downloadedData {
                    ViewerImageWebView(data: data, fileExtension: downloadable.fileExtension)
                        .edgesIgnoringSafeArea(.horizontal)
                } else {
                    VStack(spacing: VOMetrics.spacingSm) {
                        Text("Downloading…")
                            .foregroundStyle(.secondary)
                        ProgressView(value: downloadManager.progress)
                            .progressViewStyle(LinearProgressViewStyle())
                    }
                    .frame(maxWidth: VOMetrics.formWidth)
                    .padding()
                }
            }
        }
        .onAppear {
            viewerImageStore.id = file.id
            if let fileExtension = file.snapshot?.preview?.fileExtension {
                viewerImageStore.fileExtension = String(fileExtension.dropFirst())
            }
            if let session = sessionStore.session {
                assignSessionToStores(session)
            }
            if viewerImageStore.url != nil && downloadManager.downloadedData == nil {
                downloadManager.startDownload(from: viewerImageStore.url!)
            }
        }
        .onChange(of: sessionStore.session) { _, newSession in
            if let newSession {
                assignSessionToStores(newSession)
            }
        }
    }

    // MARK: - SessionDistributing

    public func assignSessionToStores(_ session: VOSession.Value) {
        viewerImageStore.session = session
    }
}
