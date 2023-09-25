
# Twilio Engage Plugin

- [Twilio Engage Destination](#twilio-engage-destination)
  - [Getting Started](#getting-started)
  - [Subscription](#subscription)
  - [Additional Setup](#additional-setup)
  - [Predefined Actions](#predefined-actions)
  - [Handling Notifications](#handling-notifications)
  - [Handling Media](#handling-media)
    - [Create Extension](#creating-the-extension)
    - [Display Media](#displaying-media)
  - [License](#license)

This plugin enables Segment's Analytics SDK to do push notification management with Twilio Engage.

## Getting Started

To get started:
1. follow the set up instructions for Analytics Swift [here](https://segment.com/docs/connections/sources/catalog/libraries/mobile/kotlin-android/#getting-started) 
to integrate Segment's Analytics SDK into your app. 
2. add the dependency: 

### via Xcode
In the Xcode `File` menu, click `Add Packages`.  You'll see a dialog where you can search for Swift packages.  In the search field, enter the URL to this repo.

```
https://github.com/segment-integrations/analytics-swift-engage
```

You'll then have the option to pin to a version, or specific branch, as well as which project in your workspace to add it to.  Once you've made your selections, click the `Add Package` button.  

### via Package.swift

Open your Package.swift file and add the following do your the `dependencies` section:

```
.package(
            name: "Segment",
            url: "https://github.com/segment-integrations/analytics-swift-engage.git",
            from: "1.1.2"
        ),
```

3. Import the Plugin in the file you configure your analytics instance: 

```
import Segment
import TwilioEngage // <-- Add this line
```

4. Just under your Analytics-Swift library setup, call `analytics.add(plugin: ...)` to add an instance of the plugin to the Analytics timeline.

```
let analytics = Analytics(configuration: Configuration(writeKey: "<YOUR WRITE KEY>")
                    .flushAt(3)
                    .trackApplicationLifecycleEvents(true))

let engage = TwilioEngage { previous, current in
    print("Push Status Changed /(current)")
}

analytics.add(plugin: engage)
```
## Subscription

Once the plugin is setup, it automatically tracks and updates push notification subscriptions 
according to device's notification permissions. To listen to the subscription status changes, 
provide a `StatusCallback` when initialize the plugin as following:
```swift
let engage = TwilioEngage { previous, current in
    //handle status updates 
    print("Push Status Changed /(current)")
}
```

On iOS, three different statuses are tracked: `Subscribed`, `DidNotSubscribe`, `Unsubscribed`. 
* `Subscribed` is reported whenever app user toggles their device settings to allow push notification
* `DidNotSubscribe` is reported in fresh start where no status has ever been reported
* `Unsubscribed` is reported whenever user toggles their device settings to disable push notification and when the SDK fails to obtain a token from APNS


## Additional Setup 

You will also need to add or modify the following methods in your `AppDelegate` in order to start receiving and handling push notifications: 

**AppDelegate**

```Swift
   func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

    //add the following:

        let center  = UNUserNotificationCenter.current()
        center.delegate = self
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
        
        //Necessary in older versions of iOS.
        if let notification = launchOptions?[UIApplication.LaunchOptionsKey.remoteNotification] as? [String: Codable] {
            Tab1ViewController.addPush(s: "App Launched via Notification \(notification)")
            Analytics.main.receivedRemoteNotification(userInfo: notification)
        }

        ...

        return true
}

func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    //Segment event to register for remote notifications
    Analytics.main.registeredForRemoteNotifications(deviceToken: deviceToken)
}

func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
    //Segment event for failure to register for remote notifications
    Analytics.main.failedToRegisterForRemoteNotification(error: error)
}

func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any]) async -> UIBackgroundFetchResult {
    //Segment event for receiving a remote notification
    Analytics.main.receivedRemoteNotification(userInfo: userInfo)

    //Handle the notification however you see fit

    return .noData
}

func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
    let userInfo = response.notification.request.content.userInfo
    //Segment event for receiving a remote notification
    Analytics.main.receivedRemoteNotification(userInfo: userInfo)

    //Handle the notification however you see fit
}
```

## Predefined Actions

Twilio Engage provides 4 predefined `tapActions` that you can handle however you see fit.
* `open_app`: the app opens to the main view when the notification/button is on tapped.
* `open_url`: the default browser opens a webview to the provided `link`
* `deep_link`: the application routes to the provided `link`
* `<custom_action>`: a custom string which can be handled much like a deep-link depending on the use case.

## Handling Notifications

How you handle and display notifications is entirely up to you. Examples for each of the predefined `tapActions` can be found below: 

**AppDelegate**

When a push is received by a device the data is available in `didReceiveRemoteNotification` (recieved in background) and `userNotificationCenter` (recieved in foreground) in your AppDelegate

```Swift
func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any]) async -> UIBackgroundFetchResult {
    //Segment event for receiving a remote notification
    Analytics.main.receivedRemoteNotification(userInfo: userInfo)

    //add a custom method to handle the notification data 
    handleNotificiation(notification: userInfo, shouldAsk: true)

    return .noData
  }

func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
    //Segment event for receiving a remote notification
    Analytics.main.receivedRemoteNotification(userInfo: userInfo)

    //add a custom method to handle the notification data 
    handleNotificiation(notification: userInfo, shouldAsk: false)
}

 ...

//an extension for logic for displaying different notification types: 
extension AppDelegate {

  //Handle the notification bacsed on the `tapAction`
  func handleNotificiation(notification: [AnyHashable: Any], shouldAsk: Bool) {
    if let aps = notification["aps"] as? NSDictionary {
      if let tapAction = aps["category"] as? String {
        switch tapAction {
          case "open_url":
            //add functionality for displaying a webview or opening a default browser 
          case "deep_link":
            //add functionality for navigating to a specific screen in the app 
          case "<custom_action>":
            //handle a custom action like accept/decline or confirm/cancel  
          default:
            //this will catch `open_app` to open home screen
            return
        }
      }
    }
  }
}
```

## Handling Media

If you would like to display media in your push notifications, you will need to add a `NotificationService` extension to your app. Reference Apple's documentation for a more detailed overview of [UNNotificationServiceExtension](https://developer.apple.com/documentation/usernotifications/unnotificationserviceextension).

### Creating the Extension 

1. in Xcode, go to File -> New -> Target
<img width="561" alt="image" src="https://github.com/segment-integrations/analytics-swift-engage/assets/50601149/a95db4c4-dc21-4033-89a8-b88cf9cbbd2b">

2. search for the `Notification Service Extension`
<img width="715" alt="image" src="https://github.com/segment-integrations/analytics-swift-engage/assets/50601149/8d23555a-4431-4715-877b-52778e8e489d">

3. name the extension `<YourAppName>NotificationService>` and finish the creation process.
4. `<YourAppName>NotificationService/NotificationService>` is where you can add custom logic to handle and display media.

### Displaying Media
**NotificationService `didRecieve` example**

```swift
    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        self.contentHandler = contentHandler
        bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)
        
        if let bestAttemptContent = bestAttemptContent {
            var urlString: String? = nil
            let mediaArray: NSArray = bestAttemptContent.userInfo["media"] as! NSArray
            
            if let mediaURLString = mediaArray[0] as? String {
                urlString = mediaURLString
            }
            
            if urlString != nil, let fileURL = URL(string: urlString!){
                
                guard let mediaData = NSData(contentsOf: fileURL) else {
                    contentHandler(bestAttemptContent)
                    return
                }
                
                guard let mediaAttachment = UNNotificationAttachment.saveImageToDisk(fileIdentifier: "engage-image.png", data: mediaData, options: nil) else {
                    contentHandler(bestAttemptContent)
                    return
                }
                
                bestAttemptContent.attachments = [ mediaAttachment ]
            }
            contentHandler(bestAttemptContent)
        }
        
    }

...

//add an extension to `UNNotificationAttachment` to download/save the image 
@available(iOSApplicationExtension 10.0, *)
extension UNNotificationAttachment {
    
    static func saveImageToDisk(fileIdentifier: String, data: NSData, options: [NSObject : AnyObject]?) -> UNNotificationAttachment? {
        let fileManager = FileManager.default
        let folderName = ProcessInfo.processInfo.globallyUniqueString
        let folderURL = NSURL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(folderName, isDirectory: true)
        
        do {
            try fileManager.createDirectory(at: folderURL!, withIntermediateDirectories: true, attributes: nil)
            let fileURL = folderURL?.appendingPathComponent(fileIdentifier)
            try data.write(to: fileURL!, options: [])
            let attachment = try UNNotificationAttachment(identifier: fileIdentifier, url: fileURL!, options: options)
            return attachment
        } catch let error {
            print("error \(error)")
        }
        
        return nil
    }
}
```

## License
```
MIT License

Copyright (c) 2021 Segment

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```
