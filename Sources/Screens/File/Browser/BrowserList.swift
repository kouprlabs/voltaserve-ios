import Combine
import SwiftUI
import VoltaserveCore

struct BrowserList: View {
    @EnvironmentObject private var authStore: AuthStore
    @EnvironmentObject private var browserStore: BrowserStore
    @EnvironmentObject private var workspaceStore: WorkspaceStore
    @State private var showError = false
    @State private var errorMessage: String?
    @State private var tappedItem: VOFile.Entity?
    @State private var searchText = ""
    @State private var searchPublisher = PassthroughSubject<String, Never>()
    @State private var cancellables = Set<AnyCancellable>()
    @State private var isLoading = false
    @Binding private var isConfirming: Bool
    private let id: String
    private let onConfirm: (() -> Void)?
    private let onDismiss: (() -> Void)?
    private let confirmationMessage: String?

    init(
        _ id: String,
        onConfirm: (() -> Void)? = nil,
        onDismiss: (() -> Void)? = nil,
        isConfirming: Binding<Bool> = .constant(false),
        confirmationMessage: String? = nil
    ) {
        self.id = id
        self.onConfirm = onConfirm
        self.onDismiss = onDismiss
        _isConfirming = isConfirming
        self.confirmationMessage = confirmationMessage
    }

    var body: some View {
        VStack {
            if let entities = browserStore.entities, !isConfirming {
                VStack {
                    if entities.count == 0 {
                        Text("There are no items.")
                    } else {
                        List {
                            ForEach(entities, id: \.id) { file in
                                NavigationLink {
                                    BrowserList(
                                        file.id,
                                        onConfirm: onConfirm,
                                        onDismiss: onDismiss,
                                        isConfirming: $isConfirming,
                                        confirmationMessage: confirmationMessage
                                    )
                                    .navigationTitle(file.name)
                                } label: {
                                    FileRow(file)
                                }
                                .onAppear { onListItemAppear(file.id) }
                            }
                            if isLoading {
                                HStack {
                                    Spacer()
                                    ProgressView()
                                    Spacer()
                                }
                            }
                        }
                        .listStyle(.inset)
                        .searchable(text: $searchText)
                        .onChange(of: searchText) { searchPublisher.send($1) }
                        .refreshable {
                            fetchList(replace: true)
                        }
                        .navigationDestination(item: $tappedItem) { FileViewer($0) }
                        .alert(VOTextConstants.errorAlertTitle, isPresented: $showError) {
                            Button(VOTextConstants.errorAlertButtonLabel) {}
                        } message: {
                            if let errorMessage {
                                Text(errorMessage)
                            }
                        }
                    }
                }
            } else {
                ProgressView()
                if let confirmationMessage, isConfirming {
                    Text(confirmationMessage)
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { onConfirm?() }
                    .disabled(isConfirming)
            }
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel", role: .cancel) { onDismiss?() }
                    .disabled(isConfirming)
            }
        }
        .onAppear {
            browserStore.clear()
            searchPublisher
                .debounce(for: .seconds(1), scheduler: RunLoop.main)
                .removeDuplicates()
                .sink { browserStore.query = .init(text: $0) }
                .store(in: &cancellables)
            if authStore.token != nil {
                onAppearOrChange()
            }
        }
        .onDisappear {
            browserStore.stopTimer()
            cancellables.forEach { $0.cancel() }
            cancellables.removeAll()
        }
        .onChange(of: authStore.token) { _, newToken in
            if newToken != nil {
                onAppearOrChange()
            }
        }
        .onChange(of: browserStore.query) {
            browserStore.entities = nil
            browserStore.list = nil
            fetchList()
        }
    }

    private func onAppearOrChange() {
        fetchFile()
        fetchList(replace: true)
        browserStore.startTimer()
    }

    private func onListItemAppear(_ id: String) {
        if browserStore.isLast(id) {
            fetchList()
        }
    }

    private func fetchFile() {
        Task {
            do {
                let file = try await browserStore.fetch(id)
                Task { @MainActor in
                    browserStore.current = file
                }
            } catch let error as VOErrorResponse {
                Task { @MainActor in
                    errorMessage = error.userMessage
                    showError = true
                }
            } catch {
                print(error.localizedDescription)
                Task { @MainActor in
                    errorMessage = VOTextConstants.unexpectedErrorOccurred
                    showError = true
                }
            }
        }
    }

    private func fetchList(replace: Bool = false) {
        Task {
            isLoading = true
            defer { isLoading = false }
            do {
                if !browserStore.hasNextPage() { return }
                let nextPage = browserStore.nextPage()
                let list = try await browserStore.fetchList(id, page: nextPage)
                Task { @MainActor in
                    browserStore.list = list
                    if let list {
                        if replace, nextPage == 1 {
                            browserStore.entities = list.data
                        } else {
                            browserStore.append(list.data)
                        }
                    }
                }
            } catch let error as VOErrorResponse {
                Task { @MainActor in
                    errorMessage = error.userMessage
                    showError = true
                }
            } catch {
                print(error.localizedDescription)
                Task { @MainActor in
                    errorMessage = VOTextConstants.unexpectedErrorOccurred
                    showError = true
                }
            }
        }
    }
}