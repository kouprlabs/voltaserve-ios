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

public struct ViewerImage: View {
    @EnvironmentObject private var tokenStore: TokenStore
    @StateObject private var viewerImageStore = ViewerImageStore()
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
                ViewerImageWebView(url: url)
                    .edgesIgnoringSafeArea(.horizontal)
            }
        }
        .onAppear {
            viewerImageStore.id = file.id
            if let fileExtension = file.snapshot?.preview?.fileExtension {
                viewerImageStore.fileExtension = String(fileExtension.dropFirst())
            }
            if let token = tokenStore.token {
                assignTokenToStores(token)
            }
        }
        .onChange(of: tokenStore.token) { _, newToken in
            if let newToken {
                assignTokenToStores(newToken)
            }
        }
    }

    private func assignTokenToStores(_ token: VOToken.Value) {
        viewerImageStore.token = token
    }
}
