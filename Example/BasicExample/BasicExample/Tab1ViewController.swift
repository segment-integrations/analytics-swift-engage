//
//  ViewController.swift
//  SegmentUIKitExample
//
//  Created by Brandon Sneed on 4/8/21.
//

import UIKit

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
