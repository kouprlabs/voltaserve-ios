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

public class ViewerMosaicStore: ObservableObject {
    @Published private(set) var metadata: VOMosaic.Metadata?
    @Published private(set) var zoomLevel: VOMosaic.ZoomLevel?
    @Published private(set) var grid: [[UIImage?]] = []
    private var busy: [[Bool]] = []
    private var mosaicClient: VOMosaic?

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

    public func loadMosaic(_ id: String) async throws {
        let metadata = try await mosaicClient?.fetchMetadata(id)
        if let metadata {
            DispatchQueue.main.async {
                self.metadata = metadata
                if let zoomLevel = self.metadata?.zoomLevels.first {
                    self.zoomLevel = zoomLevel
                    self.allocateGridForZoomLevel(zoomLevel)
                }
            }
        }
    }

    private func allocateGridForZoomLevel(_ zoomLevel: VOMosaic.ZoomLevel) {
        grid = Array(repeating: Array(repeating: nil, count: zoomLevel.cols), count: zoomLevel.rows)
        busy = Array(
            repeating: Array(repeating: false, count: zoomLevel.cols),
            count: zoomLevel.rows
        )
    }

    public func selectZoomLevel(_ zoomLevel: VOMosaic.ZoomLevel) {
        self.zoomLevel = zoomLevel
        allocateGridForZoomLevel(zoomLevel)
    }

    public func loadImageForCell(_ id: String, row: Int, column: Int) {
        guard busy[row][column] == false else { return }
        busy[row][column] = true
        if let zoomLevel, let metadata {
            Task {
                let data = try await mosaicClient?.fetchData(
                    id,
                    zoomLevel: zoomLevel,
                    forCellAtRow: row, column: column,
                    fileExtension: String(metadata.fileExtension.dropFirst())
                )
                if let data {
                    self.busy[row][column] = false
                    DispatchQueue.main.async {
                        self.grid[row][column] = UIImage(data: data)
                    }
                }
            }
        }
    }

    public func unloadImagesOutsideRect(_ visibleRect: CGRect, extraTilesToLoad: Int) {
        guard let zoomLevel else { return }

        for row in 0..<zoomLevel.rows {
            for col in 0..<zoomLevel.cols {
                let size = sizeForCell(row: row, col: col)
                let position = positionForCell(row: row, col: col)
                let frame = frameForCellAt(position: position, size: size)
                if !visibleRect.insetBy(
                    dx: -CGFloat(extraTilesToLoad) * size.width,
                    dy: -CGFloat(extraTilesToLoad) * size.height
                ).intersects(frame) {
                    grid[row][col] = nil
                }
            }
        }
    }

    public func sizeForCell(row: Int, col: Int) -> CGSize {
        if let zoomLevel {
            let tile = zoomLevel.tile
            var size = CGSize(width: tile.width, height: tile.height)
            if row == zoomLevel.rows - 1 {
                size.height = CGFloat(tile.lastRowHeight)
            }
            if col == zoomLevel.cols - 1 {
                size.width = CGFloat(tile.lastColWidth)
            }
            return size
        }
        return .zero
    }

    public func positionForCell(row: Int, col: Int) -> CGPoint {
        if let zoomLevel {
            let tile = zoomLevel.tile
            var position: CGPoint = .zero
            if row == zoomLevel.rows - 1 {
                position.y = CGFloat(row * tile.height + tile.lastRowHeight / 2)
            } else {
                position.y = CGFloat(row * tile.height + tile.height / 2)
            }
            if col == zoomLevel.cols - 1 {
                position.x = CGFloat(col * tile.width + tile.lastColWidth / 2)
            } else {
                position.x = CGFloat(col * tile.width + tile.width / 2)
            }
            return position
        }
        return .zero
    }

    public func frameForCellAt(position: CGPoint, size: CGSize) -> CGRect {
        CGRect(
            x: position.x - (size.width / 2),
            y: position.y - (size.height / 2),
            width: size.width,
            height: size.height
        )
    }
}
