import XCTest
@testable import FocusFeed

final class SiteTests: XCTestCase {
    private func u(_ s: String) -> URL { URL(string: s)! }

    private let yt = Site.youtube(terms: ["Gaming", "lo fi music"])

    func testSessionStartIsResultsForFirstTerm() {
        XCTAssertEqual(yt.start, u("https://m.youtube.com/results?search_query=gaming"))
        XCTAssertNil(yt.redirect(for: yt.start))   // no redirect loop
    }
    func testOwnSearchTermsAllowedInAnyEncoding() {
        XCTAssertNil(yt.redirect(for: u("https://m.youtube.com/results?search_query=GAMING")))
        XCTAssertNil(yt.redirect(for: u("https://m.youtube.com/results?search_query=lo+fi+music")))
        XCTAssertNil(yt.redirect(for: u("https://m.youtube.com/results?search_query=lo%20fi%20music&sp=x")))
    }
    func testForeignSearchRedirectsToSessionResults() {
        XCTAssertEqual(yt.redirect(for: u("https://m.youtube.com/results?search_query=cats")), yt.start)
        XCTAssertEqual(yt.redirect(for: u("https://m.youtube.com/results")), yt.start)
    }
    func testHomeChannelsAndShortsRedirect() {
        for s in ["https://m.youtube.com/", "https://m.youtube.com/@someone",
                  "https://m.youtube.com/shorts/abc", "https://m.youtube.com/feed/subscriptions"] {
            XCTAssertEqual(yt.redirect(for: u(s)), yt.start, s)
        }
    }
    func testYoutubeWatchAllowed() {
        XCTAssertNil(yt.redirect(for: u("https://m.youtube.com/watch?v=1")))
    }
    func testLoginHostsAreUntouched() {
        XCTAssertNil(yt.redirect(for: u("https://accounts.google.com/signin")))
        XCTAssertNil(yt.redirect(for: u("https://m.youtube.com/signin?action_handle_signin=true")))
        XCTAssertNil(Site.instagram.redirect(for: u("https://www.instagram.com/accounts/login/")))
    }
    func testReelsBlocked() {
        XCTAssertEqual(Site.instagram.redirect(for: u("https://www.instagram.com/reels/")), Site.instagram.start)
    }
    func testSingularReelAllowed() {
        XCTAssertNil(Site.instagram.redirect(for: u("https://www.instagram.com/reel/ABC123/")))
        XCTAssertNil(Site.instagram.redirect(for: u("https://www.instagram.com/someuser/reel/XYZ/")))
    }
    func testExploreTagsBlockedButExploreAllowed() {
        XCTAssertNotNil(Site.instagram.redirect(for: u("https://www.instagram.com/explore/tags/cats/")))
        XCTAssertNil(Site.instagram.redirect(for: u("https://www.instagram.com/explore/")))
    }
    func testHomeWithoutFollowingRedirects() {
        XCTAssertEqual(Site.instagram.redirect(for: u("https://www.instagram.com/")), Site.instagram.start)
    }
    func testFollowingStartIsNotRedirected() {   // no redirect loop
        XCTAssertNil(Site.instagram.redirect(for: Site.instagram.start))
    }
    func testDirectInboxAllowed() {
        XCTAssertNil(Site.instagram.redirect(for: u("https://www.instagram.com/direct/inbox/")))
    }
}
