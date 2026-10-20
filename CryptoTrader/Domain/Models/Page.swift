import Foundation

/// Страница пагинированного списка.
struct Page<Item: Sendable>: Sendable {
    let items: [Item]
    let index: Int
    let hasMore: Bool
}
