import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate, UITabBarControllerDelegate {
    var window: UIWindow?
    private var session = SessionStore.load()
    private var timer: Timer?
    private let timeLabel = UILabel()   // remaining time, pinned above the tab bar

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions o: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.makeKeyAndVisible()
        render()
        return true
    }

    // No scenes in this app, so the app delegate gets the lifecycle calls.
    func applicationDidBecomeActive(_ application: UIApplication) {
        session.resume(now: Date())
        SessionStore.save(session)
        render()
        timer?.invalidate()
        let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in self?.render() }
        RunLoop.main.add(t, forMode: .common)   // keep ticking while the user scrolls
        timer = t
    }

    func applicationWillResignActive(_ application: UIApplication) {
        timer?.invalidate()
        session.pause(now: Date())
        SessionStore.save(session)
    }

    /// Shows the screen for the current phase; builds a new one only when the phase kind changes.
    private func render() {
        let now = Date()
        let before = session
        session.settle(now)
        if session != before { SessionStore.save(session) }
        let root = window?.rootViewController

        switch session.phase(at: now) {
        case .setup:
            guard !(root is SetupViewController) else { return }
            show(SetupViewController(recent: SessionStore.recentTerms) { [weak self] terms, minutes in
                self?.start(terms: terms, minutes: minutes)
            })
        case let .running(terms, remaining):
            if !(root is UITabBarController) { show(makeTabs(terms: terms)) }
            let warn = remaining <= Session.warningLead
            timeLabel.text = (warn ? " Noch " : " ") + clock(remaining) + " "
            timeLabel.backgroundColor = warn ? .systemRed : UIColor.black.withAlphaComponent(0.6)
        case let .locked(until):
            let text = "Pause\n\nWieder frei in \(clock(until.timeIntervalSince(now)))"
            if let lock = root as? MessageViewController { lock.label.text = text } else { show(MessageViewController(text)) }
        }
    }

    private func start(terms: [String], minutes: Int) {
        guard session.start(terms: terms, minutes: minutes, now: Date()) else { return }
        SessionStore.save(session)
        SessionStore.recentTerms = session.terms + SessionStore.recentTerms.filter { !session.terms.contains($0) }
        render()
    }

    private func show(_ vc: UIViewController) {
        (window?.rootViewController as? UITabBarController)?.viewControllers?
            .forEach { ($0 as? WebViewController)?.tearDown() }
        window?.rootViewController = vc
    }

    private func makeTabs(terms: [String]) -> UITabBarController {
        let tabs = UITabBarController()
        let ig = WebViewController(site: .instagram, script: Scripts.instagram)
        ig.tabBarItem = UITabBarItem(title: "Instagram", image: UIImage(systemName: "camera"), tag: 0)
        let yt: UIViewController = terms.isEmpty
            ? MessageViewController("YouTube ist in dieser Session aus.\nKein Suchbegriff gewählt.")
            : WebViewController(site: .youtube(terms: terms), script: Scripts.youtube, terms: terms)
        yt.tabBarItem = UITabBarItem(title: "YouTube", image: UIImage(systemName: "play.rectangle"), tag: 1)
        tabs.viewControllers = [ig, yt]
        tabs.delegate = self
        let bar = UITabBarAppearance()
        bar.configureWithOpaqueBackground()
        tabs.tabBar.standardAppearance = bar
        tabs.tabBar.scrollEdgeAppearance = bar

        timeLabel.font = .monospacedDigitSystemFont(ofSize: 13, weight: .semibold)
        timeLabel.textColor = .white
        timeLabel.layer.cornerRadius = 6
        timeLabel.clipsToBounds = true
        timeLabel.translatesAutoresizingMaskIntoConstraints = false
        tabs.view.addSubview(timeLabel)
        NSLayoutConstraint.activate([
            timeLabel.trailingAnchor.constraint(equalTo: tabs.view.trailingAnchor, constant: -8),
            timeLabel.bottomAnchor.constraint(equalTo: tabs.tabBar.topAnchor, constant: -6),
        ])
        return tabs
    }

    func tabBarController(_ t: UITabBarController, shouldSelect vc: UIViewController) -> Bool {
        if vc === t.selectedViewController { (vc as? WebViewController)?.toggleDebug() }
        return true
    }
}
