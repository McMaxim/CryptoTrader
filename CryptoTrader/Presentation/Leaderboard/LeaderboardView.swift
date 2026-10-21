import SwiftUI

/// Рейтинг трейдеров по доходности демо-счёта. Свой профиль закреплён сверху.
struct LeaderboardView<ViewModel: LeaderboardViewModelProtocol>: View {
    @State private var viewModel: ViewModel

    init(viewModel: ViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        content
            .navigationTitle("Рейтинг")
            .task { await viewModel.load() }
            .task { await viewModel.observeProfile() }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            ProgressView("Загружаем рейтинг…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let message):
            ErrorStateView(message: message) {
                Task { await viewModel.load() }
            }
        case .loaded:
            list
        }
    }

    private var list: some View {
        LeaderboardTableView(
            currentUser: viewModel.currentUser,
            entries: viewModel.entries,
            onOpenProfile: { viewModel.openProfile() },
            onRefresh: { await viewModel.load() }
        )
        .ignoresSafeArea(edges: .bottom)
    }
}
