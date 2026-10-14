import Foundation

struct Site {
    let name: String
    let host: String
    let start: URL
    let blockedPrefixes: [String]
    let forceQuery: String?   // path "/" must carry this query, else → start
    /// Session mode: only watch pages and search results for these (normalized) terms; all else → start.
    var allowedSearches: [String]? = nil

    func redirect(for url: URL) -> URL? {
        guard url.host == host else { return nil }
        if let terms = allowedSearches { return Self.isAllowed(url, terms: terms) ? nil : start }
        if blockedPrefixes.contains(where: { url.path.hasPrefix($0) }) { return start }
        if let q = forceQuery, url.path == "/" || url.path.isEmpty,
           !(url.query ?? "").contains(q) { return start }
        return nil
    }

    private static func isAllowed(_ url: URL, terms: [String]) -> Bool {
        if url.path.hasPrefix("/watch") || url.path.hasPrefix("/signin") { return true }
        guard url.path == "/results",
              let q = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "search_query" })?.value else { return false }
        return terms.contains(Session.normalize(q))
    }

    static func searchURL(_ term: String) -> URL {
        var c = URLComponents(string: "https://m.youtube.com/results")!
        c.queryItems = [URLQueryItem(name: "search_query", value: term)]
        return c.url!
    }

    /// YouTube restricted to one session's search terms (expects at least one term).
    static func youtube(terms: [String]) -> Site {
        let t = terms.map(Session.normalize)
        return Site(name: "YouTube", host: "m.youtube.com", start: searchURL(t[0]),
                    blockedPrefixes: ["/shorts"], forceQuery: nil, allowedSearches: t)
    }

    static let instagram = Site(
        name: "Instagram", host: "www.instagram.com",
        start: URL(string: "https://www.instagram.com/?variant=following")!,
        blockedPrefixes: ["/reels", "/explore/tags", "/explore/locations"],
        forceQuery: "variant=following")
}
