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

public struct SnapshotRow: View {
    private let snapshot: VOSnapshot.Entity

    public init(_ snapshot: VOSnapshot.Entity) {
        self.snapshot = snapshot
    }

    public var body: some View {
        HStack(spacing: VOMetrics.spacingSm) {
            if snapshot.isActive {
                checkmark
            } else {
                spacer
            }
            VOAvatar(name: "V \(snapshot.version)", size: VOMetrics.avatarSize)
            VStack(alignment: .leading, spacing: VOMetrics.spacingXs) {
                Text(snapshot.createTime.relativeDate())
                HStack {
                    VOColorBadge(snapshot.original.size.prettyBytes(), color: .gray400, style: .outline)
                    if snapshot.hasCapabilities {
                        SnapshotCapabilities(snapshot)
                    }
                }
            }
        }
    }

    private var checkmark: some View {
        Image(systemName: "checkmark")
            .foregroundStyle(.blue)
            .fontWeight(.medium)
            .frame(width: 20, height: 20)
    }

    private var spacer: some View {
        Color.clear
            .frame(width: 20, height: 20)
    }
}
