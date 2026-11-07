import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate, UITabBarControllerDelegate {
    var window: UIWindow?
    private var session = SessionStore.load()
    private var timer: Timer?
    private let timeLabel = UILabel()   // remaining time, pinned above the tab bar
    private var warned = false          // last-minute banner already shown for this stretch

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
            if warn && !warned, let tabs = window?.rootViewController { showWarning(on: tabs.view) }
            warned = warn
        case let .locked(until):
            let text = "Pause\n\nWieder frei in \(clock(until.timeIntervalSince(now)))"
            if let lock = root as? MessageViewController { lock.label.text = text } else { show(MessageViewController(text)) }
        }
    }

    /// Last-minute warning: banner at the top for a few seconds plus a haptic buzz.
    private func showWarning(on view: UIView) {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        let banner = UILabel()
        banner.text = "Noch 1 Minute"
        banner.font = .preferredFont(forTextStyle: .headline)
        banner.textAlignment = .center
        banner.textColor = .white
        banner.backgroundColor = .systemRed
        banner.layer.cornerRadius = 12
        banner.clipsToBounds = true
        banner.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(banner)
        NSLayoutConstraint.activate([
            banner.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            banner.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            banner.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            banner.heightAnchor.constraint(equalToConstant: 48),
        ])
        UIView.animate(withDuration: 0.4, delay: 4, options: [], animations: { banner.alpha = 0 }) { _ in
            banner.removeFromSuperview()
        }
    }

    private func start(terms: [String], minutes: Int) {
        guard session.start(terms: terms, minutes: minutes, now: Date()) else { return }
        warned = false
        saveWithRecent()
        render()
    }

    private func saveWithRecent() {
        SessionStore.save(session)
        SessionStore.recentTerms = session.terms + SessionStore.recentTerms.filter { !session.terms.contains($0) }
    }

    /// "Thema" button: edit the terms mid-session; the clock keeps running.
    private func askForNewTerms(on vc: UIViewController) {
        let alert = UIAlertController(title: "Thema ändern", message: "Kommagetrennt, leer = nur Instagram. Die Zeit läuft weiter.", preferredStyle: .alert)
        alert.addTextField { [session] f in
            f.text = session.terms.joined(separator: ", ")
            f.autocapitalizationType = .none
            f.clearButtonMode = .whileEditing
        }
        alert.addAction(UIAlertAction(title: "Abbrechen", style: .cancel))
        alert.addAction(UIAlertAction(title: "Übernehmen", style: .default) { [weak self, weak alert] _ in
            guard let self, let text = alert?.textFields?.first?.text,
                  self.session.changeTerms(text.split(separator: ",").map(String.init), now: Date()) else { return }
            self.saveWithRecent()
            self.show(self.makeTabs(terms: self.session.terms))
            self.render()
        })
        vc.present(alert, animated: true)
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

        var cfg = UIButton.Configuration.filled()
        cfg.title = "Thema"
        cfg.image = UIImage(systemName: "pencil")
        cfg.imagePadding = 4
        cfg.buttonSize = .mini
        cfg.baseBackgroundColor = UIColor.black.withAlphaComponent(0.6)
        let themeButton = UIButton(configuration: cfg, primaryAction: UIAction { [weak self, weak tabs] _ in
            if let tabs { self?.askForNewTerms(on: tabs) }
        })
        themeButton.translatesAutoresizingMaskIntoConstraints = false
        tabs.view.addSubview(themeButton)

        timeLabel.font = .monospacedDigitSystemFont(ofSize: 13, weight: .semibold)
        timeLabel.textColor = .white
        timeLabel.layer.cornerRadius = 6
        timeLabel.clipsToBounds = true
        timeLabel.translatesAutoresizingMaskIntoConstraints = false
        tabs.view.addSubview(timeLabel)
        NSLayoutConstraint.activate([
            timeLabel.trailingAnchor.constraint(equalTo: tabs.view.trailingAnchor, constant: -8),
            timeLabel.bottomAnchor.constraint(equalTo: tabs.tabBar.topAnchor, constant: -6),
            themeButton.leadingAnchor.constraint(equalTo: tabs.view.leadingAnchor, constant: 8),
            themeButton.centerYAnchor.constraint(equalTo: timeLabel.centerYAnchor),
        ])
        return tabs
    }

    func tabBarController(_ t: UITabBarController, shouldSelect vc: UIViewController) -> Bool {
        if vc === t.selectedViewController { (vc as? WebViewController)?.toggleDebug() }
        return true
    }
}
