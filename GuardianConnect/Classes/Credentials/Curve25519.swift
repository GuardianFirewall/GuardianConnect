//
//  x25519.swift
//  GuardianConnect
//
//  Created by Constantin Jacob on 12.01.22.
//  Copyright © 2022 Sudo Security Group Inc. All rights reserved.
//

import Foundation
import CryptoKit

@objc public class GRDCurve25519 : NSObject {
	@objc public var privateKey: String = ""
	@objc public var publicKey: String = ""
	
	@objc public func generateKeyPair() {
		let newKey = Curve25519.KeyAgreement.PrivateKey.init()
		
		let privateKeyData = NSData(data:newKey.rawRepresentation as Data)
		let base64PrivateKey = privateKeyData.base64EncodedString(options: NSData.Base64EncodingOptions(rawValue: 0))
		
		let publicKeyData = NSData(data:newKey.publicKey.rawRepresentation as Data)
		let base64PublicKey = publicKeyData.base64EncodedString(options: NSData.Base64EncodingOptions(rawValue: 0))
		
		privateKey = base64PrivateKey
		publicKey = base64PublicKey
	}
}
