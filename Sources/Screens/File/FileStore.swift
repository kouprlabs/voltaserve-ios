import Combine
import Foundation
import VoltaserveCore

// swiftlint:disable:next type_body_length
class FileStore: ObservableObject {
    @Published var list: VOFile.List?
    @Published var entities: [VOFile.Entity]?
    @Published var current: VOFile.Entity?
    @Published var taskCount: Int?
    @Published var storageUsage: VOStorage.Usage?
    @Published var itemCount: Int?
    @Published var query: VOFile.Query?

    @Published var selection = Set<String>() {
        willSet {
            objectWillChange.send()
        }
    }

    @Published var showRename = false
    @Published var showDelete = false
    @Published var showDownload = false
    @Published var showBrowserForMove = false
    @Published var showBrowserForCopy = false
    @Published var showUploadDocumentPicker = false
    @Published var showDownloadDocumentPicker = false
    @Published var showNewFolder = false
    @Published var showUpload = false
    @Published var showMove = false
    @Published var showCopy = false
    @Published var showSharing = false
    @Published var showSnapshots = false
    @Published var showTasks = false
    @Published var showMosaic = false
    @Published var showInsights = false
    @Published var showInfo = false
    @Published var viewMode: ViewMode = .grid
    @Published var searchText = ""
    @Published var isLoading = false
    @Published var showError = false
    @Published var errorTitle: String?
    @Published var errorMessage: String?
    private var cancellables = Set<AnyCancellable>()
    private var timer: Timer?
    private var fileClient: VOFile?
    private var taskClient: VOTask?
    private var storageClient: VOStorage?
    let searchPublisher = PassthroughSubject<String, Never>()

    var token: VOToken.Value? {
        didSet {
            if let token {
                fileClient = .init(
                    baseURL: Config.production.apiURL,
                    accessToken: token.accessToken
                )
                taskClient = .init(
                    baseURL: Config.production.apiURL,
                    accessToken: token.accessToken
                )
                storageClient = .init(
                    baseURL: Config.production.apiURL,
                    accessToken: token.accessToken
                )
            }
        }
    }

    var selectionFiles: [VOFile.Entity] {
        var files: [VOFile.Entity] = []
        for id in selection {
            let file = entities?.first(where: { $0.id == id })
            if let file {
                files.append(file)
            }
        }
        return files
    }

    init() {
        loadViewModeFromUserDefaults()
        searchPublisher
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink {
                self.query = .init(text: $0)
            }
            .store(in: &cancellables)
    }

    func createFolder(name: String, workspaceID: String, parentID: String) async throws -> VOFile.Entity? {
        try await fileClient?.createFolder(.init(workspaceID: workspaceID, parentID: parentID, name: name))
    }

    func fetch(_ id: String) async throws -> VOFile.Entity? {
        try await fileClient?.fetch(id)
    }

    func fetch() {
        guard let current else { return }
        var file: VOFile.Entity?

        withErrorHandling {
            file = try await self.fetch(current.id)
            return true
        } success: {
            self.current = file
        } failure: { message in
            self.errorTitle = "Error: Fetching File"
            self.errorMessage = message
            self.showError = true
        }
    }

    func fetchList(_ id: String, page: Int = 1, size: Int = Constants.pageSize) async throws -> VOFile.List? {
        try await fileClient?.fetchList(id, options: .init(query: query, page: page, size: size))
    }

    func fetchList(replace: Bool = false) {
        guard let current else { return }

        if isLoading { return }
        isLoading = true

        var nextPage = -1
        var list: VOFile.List?

        withErrorHandling {
            if !self.hasNextPage() { return false }
            nextPage = self.nextPage()
            list = try await self.fetchList(current.id, page: nextPage)
            return true
        } success: {
            self.list = list
            if let list {
                if replace, nextPage == 1 {
                    self.entities = list.data
                } else {
                    self.append(list.data)
                }
            }
        } failure: { message in
            self.errorTitle = "Error: Fetching Files"
            self.errorMessage = message
            self.showError = true
        } anyways: {
            self.isLoading = false
        }
    }

    func fetchTaskCount() async throws -> Int? {
        try await taskClient?.fetchCount()
    }

    func fetchTaskCount() {
        var taskCount: Int?
        withErrorHandling {
            taskCount = try await self.fetchTaskCount()
            return true
        } success: {
            self.taskCount = taskCount
        } failure: { message in
            self.errorTitle = "Error: Fetching Task Count"
            self.errorMessage = message
            self.showError = true
        }
    }

    func fetchStorageUsage() async throws -> VOStorage.Usage? {
        guard let current else { return nil }
        return try await storageClient?.fetchFileUsage(current.id)
    }

    func fetchStorageUsage() {
        var storageUsage: VOStorage.Usage?
        withErrorHandling {
            storageUsage = try await self.fetchStorageUsage()
            return true
        } success: {
            self.storageUsage = storageUsage
        } failure: { message in
            self.errorTitle = "Error: Fetching File Storage Usage"
            self.errorMessage = message
            self.showError = true
        }
    }

    func fetchItemCount() async throws -> Int? {
        guard let current else { return nil }
        return try await fileClient?.fetchCount(current.id)
    }

    func fetchItemCount() {
        var itemCount: Int?
        withErrorHandling {
            itemCount = try await self.fetchItemCount()
            return true
        } success: {
            self.itemCount = itemCount
        } failure: { message in
            self.errorTitle = "Error: Fetching Item Count"
            self.errorMessage = message
            self.showError = true
        }
    }

    func patchName(_ id: String, name: String) async throws -> VOFile.Entity? {
        try await fileClient?.patchName(id, options: .init(name: name))
    }

    func copy(_ ids: [String], to targetID: String) async throws -> VOFile.CopyResult? {
        try await fileClient?.copy(.init(sourceIDs: ids, targetID: targetID))
    }

    func move(_ ids: [String], to targetID: String) async throws -> VOFile.MoveResult? {
        try await fileClient?.move(.init(sourceIDs: ids, targetID: targetID))
    }

    func delete(_ ids: [String]) async throws -> VOFile.DeleteResult? {
        try await fileClient?.delete(.init(ids: ids))
    }

    func upload(_ url: URL, workspaceID: String) async throws -> VOFile.Entity? {
        if let data = try? Data(contentsOf: url) {
            return try await fileClient?.createFile(.init(
                workspaceID: workspaceID,
                name: url.lastPathComponent,
                data: data
            ))
        }
        return nil
    }

    func urlForThumbnail(_ id: String, fileExtension: String) -> URL? {
        fileClient?.urlForThumbnail(id, fileExtension: fileExtension)
    }

    func urlForPreview(_ id: String, fileExtension: String) -> URL? {
        fileClient?.urlForPreview(id, fileExtension: fileExtension)
    }

    func urlForOriginal(_ id: String, fileExtension: String) -> URL? {
        fileClient?.urlForOriginal(id, fileExtension: fileExtension)
    }

    func append(_ newEntities: [VOFile.Entity]) {
        if entities == nil {
            entities = []
        }
        for newEntity in newEntities where !entities!.contains(where: { $0.id == newEntity.id }) {
            entities!.append(newEntity)
        }
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
            if self.isLoading { return }
            if let current = self.current {
                Task {
                    var size = Constants.pageSize
                    if let list = self.list {
                        size = Constants.pageSize * list.page
                    }
                    let list = try await self.fetchList(current.id, page: 1, size: size)
                    if let list {
                        DispatchQueue.main.async {
                            self.entities = list.data
                        }
                    }
                }
            }
            if let current = self.current {
                Task {
                    let file = try await self.fetch(current.id)
                    if let file {
                        DispatchQueue.main.async {
                            self.current = file
                        }
                    }
                }
            }
            Task {
                let taskCount = try await self.fetchTaskCount()
                DispatchQueue.main.async {
                    self.taskCount = taskCount
                }
            }
        }
    }

    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    func isOwnerInSelection(_ selection: Set<String>) -> Bool {
        guard let entities else { return false }
        return entities
            .filter { selection.contains($0.id) }
            .allSatisfy { $0.permission.ge(.owner) }
    }

    func isEditorInSelection(_ selection: Set<String>) -> Bool {
        guard let entities else { return false }
        return entities
            .filter { selection.contains($0.id) }
            .allSatisfy { $0.permission.ge(.editor) }
    }

    func isViewerInSelection(_ selection: Set<String>) -> Bool {
        guard let entities else { return false }
        return entities
            .filter { selection.contains($0.id) }
            .allSatisfy { $0.permission.ge(.viewer) }
    }

    func isFilesInSelection(_ selection: Set<String>) -> Bool {
        guard let entities else { return false }
        return entities
            .filter { selection.contains($0.id) }
            .allSatisfy { $0.type == .file }
    }

    func isInsightsAuthorized(_ file: VOFile.Entity) -> Bool {
        guard let snapshot = file.snapshot else { return false }
        guard let fileExtension = snapshot.original.fileExtension else { return false }
        return file.type == .file &&
            !(file.snapshot?.task?.isPending ?? false) &&
            (fileExtension.isPDF() ||
                fileExtension.isMicrosoftOffice() ||
                fileExtension.isOpenOffice() ||
                fileExtension.isImage()) &&
            ((file.permission.ge(.viewer) && snapshot.entities != nil) ||
                file.permission.ge(.editor))
    }

    func isMosaicAuthorized(_ file: VOFile.Entity) -> Bool {
        guard let snapshot = file.snapshot else { return false }
        guard let fileExtension = snapshot.original.fileExtension else { return false }
        return file.type == .file &&
            !(snapshot.task?.isPending ?? false) &&
            fileExtension.isImage()
    }

    func isSharingAuthorized(_ file: VOFile.Entity) -> Bool {
        file.permission.ge(.owner)
    }

    func isSharingAuthorized(_ selection: Set<String>) -> Bool {
        !selection.isEmpty && isOwnerInSelection(selection)
    }

    func isDeleteAuthorized(_ file: VOFile.Entity) -> Bool {
        file.permission.ge(.owner)
    }

    func isDeleteAuthorized(_ selection: Set<String>) -> Bool {
        !selection.isEmpty && isOwnerInSelection(selection)
    }

    func isMoveAuthorized(_ file: VOFile.Entity) -> Bool {
        file.permission.ge(.editor)
    }

    func isMoveAuthorized(_ selection: Set<String>) -> Bool {
        !selection.isEmpty && isEditorInSelection(selection)
    }

    func isCopyAuthorized(_ file: VOFile.Entity) -> Bool {
        file.permission.ge(.editor)
    }

    func isCopyAuthorized(_ selection: Set<String>) -> Bool {
        !selection.isEmpty && isEditorInSelection(selection)
    }

    func isSnapshotsAuthorized(_ file: VOFile.Entity) -> Bool {
        file.type == .file && file.permission.ge(.owner)
    }

    func isUploadAuthorized(_ file: VOFile.Entity) -> Bool {
        file.type == .file && file.permission.ge(.editor)
    }

    func isDownloadAuthorized(_ file: VOFile.Entity) -> Bool {
        file.type == .file && file.permission.ge(.viewer)
    }

    func isDownloadAuthorized(_ selection: Set<String>) -> Bool {
        !selection.isEmpty && isViewerInSelection(selection) && isFilesInSelection(selection)
    }

    func isRenameAuthorized(_ file: VOFile.Entity) -> Bool {
        file.permission.ge(.editor)
    }

    func isInfoAuthorized(_ file: VOFile.Entity) -> Bool {
        file.permission.ge(.viewer)
    }

    func isToolsAuthorized(_ file: VOFile.Entity) -> Bool {
        isInsightsAuthorized(file) || isMosaicAuthorized(file)
    }

    func isManagementAuthorized(_ file: VOFile.Entity) -> Bool {
        isSharingAuthorized(file) ||
            isSnapshotsAuthorized(file) ||
            isUploadAuthorized(file) ||
            isDownloadAuthorized(file)
    }

    func isOpenAuthorized(_ file: VOFile.Entity) -> Bool {
        file.type == .file && file.permission.ge(.viewer)
    }

    func toggleViewMode() {
        viewMode = viewMode == .list ? .grid : .list
        UserDefaults.standard.set(viewMode.rawValue, forKey: Constants.userDefaultViewModeKey)
    }

    func loadViewModeFromUserDefaults() {
        if let viewMode = UserDefaults.standard.string(forKey: Constants.userDefaultViewModeKey) {
            self.viewMode = ViewMode(rawValue: viewMode)!
        }
    }

    enum ViewMode: String {
        case list
        case grid
    }

    private enum Constants {
        static let pageSize = 10
        static let userDefaultViewModeKey = "com.voltaserve.files.viewMode"
    }
}