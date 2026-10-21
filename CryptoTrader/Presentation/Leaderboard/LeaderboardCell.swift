import SwiftUI
import UIKit

/// Строка рейтинга: место, аватар, имя со сделками и P&L справа.
final class LeaderboardCell: UITableViewCell {
    static let reuseIdentifier = "LeaderboardCell"

    private static let gold = UIColor(red: 0.98, green: 0.76, blue: 0.18, alpha: 1)
    private static let silver = UIColor(red: 0.70, green: 0.73, blue: 0.78, alpha: 1)
    private static let bronze = UIColor(red: 0.80, green: 0.50, blue: 0.25, alpha: 1)
    private static let highlightAlpha: CGFloat = 0.12

    private let rankLabel = UILabel()
    private let medalView = UIImageView()
    private let avatarView = AvatarUIView(size: 40)
    private let nameLabel = UILabel()
    private let youBadge = UIView()
    private let tradesLabel = UILabel()
    private let pnlLabel = UILabel()
    private let percentLabel = UILabel()
    private var highlightsBackground = false

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        buildLayout()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func configure(with entry: LeaderboardEntry, accessibilityIdentifier identifier: String? = nil) {
        configureRank(entry.rank)
        avatarView.configure(with: entry.avatar)
        nameLabel.text = entry.name
        youBadge.isHidden = !entry.isCurrentUser
        tradesLabel.text = RussianPlural.trades(entry.tradesCount)

        let pnlText = entry.pnl.formattedSignedUSD
        let percentText = entry.pnlPercent.formattedSignedPercent
        pnlLabel.text = pnlText
        pnlLabel.textColor = Self.trendColor(PriceTrend(delta: entry.pnl))
        percentLabel.text = percentText

        // Нажимается только строка текущего пользователя: она открывает профиль.
        accessoryType = entry.isCurrentUser ? .disclosureIndicator : .none
        selectionStyle = entry.isCurrentUser ? .default : .none
        highlightsBackground = entry.isCurrentUser && identifier == nil
        setNeedsUpdateConfiguration()

        self.accessibilityIdentifier = identifier
        isAccessibilityElement = true
        accessibilityTraits = entry.isCurrentUser ? .button : .none
        accessibilityLabel = "Место \(entry.rank), \(entry.name), результат \(pnlText), \(percentText)"
    }

    /// Свою строку в общем списке подсвечиваем цветом accent; в закреплённой секции фон обычный.
    override func updateConfiguration(using state: UICellConfigurationState) {
        var background = UIBackgroundConfiguration.listGroupedCell().updated(for: state)
        if highlightsBackground {
            background.backgroundColor = UIColor.tintColor.withAlphaComponent(Self.highlightAlpha)
        }
        backgroundConfiguration = background
    }

    // MARK: - Layout

    private func buildLayout() {
        let rankContainer = UIView()
        for view in [rankLabel, medalView] {
            view.translatesAutoresizingMaskIntoConstraints = false
            rankContainer.addSubview(view)
        }
        rankLabel.font = Self.font(.subheadline, weight: .semibold, monospaced: true)
        rankLabel.textColor = .secondaryLabel
        rankLabel.textAlignment = .center
        rankLabel.adjustsFontForContentSizeCategory = true
        medalView.contentMode = .scaleAspectFit
        medalView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .title2)

        nameLabel.font = Self.font(.body, weight: .semibold)
        nameLabel.adjustsFontForContentSizeCategory = true
        nameLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        configureYouBadge()
        tradesLabel.font = Self.font(.caption1)
        tradesLabel.textColor = .secondaryLabel
        tradesLabel.adjustsFontForContentSizeCategory = true

        pnlLabel.font = Self.font(.subheadline, weight: .semibold, monospaced: true)
        pnlLabel.textAlignment = .right
        pnlLabel.adjustsFontForContentSizeCategory = true
        percentLabel.font = Self.font(.caption1, monospaced: true)
        percentLabel.textColor = .secondaryLabel
        percentLabel.textAlignment = .right
        percentLabel.adjustsFontForContentSizeCategory = true

        let nameRow = UIStackView(arrangedSubviews: [nameLabel, youBadge, UIView()])
        nameRow.axis = .horizontal
        nameRow.spacing = 6
        nameRow.alignment = .center
        let textStack = UIStackView(arrangedSubviews: [nameRow, tradesLabel])
        textStack.axis = .vertical
        textStack.spacing = 2
        let pnlStack = UIStackView(arrangedSubviews: [pnlLabel, percentLabel])
        pnlStack.axis = .vertical
        pnlStack.alignment = .trailing
        pnlStack.spacing = 2
        pnlStack.setContentHuggingPriority(.required, for: .horizontal)
        pnlStack.setContentCompressionResistancePriority(.required, for: .horizontal)

        let row = UIStackView(arrangedSubviews: [rankContainer, avatarView, textStack, pnlStack])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 12
        row.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(row)

        let margins = contentView.layoutMarginsGuide
        NSLayoutConstraint.activate([
            rankContainer.widthAnchor.constraint(equalToConstant: 32),
            rankLabel.leadingAnchor.constraint(equalTo: rankContainer.leadingAnchor),
            rankLabel.trailingAnchor.constraint(equalTo: rankContainer.trailingAnchor),
            rankLabel.centerYAnchor.constraint(equalTo: rankContainer.centerYAnchor),
            medalView.leadingAnchor.constraint(equalTo: rankContainer.leadingAnchor),
            medalView.trailingAnchor.constraint(equalTo: rankContainer.trailingAnchor),
            medalView.centerYAnchor.constraint(equalTo: rankContainer.centerYAnchor),
            row.leadingAnchor.constraint(equalTo: margins.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: margins.trailingAnchor),
            row.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            row.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
        ])
    }

    /// Капсула «Вы» цвета accent.
    private func configureYouBadge() {
        let label = UILabel()
        label.text = "Вы"
        label.font = Self.font(.caption2, weight: .bold)
        label.textColor = .white
        label.adjustsFontForContentSizeCategory = true
        label.translatesAutoresizingMaskIntoConstraints = false
        youBadge.backgroundColor = .tintColor
        youBadge.layer.cornerCurve = .continuous
        youBadge.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: youBadge.leadingAnchor, constant: 6),
            label.trailingAnchor.constraint(equalTo: youBadge.trailingAnchor, constant: -6),
            label.topAnchor.constraint(equalTo: youBadge.topAnchor, constant: 2),
            label.bottomAnchor.constraint(equalTo: youBadge.bottomAnchor, constant: -2),
        ])
        youBadge.setContentHuggingPriority(.required, for: .horizontal)
        youBadge.setContentCompressionResistancePriority(.required, for: .horizontal)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        youBadge.layer.cornerRadius = youBadge.bounds.height / 2
    }

    // MARK: - Content

    private func configureRank(_ rank: Int) {
        let medalColor: UIColor? = switch rank {
        case 1: Self.gold
        case 2: Self.silver
        case 3: Self.bronze
        default: nil
        }
        medalView.isHidden = medalColor == nil
        rankLabel.isHidden = medalColor != nil
        if let medalColor {
            medalView.image = UIImage(systemName: "medal.fill")
            medalView.tintColor = medalColor
        } else {
            rankLabel.text = "#\(rank)"
        }
    }

    private static func trendColor(_ trend: PriceTrend) -> UIColor {
        switch trend {
        case .up: .priceUp
        case .down: .priceDown
        case .flat: .secondaryLabel
        }
    }

    /// Шрифт стиля Dynamic Type с нужным весом; цифры моноширинные, чтобы суммы не «прыгали».
    private static func font(
        _ style: UIFont.TextStyle,
        weight: UIFont.Weight = .regular,
        monospaced: Bool = false
    ) -> UIFont {
        let size = UIFont.preferredFont(forTextStyle: style).pointSize
        let base = monospaced
            ? UIFont.monospacedDigitSystemFont(ofSize: size, weight: weight)
            : UIFont.systemFont(ofSize: size, weight: weight)
        return UIFontMetrics(forTextStyle: style).scaledFont(for: base)
    }
}
