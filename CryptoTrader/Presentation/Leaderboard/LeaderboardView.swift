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
        List {
            if let me = viewModel.currentUser {
                Section {
                    Button { viewModel.openProfile() } label: {
                        LeaderboardRowView(entry: me, showsChevron: true)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("myLeaderboardRow")
                } header: {
                    Text("Ваше место")
                } footer: {
                    Text("Нажмите, чтобы сменить имя или аватар.")
                }
            }

            Section("Топ трейдеров") {
                ForEach(viewModel.entries) { entry in
                    if entry.isCurrentUser {
                        Button { viewModel.openProfile() } label: {
                            LeaderboardRowView(entry: entry, showsChevron: false)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Color.accentColor.opacity(0.12))
                    } else {
                        LeaderboardRowView(entry: entry, showsChevron: false)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable { await viewModel.load() }
    }
}

struct LeaderboardRowView: View {
    let entry: LeaderboardEntry
    let showsChevron: Bool

    var body: some View {
        HStack(spacing: 12) {
            rank
                .frame(width: 32)

            AvatarView(avatar: entry.avatar, size: 40)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(entry.name)
                        .font(.body.weight(.semibold))
                        .lineLimit(1)
                    if entry.isCurrentUser {
                        Text("Вы")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor, in: Capsule())
                    }
                }
                Text(RussianPlural.trades(entry.tradesCount))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                Text(entry.pnl.formattedSignedUSD)
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(Color.trend(PriceTrend(delta: entry.pnl)))
                Text(entry.pnlPercent.formattedSignedPercent)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var rank: some View {
        switch entry.rank {
        case 1: medal(Color(red: 0.98, green: 0.76, blue: 0.18))
        case 2: medal(Color(red: 0.70, green: 0.73, blue: 0.78))
        case 3: medal(Color(red: 0.80, green: 0.50, blue: 0.25))
        default:
            Text("#\(entry.rank)")
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    private func medal(_ color: Color) -> some View {
        Image(systemName: "medal.fill")
            .font(.title2)
            .foregroundStyle(color)
            .accessibilityLabel("Место \(entry.rank)")
    }
}
