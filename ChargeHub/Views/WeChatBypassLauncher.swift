import UIKit
import WebKit

#if os(iOS)
@MainActor
class WeChatBypassLauncher: NSObject, WKNavigationDelegate {
    static let shared = WeChatBypassLauncher()
    private var webView: WKWebView?
    
    private override init() { super.init() }
    
    func startBypass(url: URL) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let keyWindow = windowScene.windows.first(where: { $0.isKeyWindow }) else {
            print("❌ 【WeChatBypass】找不到活跃的 KeyWindow")
            return
        }
        
        self.webView?.removeFromSuperview()
        
        let config = WKWebViewConfiguration()
        config.preferences.javaScriptCanOpenWindowsAutomatically = true
        
        // 强化：为了防止尺寸太小被系统卡死，临时改成 100x100，并加到可见区域边缘看看它在干嘛
        let webView = WKWebView(frame: CGRect(x: 0, y: 100, width: 100, height: 100), configuration: config)
        webView.navigationDelegate = self
        webView.alpha = 0.5 // 临时给半透明，让你在真机上能看到这个小方块
        webView.backgroundColor = .red // 红色方块，方便你排查它有没有真正渲染出来
        
        let baseUA = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148"
        webView.customUserAgent = "\(baseUA) MicroMessenger/8.0.50(0x1800322c) NetType/WIFI Language/zh_CN"
        
        keyWindow.addSubview(webView)
        self.webView = webView
        
        print("🚀 【WeChatBypass】准备加载 Scheme 链接: \(url.absoluteString)")
        
        // 绝杀改法：桩盟返回的 URL 是 weixin:// 开头的私有协议
        // WKWebView 无法直接使用 load(URLRequest) 去加载一个私有协议，这会触发“不受支持的 URL”错误！
        // 我们必须加载一个空白 HTML，然后通过 JS 强行 window.location.href 跳转！
        webView.loadHTMLString("""
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>微信中转中</title>
        </head>
        <body>
            <p style="font-size:10px;">正在为您安全调起微信...</p>
            <script>
                setTimeout(function() {
                    var scheme = "\(url.absoluteString)";
                    console.log("准备发起强力调起: " + scheme);
                    
                    // 方法一：利用 iframe 强行向系统注入协议请求（iOS上最高效的绕过策略）
                    var iframe = document.createElement('iframe');
                    iframe.style.display = 'none';
                    iframe.src = scheme;
                    document.body.appendChild(iframe);
                    
                    // 方法二（双保险）：如果 iframe 被拦截，同时触发动态 A 标签模拟点击
                    setTimeout(function() {
                        var a = document.createElement('a');
                        a.href = scheme;
                        a.style.display = 'none';
                        document.body.appendChild(a);
                        a.click();
                    }, 50);
                    
                }, 100);
            </script>
        </body>
        </html>
        """, baseURL: URL(string: "https://xyseeker.com")) // 保持 baseURL

    }
    
    private func cleanUp() {
        print("🧹 【WeChatBypass】执行销毁清理")
        self.webView?.removeFromSuperview()
        self.webView = nil
    }
    
    // MARK: - WKNavigationDelegate 核心报错拦截与跳转捕获
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let url = navigationAction.request.url {
            print("🔗 【WeChatBypass】WebView 尝试请求 URL: \(url.absoluteString)")
            
            if url.scheme == "weixin" {
                print("🎯 【WeChatBypass】成功拦截到微信私有协议！准备拉起客户端...")
                if UIApplication.shared.canOpenURL(url) {
                    UIApplication.shared.open(url, options: [:]) { _ in
                        print("✅ 【WeChatBypass】微信客户端成功唤起！")
                        self.cleanUp()
                    }
                } else {
                    print("❌ 【WeChatBypass】系统提示无法打开 weixin://，请检查 Info.plist 的 LSApplicationQueriesSchemes 是否配置了 weixin")
                }
                decisionHandler(.cancel)
                return
            }
        }
        decisionHandler(.allow)
    }
    
    // 拦截任何页面加载失败的错误
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        print("❌ 【WeChatBypass】页面加载发生临时错误 (Provisional): \(error.localizedDescription), 错误详情: \(error)")
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("❌ 【WeChatBypass】页面加载发生硬错误 (Fail): \(error.localizedDescription), 错误详情: \(error)")
    }
}
#endif
