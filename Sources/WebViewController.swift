import UIKit
import WebKit

final class WebViewController: UIViewController, WKNavigationDelegate {
    private let site: Site
    private let web: WKWebView

    init(site: Site, script: String) {
        self.site = site
        let cfg = WKWebViewConfiguration()
        // Without a Safari token Google rejects sign-in in embedded web views.
        cfg.applicationNameForUserAgent = "Version/17.0 Mobile/15E148 Safari/604.1"
        for src in [Scripts.guardScript(for: site), script] where !src.isEmpty {
            cfg.userContentController.addUserScript(
                WKUserScript(source: src, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        }
        web = WKWebView(frame: .zero, configuration: cfg)
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        web.navigationDelegate = self
        web.allowsBackForwardNavigationGestures = true   // swipe from the left edge = back
        web.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(web)
        // Safe area keeps the page clear of the status bar and our own tab bar.
        NSLayoutConstraint.activate([
            web.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            web.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            web.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            web.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        web.load(URLRequest(url: site.start))
    }

    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let url = action.request.url, let target = site.redirect(for: url) {
            decisionHandler(.cancel)
            webView.load(URLRequest(url: target))
        } else {
            decisionHandler(.allow)
        }
    }
}
