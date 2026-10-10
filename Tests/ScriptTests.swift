import XCTest
import WebKit
@testable import FocusFeed

private final class LoadDelegate: NSObject, WKNavigationDelegate {
    let done: () -> Void
    init(_ done: @escaping () -> Void) { self.done = done }
    func webView(_ w: WKWebView, didFinish n: WKNavigation!) { done() }
}

class ScriptTestCase: XCTestCase {
    private var keep: [AnyObject] = []

    /// Loads `html` at `base` with `script` injected, returns style.display == 'none' for each id.
    func hidden(html: String, base: String, script: String, ids: [String]) -> [String: Bool] {
        let cfg = WKWebViewConfiguration()
        cfg.userContentController.addUserScript(
            WKUserScript(source: script, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        let web = WKWebView(frame: CGRect(x: 0, y: 0, width: 390, height: 800), configuration: cfg)
        let loaded = expectation(description: "load")
        let d = LoadDelegate { loaded.fulfill() }
        web.navigationDelegate = d
        keep += [web, d]
        web.loadHTMLString(html, baseURL: URL(string: base))
        wait(for: [loaded], timeout: 10)

        let done = expectation(description: "js")
        var out: [String: Bool] = [:]
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            web.evaluateJavaScript("[" + ids.map { "document.getElementById('\($0)').style.display==='none'" }
                .joined(separator: ",") + "]") { v, _ in
                if let arr = v as? [Bool] { for (i, id) in ids.enumerated() { out[id] = arr[i] } }
                done.fulfill()
            }
        }
        wait(for: [done], timeout: 10)
        return out
    }
}

final class YouTubeScriptTests: ScriptTestCase {
    func testShortsCardAndPivotHidden() {
        let r = hidden(html: """
        <ytm-pivot-bar-item-renderer id="tab"><a href="/shorts">Shorts</a></ytm-pivot-bar-item-renderer>
        <ytm-reel-shelf-renderer id="shelf"><a href="/shorts/abc">x</a></ytm-reel-shelf-renderer>
        """, base: "https://m.youtube.com/watch?v=1", script: Scripts.youtube, ids: ["tab", "shelf"])
        XCTAssertEqual(r, ["tab": true, "shelf": true])
    }
    func testNormalVideoSurvivesNextToShort() {
        let r = hidden(html: """
        <ytm-item-section-renderer id="list">
          <ytm-video-with-context-renderer id="vid"><a href="/watch?v=1">v</a></ytm-video-with-context-renderer>
          <ytm-video-with-context-renderer id="short"><a href="/shorts/zzz">s</a></ytm-video-with-context-renderer>
        </ytm-item-section-renderer>
        """, base: "https://m.youtube.com/results?search_query=a", script: Scripts.youtube,
        ids: ["list", "vid", "short"])
        XCTAssertEqual(r, ["list": false, "vid": false, "short": true])
    }
}

final class InstagramScriptTests: ScriptTestCase {
    func testReelsNavButtonHidden() {
        let r = hidden(html: #"<a id="reels" href="/reels/">R</a><a id="dm" href="/direct/inbox/">D</a>"#,
                       base: "https://www.instagram.com/?variant=following",
                       script: Scripts.instagram, ids: ["reels", "dm"])
        XCTAssertEqual(r, ["reels": true, "dm": false])
    }
    func testExploreGridHiddenSearchKept() {
        let r = hidden(html: #"<main><input id="q" type="search"><a id="g" href="/p/AAA/">p</a></main>"#,
                       base: "https://www.instagram.com/explore/",
                       script: Scripts.instagram, ids: ["q", "g"])
        XCTAssertEqual(r, ["q": false, "g": true])
    }
    func testPostLinksOutsideExploreStayVisible() {
        let r = hidden(html: #"<main><a id="g" href="/p/AAA/">p</a></main>"#,
                       base: "https://www.instagram.com/someuser/",
                       script: Scripts.instagram, ids: ["g"])
        XCTAssertEqual(r, ["g": false])
    }
    func testGermanSuggestedPostHidden() {
        let r = hidden(html: #"<article id="a">Vorgeschlagen für dich</article><article id="b">Max</article>"#,
                       base: "https://www.instagram.com/?variant=following",
                       script: Scripts.instagram, ids: ["a", "b"])
        XCTAssertEqual(r, ["a": true, "b": false])
    }
    func testOtherReelLinksHiddenOnReelPage() {
        let r = hidden(html: #"<a id="n" href="/reel/NEXT/">n</a>"#,
                       base: "https://www.instagram.com/reel/CURRENT/",
                       script: Scripts.instagram, ids: ["n"])
        XCTAssertEqual(r, ["n": true])
    }
}
