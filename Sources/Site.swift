import Foundation

struct Site {
    let name: String
    let host: String
    let start: URL
    let blockedPrefixes: [String]
    let forceQuery: String?   // path "/" must carry this query, else → start
    let embedReels: Bool      // open /reel/<code> as /reel/<code>/embed/ (one video, no next-reel feed)

    private static let reelPath = try! NSRegularExpression(pattern: "^/(?:[^/]+/)?reel/([^/]+)/?$")

    /// "/reel/ABC/" or "/user/reel/ABC/" → "ABC"; "/reel/ABC/embed/" → nil.
    static func reelCode(in path: String) -> String? {
        let r = NSRange(path.startIndex..., in: path)
        guard let m = reelPath.firstMatch(in: path, range: r),
              let c = Range(m.range(at: 1), in: path) else { return nil }
        return String(path[c])
    }

    func redirect(for url: URL) -> URL? {
        guard url.host == host else { return nil }
        if embedReels, let code = Site.reelCode(in: url.path) {
            return URL(string: "https://\(host)/reel/\(code)/embed/")
        }
        if blockedPrefixes.contains(where: { url.path.hasPrefix($0) }) { return start }
        if let q = forceQuery, url.path == "/" || url.path.isEmpty,
           !(url.query ?? "").contains(q) { return start }
        return nil
    }

    static let youtube = Site(
        name: "YouTube", host: "m.youtube.com",
        start: URL(string: "https://m.youtube.com/")!,
        blockedPrefixes: ["/shorts"], forceQuery: nil, embedReels: false)

    static let instagram = Site(
        name: "Instagram", host: "www.instagram.com",
        start: URL(string: "https://www.instagram.com/?variant=following")!,
        blockedPrefixes: ["/reels", "/explore/tags", "/explore/locations"],
        forceQuery: "variant=following", embedReels: true)
}
