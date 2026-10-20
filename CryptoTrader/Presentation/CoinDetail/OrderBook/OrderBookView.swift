import UIKit

/// Стакан на `UICollectionView`: сверху заявки на продажу, посередине спред, снизу — на покупку.
///
/// Стакан обновляется раз в секунду, поэтому ячейки не пересоздаются: идентификатор ячейки —
/// это позиция (секция + индекс), а новое содержимое подставляется через
/// `reconfigureItems` диффабл-источника. Так нет мерцания и лишних аллокаций.
final class OrderBookView: UIView {
    private enum Section: Int, CaseIterable, Sendable {
        case asks, spread, bids
    }

    private struct Item: Hashable, Sendable {
        let section: Section
        let index: Int
    }

    private struct SpreadInfo {
        let value: Decimal
        let percent: Double
        let midPrice: Decimal
    }

    /// Сверху вниз: от дорогих заявок к лучшей цене продажи.
    private var asks: [OrderBookLevel] = []
    /// Сверху вниз: от лучшей цены покупки к дешёвым заявкам.
    private var bids: [OrderBookLevel] = []
    private var spread: SpreadInfo?
    private var maxQuantity: Decimal = 0
    private var priceFractionDigits = 2
    private var hasScrolledToSpread = false

    private lazy var collectionView: UICollectionView = {
        let view = UICollectionView(frame: .zero, collectionViewLayout: Self.makeLayout())
        view.backgroundColor = .clear
        view.allowsSelection = false
        view.showsVerticalScrollIndicator = false
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private var dataSource: UICollectionViewDiffableDataSource<Section, Item>!

    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(collectionView)
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: topAnchor),
            collectionView.bottomAnchor.constraint(equalTo: bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
        configureDataSource()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        scrollToSpreadIfNeeded()
    }

    // MARK: - Public

    func apply(_ book: OrderBook?, priceFractionDigits: Int) {
        guard let book else { return }
        self.priceFractionDigits = priceFractionDigits
        asks = book.asks.reversed()
        bids = book.bids
        maxQuantity = (asks + bids).map(\.quantity).max() ?? 0
        if let value = book.spread, let mid = book.midPrice, mid > 0 {
            spread = SpreadInfo(value: value, percent: (value / mid * 100).doubleValue, midPrice: mid)
        } else {
            spread = nil
        }

        var snapshot = dataSource.snapshot()
        let shapeChanged = snapshot.sectionIdentifiers != Section.allCases
            || snapshot.numberOfItems(inSection: .asks) != asks.count
            || snapshot.numberOfItems(inSection: .bids) != bids.count

        if shapeChanged {
            var fresh = NSDiffableDataSourceSnapshot<Section, Item>()
            fresh.appendSections(Section.allCases)
            fresh.appendItems(asks.indices.map { Item(section: .asks, index: $0) }, toSection: .asks)
            fresh.appendItems([Item(section: .spread, index: 0)], toSection: .spread)
            fresh.appendItems(bids.indices.map { Item(section: .bids, index: $0) }, toSection: .bids)
            dataSource.applySnapshotUsingReloadData(fresh)
        } else {
            // Та же «форма» стакана — просто перерисовываем содержимое видимых ячеек.
            snapshot.reconfigureItems(snapshot.itemIdentifiers)
            dataSource.apply(snapshot, animatingDifferences: false)
        }
        scrollToSpreadIfNeeded()
    }

    // MARK: - Setup

    private func configureDataSource() {
        let levelRegistration = UICollectionView.CellRegistration<OrderBookLevelCell, Item> { [weak self] cell, _, item in
            guard let self else { return }
            let isAsk = item.section == .asks
            let levels = isAsk ? asks : bids
            guard levels.indices.contains(item.index) else { return }
            let level = levels[item.index]
            let ratio = maxQuantity > 0 ? (level.quantity / maxQuantity).doubleValue : 0
            cell.configure(
                level: level,
                side: isAsk ? .sell : .buy,
                depthRatio: ratio,
                priceFractionDigits: priceFractionDigits
            )
        }

        let spreadRegistration = UICollectionView.CellRegistration<OrderBookSpreadCell, Item> { [weak self] cell, _, _ in
            guard let self else { return }
            cell.configure(
                midPrice: spread?.midPrice,
                spread: spread?.value,
                spreadPercent: spread?.percent,
                priceFractionDigits: priceFractionDigits
            )
        }

        dataSource = UICollectionViewDiffableDataSource(collectionView: collectionView) { collectionView, indexPath, item in
            if item.section == .spread {
                collectionView.dequeueConfiguredReusableCell(using: spreadRegistration, for: indexPath, item: item)
            } else {
                collectionView.dequeueConfiguredReusableCell(using: levelRegistration, for: indexPath, item: item)
            }
        }
    }

    private static func makeLayout() -> UICollectionViewCompositionalLayout {
        UICollectionViewCompositionalLayout { sectionIndex, _ in
            let height: CGFloat = sectionIndex == Section.spread.rawValue ? 44 : 24
            let size = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(height))
            let group = NSCollectionLayoutGroup.vertical(layoutSize: size, subitems: [NSCollectionLayoutItem(layoutSize: size)])
            return NSCollectionLayoutSection(group: group)
        }
    }

    /// При первом показе ставим спред по центру: видно и лучшие продажи, и лучшие покупки.
    private func scrollToSpreadIfNeeded() {
        guard !hasScrolledToSpread, !asks.isEmpty, collectionView.bounds.height > 0 else { return }
        collectionView.layoutIfNeeded()
        collectionView.scrollToItem(
            at: IndexPath(item: 0, section: Section.spread.rawValue),
            at: .centeredVertically,
            animated: false
        )
        hasScrolledToSpread = true
    }
}
