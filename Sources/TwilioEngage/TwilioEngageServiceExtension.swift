//
//  TwilioEngageServiceExtension.swift
//
//  Created by Alan Charles on 11/21/23.
//

import Foundation
import Segment
import UserNotifications

public class TwilioEngageServiceExtension: UtilityPlugin {
    public var type = PluginType.utility
    public weak var analytics: Analytics? = nil
    let userDefaults = UserDefaults(suiteName: "group.com.segment.twilioEngage")

    public init() {
    }

    public func configure(analytics: Analytics) {
        self.analytics = analytics
    }
    
    public func handleNotification(content: UNMutableNotificationContent, _ contentHandler: @escaping (UNNotificationContent) -> Void)  {
        
        // set badge
        let badgeAmount = content.userInfo["badgeAmount"] as? Int ?? 1
        let badgeStrategy = content.userInfo["badgeStrategy"] as? String
        var currentBadge = 2
        
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
        content.badge = NSNumber(value: currentBadge)
        
        // handle media
        var urlString: String? = nil
        if let mediaArray: NSArray = content.userInfo["media"] as? NSArray {
            
            if let mediaURLString = mediaArray[0] as? String {
                urlString = mediaURLString
            }
            
            if urlString != nil, let fileURL = URL(string: urlString!){
                
                guard let mediaData = NSData(contentsOf: fileURL) else {
                    contentHandler(content)
                    return
                }
                
                guard let mediaAttachment = UNNotificationAttachment.saveImageToDisk(fileIdentifier: "engage-image.png", data: mediaData, options: nil) else {
                    contentHandler(content)
                    return
                }
                
                content.attachments = [ mediaAttachment ]
            }
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

