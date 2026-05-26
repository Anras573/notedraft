import Foundation

@MainActor
final class PageViewModelCache {
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
