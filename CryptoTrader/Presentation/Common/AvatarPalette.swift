import SwiftUI
import UIKit

/// Палитры градиентов для аватаров. Общие для SwiftUI `AvatarView` и UIKit-аватара в списке,
/// чтобы один и тот же пользователь выглядел одинаково на всех экранах.
enum AvatarPalette {
    private static let palettes: [[Color]] = [
        [.orange, .pink], [.blue, .purple], [.teal, .blue], [.green, .teal],
        [.indigo, .pink], [.purple, .orange], [.mint, .cyan],
    ]

    /// Стабильные цвета для строки (hashValue меняется между запусками, поэтому считаем сами).
    static func colors(seed: String) -> [Color] {
        let index = seed.unicodeScalars.reduce(0) { $0 &+ Int($1.value) } % palettes.count
        return palettes[index]
    }

    static func uiColors(seed: String) -> [UIColor] {
        colors(seed: seed).map { UIColor($0) }
    }
}
