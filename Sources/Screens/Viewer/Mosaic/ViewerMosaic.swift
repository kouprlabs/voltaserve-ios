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

struct ViewerMosaic: View {
    @EnvironmentObject private var tokenStore: TokenStore
    @StateObject private var viewerMosaicStore = ViewerMosaicStore()
    @State private var dragOffset = CGSize.zero
    @State private var lastDragOffset = CGSize.zero
    @State private var showZoomLevelMenu = false
    @State private var selectedZoomLevel: VOMosaic.ZoomLevel?
    private let file: VOFile.Entity

    init(_ file: VOFile.Entity) {
        self.file = file
    }

    var body: some View {
        if file.type == .file,
            let snapshot = file.snapshot,
            let download = snapshot.preview,
            let fileExtension = download.fileExtension, fileExtension.isImage(), snapshot.mosaic != nil
        {
            GeometryReader { geometry in
                let visibleRect = CGRect(
                    origin: CGPoint(x: -dragOffset.width, y: -dragOffset.height),
                    size: geometry.size
                )
                ZStack {
                    if let zoomLevel = viewerMosaicStore.zoomLevel, !viewerMosaicStore.grid.isEmpty {
                        ForEach(0..<zoomLevel.rows, id: \.self) { row in
                            ForEach(0..<zoomLevel.cols, id: \.self) { col in
                                let size = viewerMosaicStore.sizeForCell(row: row, col: col)
                                let position = viewerMosaicStore.positionForCell(row: row, col: col)
                                let frame = viewerMosaicStore.frameForCellAt(position: position, size: size)

                                // Check if the cell is within the visible bounds or the surrounding buffer
                                if visibleRect.insetBy(
                                    dx: -CGFloat(Constants.extraTilesToLoad) * size.width,
                                    dy: -CGFloat(Constants.extraTilesToLoad) * size.height
                                ).intersects(frame) {
                                    if let image = viewerMosaicStore.grid[row][col] {
                                        Image(uiImage: image)
                                            .resizable()
                                            .frame(width: size.width, height: size.height)
                                            .position(
                                                x: position.x + dragOffset.width,
                                                y: position.y + dragOffset.height
                                            )
                                    } else {
                                        Rectangle()
                                            .fill(Color.black)
                                            .frame(width: size.width, height: size.height)
                                            .position(
                                                x: position.x + dragOffset.width,
                                                y: position.y + dragOffset.height
                                            )
                                            .onAppear {
                                                viewerMosaicStore.loadImageForCell(file.id, row: row, column: col)
                                            }
                                    }
                                }
                            }
                        }
                    } else {
                        Rectangle()
                            .fill(Color.gray)
                            .frame(width: geometry.size.width, height: geometry.size.height)
                    }
                }
                .clipped()
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            dragOffset = CGSize(
                                width: lastDragOffset.width + value.translation.width,
                                height: lastDragOffset.height + value.translation.height
                            )
                        }
                        .onEnded { _ in
                            lastDragOffset = dragOffset
                            viewerMosaicStore.unloadImagesOutsideRect(
                                visibleRect,
                                extraTilesToLoad: Constants.extraTilesToLoad
                            )
                        }
                )
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            if let zoomLevels = viewerMosaicStore.info?.metadata.zoomLevels {
                                ForEach(zoomLevels, id: \.index) { zoomLevel in
                                    Button(
                                        action: {
                                            resetMosaicPosition()
                                            viewerMosaicStore.selectZoomLevel(zoomLevel)
                                        },
                                        label: {
                                            Text("\(Int(zoomLevel.scaleDownPercentage))%")
                                        })
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
                .onAppear {
                    if let token = tokenStore.token {
                        assignTokenToStores(token)
                        Task {
                            try await viewerMosaicStore.loadMosaic(file.id)
                        }
                    }
                }
                .onChange(of: tokenStore.token) { _, newToken in
                    if let newToken {
                        assignTokenToStores(newToken)
                    }
                }
            }
        }
    }

    private func assignTokenToStores(_ token: VOToken.Value) {
        viewerMosaicStore.token = token
    }

    private func resetMosaicPosition() {
        dragOffset = .zero
        lastDragOffset = .zero
    }

    private enum Constants {
        static let extraTilesToLoad = 1
    }
}
