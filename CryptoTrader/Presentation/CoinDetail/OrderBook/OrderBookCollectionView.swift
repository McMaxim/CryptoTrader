import SwiftUI

/// Мост UIKit → SwiftUI: оборачивает `OrderBookView` (UICollectionView) для SwiftUI-экрана.
/// SwiftUI вызывает `updateUIView` при каждом новом стакане — коллекция обновляет ячейки на месте.
struct OrderBookCollectionView: UIViewRepresentable {
    let orderBook: OrderBook?
    let priceFractionDigits: Int

    func makeUIView(context: Context) -> OrderBookView {
        OrderBookView()
    }

    func updateUIView(_ view: OrderBookView, context: Context) {
        view.apply(orderBook, priceFractionDigits: priceFractionDigits)
    }
}
