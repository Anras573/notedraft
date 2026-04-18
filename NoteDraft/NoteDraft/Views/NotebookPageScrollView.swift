import SwiftUI

/// A horizontally swipeable page container that starts on a selected page
/// so users can move between notebook pages without returning to the list.
struct NotebookPageScrollView: View {
    @ObservedObject var notebookViewModel: NotebookViewModel
    let initialPageIndex: Int
    @State private var selectedPageIndex: Int
    @State private var hasInitializedSelection = false

    init(notebookViewModel: NotebookViewModel, initialPageIndex: Int) {
        self.notebookViewModel = notebookViewModel
        self.initialPageIndex = initialPageIndex
        _selectedPageIndex = State(initialValue: initialPageIndex)
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
                        PageView(viewModel: notebookViewModel.createPageViewModel(for: page))
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .automatic))
                .onAppear {
                    setInitialSelection()
                }
                .onChange(of: selectedPageIndex) { _, newValue in
                    guard let index = clampedPageIndex(preferred: newValue) else { return }
                    notebookViewModel.setCurrentPageIndex(index)
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
        guard !notebookViewModel.notebook.pages.isEmpty else {
            return
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
    }
}

