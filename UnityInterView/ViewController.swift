//
//  ViewController.swift
//  UnityInterView
//
//  Created by Wangshu Zhu on 2021/7/10.
//

import UIKit

let rewardedAdUnitId = "8f000bd5e00246de9c789eed39ff6096"
let intestitialAdUnitId = "4f117153f5c24fa6a3a92b818a5eb630"


class ViewController: UIViewController, MPInterstitialAdControllerDelegate, MPRewardedAdsDelegate {
    var initializeSDKButton:UIButton!
    var loadInterstitialButton: UIButton!
    var showInterstitialButton: UIButton!
    var loadRewardedButton: UIButton!
    var showRewardedButton: UIButton!
    var interstitialStatusLabel : UILabel!
    var rewardedCounter : UILabel!
    
    var statusText : String? {
        didSet {
            interstitialStatusLabel.text = statusText
            interstitialStatusLabel.sizeToFit()
        }
    }
    
    var counter: Int  = 0  {
        didSet {
            rewardedCounter.text = "\(counter) rewarded ads showed"
            rewardedCounter.sizeToFit()
        }
    }
    
    var interstitial: MPInterstitialAdController?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .groupTableViewBackground
        
        
        // MARK: - Buttons setup
        initializeSDKButton = UIButton.init(type: .system)
        initializeSDKButton.setTitle("Init SDK", for: .normal)
        initializeSDKButton.setTitle("Init SDK", for: .highlighted)
        
        // Do any additional setup after loading the view.
        loadInterstitialButton = UIButton.init(type: .system)
        loadInterstitialButton.setTitle("Load Interstial", for: .normal)
        loadInterstitialButton.setTitle("Load Interstial", for: .highlighted)
        
        showInterstitialButton = UIButton.init(type: .system)
        showInterstitialButton.setTitle("Show Interstial", for: .normal)
        showInterstitialButton.setTitle("Show Interstial", for: .highlighted)
        
        loadRewardedButton = UIButton.init(type: .system)
        loadRewardedButton.setTitle("Load Rewarded", for: .normal)
        loadRewardedButton.setTitle("Load Rewarded", for: .highlighted)
        
        showRewardedButton = UIButton.init(type: .system)
        showRewardedButton.setTitle("Show Rewarded", for: .normal)
        showRewardedButton.setTitle("Show Rewarded", for: .highlighted)
        
        initializeSDKButton.addTarget(self, action: #selector(onTapIntializeSDK(sender:)), for: .touchUpInside)
        loadInterstitialButton.addTarget(self, action: #selector(onTapLoadInterstitial(sender:)), for: .touchUpInside)
        showInterstitialButton.addTarget(self, action: #selector(onTapShowInterstitial(sender:)), for: .touchUpInside)
        loadRewardedButton.addTarget(self, action: #selector(onTapLoadRewarded(sender:)), for: .touchUpInside)
        showRewardedButton.addTarget(self, action: #selector(onTapShowRewarded(sender:)), for: .touchUpInside)
        
        view.addSubview(initializeSDKButton)
        view.addSubview(loadInterstitialButton)
        view.addSubview(showInterstitialButton)
        view.addSubview(loadRewardedButton)
        view.addSubview(showRewardedButton)
        
        //MARK: - Labels setup
        
        interstitialStatusLabel = UILabel()
        interstitialStatusLabel.numberOfLines = 0
        view.addSubview(interstitialStatusLabel)
        
        rewardedCounter = UILabel()
        rewardedCounter.numberOfLines = 0
        view.addSubview(rewardedCounter)
        
    }
    
    @objc func onTapIntializeSDK(sender: NSObject?) {
        print("initialize SDK!")
        var config = MPMoPubConfiguration(adUnitIdForAppInitialization: intestitialAdUnitId)
        
        MoPub.sharedInstance().initializeSdk(with: config) {
            print("MoPub initialized!")
        }
    }
    
    @objc func onTapLoadInterstitial(sender: NSObject?) {
        print("Load Interstitial!")
        self.interstitial = MPInterstitialAdController.init(forAdUnitId: intestitialAdUnitId)
        self.interstitial?.delegate = self
        self.interstitial?.loadAd()
    }
    
    @objc func onTapShowInterstitial(sender: NSObject?) {
        print("Show Interstitial!")
        if self.interstitial != nil && self.interstitial!.ready {
            self.interstitial?.show(from: self)
        }
    }
    
    @objc func onTapLoadRewarded(sender: NSObject?) {
        print("Load Rewarded!")
        MPRewardedAds.setDelegate(self, forAdUnitId: rewardedAdUnitId)
        MPRewardedAds.loadRewardedAd(withAdUnitID: rewardedAdUnitId, withMediationSettings: nil)
    }
    
    @objc func onTapShowRewarded(sender: NSObject?) {
        print("Show Rewarded!")
        
        let rewards = MPRewardedAds.availableRewards(forAdUnitID: rewardedAdUnitId)?.first as? MPReward
        MPRewardedAds.presentRewardedAd(forAdUnitID: rewardedAdUnitId, from: self, with: rewards, customData: "Rewarded!")
    }
    
    override func viewDidLayoutSubviews() {
        initializeSDKButton.frame = CGRect(x: view.bounds.size.width/2 - 50, y: 100, width: 120, height: 40)
        loadInterstitialButton.frame = CGRect(x: view.bounds.size.width/2 - 50, y: 180, width: 120, height: 40)
        showInterstitialButton.frame = CGRect(x: view.bounds.size.width/2 - 50, y: 260, width: 120, height: 40)
        loadRewardedButton.frame = CGRect(x: view.bounds.size.width/2 - 50, y: 340, width: 120, height: 40)
        showRewardedButton.frame = CGRect(x: view.bounds.size.width/2 - 50, y: 420, width: 120, height: 40)
        
        interstitialStatusLabel.frame = CGRect(x: 20, y: 460, width: view.bounds.size.width - 40, height: 40)
        rewardedCounter.frame = CGRect(x: 20, y: 500, width: view.bounds.size.width - 40, height: 40)
    }

    // MARK:  -   Interstitial Delegates
    
    func interstitialDidLoadAd(_ interstitial: MPInterstitialAdController!) {
        print("interstitial ad load success!")
    }
    
    
    func interstitialDidFail(toLoadAd interstitial: MPInterstitialAdController!, withError error: Error!) {
        print(error)
    }
    
    func interstitialWillDismiss(_ interstitial: MPInterstitialAdController!) {
        
    }
    
    
    
    func interstitialDidDismiss(_ interstitial: MPInterstitialAdController!) {
        statusText = "insterstitial status: showed"
        print(interstitial)
    }
    

    
    
    
    // MARK: - Rewarded Delegates
    
    func rewardedAdShouldReward(forAdUnitID adUnitID: String!, reward: MPReward!) {
        print("should reward : \(reward)")
        counter += 1
    }
    
    
    func rewardedAdDidDismiss(forAdUnitID adUnitID: String!) {
        print("rewarded dismissed")
    }
    
    func rewardedAdDidFailToLoad(forAdUnitID adUnitID: String!, error: Error!) {
        print(error)
    }
    
    func rewardedAdDidLoad(forAdUnitID adUnitID: String!) {
        print("rewarded video load success!")
    }
}

