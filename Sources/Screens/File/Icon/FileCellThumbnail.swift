import SwiftUI
import VoltaserveCore

struct FileCellThumbnail<FallbackContent: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    private let url: URL
    private let fallback: () -> FallbackContent
    private let file: VOFile.Entity

    init(url: URL, file: VOFile.Entity, @ViewBuilder fallback: @escaping () -> FallbackContent) {
        self.url = url
        self.fallback = fallback
        self.file = file
    }

    var body: some View {
        AsyncImage(url: url) { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: VOMetrics.borderRadiusSm))
                .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: VOMetrics.borderRadiusSm))
                .fileActions(file)
                .overlay {
                    RoundedRectangle(cornerRadius: VOMetrics.borderRadiusSm)
                        .stroke(Color.borderColor(colorScheme: colorScheme), lineWidth: 1)
                }
                .fileCellAdornments(file)
                .frame(maxWidth: FileCellMetrics.frameSize.width, maxHeight: FileCellMetrics.frameSize.height)
        } placeholder: {
            fallback()
        }
    }
}