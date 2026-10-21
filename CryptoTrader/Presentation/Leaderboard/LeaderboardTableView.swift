import SwiftUI
import UIKit

/// Мост UIKit → SwiftUI: оборачивает `LeaderboardListView` (UITableView) для экрана рейтинга.
/// SwiftUI вызывает `updateUIView` при каждом новом состоянии модели — таблица сама решает, что обновить.
struct LeaderboardTableView: UIViewRepresentable {
    let currentUser: LeaderboardEntry?
    let entries: [LeaderboardEntry]
    let onOpenProfile: () -> Void
    let onRefresh: () async -> Void

    func makeUIView(context: Context) -> LeaderboardListView {
        LeaderboardListView()
    }

    func updateUIView(_ view: LeaderboardListView, context: Context) {
        view.onOpenProfile = onOpenProfile
        view.onRefresh = onRefresh
        view.apply(currentUser: currentUser, entries: entries)
    }
}

/// Список рейтинга на `UITableView` с диффабл-источником.
///
/// Свой пользователь стоит сразу в двух секциях, поэтому идентификатор элемента — секция плюс id
/// записи. Если изменилось только содержимое (имя, аватар, P&L), ячейки обновляются через
/// `reconfigureItems`, без пересоздания и мерцания.
final class LeaderboardListView: UIView, UITableViewDelegate {
    private enum Section: Int, Hashable, Sendable {
        case me, top
    }

    private struct ItemID: Hashable, Sendable {
        let section: Section
        let entryID: String
    }

    /// Диффабл-источник не умеет заголовки сам — отдаём их через подкласс.
    private final class DataSource: UITableViewDiffableDataSource<Section, ItemID> {
        override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
            switch sectionIdentifier(for: section) {
            case .me: "Ваше место"
            case .top: "Топ трейдеров"
            case nil: nil
            }
        }

        override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
            sectionIdentifier(for: section) == .me ? "Нажмите, чтобы сменить имя или аватар." : nil
        }
    }

    var onOpenProfile: () -> Void = {}
    var onRefresh: () async -> Void = {}

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let refreshControl = UIRefreshControl()
    private var dataSource: DataSource!
    private var content: [ItemID: LeaderboardEntry] = [:]

    override init(frame: CGRect) {
        super.init(frame: frame)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.register(LeaderboardCell.self, forCellReuseIdentifier: LeaderboardCell.reuseIdentifier)
        addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: topAnchor),
            tableView.bottomAnchor.constraint(equalTo: bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])

        refreshControl.addAction(UIAction { [weak self] _ in self?.refresh() }, for: .valueChanged)
        tableView.refreshControl = refreshControl
        configureDataSource()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: - Public

    func apply(currentUser: LeaderboardEntry?, entries: [LeaderboardEntry]) {
        var newContent: [ItemID: LeaderboardEntry] = [:]
        var snapshot = NSDiffableDataSourceSnapshot<Section, ItemID>()

        if let currentUser {
            let id = ItemID(section: .me, entryID: currentUser.id)
            newContent[id] = currentUser
            snapshot.appendSections([.me])
            snapshot.appendItems([id], toSection: .me)
        }
        let topIDs = entries.map { ItemID(section: .top, entryID: $0.id) }
        for (id, entry) in zip(topIDs, entries) {
            newContent[id] = entry
        }
        snapshot.appendSections([.top])
        snapshot.appendItems(topIDs, toSection: .top)

        let changed = newContent.filter { id, entry in content[id].map { $0 != entry } ?? false }.keys
        content = newContent
        snapshot.reconfigureItems(Array(changed))
        dataSource.apply(snapshot, animatingDifferences: window != nil)
    }

    // MARK: - Data source

    private func configureDataSource() {
        dataSource = DataSource(tableView: tableView) { [weak self] tableView, indexPath, id in
            let cell = tableView.dequeueReusableCell(
                withIdentifier: LeaderboardCell.reuseIdentifier,
                for: indexPath
            )
            guard let cell = cell as? LeaderboardCell, let entry = self?.content[id] else { return cell }
            cell.configure(with: entry, accessibilityIdentifier: id.section == .me ? "myLeaderboardRow" : nil)
            return cell
        }
        dataSource.defaultRowAnimation = .fade
    }

    // MARK: - UITableViewDelegate

    func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        isCurrentUser(at: indexPath)
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if isCurrentUser(at: indexPath) {
            onOpenProfile()
        }
    }

    private func isCurrentUser(at indexPath: IndexPath) -> Bool {
        guard let id = dataSource.itemIdentifier(for: indexPath) else { return false }
        return content[id]?.isCurrentUser ?? false
    }

    // MARK: - Refresh

    private func refresh() {
        Task { [weak self] in
            await self?.onRefresh()
            self?.refreshControl.endRefreshing()
        }
    }
}
