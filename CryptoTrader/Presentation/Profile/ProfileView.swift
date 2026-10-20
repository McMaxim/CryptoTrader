import PhotosUI
import SwiftUI

/// Профиль: имя и аватар (видны в рейтинге), состояние демо-счёта и история сделок.
struct ProfileView<ViewModel: ProfileViewModelProtocol>: View {
    @State private var viewModel: ViewModel
    @State private var pickerItem: PhotosPickerItem?
    @State private var isResetConfirmationShown = false
    @FocusState private var isNameFocused: Bool

    init(viewModel: ViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        Form {
            avatarSection
            nameSection
            accountSection
            positionsSection
            tradesSection
            resetSection
        }
        .navigationTitle("Профиль")
        .leaderboardButton { viewModel.openLeaderboard() }
        .task { await viewModel.observeChanges() }
        .task(id: viewModel.name) {
            // Дебаунс: сохраняем, когда пользователь перестал печатать.
            do {
                try await Task.sleep(for: .milliseconds(600))
                await viewModel.autosaveName()
            } catch {}
        }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    await viewModel.setAvatar(imageData: data)
                }
                pickerItem = nil
            }
        }
        .onChange(of: isNameFocused) { _, isFocused in
            if !isFocused { Task { await viewModel.commitName() } }
        }
        .onDisappear { Task { await viewModel.commitName() } }
        .confirmationDialog("Сбросить демо-счёт?", isPresented: $isResetConfirmationShown, titleVisibility: .visible) {
            Button("Сбросить", role: .destructive) {
                Task { await viewModel.resetAccount() }
            }
        } message: {
            Text("Баланс вернётся к $10,000, позиции и история сделок удалятся.")
        }
        .alert("Ошибка", isPresented: errorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    // MARK: - Sections

    private var avatarSection: some View {
        Section {
            VStack(spacing: 12) {
                AvatarView(avatar: viewModel.avatar, size: 96)
                    .overlay {
                        if viewModel.isProcessingAvatar {
                            Circle().fill(.black.opacity(0.4))
                            ProgressView().tint(.white)
                        }
                    }
                HStack(spacing: 12) {
                    let pickerTitle = viewModel.hasCustomAvatar ? "Сменить фото" : "Выбрать фото"
                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        Label(pickerTitle, systemImage: "photo")
                    }
                    .accessibilityIdentifier("choosePhotoButton")
                    if viewModel.hasCustomAvatar {
                        Button("Удалить", role: .destructive) {
                            Task { await viewModel.removeAvatar() }
                        }
                    }
                }
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity)
            .listRowBackground(Color.clear)
        }
    }

    private var nameSection: some View {
        Section {
            TextField("Ваше имя", text: $viewModel.name)
                .focused($isNameFocused)
                .submitLabel(.done)
                .onSubmit { Task { await viewModel.commitName() } }
                .accessibilityIdentifier("nameField")
        } header: {
            Text("Имя в рейтинге")
        }
    }

    @ViewBuilder
    private var accountSection: some View {
        Section {
            if let valuation = viewModel.valuation {
                LabeledContent("Свободно", value: valuation.cash.formattedUSD)
                LabeledContent("В монетах", value: valuation.positionsValue.formattedUSD)
                LabeledContent("Всего", value: valuation.equity.formattedUSD)
                LabeledContent("Результат") {
                    Text("\(valuation.pnl.formattedSignedUSD) (\(valuation.pnlPercent.formattedSignedPercent))")
                        .foregroundStyle(Color.trend(PriceTrend(delta: valuation.pnl)))
                }
            } else {
                ProgressView()
            }
        } header: {
            Text("Демо-счёт")
        } footer: {
            if let valuation = viewModel.valuation, !valuation.usesLivePrices {
                Text("Нет связи с биржей: монеты оценены по цене покупки.")
            }
        }
        .monospacedDigit()
    }

    @ViewBuilder
    private var positionsSection: some View {
        if let positions = viewModel.valuation?.positions, !positions.isEmpty {
            Section("Активы") {
                ForEach(positions) { position in
                    HStack(spacing: 12) {
                        CoinIconView(baseAsset: position.holding.baseAsset, size: 32)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(position.holding.quantity.formattedQuantity) \(position.holding.baseAsset)")
                                .font(.subheadline.weight(.semibold))
                            Text("средняя $\(position.holding.averagePrice.formattedPrice)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(position.value.formattedUSD).font(.subheadline)
                            Text(position.pnlPercent.formattedSignedPercent)
                                .font(.caption)
                                .foregroundStyle(Color.trend(PriceTrend(delta: position.pnl)))
                        }
                    }
                    .monospacedDigit()
                }
            }
        }
    }

    private var tradesSection: some View {
        Section("История сделок") {
            if viewModel.trades.isEmpty {
                Text("Сделок пока нет — купите монету на экране стакана.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.trades.prefix(20)) { trade in
                    HStack {
                        Image(systemName: trade.side == .buy ? "arrow.down.left.circle.fill" : "arrow.up.right.circle.fill")
                            .foregroundStyle(trade.side == .buy ? Color.priceUp : Color.priceDown)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(trade.side == .buy ? "Покупка" : "Продажа") \(trade.quantity.formattedQuantity) \(trade.baseAsset)")
                                .font(.subheadline)
                            Text(trade.date.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(trade.total.formattedUSD).font(.subheadline)
                            Text("по $\(trade.price.formattedPrice)").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .monospacedDigit()
                }
            }
        }
    }

    private var resetSection: some View {
        Section {
            Button("Сбросить демо-счёт", role: .destructive) {
                isResetConfirmationShown = true
            }
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }
}
