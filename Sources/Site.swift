import Foundation

struct Site {
    let name: String
    let host: String
    let start: URL
    let blockedPrefixes: [String]
    let forceQuery: String?   // path "/" must carry this query, else → start

    func redirect(for url: URL) -> URL? {
        guard url.host == host else { return nil }
        if blockedPrefixes.contains(where: { url.path.hasPrefix($0) }) { return start }
        if let q = forceQuery, url.path == "/" || url.path.isEmpty,
           !(url.query ?? "").contains(q) { return start }
        return nil
    }

    static let youtube = Site(
        name: "YouTube", host: "m.youtube.com",
        start: URL(string: "https://m.youtube.com/")!,
        blockedPrefixes: ["/shorts"], forceQuery: nil)

    static let instagram = Site(
        name: "Instagram", host: "www.instagram.com",
        start: URL(string: "https://www.instagram.com/?variant=following")!,
        blockedPrefixes: ["/reels", "/explore/tags", "/explore/locations"],
        forceQuery: "variant=following")
}
