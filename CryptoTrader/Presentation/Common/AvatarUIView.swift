import UIKit

/// UIKit-версия `AvatarView`: круг с фото либо градиентом с иконкой или инициалами.
final class AvatarUIView: UIView {
    private let gradientLayer = CAGradientLayer()
    private let imageView = UIImageView()
    private let symbolView = UIImageView()
    private let label = UILabel()
    private var gradientColors: [UIColor] = []
    private let size: CGFloat

    init(size: CGFloat) {
        self.size = size
        super.init(frame: .zero)
        clipsToBounds = true
        isAccessibilityElement = false

        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        layer.addSublayer(gradientLayer)

        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true

        symbolView.tintColor = .white
        symbolView.contentMode = .scaleAspectFit
        symbolView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: size * 0.42, weight: .semibold)

        label.font = Self.roundedFont(size: size * 0.36)
        label.textColor = .white
        label.textAlignment = .center
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.5

        for subview in [imageView, symbolView, label] {
            subview.translatesAutoresizingMaskIntoConstraints = false
            addSubview(subview)
        }
        let inset = size * 0.12
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: size),
            heightAnchor.constraint(equalToConstant: size),
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            symbolView.centerXAnchor.constraint(equalTo: centerXAnchor),
            symbolView.centerYAnchor.constraint(equalTo: centerYAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: inset),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -inset),
        ])
        // Градиент хранит cgColor, а он не следит за светлой/тёмной темой — пересчитываем вручную.
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: AvatarUIView, _) in
            view.applyGradientColors()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
        layer.cornerRadius = bounds.width / 2
    }

    func configure(with avatar: Avatar) {
        imageView.image = nil
        imageView.isHidden = true
        symbolView.isHidden = true
        label.isHidden = true
        gradientLayer.isHidden = false

        switch avatar {
        case .image(let data):
            if let image = UIImage(data: data) {
                imageView.image = image
                imageView.isHidden = false
                gradientLayer.isHidden = true
            } else {
                showInitials("?", seed: "?")
            }
        case .symbol(let name):
            setGradient(seed: name)
            symbolView.image = UIImage(systemName: name)
            symbolView.isHidden = false
        case .initials(let initials):
            showInitials(initials, seed: initials)
        }
    }

    private func showInitials(_ text: String, seed: String) {
        setGradient(seed: seed)
        label.text = text
        label.isHidden = false
    }

    private func setGradient(seed: String) {
        gradientColors = AvatarPalette.uiColors(seed: seed)
        applyGradientColors()
    }

    private func applyGradientColors() {
        gradientLayer.colors = gradientColors.map { $0.resolvedColor(with: traitCollection).cgColor }
    }

    private static func roundedFont(size: CGFloat) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: .semibold)
        guard let descriptor = base.fontDescriptor.withDesign(.rounded) else { return base }
        return UIFont(descriptor: descriptor, size: size)
    }
}
