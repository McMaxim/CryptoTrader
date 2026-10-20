import SwiftUI

extension TradeSide: Identifiable {
    var id: String { rawValue }
}

/// Экран монеты: шапка и кнопки на SwiftUI, стакан — UIKit `UICollectionView`,
/// встроенный через `UIViewRepresentable` (мост UIKit ↔ SwiftUI).
struct CoinDetailView<ViewModel: CoinDetailViewModelProtocol>: View {
    @State private var viewModel: ViewModel

    init(viewModel: ViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        VStack(spacing: 0) {
            CoinHeaderView(coin: viewModel.coin, tickTrend: viewModel.tickTrend)
                .padding(.horizontal)
                .padding(.top, 8)

            PositionSummaryView(
                holding: viewModel.holding,
                cash: viewModel.cash,
                lastPrice: viewModel.coin.lastPrice
            )
            .padding(.horizontal)
            .padding(.vertical, 10)

            orderBookSection
        }
        .safeAreaInset(edge: .bottom) { actionPanel }
        .overlay(alignment: .top) { toast }
        .animation(.spring(duration: 0.35), value: viewModel.toastMessage)
        .navigationTitle(viewModel.coin.pairTitle)
        .navigationBarTitleDisplayMode(.inline)
        .leaderboardButton { viewModel.openLeaderboard() }
        .sheet(item: $viewModel.activeTradeSide) { _ in
            TradeSheetView(viewModel: viewModel)
                .presentationDetents([.large])
        }
        .task { await viewModel.startLiveUpdates() }
        .task { await viewModel.observePortfolio() }
        .task(id: viewModel.toastMessage) {
            guard viewModel.toastMessage != nil else { return }
            do {
                try await Task.sleep(for: .seconds(2.5))
                viewModel.dismissToast()
            } catch {}
        }
    }

    private var orderBookSection: some View {
        VStack(spacing: 6) {
            HStack {
                Text("Стакан")
                    .font(.headline)
                Spacer()
                if let error = viewModel.streamError {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .lineLimit(1)
                } else if viewModel.orderBook != nil {
                    LiveIndicator()
                }
            }

            OrderBookColumnsHeader(baseAsset: viewModel.coin.baseAsset, quoteAsset: viewModel.coin.quoteAsset)

            OrderBookCollectionView(
                orderBook: viewModel.orderBook,
                priceFractionDigits: NumberFormatting.priceFractionDigits(for: viewModel.coin.lastPrice)
            )
            .overlay {
                if viewModel.orderBook == nil {
                    ProgressView()
                }
            }
            .accessibilityIdentifier("orderBook")
        }
        .padding(.horizontal)
    }

    private var actionPanel: some View {
        VStack(spacing: 10) {
            Button { viewModel.showChart() } label: {
                Label("Показать график", systemImage: "chart.xyaxis.line")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("showChartButton")

            HStack(spacing: 12) {
                Button { viewModel.beginTrade(.buy) } label: {
                    Text("Купить").frame(maxWidth: .infinity)
                }
                .tint(.priceUp)
                .accessibilityIdentifier("buyButton")

                Button { viewModel.beginTrade(.sell) } label: {
                    Text("Продать").frame(maxWidth: .infinity)
                }
                .tint(.priceDown)
                .accessibilityIdentifier("sellButton")
            }
            .buttonStyle(.borderedProminent)
            .fontWeight(.semibold)
        }
        .controlSize(.large)
        .padding(.horizontal)
        .padding(.top, 10)
        .padding(.bottom, 4)
        .background(.bar)
    }

    @ViewBuilder
    private var toast: some View {
        if let message = viewModel.toastMessage {
            ToastView(message: message)
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
                .onTapGesture { viewModel.dismissToast() }
        }
    }
}

/// Название, цена со стрелкой направления и изменение за сутки.
struct CoinHeaderView: View {
    let coin: Coin
    let tickTrend: PriceTrend

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                CoinIconView(baseAsset: coin.baseAsset, size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(coin.name).font(.title3.weight(.semibold))
                    Text(coin.pairTitle).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: tickTrend == .down ? "arrow.down" : "arrow.up")
                            .font(.headline)
                            .foregroundStyle(Color.trend(tickTrend))
                            .contentTransition(.symbolEffect(.replace))
                        Text("$" + coin.lastPrice.formattedPrice)
                            .font(.title2.weight(.semibold).monospacedDigit())
                            .contentTransition(.numericText(value: coin.lastPrice.doubleValue))
                    }
                    PriceChangeBadge(percent: coin.priceChangePercent)
                }
                .animation(.snappy, value: coin.lastPrice)
            }

            HStack {
                stat("Макс. 24ч", "$" + coin.highPrice.formattedPrice)
                Spacer()
                stat("Мин. 24ч", "$" + coin.lowPrice.formattedPrice)
                Spacer()
                stat("Оборот 24ч", "$" + coin.quoteVolume.formattedCompact)
            }
        }
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.footnote.weight(.medium).monospacedDigit())
        }
    }
}

/// Позиция пользователя по монете и свободные деньги на демо-счёте.
struct PositionSummaryView: View {
    let holding: Holding?
    let cash: Decimal
    let lastPrice: Decimal

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Ваша позиция").font(.caption).foregroundStyle(.secondary)
                if let holding {
                    Text("\(holding.quantity.formattedQuantity) \(holding.baseAsset) ≈ \((holding.quantity * lastPrice).formattedUSD)")
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                } else {
                    Text("Нет").font(.subheadline.weight(.semibold))
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("Демо-счёт").font(.caption).foregroundStyle(.secondary)
                Text(cash.formattedUSD).font(.subheadline.weight(.semibold).monospacedDigit())
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }
}

struct OrderBookColumnsHeader: View {
    let baseAsset: String
    let quoteAsset: String

    var body: some View {
        HStack(spacing: 8) {
            Text("Цена (\(quoteAsset))").frame(maxWidth: .infinity, alignment: .leading)
            Text("Кол-во (\(baseAsset))").frame(maxWidth: .infinity, alignment: .trailing)
            Text("Сумма (\(quoteAsset))").frame(maxWidth: .infinity, alignment: .trailing)
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .padding(.horizontal, 4)
    }
}

/// Мигающая точка «Live».
struct LiveIndicator: View {
    @State private var isOn = false

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(Color.priceUp)
                .frame(width: 6, height: 6)
                .opacity(isOn ? 1 : 0.3)
            Text("Live").font(.caption.weight(.medium)).foregroundStyle(.secondary)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever()) { isOn = true }
        }
    }
}
