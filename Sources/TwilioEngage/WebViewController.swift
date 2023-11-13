//
//  File.swift
//  
//
//  Created by Alan Charles on 11/12/23.
//

import Foundation
import UIKit
import WebKit


public class WebViewController: UIViewController, WKNavigationDelegate {
    var webView: WKWebView!
   public var url: URL = URL(string: "https://www.segment.com")!
    
    public override func loadView() {
        
        webView = WKWebView()
        webView.navigationDelegate = self
        view = webView

    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        webView.load(URLRequest(url: url))
        webView.allowsBackForwardNavigationGestures = true
        
    }
}
