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
        case tapped = "Push Opened" // App was not running
        case received = "Push Delivered" // App was running
        case registered = "Registered for Push"
        case unregistered = "Unable to Register for Push"
        case changed = "Push Subscription Change"
        case declined = "Push Subscription Declined"
    }
    
    internal let userDefaults = UserDefaults(suiteName: "com.twilio.engage")

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
    
    public var deviceToken: String? = nil
    
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
//        guard var properties = event.properties else {return event }
        
        // this will succeed if the event name can be used to generate a push event case.
        guard Events(rawValue: event.event) != nil else { return event as? T }
       
        // we only need to add a deDup_id to `push recieved` and `push opened` events
        if event.event == Events.tapped.rawValue || event.event == Events.received.rawValue {
            if var properties = event.properties?.dictionaryValue {
                let formattedEventName = event.event.lowercased().replacingOccurrences(of: " ", with: "_")
//                if properties.con
                let messageId = properties["message_id"] ?? UUID().toString()
                let deDup_id = "\(formattedEventName)\(messageId)"
                properties[keyPath: "dedup_id"] = deDup_id
                
                event.properties = try? JSON(properties)
            }
        }

        // `messaging_subscription` data type is an array of objects
        context[keyPath: KeyPath(Self.contextKey)] = [[
            "key": deviceToken,
            "type": Self.subscriptionType,
            "status": status.rawValue
        ]]
        
      
        event.context = context
        return event as? T
    }
    
    func trackNotification(_ properties: [String: Any], fromLaunch launch: Bool) {
        if launch {
            analytics?.track(name: Events.tapped.rawValue, properties: properties)
            print("Push Notification Tapped (launch=true)")
        } else {
            analytics?.track(name: Events.received.rawValue, properties: properties)
            print("Push Notification Received (launch=false)")
        }
    }
}

extension TwilioEngage: RemoteNotifications {
    public func receivedRemoteNotification(userInfo: [AnyHashable: Any]) {
        if let notification = userInfo as? [String: Any] {
            trackNotification(notification, fromLaunch: false)
        }
    }
    
    public func declinedRemoteNotifications() {
        self.deviceToken = nil
        self.status = .didNotSubscribe
        analytics?.track(name: Events.declined.rawValue)
        print("Push Notifications were declined.")
    }
    
    public func registeredForRemoteNotifications(deviceToken: Data) {
        let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
        let token = tokenParts.joined()
        self.deviceToken = token
        self.status = .subscribed
        analytics?.track(name: Events.registered.rawValue, properties: ["token": token])
        print("Registered for Push Notifications (token=\(token)")
    }
    
    public func failedToRegisterForRemoteNotification(error: Error?) {
        self.deviceToken = nil
        self.status = .didNotSubscribe
        analytics?.track(name: Events.unregistered.rawValue, properties: ["error": error?.localizedDescription ?? NSNull() ])
        print("Unable to register for Push Notifications (error=\(error?.localizedDescription ?? "unknown")")
    }
}


#if os(tvOS) || os(iOS) || targetEnvironment(macCatalyst)
import UIKit
extension TwilioEngage: iOSLifecycle {
    public func application(_ application: UIApplication?, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) {
        // notification was received while the app was not running.
        if let notification = launchOptions?[UIApplication.LaunchOptionsKey.remoteNotification] as? [String: Codable] {
            trackNotification(notification, fromLaunch: true)
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
