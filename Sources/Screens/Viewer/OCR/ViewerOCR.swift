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

struct ViewerOCR: View {
    @EnvironmentObject private var tokenStore: TokenStore
    @StateObject private var viewerOCRStore = ViewerOCRStore()
    private let file: VOFile.Entity

    init(_ file: VOFile.Entity) {
        self.file = file
    }

    var body: some View {
        VStack {
            if file.type == .file,
                let snapshot = file.snapshot, snapshot.capabilities.ocr,
                let downloadable = snapshot.ocr,
                let fileExtension = downloadable.fileExtension, fileExtension.isPDF(),
                let url = viewerOCRStore.url
            {
                ViewerOCRWebView(url: url)
                    .edgesIgnoringSafeArea(.horizontal)
            }
        }
        .onAppear {
            viewerOCRStore.id = file.id
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
        viewerOCRStore.token = token
    }
}
