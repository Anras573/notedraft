import SwiftUI

/// A horizontally swipeable page container that starts on a selected page
/// so users can move between notebook pages without returning to the list.
struct NotebookPageScrollView: View {
    @ObservedObject var notebookViewModel: NotebookViewModel
    let initialPageIndex: Int
    @State private var selectedPageIndex: Int
    @State private var hasInitializedSelection = false
    @State private var pageViewModelCache = PageViewModelCache()
    @State private var cachedPageCount: Int

    init(notebookViewModel: NotebookViewModel, initialPageIndex: Int) {
        self.notebookViewModel = notebookViewModel
        self.initialPageIndex = initialPageIndex
        _selectedPageIndex = State(initialValue: initialPageIndex)
        _cachedPageCount = State(initialValue: notebookViewModel.notebook.pages.count)
    }

    private var displayedPageIndex: Int? {
        clampedPageIndex(preferred: selectedPageIndex)
    }

    private var navigationTitle: String {
        guard let displayedPageIndex else { return notebookViewModel.notebook.name }
        return "Page \(displayedPageIndex + 1) of \(notebookViewModel.notebook.pages.count)"
    }

    var body: some View {
        Group {
            if notebookViewModel.notebook.pages.isEmpty {
                Text("No pages available.")
                    .foregroundStyle(.secondary)
            } else {
                TabView(selection: $selectedPageIndex) {
                    ForEach(Array(notebookViewModel.notebook.pages.enumerated()), id: \.element.id) { index, page in
                        Group {
                            if shouldLoadPage(at: index) {
                                PageView(viewModel: pageViewModelCache.viewModel(for: page, notebookViewModel: notebookViewModel))
                            } else {
                                Color.clear
                                    .accessibilityHidden(true)
                            }
                        }
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .automatic))
                .onAppear {
                    setInitialSelection()
                }
                .onChange(of: selectedPageIndex) { _, newValue in
                    guard let index = clampedPageIndex(preferred: newValue) else { return }
                    applySelection(at: index)
                }
                .onChange(of: notebookViewModel.notebook.pages.count) { _, _ in
                    ensureValidSelection()
                }
            }
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func setInitialSelection() {
        guard !hasInitializedSelection else { return }
        hasInitializedSelection = true

        guard let boundedIndex = clampedPageIndex(preferred: initialPageIndex) else { return }
        applySelection(at: boundedIndex)
    }

    private func ensureValidSelection() {
        let pageCount = notebookViewModel.notebook.pages.count
        guard pageCount > 0 else {
            pageViewModelCache.clear()
            cachedPageCount = 0
            return
        }

        if pageCount != cachedPageCount {
            pageViewModelCache.prune(keeping: activePageIDs(for: selectedPageIndex, pages: notebookViewModel.notebook.pages))
            cachedPageCount = pageCount
        }

        guard let boundedIndex = clampedPageIndex(preferred: selectedPageIndex) else { return }
        applySelection(at: boundedIndex)
    }

    private func clampedPageIndex(preferred index: Int) -> Int? {
        guard !notebookViewModel.notebook.pages.isEmpty else { return nil }
        return min(max(index, 0), notebookViewModel.notebook.pages.count - 1)
    }

    private func applySelection(at index: Int) {
        selectedPageIndex = index
        notebookViewModel.setCurrentPageIndex(index)
        pageViewModelCache.prune(keeping: activePageIDs(for: index, pages: notebookViewModel.notebook.pages))
    }

    /// Loads only the current page and one neighboring page on each side.
    /// This keeps swiping smooth while avoiding eager creation of all tabs.
    private func shouldLoadPage(at index: Int) -> Bool {
        abs(index - selectedPageIndex) <= 1
    }

    /// Returns page IDs for the currently selected page and its immediate neighbors.
    /// These IDs are retained in the view-model cache and all others are pruned.
    private func activePageIDs(for centerIndex: Int, pages: [Page]) -> Set<UUID> {
        guard !pages.isEmpty else { return [] }
        let lowerBound = max(0, centerIndex - 1)
        let upperBound = min(pages.count - 1, centerIndex + 1)
        return Set((lowerBound...upperBound).map { pages[$0].id })
    }
}

private final class PageViewModelCache {
    private var cache: [UUID: PageViewModel] = [:]

    /// Returns a stable `PageViewModel` instance for the given page.
    /// The first request creates and caches the model; subsequent requests
    /// for the same page ID return that same instance so redraws do not
    /// reset page-level state (e.g. lazy drawing-load flags).
    func viewModel(for page: Page, notebookViewModel: NotebookViewModel) -> PageViewModel {
        if let existing = cache[page.id] {
            return existing
        }

        let created = notebookViewModel.createPageViewModel(for: page)
        cache[page.id] = created
        return created
    }

    func prune(keeping validPageIDs: Set<UUID>) {
        cache = cache.filter { validPageIDs.contains($0.key) }
    }

    func clear() {
        cache.removeAll()
    }
}
