//
//  ViewController.swift
//  iOSSampleApp
//
//  Created by Kevin Bradley on 5/17/21.
//  Copyright © 2021 Sudo Security Group Inc. All rights reserved.
//

import UIKit
import GuardianConnect

class ViewController: UIViewController {
    
    @IBOutlet var usernameTextField: UITextField!
    @IBOutlet var passwordTextField: UITextField!
    @IBOutlet var createVPNButton: UIButton!
    @IBOutlet var hostnameLabel: UILabel!
    @IBOutlet var statusLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        NEVPNManager.shared().loadFromPreferences { (error) in
            if (error != nil) {
                print(error)
            } else {
                self.observeVPNConnection()
            }
        }
        GRDVPNHelper.sharedInstance().validateCurrentEAPCredentials { (success, error) in
            if (success) {
                print("we have valid EAP credentials!");
                DispatchQueue.main.async {
                    self.createVPNButton.isEnabled = true
                }
            }
        }
    }
    
    
    func vpnStatus() -> NEVPNStatus {
        
        return NEVPNManager.shared().connection.status
    }
    
    //i force unwrap everything, i dont have time for swift's nonsense.
    
    @IBAction func attemptLogin() {
        GRDHousekeepingAPI().loginUser(withEMail: usernameTextField.text!, password: passwordTextField.text!) { (response, errorMessage, success) in
            
            if (success){
                let resp: Dictionary = response! as! Dictionary<String, AnyObject>
                print(response ?? [:])
                GRDKeychain.storePassword(resp[kKeychainStr_PEToken] as? String, forAccount: kKeychainStr_PEToken)
                GRDVPNHelper.setIsPayingUser(true)
                let def = UserDefaults.standard
                def.set(resp["type"], forKey: kSubscriptionPlanTypeStr)
                let petExpires = resp["pet-expires"] as! NSNumber
                let expireDate = TimeInterval(petExpires)
                def.set(Date(timeIntervalSince1970: expireDate), forKey: kGuardianPETokenExpirationDate)
                def.set(true, forKey: "userLoggedIn") //just for POC purposes, can track this in more intelligent ways.
                DispatchQueue.main.async {
                    self.createVPNButton.isEnabled = true
                    self.createVPNButton.setTitle("Disconnect VPN", for: .normal)
                }
            } else {
                print(errorMessage ?? "no error")
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        vpnConfigChanged() //janky stopgap to keep track for now.
    }
    
    @objc func vpnConfigChanged() {
        
        print("vpnConfigChanged")
        switch vpnStatus() {
        case .connected:
            DispatchQueue.main.async {
                self.createVPNButton.setTitle("Disconnect VPN", for: .normal)
                let creds = GRDCredentialManager.mainCredentials()
                self.hostnameLabel.text = creds.hostname
                self.statusLabel.text = "Connected"
            }
        default:
            DispatchQueue.main.async {
                self.createVPNButton.setTitle("Connect VPN", for: .normal)
                self.statusLabel.text = "Disconnected"
            }
        }
        
    }
    
    func observeVPNConnection() {
        NotificationCenter.default.addObserver(self, selector: #selector(vpnConfigChanged),
                                               name: .NEVPNStatusDidChange, object: nil)
        vpnConfigChanged()
    }
    
    @IBAction func createVPNConnection() {
        
        if (vpnStatus() == .connected){
            
            GRDVPNHelper.sharedInstance().disconnectVPN()
            DispatchQueue.main.async {
                self.createVPNButton.isEnabled = true
                self.createVPNButton.setTitle("Connect VPN", for: .normal)
            }
            return
        }
        
        if GRDVPNHelper.activeConnectionPossible() {
            GRDVPNHelper.sharedInstance().configureAndConnectVPN { (error, status) in
                print(error)
                print(status)
            }
        } else {
            GRDVPNHelper.sharedInstance().configureFirstTimeUserPostCredential({
                //no op
            }) { (success, error) in
                if (success){
                    print("created a VPN connection successfully!");
                    
                } else {
                    print ("VPN creation failed")
                }
            }
        }
        
        
    }
    
    @IBAction func clearKeychain() {
        GRDKeychain.removeGuardianKeychainItems()
        GRDKeychain.removeSubscriberCredential(withRetries: 3)
    }
    
}

