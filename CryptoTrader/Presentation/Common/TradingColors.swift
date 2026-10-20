import SwiftUI
import UIKit

extension Color {
    static var priceUp: Color { Color(red: 0.05, green: 0.72, blue: 0.47) }
    static var priceDown: Color { Color(red: 0.95, green: 0.27, blue: 0.36) }

    static func trend(_ trend: PriceTrend) -> Color {
        switch trend {
        case .up: .priceUp
        case .down: .priceDown
        case .flat: .secondary
        }
    }
}

extension UIColor {
    static var priceUp: UIColor { UIColor(Color.priceUp) }
    static var priceDown: UIColor { UIColor(Color.priceDown) }
}
