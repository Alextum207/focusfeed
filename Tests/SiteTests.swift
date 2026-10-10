import XCTest
@testable import FocusFeed

final class SiteTests: XCTestCase {
    private func u(_ s: String) -> URL { URL(string: s)! }

    func testYoutubeShortsRedirectToStart() {
        XCTAssertEqual(Site.youtube.redirect(for: u("https://m.youtube.com/shorts/abc")), Site.youtube.start)
    }
    func testYoutubeWatchAllowed() {
        XCTAssertNil(Site.youtube.redirect(for: u("https://m.youtube.com/watch?v=1")))
    }
    func testLoginHostsAreUntouched() {
        XCTAssertNil(Site.youtube.redirect(for: u("https://accounts.google.com/signin")))
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
