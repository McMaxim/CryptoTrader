import SwiftUI

/// Окно покупки/продажи. Сделка проходит на демо-счёте по текущей лучшей цене стакана.
struct TradeSheetView<ViewModel: CoinDetailViewModelProtocol>: View {
    @Bindable var viewModel: ViewModel
    @FocusState private var isAmountFocused: Bool

    var body: some View {
        NavigationStack {
            if let quote = viewModel.quote {
                form(quote: quote)
                    .navigationTitle(title(for: quote.side))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Отмена") { viewModel.activeTradeSide = nil }
                        }
                    }
                    .safeAreaInset(edge: .bottom) { confirmButton(quote: quote) }
            }
        }
        .onAppear { isAmountFocused = true }
    }

    private func form(quote: TradeQuote) -> some View {
        Form {
            Section {
                LabeledContent("Цена исполнения") {
                    Text("$" + quote.price.formattedPrice).monospacedDigit()
                }
                HStack {
                    Text("$").foregroundStyle(.secondary)
                    TextField("Сумма в USDT", text: $viewModel.amountText)
                        .keyboardType(.decimalPad)
                        .focused($isAmountFocused)
                        .font(.title3.monospacedDigit())
                        .accessibilityIdentifier("amountField")
                }
                HStack(spacing: 8) {
                    ForEach(TradeQuote.quickFractions, id: \.self) { fraction in
                        Button("\(Int((fraction * 100).doubleValue))%") {
                            viewModel.applyFraction(fraction)
                        }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)
                    }
                }
            } footer: {
                Text(quote.availableText)
            }

            Section {
                LabeledContent("Количество") {
                    Text("\(quote.quantity.formattedQuantity) \(viewModel.coin.baseAsset)").monospacedDigit()
                }
                LabeledContent("Итого") {
                    Text(quote.amount.formattedUSD).monospacedDigit()
                }
            } footer: {
                Text(quote.side == .buy
                     ? "Покупка по лучшей цене продавца в стакане."
                     : "Продажа по лучшей цене покупателя в стакане.")
            }

            if let message = viewModel.tradeError ?? quote.validationMessage {
                Section {
                    Label(message, systemImage: "exclamationmark.circle.fill")
                        .foregroundStyle(Color.priceDown)
                }
            }
        }
    }

    private func confirmButton(quote: TradeQuote) -> some View {
        Button {
            Task { await viewModel.submitTrade() }
        } label: {
            Group {
                if viewModel.isSubmitting {
                    ProgressView()
                } else {
                    Text(title(for: quote.side))
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .fontWeight(.semibold)
        .tint(quote.side == .buy ? .priceUp : .priceDown)
        .disabled(!quote.canSubmit || viewModel.isSubmitting)
        .padding()
        .background(.bar)
        .accessibilityIdentifier("confirmTradeButton")
    }

    private func title(for side: TradeSide) -> String {
        side == .buy ? "Купить \(viewModel.coin.baseAsset)" : "Продать \(viewModel.coin.baseAsset)"
    }
}
