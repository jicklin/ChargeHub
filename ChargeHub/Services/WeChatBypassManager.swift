import SwiftUI
import WebKit

#if os(iOS)
struct WeChatBypassWebView: UIViewRepresentable {
    let url: URL
    @Binding var triggerReset: URL?

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.javaScriptCanOpenWindowsAutomatically = true
        
        // 给予 1x1 的极小尺寸，确保 WebKit 内核判定其为“活跃视图”并正常工作
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 1, height: 1), configuration: config)
        webView.navigationDelegate = context.coordinator
        
        // 关键：伪造微信 UA 绕过 getexpappinfo 校验
        let baseUA = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148"
        webView.customUserAgent = "\(baseUA) MicroMessenger/8.0.50(0x1800322c) NetType/WIFI Language/zh_CN"
        
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // 当收到有效的 URL 时，立刻让 WebView 发起请求
        let request = URLRequest(url: url)
        uiView.load(request)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WeChatBypassWebView
        
        init(_ parent: WeChatBypassWebView) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if let url = navigationAction.request.url, url.scheme == "weixin" {
                // 捕获到微信内部真正的拉起指令，递交给系统应用层
                if UIApplication.shared.canOpenURL(url) {
                    UIApplication.shared.open(url, options: [:]) { _ in
                        // 打开完成后，立刻清空外部状态，防止重复触发
                        DispatchQueue.main.async {
                            self.parent.triggerReset = nil
                        }
                    }
                }
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }
    }
}
#endif

