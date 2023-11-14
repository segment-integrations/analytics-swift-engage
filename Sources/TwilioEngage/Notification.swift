//
//  File.swift
//  
//
//  Created by Alan Charles on 11/10/23.
//

import Foundation

public extension Notification.Name {
  
 static let openButton = Notification.Name("acceptTapped")
 static let dismissButton = Notification.Name("rejectTapped")

  func post(
    center: NotificationCenter = NotificationCenter.default,
    object: Any? = nil,
    userInfo: [AnyHashable : Any]? = nil) {
        
    center.post(name: self, object: object, userInfo: userInfo)
  }

  @discardableResult
  func onPost(
    center: NotificationCenter = NotificationCenter.default,
    object: Any? = nil,
    queue: OperationQueue? = nil,
    using: @escaping (Notification) -> Void)
    -> NSObjectProtocol {
    
    return center.addObserver(
      forName: self,
      object: object,
      queue: queue,
      using: using)
  }
}
