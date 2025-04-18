// Copyright (c) 2024 Anass Bouassaba.
//
// Use of this software is governed by the Business Source License
// included in the file LICENSE in the root of this repository.
//
// As of the Change Date specified in that file, in accordance with
// the Business Source License, use of this software will be governed
// by the GNU Affero General Public License v3.0 only, included in the file
// AGPL-3.0-only in the root of this repository.

import Combine
import Foundation

@MainActor
public class MosaicStore: ObservableObject {
    @Published public var metadata: VOMosaic.Metadata?
    @Published public var metadataIsLoading = false
    @Published public var metadataError: String?
    private var mosaicClient: VOMosaic?
    private var timer: Timer?
    public var fileID: String?

    public var session: VOSession.Value? {
        didSet {
            if let session {
                mosaicClient = .init(
                    baseURL: Config.shared.apiURL,
                    accessKey: session.accessKey
                )
            }
        }
    }

    private func fetchMetadata() async throws -> VOMosaic.Metadata? {
        guard let fileID else { return nil }
        return try await mosaicClient?.fetchMetadata(fileID)
    }

    public func fetchMetadata() {
        var metadata: VOMosaic.Metadata?
        withErrorHandling {
            metadata = try await self.fetchMetadata()
            return true
        } before: {
            self.metadataIsLoading = true
        } success: {
            self.metadata = metadata
            self.metadataError = nil
        } failure: { message in
            self.metadataError = message
        } anyways: {
            self.metadataIsLoading = false
        }
    }

    public func create() async throws -> VOTask.Entity? {
        guard let fileID else { return nil }
        return try await mosaicClient?.create(fileID)
    }

    public func delete() async throws -> VOTask.Entity? {
        guard let fileID else { return nil }
        return try await mosaicClient?.delete(fileID)
    }

    public func startTimer() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            Task.detached {
                if await self.metadata != nil {
                    let metadata = try await self.fetchMetadata()
                    if let metadata {
                        await MainActor.run {
                            self.metadata = metadata
                            self.metadataError = nil
                        }
                    }
                }
            }
        }
    }

    public func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}
