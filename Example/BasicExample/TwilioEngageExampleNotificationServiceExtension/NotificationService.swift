//
//  NotificationService.swift
//  TwilioEngageExampleNotificationService
//
//  Created by Alan Charles on 7/29/23.
//

import UserNotifications

class NotificationService: UNNotificationServiceExtension {
    
    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?
    let userDefaults = UserDefaults(suiteName: "group.com.segment.twilioEngage")
    
    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        self.contentHandler = contentHandler
        bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)

        if let bestAttemptContent = bestAttemptContent {
            // set badge
            let badgeAmount = bestAttemptContent.userInfo["badgeAmount"] as? Int ?? 1
            let badgeStrategy = bestAttemptContent.userInfo["badgeStrategy"] as? String
            var currentBadge = 2
            
            print("****CURRENTBADGE******\(currentBadge)")
            switch badgeStrategy {
            case "inc":
                currentBadge += badgeAmount
            case "dec":
                currentBadge -= badgeAmount
            case "set":
                currentBadge = badgeAmount
            default:
                currentBadge = badgeAmount
            }
            
            userDefaults?.set(currentBadge, forKey: "Count")
            bestAttemptContent.badge = NSNumber(value: currentBadge)

            // handle media
            var urlString: String? = nil
            if let mediaArray: NSArray = bestAttemptContent.userInfo["media"] as? NSArray {
                
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
            }
            
            
            contentHandler(bestAttemptContent)
        }
        
    }
    
    override func serviceExtensionTimeWillExpire() {
        // Called just before the extension will be terminated by the system.
        // Use this as an opportunity to deliver your "best attempt" at modified content, otherwise the original push payload will be used.
        if let contentHandler = contentHandler, let bestAttemptContent =  bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
    }
    
}

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
