import Combine
import Foundation
import VoltaserveCore

class BrowserStore: ObservableObject {
    @Published var list: VOFile.List?
    @Published var entities: [VOFile.Entity]?
    @Published var current: VOFile.Entity?
    @Published var query: VOFile.Query?
    private var timer: Timer?

    var token: VOToken.Value? {
        didSet {
            if let token {
                client = .init(
                    baseURL: Config.production.apiURL,
                    accessToken: token.accessToken
                )
            }
        }
    }

    private var client: VOFile?

    func fetch(_ id: String) async throws -> VOFile.Entity? {
        try await client?.fetch(id)
    }

    func fetchList(_ id: String, page: Int = 1, size: Int = Constants.pageSize) async throws -> VOFile.List? {
        try await client?.fetchList(id, options: .init(query: query, page: page, size: size, type: .folder))
    }

    func append(_ newEntities: [VOFile.Entity]) {
        if entities == nil {
            entities = []
        }
        entities!.append(contentsOf: newEntities)
    }

    func clear() {
        entities = nil
        list = nil
    }

    func nextPage() -> Int {
        var page = 1
        if let list {
            if list.page < list.totalPages {
                page = list.page + 1
            } else if list.page == list.totalPages {
                return -1
            }
        }
        return page
    }

    func hasNextPage() -> Bool {
        nextPage() != -1
    }

    func isLast(_ id: String) -> Bool {
        id == entities?.last?.id
    }

    func startTimer() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            if let entities = self.entities, let current = self.current, !entities.isEmpty {
                Task {
                    let list = try await self.fetchList(current.id, page: 1, size: entities.count)
                    if let list {
                        Task { @MainActor in
                            self.entities = list.data
                        }
                    }
                }
            }
            if let current = self.current {
                Task {
                    let file = try await self.fetch(current.id)
                    if let file {
                        Task { @MainActor in
                            self.current = file
                        }
                    }
                }
            }
        }
    }

    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private enum Constants {
        static let pageSize = 10
    }
}