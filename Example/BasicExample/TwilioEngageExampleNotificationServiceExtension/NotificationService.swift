//
//  NotificationService.swift
//  TwilioEngageExampleNotificationService
//
//  Created by Alan Charles on 7/29/23.
//

import UserNotifications
import TwilioEngage

class NotificationService: UNNotificationServiceExtension {
    let engage = TwilioEngageServiceExtension()
    
    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?
    
    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        self.contentHandler = contentHandler
        bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)
      
        if let bestAttemptContent = bestAttemptContent {
      
            engage.handleNotification(content: bestAttemptContent, contentHandler)
            
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
