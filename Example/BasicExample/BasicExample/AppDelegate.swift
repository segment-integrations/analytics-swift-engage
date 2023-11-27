//
//  AppDelegate.swift
//  SegmentUIKitExample
//
//  Created by Brandon Sneed on 4/8/21.
//

import UIKit
import Segment
import UserNotifications
import UserNotificationsUI
import ProgressWebViewController
import TwilioEngage

extension Analytics {
    static var main = Analytics(configuration: Configuration(writeKey: "<Write_Key>")
        .flushAt(1)
        .trackApplicationLifecycleEvents(true))
}

@main
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    let engage = TwilioEngage { previous, current in
        Tab1ViewController.addPush(s: "Push Status Changed = \(current)")
    }
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        Analytics.main.add(plugin: UIKitScreenTracking())
        
        Analytics.main.add(plugin: engage)
        
        Analytics.main.screen(title: "home screen shown", category: nil, properties: nil)
        
        Tab1ViewController.addPush(s: "App Started, Push Status = \(engage.status)")
        
        let center  = UNUserNotificationCenter.current()
        center.delegate = self
        
        let customCategory = TwilioEngage.CustomCategory(title: "customized_push", acceptActionTitle: "Accept Title", dismissActionTitle: "Dismiss Title")
        
        let categories = engage.createDefaultCategories(customCategory: customCategory)

        UNUserNotificationCenter.current()
            .setNotificationCategories(categories)
        
        center.requestAuthorization(options: [.sound, .alert, .badge]) { (granted, error) in
            guard granted else {
                Analytics.main.declinedRemoteNotifications()
                Tab1ViewController.addPush(s: "User Declined Notifications")
                return
            }
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
        
        // Necessary in older versions of iOS.
        if let notification = launchOptions?[UIApplication.LaunchOptionsKey.remoteNotification] as? [String: Codable] {
            Tab1ViewController.addPush(s: "App Launched via Notification \(notification)")
            Analytics.main.receivedRemoteNotification(userInfo: notification)
        }
        
        return true
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Analytics.main.registeredForRemoteNotifications(deviceToken: deviceToken)
        let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
        let token = tokenParts.joined()
        Tab1ViewController.addPush(s: "Registered for Notifications \(token)")
        print(token)
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        Analytics.main.failedToRegisterForRemoteNotification(error: error)
        Tab1ViewController.addPush(s: "Failed to register for Notifications")
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler:
        @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let userInfo = notification.request.content.userInfo
        Tab1ViewController.addPush(s: "Received in foreground: \(userInfo)")
        Analytics.main.receivedRemoteNotification(userInfo: userInfo)
        
        completionHandler([.banner, .sound, .badge])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void)
    {
        let userInfo = response.notification.request.content.userInfo
        Tab1ViewController.addPush(s: "Received in background: \(userInfo)")
        Analytics.main.receivedRemoteNotification(userInfo: userInfo)

        engage.handleNotificiation(response: response)
        completionHandler()
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
      
        UserDefaults(suiteName: "group.com.segment.twilioEngage")?.set(0, forKey: "Count");  UIApplication.shared.applicationIconBadgeNumber = 0
    }
    
    // MARK: UISceneSession Lifecycle
    
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
    
    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }
    
}

extension AppDelegate {
    func openWebview(notification: [AnyHashable : Any], shouldAsk: Bool) {
        let webViewController = ProgressWebViewController(nibName: "Main", bundle: Bundle.main)
        guard var urlString = notification["link"] as? String else { return }
        urlString = urlString.replacingOccurrences(of: "engage://", with: "https://")
        guard let url = URL(string: urlString) else { return }
        
        let aps = notification["aps"] as? [AnyHashable: Any]
        let alert = aps?["alert"] as? [AnyHashable: Any]
        let title = alert?["title"] as? String
        if shouldAsk == true, let title = title {
            let alert = UIAlertController(
                title: "New Product Alert!",
                message: title,
                preferredStyle: UIAlertController.Style.alert
            )
            
            alert.addAction(UIAlertAction(title: "Maybe Later", style: UIAlertAction.Style.default, handler: { _ in
                //Cancel Action
            }))
            alert.addAction(UIAlertAction(title: "Sure!",
                                          style: UIAlertAction.Style.default,
                                          handler: {(_: UIAlertAction!) in
                webViewController.websiteTitleInNavigationBar = true
                webViewController.load(url)
                webViewController.navigationWay = .push(targetViewController: webViewController)
                webViewController.pullToRefresh = true
                //mainView?.navigationController?.pushViewController(webViewController, animated: true)
            }))
            mainView?.present(alert, animated: true, completion: nil)
        } else {
            webViewController.websiteTitleInNavigationBar = true
            webViewController.load(url)
            webViewController.navigationWay = .push(targetViewController: webViewController)
            webViewController.pullToRefresh = true
            
            //mainView?.navigationController?.pushViewController(webViewController, animated: true)
        }
    }
    
    private func openDeepLinkViewController(notification: [AnyHashable: Any], shouldAsk: Bool)
    {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        guard var deepLinkString = notification["link"] as? String else { return }
        let deepLinkScreen = deepLinkString.replacingOccurrences(of: "engage://", with: "")
        let deepLinkVC = storyboard.instantiateViewController(identifier: deepLinkScreen)
        
        let aps = notification["aps"] as? [AnyHashable: Any]
        let alert = aps?["alert"] as? [AnyHashable: Any]
        let title = alert?["title"] as? String
        if shouldAsk == true, let title = title {
            let alert = UIAlertController(
                title: "New Product Alert!",
                message: title,
                preferredStyle: UIAlertController.Style.alert
            )
            
            alert.addAction(UIAlertAction(title: "Maybe Later", style: UIAlertAction.Style.default, handler: { _ in
                //Cancel Action
            }))
            alert.addAction(UIAlertAction(title: "Sure!",
                                          style: UIAlertAction.Style.default,
                                          handler: {(_: UIAlertAction!) in
                mainView?.navigationController?.pushViewController(deepLinkVC, animated: true)
            }))
            mainView?.present(alert, animated: true, completion: nil)
        } else {
            mainView?.navigationController?.pushViewController(deepLinkVC, animated: true)
        }
    }
}
