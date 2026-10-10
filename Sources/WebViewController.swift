import UIKit
import WebKit

final class WebViewController: UIViewController, WKNavigationDelegate {
    private let site: Site
    private let web: WKWebView
    private let urlLabel = UILabel()          // debug: shows the current path so we can target viewers
    private var urlObs: NSKeyValueObservation?

    init(site: Site, script: String) {
        self.site = site
        let cfg = WKWebViewConfiguration()
        // Without a Safari token Google rejects sign-in in embedded web views.
        cfg.applicationNameForUserAgent = "Version/17.0 Mobile/15E148 Safari/604.1"
        // Default is false on iPhone: every playing <video> would jump to the native fullscreen player.
        cfg.allowsInlineMediaPlayback = true
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
        urlLabel.translatesAutoresizingMaskIntoConstraints = false
        urlLabel.font = .monospacedSystemFont(ofSize: 10, weight: .regular)
        urlLabel.textColor = .lightGray
        urlLabel.backgroundColor = .black
        view.addSubview(web)
        view.addSubview(urlLabel)
        // Safe area keeps the page clear of the status bar and our own tab bar.
        NSLayoutConstraint.activate([
            web.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            web.bottomAnchor.constraint(equalTo: urlLabel.topAnchor),
            web.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            web.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            urlLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 6),
            urlLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            urlLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            urlLabel.heightAnchor.constraint(equalToConstant: 14),
        ])
        urlObs = web.observe(\.url, options: [.new]) { [weak self] w, _ in
            guard let u = w.url else { return }
            self?.urlLabel.text = u.path + (u.query.map { "?" + $0 } ?? "")
        }
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
