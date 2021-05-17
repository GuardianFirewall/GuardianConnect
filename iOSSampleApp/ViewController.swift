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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    @IBAction func attemptLogin() {
        GRDHousekeepingAPI().loginUser(withEMail: usernameTextField.text!, password: passwordTextField.text!) { (response, errorMessage, success) in
            
            let resp: Dictionary = response! as! Dictionary<String, AnyObject>
            
            if (success){
                print(response ?? [:])
                GRDKeychain.storePassword(resp[kKeychainStr_PEToken] as? String, forAccount: kKeychainStr_PEToken)
                DispatchQueue.main.async {
                    self.createVPNButton.isEnabled = true
                }
            } else {
                print(errorMessage ?? "no error")
            }
        }
    }

    @IBAction func createVPNConnection() {
        GRDVPNHelper.sharedInstance().configureFirstTimeUserPostCredential({
            //no op
        }) { (success, error) in
            if (success){
                print("created a VPN connection successfully?");
            }
        }
    }
    
}

