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
import VoltaserveCore

class MosaicStore: ObservableObject {
    @Published var info: VOMosaic.Info?
    @Published var showError = false
    @Published var errorTitle: String?
    @Published var errorMessage: String?
    private var mosaicClient: VOMosaic?
    private var timer: Timer?
    var fileID: String?

    var token: VOToken.Value? {
        didSet {
            if let token {
                mosaicClient = .init(
                    baseURL: Config.production.apiURL,
                    accessToken: token.accessToken
                )
            }
        }
    }

    private func fetchInfo() async throws -> VOMosaic.Info? {
        guard let fileID else { return nil }
        return try await mosaicClient?.fetchInfo(fileID)
    }

    func fetchInfo() {
        var info: VOMosaic.Info?
        withErrorHandling {
            info = try await self.fetchInfo()
            return true
        } success: {
            self.info = info
        } failure: { message in
            self.errorTitle = "Error: Fetching Mosaic Info"
            self.errorMessage = message
            self.showError = true
        }
    }

    func create() async throws -> VOTask.Entity? {
        guard let fileID else { return nil }
        return try await mosaicClient?.create(fileID)
    }

    func delete() async throws -> VOTask.Entity? {
        guard let fileID else { return nil }
        return try await mosaicClient?.delete(fileID)
    }

    func startTimer() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            Task {
                let info = try await self.fetchInfo()
                if let info {
                    DispatchQueue.main.async {
                        self.info = info
                    }
                }
            }
        }
    }

    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}
