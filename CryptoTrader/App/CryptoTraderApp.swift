import SwiftUI

@main
struct CryptoTraderApp: App {
    @State private var dependencies = AppDependencies.live()

    var body: some Scene {
        WindowGroup {
            RootView(
                router: dependencies.router,
                factory: ScreenFactory(dependencies: dependencies)
            )
        }
    }
}
