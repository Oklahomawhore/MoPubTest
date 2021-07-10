//
//  AppDelegate.swift
//  UnityInterView
//
//  Created by Wangshu Zhu on 2021/7/10.
//

import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var mopubConfig: MPMoPubConfiguration?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        
        window = UIWindow()
        
        window?.rootViewController = ViewController()
        
        window?.makeKeyAndVisible()
        
        MPMoPubConfiguration(adUnitIdForAppInitialization: "")
        
        return true
    }


}

