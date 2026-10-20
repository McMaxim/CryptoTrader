import UIKit

/// Строка стакана: цена, количество, сумма и полоска глубины на фоне.
final class OrderBookLevelCell: UICollectionViewCell {
    private let depthBar = UIView()
    private let priceLabel = UILabel()
    private let quantityLabel = UILabel()
    private let totalLabel = UILabel()
    private var depthRatio: CGFloat = 0

    override init(frame: CGRect) {
        super.init(frame: frame)

        depthBar.layer.cornerRadius = 2
        contentView.addSubview(depthBar)

        priceLabel.font = .monospacedDigitSystemFont(ofSize: 13, weight: .semibold)
        quantityLabel.font = .monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        totalLabel.font = .monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        quantityLabel.textColor = .label
        totalLabel.textColor = .secondaryLabel
        priceLabel.textAlignment = .left
        quantityLabel.textAlignment = .right
        totalLabel.textAlignment = .right
        for label in [priceLabel, quantityLabel, totalLabel] {
            label.adjustsFontSizeToFitWidth = true
            label.minimumScaleFactor = 0.7
        }

        let stack = UIStackView(arrangedSubviews: [priceLabel, quantityLabel, totalLabel])
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 4),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -4),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func configure(level: OrderBookLevel, side: TradeSide, depthRatio: Double, priceFractionDigits: Int) {
        let color: UIColor = side == .buy ? .priceUp : .priceDown
        priceLabel.text = level.price.formatted(fractionDigits: priceFractionDigits)
        priceLabel.textColor = color
        quantityLabel.text = level.quantity.formattedQuantity
        totalLabel.text = level.total.formattedCompact
        depthBar.backgroundColor = color.withAlphaComponent(0.15)

        let ratio = CGFloat(min(max(depthRatio, 0), 1))
        guard ratio != self.depthRatio else { return }
        self.depthRatio = ratio
        // Плавно меняем длину полоски, когда объём на уровне меняется.
        UIView.animate(withDuration: 0.25, delay: 0, options: [.beginFromCurrentState, .allowUserInteraction]) {
            self.layoutDepthBar()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layoutDepthBar()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        depthRatio = 0
        layoutDepthBar()
    }

    private func layoutDepthBar() {
        let bounds = contentView.bounds
        let width = bounds.width * depthRatio
        depthBar.frame = CGRect(x: bounds.width - width, y: 1, width: width, height: max(bounds.height - 2, 0))
    }
}

/// Середина стакана: средняя цена и спред между лучшими заявками.
final class OrderBookSpreadCell: UICollectionViewCell {
    private let midPriceLabel = UILabel()
    private let spreadLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)

        let background = UIView()
        background.backgroundColor = .secondarySystemBackground
        background.layer.cornerRadius = 8
        background.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(background)

        midPriceLabel.font = .monospacedDigitSystemFont(ofSize: 17, weight: .semibold)
        midPriceLabel.adjustsFontSizeToFitWidth = true
        midPriceLabel.minimumScaleFactor = 0.7
        spreadLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        spreadLabel.textColor = .secondaryLabel
        spreadLabel.textAlignment = .right

        let stack = UIStackView(arrangedSubviews: [midPriceLabel, spreadLabel])
        stack.axis = .horizontal
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(stack)

        NSLayoutConstraint.activate([
            background.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            background.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            background.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            background.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
            stack.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(equalTo: background.trailingAnchor, constant: -8),
            stack.centerYAnchor.constraint(equalTo: background.centerYAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func configure(midPrice: Decimal?, spread: Decimal?, spreadPercent: Double?, priceFractionDigits: Int) {
        midPriceLabel.text = midPrice.map { "$" + $0.formatted(fractionDigits: priceFractionDigits + 1) } ?? "—"
        if let spread, let spreadPercent {
            spreadLabel.text = "Спред \(spread.formatted(fractionDigits: priceFractionDigits)) · "
                + spreadPercent.formatted(.number.precision(.fractionLength(3)).locale(NumberFormatting.locale)) + "%"
        } else {
            spreadLabel.text = nil
        }
    }
}
