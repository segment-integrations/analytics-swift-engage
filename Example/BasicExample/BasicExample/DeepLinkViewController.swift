//
//  DeepLinkViewController.swift
//  TwilioEngageExample
//
//  Created by Alan Charles on 8/2/23.
//

import Foundation
import UIKit

class DeepLinkViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let label = UILabel(frame: CGRect(x: self.view.center.x, y: self.view.center.y, width: 200, height: 21))
        label.center = self.view.center
        label.textAlignment = .center
        label.text = "Deep Link Engage(d)"

        self.view.addSubview(label)
    }
}
