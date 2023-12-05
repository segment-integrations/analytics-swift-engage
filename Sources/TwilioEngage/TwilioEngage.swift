//
//  TwilioEngage.swift
//
//  Created by Brandon Sneed on 5/4/23.
//

#if !os(Linux)

import Foundation
import Segment
import UserNotifications

public class TwilioEngage: EventPlugin {
    public var type = PluginType.enrichment
    public weak var analytics: Analytics? = nil
    
    internal static let subscriptionType = "IOS_PUSH"
    internal static let contextKey = "messaging_subscriptions"
    
    public typealias SubscriptionStatusCallback = (_ previous: Status, _ current: Status) -> Void
    internal let statusCallback: SubscriptionStatusCallback?
    
    public enum Status: String {
        case subscribed = "SUBSCRIBED"
        case unsubscribed = "UNSUBSCRIBED"
        case didNotSubscribe = "DID_NOT_SUBSCRIBE"
    }
    
    internal enum Events: String, CaseIterable {
        case opened = "Push Opened"
        case registered = "Registered for Push"
        case unregistered = "Unable to Register for Push"
        case changed = "Push Subscription Change"
        case declined = "Push Subscription Declined"
        case action = "Action Button Pressed"
        case actionIgnored = "Action Button Declined"
    }
    
    internal let userDefaults = UserDefaults(suiteName: "group.com.segment.twilioEngage")

    public var status: Status {
        get {
            guard let value = userDefaults?.string(forKey: "Status") else { return .didNotSubscribe }
            guard let status = Status(rawValue: value) else { return .didNotSubscribe }
            return status
        }
        set(value) {
            userDefaults?.set(value.rawValue, forKey: "Status")
            if self.status != value, let callback = statusCallback {
                callback(self.status, value)
            }
        }
    }
    
    public init(statusCallback: SubscriptionStatusCallback?) {
        self.statusCallback = statusCallback
    }
    
    public var deviceToken: String? = UserDefaults.standard.string(forKey: "deviceToken") ?? nil
    
    public func configure(analytics: Analytics) {
        self.analytics = analytics
        // once we're configured, get a handle on our subscription status.
        updateStatus()
    }
    
    public func reset() {
        // do we need to reset anything here?
        // like stored subscription info maybe?
    }
    
    public func updateStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            guard let self = self else { return }
            
            let currentStatus = self.status
            var newStatus = currentStatus
            
            switch settings.authorizationStatus {
            case .notDetermined:
                newStatus = .didNotSubscribe
            case .denied:
                // accounts for user disabling notifications in settings
                if currentStatus == .subscribed {
                    newStatus = .unsubscribed
                } else {
                    newStatus = .didNotSubscribe
                }
            default:
                // These cases are all some version of subscribed.
                //case .authorized:
                //case .provisional:
                //case .ephemeral:
                newStatus = .subscribed
            }
            
            if newStatus != currentStatus {
                self.status = newStatus
                // if we're subscribed now (we weren't previously, user enabled in settings), we need to
                // register for push notifications so we can get our device token.
                if newStatus == .subscribed {
                    DispatchQueue.main.async {
                        UIApplication.shared.registerForRemoteNotifications()
                    }
                }
                
                print("Push Status Changed, old=\(currentStatus), new=\(newStatus)")
                self.analytics?.track(name: Events.changed.rawValue)
            }
        }
    }
    
    public func execute<T>(event: T?) -> T? where T : RawEvent {
        // we only wanna look at track events
        guard var event = event as? TrackEvent else { return event }
        guard var context = event.context else { return event as? T }
        
        // this will succeed if the event name can be used to generate a push event case.
        guard Events(rawValue: event.event) != nil else { return event as? T }
        
        // we only need to add a deDup_id to `push recieved` and `push opened` events
        if event.event == Events.opened.rawValue {
            if var properties = event.properties?.dictionaryValue {
                let formattedEventName = event.event.lowercased().replacingOccurrences(of: " ", with: "_")
                let messageId: String = properties["message_id"] as? String ?? UUID().toString()
                let deDup_id = "\(messageId)\(formattedEventName)"
                properties[keyPath: "dedup_id"] = deDup_id
                properties[keyPath: "event_id"] = messageId
                event.properties = try? JSON(properties)
            }
        }
        
        //only events that manipulate a user's subscription status
        //should include `messaging_subscription` data
        if event.event != Events.opened.rawValue {
            // `messaging_subscription` data type is an array of objects
            context[keyPath: KeyPath(Self.contextKey)] = [[
                "key": deviceToken,
                "type": Self.subscriptionType,
                "status": status.rawValue
            ]]
        }
        
        event.context = context
        return event as? T
    }
    
    func trackNotification(_ properties: [String: Any]) {
        analytics?.track(name: Events.opened.rawValue, properties: properties)
    }
}

extension TwilioEngage: RemoteNotifications {
    public func receivedRemoteNotification(userInfo: [AnyHashable: Any]) {
        if let notification = userInfo as? [String: Any] {
            trackNotification(notification)
            
        }
    }
    
    public func declinedRemoteNotifications() {
        self.status = .didNotSubscribe
        analytics?.track(name: Events.declined.rawValue)
        print("Push Notifications were declined.")
    }
    
    public func registeredForRemoteNotifications(deviceToken: Data) {
        let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
        let token = tokenParts.joined()
        self.deviceToken = token
        UserDefaults.standard.set(token, forKey: "deviceToken")
        self.status = .subscribed
        analytics?.track(name: Events.registered.rawValue, properties: ["token": token])
        print("Registered for Push Notifications (token=\(token)")
    }
    
    public func failedToRegisterForRemoteNotification(error: Error?) {
        self.status = .didNotSubscribe
        analytics?.track(name: Events.unregistered.rawValue, properties: ["error": error?.localizedDescription ?? NSNull() ])
        print("Unable to register for Push Notifications (error=\(error?.localizedDescription ?? "unknown")")
    }
    
    public func handleNotificiation(response: UNNotificationResponse) {
        let userInfo = response.notification.request.content.userInfo
        let identity = response.notification
            .request.content.categoryIdentifier
        let actionIdentifier = response.actionIdentifier
        let actionIdentifierArr = actionIdentifier.components(separatedBy: "-")
        let identifier = actionIdentifierArr.count > 0 ? actionIdentifierArr[0] : ""
        let id = actionIdentifierArr.count > 1 ? actionIdentifierArr[1] : ""
        
        switch identifier {
        case "com.apple.UNNotificationDefaultActionIdentifier":
            handleTapNotification(identity: identity, userInfo: userInfo)
        case "open_app":
            return
        case "deep_link":
            handleDeepLinksActionButtons(userInfo: userInfo, id: id)
        case "open_url":
            handleOpenUrlsActionButtons(id: id)
        default:
            handleCustomActionButtons(userInfo: userInfo, id: id)
        }
    }
    
    func handleTapNotification(identity: String, userInfo: [AnyHashable: Any]) {
        switch identity {
        case "open_app":
            return
        case "deep_link":
            handleDeepLinks(userInfo: userInfo)
        case "open_url":
            handleOpenUrls(userInfo: userInfo)
        default:
            handleCustomAction(userInfo: userInfo, identity: identity)
        }
    }
    
    func handleDeepLinks(userInfo: [AnyHashable: Any]) {
        if let actionLink = userInfo["link"] as? String {
            var deepLinkData: [AnyHashable: Any] = [
                "deep_link": actionLink,
            ]
            
            //merge existing userInfo into deepLinkData dictionary
            deepLinkData.merge(userInfo) { (current, _) in current }
            
            Notification.Name.openButton.post(userInfo: deepLinkData)
        }
    }
    
    func handleOpenUrls(userInfo: [AnyHashable: Any]) {
        if let urlString = userInfo["link"] as? String {
            guard let url = URL(string: urlString) else {return}
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }
    
    func handleCustomAction(userInfo: [AnyHashable: Any], identity: String) {
        if identity != "" {
            var customActionData: [AnyHashable: Any] = [
                "custom_action": identity,
            ]
            
            //merge existing userInfo into customActionData dictionary
            customActionData.merge(userInfo) { (current, _) in current }
            
            Notification.Name.openButton.post(userInfo: customActionData)
        }
    }
    
    func handleOpenUrlsActionButtons(id: String) {
        if let actionLink = userDefaults?.string(forKey: "ActionLink-\(id)") as? String {
            guard let url = URL(string: actionLink) else {return}
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
            userDefaults?.removeObject(forKey: "ActionLink-\(id)")
        }
    }
    
    func handleDeepLinksActionButtons(userInfo: [AnyHashable: Any], id: String) {
        if let actionLink = userDefaults?.string(forKey: "ActionDeepLink-\(id)") as? String {
            var deepLinkData: [AnyHashable: Any] = [
                "deep_link": actionLink,
            ]
            
            //merge existing userInfo into deepLinkData dictionary
            deepLinkData.merge(userInfo) { (current, _) in current }
            
            Notification.Name.openButton.post(userInfo: deepLinkData)
            userDefaults?.removeObject(forKey: "ActionDeepLink-\(id)")
        }
    }
    
    func handleCustomActionButtons(userInfo: [AnyHashable: Any], id: String) {
        if let customAction = userDefaults?.string(forKey: "CustomAction-\(id)") as? String {
            var customActionData: [AnyHashable: Any] = [
                "custom_action": customAction,
            ]
            
            //merge existing userInfo into customActionData dictionary
            customActionData.merge(userInfo) { (current, _) in current }
            
            Notification.Name.openButton.post(userInfo: customActionData)
            userDefaults?.removeObject(forKey: "CustomAction-\(id)")
        }
    }
}

#if os(tvOS) || os(iOS) || targetEnvironment(macCatalyst)
import UIKit
extension TwilioEngage: iOSLifecycle {
    public func application(_ application: UIApplication?, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) {
        // notification was received while the app was not running.
        if let notification = launchOptions?[UIApplication.LaunchOptionsKey.remoteNotification] as? [String: Codable] {
            trackNotification(notification)
        }
    }
    
    public func applicationWillEnterForeground(application: UIApplication?) {
        // check our status to see if it's changed from last time and report if necessary.
        // user could've changed status in the settings app while we weren't around.
        updateStatus()
    }
    
}
#endif

#if os(macOS)
import Cocoa
extension NotificationTracking: macOSLifecycle {
    func application(didFinishLaunchingWithOptions launchOptions: [String: Any]?) {
        if let notification = launchOptions?[NSApplication.launchUserNotificationUserInfoKey] as? [String: Any] {
            trackNotification(notification, fromLaunch: true)
        }
    }
}
#endif

#endif // !Linux
