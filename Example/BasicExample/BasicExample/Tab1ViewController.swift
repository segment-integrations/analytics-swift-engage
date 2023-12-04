//
//  ViewController.swift
//  SegmentUIKitExample
//
//  Created by Brandon Sneed on 4/8/21.
//

import UIKit
import TwilioEngage

var mainView: Tab1ViewController? = nil

class Tab1ViewController: UITableViewController {
    var pushes = [String]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        mainView = self
        // Do any additional setup after loading the view.
        
        tableView.delegate = self
        tableView.dataSource = self
        
        self.tableView.register(UITableViewCell.self, forCellReuseIdentifier: "pushCell")
        
        Notification.Name.openButton.onPost { notification in
            if let deeplink = notification.userInfo?["deep_link"] as? String {
                print("Deep Link in viewDidLoad() \(deeplink)")
                let storyboard = UIStoryboard(name: "Main", bundle: nil)

                let deepLinkScreen = deeplink.replacingOccurrences(of: "engage://", with: "")
                let deepLinkVC = storyboard.instantiateViewController(identifier: deepLinkScreen)
                mainView?.navigationController?.pushViewController(deepLinkVC, animated: true)
            } else if let custom_action = notification.userInfo?["custom_action"] as? String {
                if custom_action == "open_settings" {
                    print("Open Settings")
                    let storyboard = UIStoryboard(name: "Main", bundle: nil)
                    let settingsVC = storyboard.instantiateViewController(withIdentifier: "settings.vc")
                    mainView?.navigationController?.pushViewController(settingsVC, animated: true)
                } else if (custom_action == "DeepLinkScreen") {
                    print("Deep Link Screen")
                    let storyboard = UIStoryboard(name: "Main", bundle: nil)
                    let deepLinkVC = storyboard.instantiateViewController(identifier: custom_action)
                    mainView?.navigationController?.pushViewController(deepLinkVC, animated: true)
                }
            }
        }
    }
        
        @IBAction func queryAction(_ sender: Any) {
            
        }
        
        static func addPush(s: String) {
            debugPrint(s)
            DispatchQueue.main.async {
                mainView?.pushes.insert(s, at: 0)
                mainView?.tableView.reloadData()
            }
        }
        
        override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
            if section == 0 {
                return pushes.count
            }
            return 0
        }
        
        override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
            let cell = tableView.dequeueReusableCell(withIdentifier: "pushCell") ??  UITableViewCell(style: .default, reuseIdentifier: "pushCell")
            
            let s = pushes[indexPath.row]
            cell.textLabel!.text = s
            
            return cell
        }
    }
