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

    /// Loads `html` at `base` with `script` injected, optionally runs `act`, then returns the value of `js`.
    func eval(html: String, base: String, script: String, act: String? = nil, js: String) -> Any? {
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
        if let act { web.evaluateJavaScript(act, completionHandler: nil) }

        let done = expectation(description: "js")
        var out: Any?
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            web.evaluateJavaScript(js) { v, _ in out = v; done.fulfill() }
        }
        wait(for: [done], timeout: 10)
        return out
    }

    /// style.display == 'none' for each id.
    func hidden(html: String, base: String, script: String, ids: [String]) -> [String: Bool] {
        let js = "[" + ids.map { "getComputedStyle(document.getElementById('\($0)')).display==='none'" }
            .joined(separator: ",") + "]"
        let arr = eval(html: html, base: base, script: script, js: js) as? [Bool] ?? []
        return Dictionary(uniqueKeysWithValues: zip(ids, arr))
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

final class YouTubeDurationTests: ScriptTestCase {
    func testShortDurationCardsHiddenLongOnesKept() {
        let r = hidden(html: """
        <ytm-rich-item-renderer id="s"><span>0:57</span></ytm-rich-item-renderer>
        <ytm-rich-item-renderer id="e"><div><span>1:00</span></div></ytm-rich-item-renderer>
        <ytm-rich-item-renderer id="l"><span>1:01</span></ytm-rich-item-renderer>
        <ytm-rich-item-renderer id="t"><span>3:00</span></ytm-rich-item-renderer>
        <ytm-rich-item-renderer id="m"><span>57:45</span></ytm-rich-item-renderer>
        <ytm-rich-item-renderer id="h"><span>1:02:03</span></ytm-rich-item-renderer>
        """, base: "https://m.youtube.com/", script: Scripts.youtube, ids: ["s", "e", "l", "t", "m", "h"])
        XCTAssertEqual(r, ["s": true, "e": true, "l": false, "t": false, "m": false, "h": false])
    }
    func testShortsTabWithoutLinkHidden() {
        let r = hidden(html: """
        <ytm-pivot-bar-item-renderer id="t"><div><span>Shorts</span></div></ytm-pivot-bar-item-renderer>
        <ytm-pivot-bar-item-renderer id="h"><div><span>Home</span></div></ytm-pivot-bar-item-renderer>
        """, base: "https://m.youtube.com/", script: Scripts.youtube, ids: ["t", "h"])
        XCTAssertEqual(r, ["t": true, "h": false])
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
    private func locked(base: String, act: String? = nil) -> Bool {
        eval(html: "<main></main>", base: base, script: Scripts.instagram, act: act,
             js: "!!document.getElementById('ff-lock')") as? Bool ?? false
    }
    func testScrollLockedOnUserReelPath() {
        XCTAssertTrue(locked(base: "https://www.instagram.com/someuser/reel/ABC/"))
    }
    func testFeedIsNotLocked() {
        XCTAssertFalse(locked(base: "https://www.instagram.com/?variant=following"))
    }
    func testLockReleasedAfterLeavingReel() {
        XCTAssertFalse(locked(base: "https://www.instagram.com/reel/ABC/",
            act: "history.pushState({}, '', '/'); document.body.appendChild(document.createElement('i'));"))
    }

    private func lockedAt(_ path: String, video: String) -> Bool {
        let html = "<meta name='viewport' content='width=device-width'><body style='margin:0'>" + video
        return eval(html: html, base: "https://www.instagram.com" + path, script: Scripts.instagram,
                    js: "window.__ffLocked()") as? Bool ?? false
    }
    func testBigVideoInDirectThreadLocksGestures() {
        XCTAssertTrue(lockedAt("/direct/t/1/", video: "<video style='display:block;width:100%;height:600px'></video>"))
    }
    func testSmallVideoInDirectThreadDoesNotLock() {
        XCTAssertFalse(lockedAt("/direct/t/1/", video: "<video style='display:block;width:120px;height:120px'></video>"))
    }
    func testBigVideoOnReelPagesLocksGestures() {
        let v = "<video style='display:block;width:100%;height:600px'></video>"
        XCTAssertTrue(lockedAt("/reel/ABC/", video: v))
        XCTAssertTrue(lockedAt("/someuser/reel/ABC/", video: v))
    }
    func testBigVideoInFeedDoesNotLock() {
        XCTAssertFalse(lockedAt("/", video: "<video style='display:block;width:100%;height:600px'></video>"))
    }
    func testViewportIsPinnedToDeviceWidth() {
        let c = eval(html: "<meta name='viewport' content='width=980'><body>x</body>",
                     base: "https://www.instagram.com/", script: Scripts.instagram,
                     js: "document.querySelector('meta[name=viewport]').content") as? String ?? ""
        XCTAssertTrue(c.contains("width=device-width") && c.contains("minimum-scale=1"), c)
    }
}

final class YouTubeStatsTests: ScriptTestCase {
    func testStatsCountItemsAndHiddenCards() {
        let html = """
        <ytm-rich-item-renderer><span>12:30</span></ytm-rich-item-renderer>
        <ytm-rich-item-renderer><span>5:00</span></ytm-rich-item-renderer>
        <ytm-rich-item-renderer><span>0:30</span></ytm-rich-item-renderer>
        """
        let r = eval(html: html, base: "https://m.youtube.com/", script: Scripts.youtube,
                     js: "JSON.stringify(window.__ffStats())") as? String ?? ""
        XCTAssertTrue(r.contains("\"items\":3") && r.contains("\"hid\":1"), r)
    }

    private func blockedPlays(path: String) -> Int {
        let v = eval(html: "<body>x</body>", base: "https://m.youtube.com" + path, script: Scripts.youtube,
                     act: "document.createElement('video').play().catch(function(){})",
                     js: "window.__ffBlockedPlays") as? Int ?? -1
        return v
    }
    func testFeedPreviewPlaybackIsBlocked() {
        XCTAssertEqual(blockedPlays(path: "/"), 1)
        XCTAssertEqual(blockedPlays(path: "/results?search_query=a"), 1)
    }
    func testWatchPagePlaybackIsAllowed() {
        XCTAssertEqual(blockedPlays(path: "/watch?v=1"), 0)
    }

final class YouTubeRecyclingTests: ScriptTestCase {
    /// YouTube reuses card elements while scrolling: a card that stops being a Short must reappear.
    func testRecycledCardIsShownAgain() {
        let html = "<ytm-rich-item-renderer id='c'><span id='d'>0:30</span></ytm-rich-item-renderer>"
        let v = eval(html: html, base: "https://m.youtube.com/", script: Scripts.youtube,
                     act: "setTimeout(function(){ document.getElementById('d').textContent='12:30'; }, 100)",
                     js: "getComputedStyle(document.getElementById('c')).display") as? String ?? ""
        XCTAssertNotEqual(v, "none")
    }
}
