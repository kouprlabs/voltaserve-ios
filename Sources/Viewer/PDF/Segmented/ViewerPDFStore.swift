import PDFKit
import SwiftUI
import Voltaserve

class ViewerPDFStore: ObservableObject {
    @Published var pdfDocument: PDFDocument?
    @Published var loadedThumbnails: [Int: UIImage] = [:]
    @Published var totalPages = 0
    @Published var currentPage = 1

    private var data: VOFile
    private var file: VOFile.Entity?
    private var randomizer = Randomizer(Constants.fileIds)

    private var fileId: String {
        randomizer.value
    }

    init(config: Config, token: VOToken.Value) {
        data = VOFile(baseURL: config.apiURL, accessToken: token.accessToken)
    }

    func loadPDF() async {
        do {
            let file = try await data.fetch(fileId)
            self.file = file
            if let pages = file.snapshot?.preview?.document?.pages?.count {
                Task { @MainActor in
                    self.totalPages = pages
                    await self.loadPage(at: self.currentPage)
                    await self.preloadSurroundingPages(for: self.currentPage)
                }
            }
        } catch {
            print(error.localizedDescription)
        }
    }

    func loadPage(at index: Int) async {
        guard index > 0, index <= totalPages else { return }
        guard let fileExtension = file?.snapshot?.segmentation?.document?.pages?.fileExtension else { return }

        do {
            let data = try await data.fetchSegmentedPage(
                fileId,
                page: index,
                fileExtension: String(fileExtension.dropFirst())
            )
            if let newDocument = PDFDocument(data: data) {
                Task { @MainActor in
                    self.pdfDocument = newDocument
                    self.currentPage = index
                    await self.preloadSurroundingPages(for: index)
                }
            }
        } catch {
            print(error.localizedDescription)
        }
    }

    func loadThumbnail(for index: Int) async {
        guard index > 0, index <= totalPages else { return }
        guard loadedThumbnails[index] == nil else { return }
        guard let fileExtension = file?.snapshot?.segmentation?.document?.thumbnails?.fileExtension else { return }

        do {
            let data = try await data.fetchSegmentedThumbnail(
                fileId,
                page: index, fileExtension: fileExtension
            )
            if let image = UIImage(data: data) {
                Task { @MainActor in
                    self.loadedThumbnails[index] = image
                    await self.loadThumbnail(for: index + 1)
                }
            }
        } catch {
            print(error.localizedDescription)
        }
    }

    private func isPreloaded(page index: Int) -> Bool {
        // Check if page is preloaded in the local cache.
        pdfDocument?.page(at: index - 1) != nil
    }

    private func preloadSurroundingPages(for index: Int) async {
        guard let fileExtension = file?.snapshot?.segmentation?.document?.pages?.fileExtension else { return }
        let start = max(1, index - Constants.preloadBufferSize)
        let end = min(totalPages, index + Constants.preloadBufferSize)

        for pageNumber in start ... end where !isPreloaded(page: pageNumber) {
            do {
                let data = try await data.fetchSegmentedPage(
                    fileId,
                    page: pageNumber,
                    fileExtension: String(fileExtension.dropFirst())
                )
                // Preload pages silently without affecting loading state of main view.
                if let tempDoc = PDFDocument(data: data) {
                    DispatchQueue.main.async {
                        if self.pdfDocument?.pageCount == 0 {
                            self.pdfDocument = PDFDocument()
                        }
                        // Ensure index is within bounds
                        let targetIndex = min(pageNumber - 1, (self.pdfDocument?.pageCount ?? 0))
                        if targetIndex >= 0, targetIndex < (self.pdfDocument?.pageCount ?? 0) {
                            self.pdfDocument?.insert(tempDoc.page(at: 0)!, at: targetIndex)
                        }
                    }
                }
            } catch {
                print(error.localizedDescription)
            }
        }
    }

    func shuffleFileId() async {
        Task { @MainActor in
            pdfDocument = nil
        }
        randomizer.shuffle()
        await loadPDF()
    }

    private enum Constants {
        static let fileIds = [
            "6A5POegb8wwn7" // human-freedom-index-2022
        ]

        // Number of pages to preload before and after the current page
        static let preloadBufferSize = 5
    }
}