import SwiftUI

/// Главный экран: список монет с бесконечной прокруткой.
struct CoinListView<ViewModel: CoinListViewModelProtocol>: View {
    @State private var viewModel: ViewModel

    init(viewModel: ViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        content
            .navigationTitle("Рынок")
            .leaderboardButton { viewModel.openLeaderboard() }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { viewModel.openProfile() } label: {
                        if let profile = viewModel.profile {
                            AvatarView(avatar: Avatar(profile: profile), size: 30)
                        } else {
                            Image(systemName: "person.crop.circle")
                        }
                    }
                    .accessibilityLabel("Профиль")
                    .accessibilityIdentifier("profileButton")
                }
            }
            .task { await viewModel.loadInitial() }
            .task { await viewModel.observeProfile() }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            ProgressView("Загружаем рынок…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let message):
            ErrorStateView(message: message) {
                Task { await viewModel.refresh() }
            }
        case .loaded:
            list
        }
    }

    private var list: some View {
        List {
            ForEach(viewModel.coins) { coin in
                Button { viewModel.select(coin) } label: {
                    CoinRowView(coin: coin)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("coin_\(coin.symbol)")
                .onAppear {
                    // Отдельная задача, чтобы загрузка не отменилась, когда строка уедет за экран.
                    Task { await viewModel.loadNextPageIfNeeded(after: coin) }
                }
            }
            footer
        }
        .listStyle(.plain)
        .refreshable { await viewModel.refresh() }
    }

    @ViewBuilder
    private var footer: some View {
        if viewModel.isLoadingNextPage {
            ProgressView()
                .frame(maxWidth: .infinity)
                .listRowSeparator(.hidden)
        } else if let error = viewModel.nextPageError {
            VStack(spacing: 8) {
                Text(error).font(.footnote).foregroundStyle(.secondary)
                Button("Загрузить ещё") {
                    Task { await viewModel.retryNextPage() }
                }
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity)
            .listRowSeparator(.hidden)
        } else if !viewModel.hasMore {
            Text("Это все пары к USDT")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .listRowSeparator(.hidden)
        }
    }
}

struct CoinRowView: View {
    let coin: Coin

    var body: some View {
        HStack(spacing: 12) {
            CoinIconView(baseAsset: coin.baseAsset, size: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(coin.name)
                    .font(.body.weight(.semibold))
                    .lineLimit(1)
                Text("\(coin.pairTitle) · об. $\(coin.quoteVolume.formattedCompact)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 4) {
                Text("$" + coin.lastPrice.formattedPrice)
                    .font(.body.weight(.medium).monospacedDigit())
                PriceChangeBadge(percent: coin.priceChangePercent)
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}
