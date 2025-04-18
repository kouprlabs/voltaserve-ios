// Copyright (c) 2024 Anass Bouassaba.
//
// Use of this software is governed by the Business Source License
// included in the file LICENSE in the root of this repository.
//
// As of the Change Date specified in that file, in accordance with
// the Business Source License, use of this software will be governed
// by the GNU Affero General Public License v3.0 only, included in the file
// AGPL-3.0-only in the root of this repository.

import PDFKit
import SwiftUI

public class ViewerAudioStore: ObservableObject {
    @Published public var url: URL?

    public var id: String? {
        didSet {
            url = buildURL(id: id, session: session, fileExtension: fileExtension)
        }
    }

    public var fileExtension: String? {
        didSet {
            url = buildURL(id: id, session: session, fileExtension: fileExtension)
        }
    }

    public var session: VOSession.Value? {
        didSet {
            if let session {
                url = buildURL(id: id, session: session, fileExtension: fileExtension)
            }
        }
    }

    private func buildURL(id: String?, session: VOSession.Value?, fileExtension: String?) -> URL? {
        guard let id, let fileExtension, let session else { return nil }
        return VOFile(
            baseURL: Config.shared.apiURL,
            accessKey: session.accessKey
        ).urlForPreview(id, fileExtension: fileExtension)
    }
}
