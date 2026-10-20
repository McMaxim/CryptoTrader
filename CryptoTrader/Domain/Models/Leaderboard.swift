import Foundation

/// Аватар участника рейтинга.
enum Avatar: Hashable, Sendable {
    case image(Data)
    /// Имя системной иконки из SF Symbols.
    case symbol(String)
    case initials(String)

    init(profile: UserProfile) {
        if let data = profile.avatarData {
            self = .image(data)
        } else {
            self = .initials(Self.initials(from: profile.name))
        }
    }

    static func initials(from name: String) -> String {
        let letters = name
            .split(whereSeparator: { $0.isWhitespace || $0 == "_" || $0 == "." })
            .prefix(2)
            .compactMap(\.first)
        let result = String(letters).uppercased()
        return result.isEmpty ? "?" : result
    }
}

/// Трейдер из общего рейтинга (то, что пришло бы с сервера).
struct Trader: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let symbolName: String
    let pnl: Decimal
    let initialBalance: Decimal
    let tradesCount: Int
}

/// Строка рейтинга.
struct LeaderboardEntry: Identifiable, Hashable, Sendable {
    let id: String
    let rank: Int
    var name: String
    var avatar: Avatar
    let pnl: Decimal
    let pnlPercent: Double
    let tradesCount: Int
    let isCurrentUser: Bool
}

struct Leaderboard: Equatable, Sendable {
    let entries: [LeaderboardEntry]

    var currentUser: LeaderboardEntry? {
        entries.first(where: \.isCurrentUser)
    }
}
