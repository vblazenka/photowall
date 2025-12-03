import SwiftUI
import WebKit

// MARK: - PickerWebView

struct PickerWebView: NSViewRepresentable {

    let pickerUri: String
    let onComplete: (Bool) -> Void

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()

        // Use non-persistent data store to share authentication
        // This allows the WebView to access cookies and credentials
        configuration.websiteDataStore = WKWebsiteDataStore.nonPersistent()

        // Configure preferences for better web compatibility
        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true
        configuration.defaultWebpagePreferences = preferences

        // Set up message handler to detect picker completion
        let contentController = WKUserContentController()
        contentController.add(context.coordinator, name: "pickerHandler")
        configuration.userContentController = contentController

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"

        // Load the picker URI
        if let url = URL(string: pickerUri) {
            print("=== PickerWebView: Loading URL ===")
            print("URL: \(url.absoluteString)")
            let request = URLRequest(url: url)
            webView.load(request)
        } else {
            print("=== PickerWebView: Invalid URL ===")
            print("URI: \(pickerUri)")
        }

        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        // No updates needed
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        let parent: PickerWebView
        private var hasCompleted = false

        init(parent: PickerWebView) {
            self.parent = parent
        }

        // MARK: - WKNavigationDelegate

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            print("=== PickerWebView: Navigation started ===")
            if let url = webView.url {
                print("Current URL: \(url.absoluteString)")
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            print("=== PickerWebView: Navigation finished ===")
            if let url = webView.url {
                print("Loaded URL: \(url.absoluteString)")
            }

            // Inject JavaScript to detect picker completion
            let script = """
            // Listen for messages from Google Picker
            window.addEventListener('message', function(event) {
                if (event.data && event.data.action === 'CLOSE') {
                    window.webkit.messageHandlers.pickerHandler.postMessage('complete');
                }
            });

            // Notify if window is about to close
            window.addEventListener('beforeunload', function() {
                window.webkit.messageHandlers.pickerHandler.postMessage('complete');
            });
            """

            webView.evaluateJavaScript(script) { _, error in
                if let error = error {
                    print("Error injecting picker completion script: \(error)")
                } else {
                    print("Successfully injected picker completion script")
                }
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("=== PickerWebView: Navigation failed ===")
            print("Error: \(error)")
            if !hasCompleted {
                hasCompleted = true
                parent.onComplete(false)
            }
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            print("=== PickerWebView: Provisional navigation failed ===")
            print("Error: \(error)")
            if !hasCompleted {
                hasCompleted = true
                parent.onComplete(false)
            }
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            // Check if Google is redirecting to a completion URL
            if let url = navigationAction.request.url,
               url.absoluteString.contains("close") || url.absoluteString.contains("done") {
                if !hasCompleted {
                    hasCompleted = true
                    parent.onComplete(true)
                }
                decisionHandler(.cancel)
                return
            }

            decisionHandler(.allow)
        }

        // MARK: - WKScriptMessageHandler

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            if message.name == "pickerHandler", !hasCompleted {
                hasCompleted = true
                parent.onComplete(true)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    PickerWebView(
        pickerUri: "https://photos.google.com/picker",
        onComplete: { success in
            print("Picker completed: \(success)")
        }
    )
    .frame(width: 800, height: 600)
}
