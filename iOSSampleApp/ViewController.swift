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
    @IBOutlet var selectRegionButton: UIButton!
    @IBOutlet var hostnameLabel: UILabel!
    @IBOutlet var statusLabel: UILabel!
    @IBOutlet var tableView: UITableView!
    
    var rawRegions: [Any]!
    var regions: [GRDRegion]!
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        self.tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        
        // its important to do this as early as possible
        
        NEVPNManager.shared().loadFromPreferences { (error) in
            if (error != nil) {
                print(error as Any)
            } else {
                self.observeVPNConnection()
            }
        }
        
        // can use this as an early validation upon launch to make sure EAP credentials are still valid
        GRDVPNHelper.sharedInstance().validateCurrentEAPCredentials { (success, error) in
            if (success) {
                print("we have valid EAP credentials!");
                //populate the region selection data
                self.populateRegionDataIfNecessary()
                DispatchQueue.main.async {
                    self.createVPNButton.isEnabled = true
                }
            }
        }
    }
    
    /// track current status of the VPN, this should never be invalid since loadFromPreferences is called so early in the lifecycle.
    func vpnStatus() -> NEVPNStatus {
        return NEVPNManager.shared().connection.status
    }
    
    //NOTE: I force unwrap everything, I dont have time for Swift's "safety" nonsense.
    
    @IBAction func attemptLogin() {
        
        GRDVPNHelper.sharedInstance().proLogin(withEmail: usernameTextField.text!, password: passwordTextField.text!) { (success, errorMessage) in
            if success {
                DispatchQueue.main.async {
                    self.createVPNButton.isEnabled = true
                }
                UserDefaults.standard.set(true, forKey: "userLoggedIn")
            } else {
                print(errorMessage ?? "no error")
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        vpnConfigChanged() //janky stopgap to keep track for now.
    }
    
    /// This should be more elegant, just a rough example
    @objc func vpnConfigChanged() {
        DispatchQueue.main.async {
            let creds = GRDCredentialManager.mainCredentials()
            switch self.vpnStatus() {
            case .connected:
                self.createVPNButton.setTitle("Disconnect VPN", for: .normal)
                self.hostnameLabel.text = creds.hostname
                self.statusLabel.text = "Connected"
                
            case .connecting:
                self.hostnameLabel.text = creds.hostname
                self.statusLabel.text = "Connecting..."
                
            case .disconnecting:
                self.hostnameLabel.text = creds.hostname
                self.statusLabel.text = "Disconnecting..."
                
            default:
                self.createVPNButton.setTitle("Connect VPN", for: .normal)
                self.statusLabel.text = "Disconnected"
            }
        }
        
    }
    
    func observeVPNConnection() {
        NotificationCenter.default.addObserver(self, selector: #selector(vpnConfigChanged),
                                               name: .NEVPNStatusDidChange, object: nil)
        vpnConfigChanged() //call it once manually upon view loading so we know the current state of the UI is tracked accurately if they are already connected
    }
    
    /// called to create OR disconnect the VPN depending on its current state.
    @IBAction func createVPNConnection() {
        
        // already connected, we want to disconnect in this case.
        if (vpnStatus() == .connected){
            
            GRDVPNHelper.sharedInstance().disconnectVPN()
            DispatchQueue.main.async {
                self.createVPNButton.isEnabled = true
                self.createVPNButton.setTitle("Connect VPN", for: .normal)
            }
            return
        }
        
        // do they have EAP creds
        if GRDVPNHelper.activeConnectionPossible() {
            // just configure & connect, no need for 'first user' setup
            GRDVPNHelper.sharedInstance().configureAndConnectVPN { (error, status) in
                print(error as Any)
                print(status)
            }
        } else {
            
            // first time user, OR recently cleared VPN creds
            GRDVPNHelper.sharedInstance().configureFirstTimeUserPostCredential({
                //no op
                
                // post credential block is optional and can be used as a midway point to update the UI if necessary
                
            }) { (success, error) in
                if (success){
                    print("created a VPN connection successfully!");
                    self.populateRegionDataIfNecessary()
                    
                } else {
                    print ("VPN creation failed")
                }
            }
        }
    }
    
    /// populate region selection data
    func populateRegionDataIfNecessary () {
        GRDServerManager().populateTimezonesIfNecessary { (regions) in
            self.rawRegions = regions
            self.regions = GRDRegion.regions(fromTimezones: regions)
            print(self.regions as Any)
            DispatchQueue.main.async {
                self.tableView.reloadData()
            }
            
        }
    }
    
    @IBAction func clearKeychain() {
        GRDKeychain.removeGuardianKeychainItems()
        GRDKeychain.removeSubscriberCredential(withRetries: 3)
    }
    
    /// region selection, called upon the 'select region' button being pressed.
    @IBAction func connectHost() {
        let indexPath = self.tableView.indexPathForSelectedRow
        if (indexPath != nil) {
            let currentItem = self.regions[indexPath!.row]
            print(currentItem)
            
            GRDVPNHelper.sharedInstance().configureFirstTimeUser(with: currentItem) { (success, error) in
                print(success)
                print(error as Any)
                if (success){
                    //GRDVPNHelper.sharedInstance().select(currentItem) //NOTE: CRUCIAL TO MAKE REGION SELECTION WORK PROPERLY!!!!
                } else {
                    //handle error for first time config failure
                }
            }
        }
    }
}

extension ViewController: UITextFieldDelegate {
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        textField.resignFirstResponder()
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
}

extension ViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if (self.regions != nil){
            return self.regions.count;
        }
        return 0
    }
    
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let tableCell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let currentItem = self.regions[indexPath.row]
        tableCell.textLabel?.text = currentItem.displayName
        return tableCell
    }
}
