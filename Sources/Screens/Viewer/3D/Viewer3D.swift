// Copyright (c) 2024 Anass Bouassaba.
//
// Use of this software is governed by the Business Source License
// included in the file LICENSE in the root of this repository.
//
// As of the Change Date specified in that file, in accordance with
// the Business Source License, use of this software will be governed
// by the GNU Affero General Public License v3.0 only, included in the file
// AGPL-3.0-only in the root of this repository.

import GLTFKit2
import SceneKit
import SwiftUI

public struct Viewer3D: View, SessionDistributing {
    @EnvironmentObject private var sessionStore: SessionStore
    @StateObject private var viewer3DStore = Viewer3DStore()
    private let file: VOFile.Entity

    public init(_ file: VOFile.Entity) {
        self.file = file
    }

    public var body: some View {
        VStack {
            if file.type == .file,
                let snapshot = file.snapshot,
                let downloadable = snapshot.preview,
                let fileExtension = downloadable.fileExtension, fileExtension.isGLB(),
                let url = viewer3DStore.url
            {
                Viewer3DRenderer(file: file, url: url)
                    .edgesIgnoringSafeArea(.horizontal)
            }
        }
        .onAppear {
            viewer3DStore.id = file.id
            if let session = sessionStore.session {
                assignSessionToStores(session)
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
        viewer3DStore.session = session
    }
}
