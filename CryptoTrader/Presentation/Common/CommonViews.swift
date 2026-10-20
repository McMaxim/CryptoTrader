import SwiftUI

/// Круглый аватар: фото, иконка или инициалы на цветном фоне.
struct AvatarView: View {
    let avatar: Avatar
    var size: CGFloat = 40

    var body: some View {
        content
            .frame(width: size, height: size)
            .clipShape(Circle())
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var content: some View {
        switch avatar {
        case .image(let data):
            if let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                badge(text: "?", seed: "?")
            }
        case .symbol(let name):
            ZStack {
                Circle().fill(Self.gradient(seed: name))
                Image(systemName: name)
                    .font(.system(size: size * 0.42, weight: .semibold))
                    .foregroundStyle(.white)
            }
        case .initials(let initials):
            badge(text: initials, seed: initials)
        }
    }

    private func badge(text: String, seed: String) -> some View {
        ZStack {
            Circle().fill(Self.gradient(seed: seed))
            Text(text)
                .font(.system(size: size * 0.36, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.5)
                .padding(size * 0.12)
        }
    }

    private static let palettes: [[Color]] = [
        [.orange, .pink], [.blue, .purple], [.teal, .blue], [.green, .teal],
        [.indigo, .pink], [.purple, .orange], [.mint, .cyan],
    ]

    /// Стабильный цвет для строки (hashValue меняется между запусками, поэтому считаем сами).
    private static func gradient(seed: String) -> LinearGradient {
        let index = seed.unicodeScalars.reduce(0) { $0 &+ Int($1.value) } % palettes.count
        return LinearGradient(colors: palettes[index], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

/// Иконка монеты из открытого набора иконок; пока грузится или если её нет — тикер на кружке.
struct CoinIconView: View {
    let baseAsset: String
    var size: CGFloat = 36

    var body: some View {
        AsyncImage(url: Self.iconURL(for: baseAsset)) { phase in
            if let image = phase.image {
                image.resizable().scaledToFit()
            } else {
                AvatarView(avatar: .initials(String(baseAsset.prefix(4))), size: size)
            }
        }
        .frame(width: size, height: size)
    }

    static func iconURL(for baseAsset: String) -> URL? {
        URL(string: "https://assets.coincap.io/assets/icons/\(baseAsset.lowercased())@2x.png")
    }
}

/// Плашка изменения цены: ▲ 2.34% зелёным или ▼ 1.20% красным.
struct PriceChangeBadge: View {
    let percent: Double

    var body: some View {
        let trend: PriceTrend = percent > 0 ? .up : (percent < 0 ? .down : .flat)
        HStack(spacing: 3) {
            Image(systemName: trend == .down ? "arrowtriangle.down.fill" : "arrowtriangle.up.fill")
                .font(.system(size: 8, weight: .bold))
            Text(abs(percent).formattedPercent)
                .font(.caption.weight(.semibold).monospacedDigit())
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.trend(trend), in: Capsule())
        .accessibilityLabel(percent >= 0 ? "Рост \(percent.formattedPercent)" : "Падение \(abs(percent).formattedPercent)")
    }
}

/// Ошибка с кнопкой «Повторить».
struct ErrorStateView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("Не получилось загрузить", systemImage: "wifi.exclamationmark")
        } description: {
            Text(message)
        } actions: {
            Button("Повторить", action: retry)
                .buttonStyle(.borderedProminent)
        }
    }
}

/// Всплывающее уведомление сверху экрана.
struct ToastView: View {
    let message: String

    var body: some View {
        Label(message, systemImage: "checkmark.circle.fill")
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.regularMaterial, in: Capsule())
            .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
            .padding(.horizontal)
    }
}
