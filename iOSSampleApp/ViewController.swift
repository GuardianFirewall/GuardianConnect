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
	@IBOutlet var preferredTransportProtocolButton: UIButton!
    @IBOutlet var apiKeyTextField: UITextField!
    @IBOutlet var createVPNButton: UIButton!
    @IBOutlet var storeDemoKeyButton: UIButton!
    @IBOutlet var hostnameLabel: UILabel!
    @IBOutlet var statusLabel: UILabel!
    @IBOutlet var tableView: UITableView!
    
    @IBOutlet var dataTrackerLabel: UILabel!
    @IBOutlet var mailTrackerLabel: UILabel!
    @IBOutlet var locationTrackerLabel: UILabel!
    @IBOutlet var pageHijackerLabel: UILabel!
    var timer: Timer!
    
    var regions: [GRDRegion]!
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        self.tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        
        // Provide a string (can be localized if required) which will be used by GuardianConnect as the "title" for the VPN
        // configuration. This title is shown in iOS Settings VPN and should clearly identify the source of the VPN configuration.
        // It is recommended to use the app name, or company title for this
        GRDVPNHelper.sharedInstance().tunnelLocalizedDescription = "Sample App IKEv2"
		GRDVPNHelper.sharedInstance().grdTunnelProviderManagerLocalizedDescription = "Sample App WireGuard"
		GRDVPNHelper.sharedInstance().tunnelProviderBundleIdentifier = "com.sudosecuritygroup.iOSSampleApp2.WireGuardPTP"
		GRDVPNHelper.sharedInstance().appGroupIdentifier = "group.com.sudosecuritygroup.iOSSampleApp"
        
        // its important to do this as early as possible
        NEVPNManager.shared().loadFromPreferences { (error) in
            if (error != nil) {
                print(error as Any)
                
            } else {
                self.observeVPNConnection()
            }
        }
        
        if isDemoAPIKeyPresent() {
            DispatchQueue.main.async {
                self.createVPNButton.isEnabled = true
                self.apiKeyTextField.placeholder = GRDKeychain.getPasswordString(forAccount: kKeychainStr_PEToken)
                GRDSubscriptionManager.setIsPayingUser(true)
				if self.vpnStatus() == .connected  || self.tunnelVPNStatus() == .connected {
                    self.startRefreshTimer()
                }
            }
        }
        
        // can use this as an early validation upon launch to make sure VPN credentials are still valid
        GRDVPNHelper.sharedInstance().verifyMainCredentials { (success, error) in
            if (success) {
                print("Valid VPN credentials present!");
                DispatchQueue.main.async {
                    self.createVPNButton.isEnabled = true
                }
            }
        }
		
		// populate the region selection data
		self.populateRegionDataIfNecessary()
    }
    
    /// Refresh timer that tracks event counts, its ideal to listen for push notifications for real time updates, but this will do in a pinch if that isnt possible.
    func startRefreshTimer() {
        self.stopRefreshTimer() //this only stops the timer if applicable
        timer = Timer.scheduledTimer(withTimeInterval: 20, repeats: true, block: { (timer) in
            GRDGatewayAPI().getAlertTotals { (results, success, errorMessage) in
                if (success) {
                    let resp: Dictionary = results! as! Dictionary<String, AnyObject>
                    //print(resp)
                    //["page-hijacker-total": 0, "data-tracker-total": 0, "location-tracker-total": 0, "mail-tracker-total": 0]
                    let pht = "Page Hijackers: \(resp["page-hijacker-total"] ?? "0" as AnyObject)"
                    let dtt = "Data Trackers: \(resp["data-tracker-total"] ?? "0" as AnyObject)"
                    let ltt = "Location Trackers: \(resp["location-tracker-total"] ?? "0" as AnyObject)"
                    let mtt = "Mail Trackers: \(resp["mail-tracker-total"] ?? "0" as AnyObject)"
                    DispatchQueue.main.async {
                        self.dataTrackerLabel.text = dtt
                        self.pageHijackerLabel.text = pht
                        self.locationTrackerLabel.text = ltt
                        self.mailTrackerLabel.text = mtt
                    }
                }
                
            }
        })
    }
    
    func stopRefreshTimer() {
        if (timer != nil) {
            timer.invalidate()
            timer = nil
        }
    }
    
    func isDemoAPIKeyPresent() -> Bool {
        let demoAPIKey = GRDKeychain.getPasswordString(forAccount: kKeychainStr_PEToken)
        if demoAPIKey == "" || demoAPIKey == nil {
            return false
        }
        
        return true
    }
    
    /// track current status of the VPN, this should never be invalid since loadFromPreferences is called so early in the lifecycle.
    func vpnStatus() -> NEVPNStatus {
        return NEVPNManager.shared().connection.status
    }
	
	func tunnelVPNStatus() -> NEVPNStatus {
		let tunnelProvider = GRDVPNHelper.sharedInstance().tunnelManager.tunnelProviderManager
		let status = tunnelProvider?.connection.status
		return status ?? .invalid
	}
    
	@IBAction func togglePreferredTransportProtocol() {
		let current = GRDTransportProtocol.getUserPreferredTransportProtocol()
		var newTransport = TransportProtocol.ikEv2
		if current == .ikEv2 {
			newTransport = .wireGuard
		}
		
		GRDTransportProtocol.setUserPreferred(newTransport)
		self.preferredTransportProtocolButton.setTitle(GRDTransportProtocol.prettyTransportProtocolString(for: newTransport), for: .normal)
	}
	
    @IBAction func storeDemoKey() {
        // got passed the sign in check, the user is not signed in currently, attempt to sign them in!
        GRDKeychain.storePassword(apiKeyTextField.text, forAccount: kKeychainStr_PEToken)
        self.createVPNButton.isEnabled = true
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        vpnConfigChanged() //janky stopgap to keep track for now.
		
		self.preferredTransportProtocolButton.setTitle(GRDTransportProtocol.prettyTransportProtocolString(for: GRDTransportProtocol.getUserPreferredTransportProtocol()), for: .normal)
    }
    
    /// This should be more elegant, just a rough example
    @objc func vpnConfigChanged() {
        DispatchQueue.main.async {
            //grab the current credentials to get the hostname
            let creds = GRDCredentialManager.mainCredentials()
			let vpnStatus = self.vpnStatus()
			let tunnelStatus = self.tunnelVPNStatus()
			if vpnStatus == .connected || tunnelStatus == .connected {	
				self.createVPNButton.setTitle("Disconnect VPN", for: .normal)
				self.hostnameLabel.text = creds.hostname
				self.statusLabel.text = "Connected"
				self.startRefreshTimer()
				
			} else if vpnStatus == .connecting || tunnelStatus == .connecting {
				self.hostnameLabel.text = creds.hostname
				self.statusLabel.text = "Connecting..."
				
			} else if vpnStatus == .disconnecting || tunnelStatus == .disconnecting {
				self.hostnameLabel.text = creds.hostname
				self.statusLabel.text = "Disconnecting..."
				
			} else if vpnStatus == .disconnected || tunnelStatus == .disconnected {
				self.stopRefreshTimer()
				self.hostnameLabel.text = creds.hostname
				self.createVPNButton.setTitle("Connect VPN", for: .normal)
				self.statusLabel.text = "Disconnected"
				
			} else {
				self.createVPNButton.setTitle("Connect VPN", for: .normal)
				self.statusLabel.text = "Disconnected"
			}
        }
        
    }
    
    func observeVPNConnection() {
        NotificationCenter.default.addObserver(self, selector: #selector(vpnConfigChanged), name: .NEVPNStatusDidChange, object: nil)
        vpnConfigChanged() //call it once manually upon view loading so we know the current state of the UI is tracked accurately if they are already connected
    }
    
    /// called to create OR disconnect the VPN depending on its current state. Connected in the Storyboard
    @IBAction func createVPNConnection() {
        // already connected, we want to disconnect in this case.
		let vpnStatus = vpnStatus()
		let tunnelStatus = tunnelVPNStatus()
		if (vpnStatus == .connected || tunnelStatus == .connected) {
            GRDVPNHelper.sharedInstance().disconnectVPN()
            DispatchQueue.main.async {
                self.createVPNButton.isEnabled = true
                self.createVPNButton.setTitle("Connect VPN", for: .normal)
            }
            return
        }
        
        // do they have VPN creds
        if GRDVPNHelper.activeConnectionPossible() {
            // just configure & connect, no need for 'first user' setup
            GRDVPNHelper.sharedInstance().configureAndConnectVPNTunnel { (status, error) in
                print(error as Any)
                print(status)
                self.populateRegionDataIfNecessary()
            }
            
        } else { //they do not have credentials yet.
            // first time user, OR recently cleared VPN creds			
            GRDVPNHelper.sharedInstance().configureFirstTimeUserPostCredential {
                // post credential block is optional and can be used as a midway point to update the UI if necessary
                print("midway point, we have credentials!")
                
            } completion: { (success, error) in
				print("Completed connection operation with status:\(String(describing: error))")
            }
        }
    }
    
    /// populate region selection data
    func populateRegionDataIfNecessary () {
		GRDServerManager().allRegions { regions, error in
			if error != nil {
				print("Failed to fetch regions from the Connect API: \(error?.localizedDescription ?? "No error message provided")")
				return
			}
			
			self.regions = regions;
			DispatchQueue.main.async {
				self.tableView.reloadData()
			}
		}
    }
    
    @IBAction func clearKeychain() {
        GRDKeychain.removeGuardianKeychainItems()
        GRDKeychain.removeSubscriberCredential(withRetries: 3)
    }
    
    /// region selection, called upon any item being selected in the table view
    @IBAction func connectHost() {
        //if the GRDRegion is nil, configureFirstTimeUser() will perform an automatic selection
        var currentItem: GRDRegion? = nil
        let indexPath = self.tableView.indexPathForSelectedRow
        if (indexPath != nil) { //i know theres a 'swiftier' way to do this, but i'm solely focused on a working example.
            if indexPath?.section == 1 { //if the section is 1 (manual selection) grab the GRDRegion option at the selected index path, 'automatic' is in 0 section and is the only object
                currentItem = self.regions[indexPath!.row]
            }
        }
        
		// Force all connections to be terminated first to prevent
		// two tunnels to become active in a multi protocol setup
		GRDVPNHelper.sharedInstance().forceDisconnectVPNIfNecessary()
		
		// Throw out the old credentials and everything else related
		// to the old connection - if one had existed previously
		GRDKeychain.removeGuardianKeychainItems()
		
        // configure first time user based on a specified region.
		GRDVPNHelper.sharedInstance().configureFirstTimeUser(for: GRDTransportProtocol.getUserPreferredTransportProtocol(), with: currentItem) { (status, error) in
            print(status)
            print(error as Any)
			if (status == .success) {
                print("connected successfully!")
            } else {
                //handle error for first time config failure
                print("connection failed: \(String(describing: error))")
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

extension ViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.connectHost()
    }
    
}

extension ViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return 1
        }
        if (self.regions != nil) {
            return self.regions.count;
        }
        return 0
    }
    
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let tableCell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        if indexPath.section == 0 {
            tableCell.textLabel?.text = "Automatic" //automatic region selection
        } else {
            let currentItem = self.regions[indexPath.row]
            tableCell.textLabel?.text = currentItem.displayName //manual region selection item
            
        }
        return tableCell
    }
}
