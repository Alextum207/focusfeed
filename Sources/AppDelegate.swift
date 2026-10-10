import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions o: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let tabs = UITabBarController()
        let ig = WebViewController(site: .instagram, script: Scripts.instagram)
        ig.tabBarItem = UITabBarItem(title: "Instagram", image: UIImage(systemName: "camera"), tag: 0)
        let yt = WebViewController(site: .youtube, script: Scripts.youtube)
        yt.tabBarItem = UITabBarItem(title: "YouTube", image: UIImage(systemName: "play.rectangle"), tag: 1)
        tabs.viewControllers = [ig, yt]
        let bar = UITabBarAppearance()
        bar.configureWithOpaqueBackground()
        tabs.tabBar.standardAppearance = bar
        tabs.tabBar.scrollEdgeAppearance = bar
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = tabs
        window?.makeKeyAndVisible()
        return true
    }
}
