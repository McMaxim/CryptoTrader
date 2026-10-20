import SwiftUI

/// Экраны, на которые можно перейти. Таббара нет — всё через один NavigationStack.
enum Route: Hashable {
    case coinDetail(Coin)
    case chart(Coin)
    case leaderboard
    case profile
}

/// Навигация для ViewModel: она знает только этот протокол и не зависит от SwiftUI.
@MainActor
protocol AppRouting: AnyObject {
    func push(_ route: Route)
    func pop()
    /// Открыть рейтинг; если он уже есть в стеке — вернуться к нему, а не открывать второй раз.
    func showLeaderboard()
}

@MainActor
@Observable
final class AppRouter: AppRouting {
    var path: [Route] = []

    func push(_ route: Route) {
        path.append(route)
    }

    func pop() {
        _ = path.popLast()
    }

    func showLeaderboard() {
        if let index = path.lastIndex(of: .leaderboard) {
            path.removeSubrange((index + 1)...)
        } else {
            path.append(.leaderboard)
        }
    }
}

/// ViewModel экрана, у которого слева вверху есть кнопка «Рейтинг».
@MainActor
protocol LeaderboardNavigable: AnyObject {
    func openLeaderboard()
}

extension View {
    /// Кнопка рейтинга трейдеров в левом верхнем углу. Добавляется на все экраны, кроме самого рейтинга.
    func leaderboardButton(action: @escaping @MainActor () -> Void) -> some View {
        toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: action) {
                    Label("Рейтинг", systemImage: "trophy")
                }
                .accessibilityIdentifier("leaderboardButton")
            }
        }
    }
}
