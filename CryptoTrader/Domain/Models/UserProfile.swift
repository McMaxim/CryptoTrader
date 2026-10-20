import Foundation

/// Профиль пользователя: имя и аватар, которые видны в рейтинге.
struct UserProfile: Equatable, Sendable {
    static let defaultName = "Трейдер"

    var name: String
    /// JPEG-картинка аватара или `nil`, если показываем инициалы.
    var avatarData: Data?
}
