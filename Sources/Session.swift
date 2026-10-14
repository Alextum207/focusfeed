import Foundation

/// The whole time/lock state machine. Pure: every call gets `now`, nothing reads a clock.
/// Time only counts while the app is active (between `resume` and `pause`).
struct Session: Codable, Equatable {
    static let maxMinutes = 90
    static let lockFactor = 4.0
    static let backgroundTimeout: TimeInterval = 30 * 60
    static let warningLead: TimeInterval = 60

    enum Phase: Equatable {
        case setup
        case running(terms: [String], remaining: TimeInterval)
        case locked(until: Date)
    }

    private(set) var terms: [String] = []
    private var budget: TimeInterval = 0       // > 0 while a session runs
    private var used: TimeInterval = 0         // active time banked at the last pause
    private var activeSince: Date?             // set while the app is active
    private var pausedAt: Date?                // set while the app is inactive
    private var lockedUntil: Date?

    /// Starts a session; returns false (and changes nothing) unless in setup with 1...90 minutes.
    @discardableResult
    mutating func start(terms: [String], minutes: Int, now: Date) -> Bool {
        settle(now)
        guard phase(at: now) == .setup, (1...Self.maxMinutes).contains(minutes) else { return false }
        self = Session()
        self.terms = terms.map(Self.normalize).filter { !$0.isEmpty }
        budget = TimeInterval(minutes * 60)
        activeSince = now
        return true
    }

    /// App became active.
    mutating func resume(now: Date) {
        settle(now)
        guard budget > 0, activeSince == nil else { return }
        pausedAt = nil
        activeSince = now
    }

    /// App resigned active (app switch, screen lock, Control Center).
    mutating func pause(now: Date) {
        settle(now)
        guard budget > 0, let since = activeSince else { return }
        used += now.timeIntervalSince(since)
        activeSince = nil
        pausedAt = now
    }

    /// Applies every transition that is due at `now` (budget used up, background timeout, lock over).
    mutating func settle(_ now: Date) {
        if budget > 0, let since = activeSince, used + now.timeIntervalSince(since) >= budget {
            lock(from: since.addingTimeInterval(budget - used), used: budget)
        } else if budget > 0, let p = pausedAt, now.timeIntervalSince(p) >= Self.backgroundTimeout {
            lock(from: p, used: used)
        }
        if let until = lockedUntil, now >= until { self = Session() }
    }

    func phase(at now: Date) -> Phase {
        var s = self
        s.settle(now)
        if let until = s.lockedUntil { return .locked(until: until) }
        guard s.budget > 0 else { return .setup }
        let active = s.used + (s.activeSince.map { now.timeIntervalSince($0) } ?? 0)
        return .running(terms: s.terms, remaining: s.budget - active)
    }

    private mutating func lock(from end: Date, used: TimeInterval) {
        self = Session()
        if used > 0 { lockedUntil = end.addingTimeInterval(used * Self.lockFactor) }
    }

    /// Lowercased, trimmed, single-spaced; "+" counts as a space (YouTube's query encoding).
    static func normalize(_ term: String) -> String {
        term.replacingOccurrences(of: "+", with: " ").lowercased()
            .split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}

/// UserDefaults persistence for the session and the recently used terms.
enum SessionStore {
    private static let key = "ff.session", recentKey = "ff.recentTerms"

    static func load() -> Session {
        guard let d = UserDefaults.standard.data(forKey: key),
              let s = try? JSONDecoder().decode(Session.self, from: d) else { return Session() }
        return s
    }
    static func save(_ s: Session) {
        if let d = try? JSONEncoder().encode(s) { UserDefaults.standard.set(d, forKey: key) }
    }
    static var recentTerms: [String] {
        get { UserDefaults.standard.stringArray(forKey: recentKey) ?? [] }
        set { UserDefaults.standard.set(Array(newValue.prefix(8)), forKey: recentKey) }
    }
}
