import SwiftUI
import WebKit

/// Экран графика: виджет TradingView во встроенном WebView.
struct ChartView<ViewModel: ChartViewModelProtocol>: View {
    @State private var viewModel: ViewModel
    @Environment(\.colorScheme) private var colorScheme

    init(viewModel: ViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Интервал", selection: $viewModel.selectedInterval) {
                ForEach(viewModel.intervals) { interval in
                    Text(interval.title).tag(interval)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)

            ZStack {
                TradingViewWebView(
                    url: viewModel.chartURL(isDarkMode: colorScheme == .dark),
                    reloadToken: viewModel.reloadToken,
                    onStart: { viewModel.loadingStarted() },
                    onFinish: { viewModel.loadingFinished() },
                    onFail: { viewModel.loadingFailed($0) }
                )
                .accessibilityIdentifier("chartWebView")

                if let message = viewModel.errorMessage {
                    ErrorStateView(message: message) { viewModel.retry() }
                        .background(Color(.systemBackground))
                } else if viewModel.isLoading {
                    ProgressView("Загружаем график…")
                }
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .navigationTitle(viewModel.title)
        .navigationBarTitleDisplayMode(.inline)
        .leaderboardButton { viewModel.openLeaderboard() }
    }
}

/// `WKWebView` для SwiftUI. Перезагружает страницу, только когда меняется URL
/// (интервал, тема) или токен перезагрузки.
struct TradingViewWebView: UIViewRepresentable {
    let url: URL
    let reloadToken: Int
    let onStart: () -> Void
    let onFinish: () -> Void
    let onFail: (any Error) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .systemBackground
        webView.scrollView.bounces = false
        webView.navigationDelegate = context.coordinator
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self
        guard coordinator.loadedURL != url || coordinator.loadedToken != reloadToken else { return }
        coordinator.loadedURL = url
        coordinator.loadedToken = reloadToken
        webView.load(URLRequest(url: url))
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate {
        var parent: TradingViewWebView?
        var loadedURL: URL?
        var loadedToken: Int?

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            parent?.onStart()
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent?.onFinish()
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: any Error) {
            handle(error)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: any Error) {
            handle(error)
        }

        private func handle(_ error: any Error) {
            // Отмена — это переключение интервала посреди загрузки, а не ошибка.
            guard (error as NSError).code != NSURLErrorCancelled else { return }
            parent?.onFail(error)
        }
    }
}
