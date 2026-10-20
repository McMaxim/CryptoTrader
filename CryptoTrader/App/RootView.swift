import SwiftUI

/// Корень навигации: один NavigationStack без таббара, путь хранится в роутере.
struct RootView: View {
    @Bindable var router: AppRouter
    let factory: ScreenFactory

    var body: some View {
        NavigationStack(path: $router.path) {
            factory.makeCoinList()
                .navigationDestination(for: Route.self) { route in
                    factory.makeScreen(for: route)
                }
        }
    }
}
