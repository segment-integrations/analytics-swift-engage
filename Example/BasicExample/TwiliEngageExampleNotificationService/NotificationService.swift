//
//  NotificationService.swift
//  TwilioEngageExampleNotificationService
//
//  Created by Alan Charles on 7/29/23.
//

import UserNotifications
import Segment
import TwilioEngage
import UserNotificationsUI

// add service extension package here
class NotificationService: UNNotificationServiceExtension {
    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        let bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)
        
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
}

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


