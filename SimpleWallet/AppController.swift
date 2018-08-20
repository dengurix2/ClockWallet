//
//  AppController.swift
//  SampleWallet
//
//  Created by Akifumi Fujita on 2018/08/17.
//  Copyright © 2018年 Akifumi Fujita. All rights reserved.
//

import Foundation
import BitcoinKit
import KeychainAccess

class AppController {
    static let shared = AppController()
    
    private(set) var wallet: Wallet?
    let mainColor = UIColor(red:250/255, green:98/255, blue:104/255, alpha:1.0)
    var year:Double = 1
    
    private init() {
        let keychain = Keychain()
        if let wif = keychain[string: "wif"] {
            wallet = try! Wallet(wif: wif)
            return
        }
    }
    
    func importWallet(wif: String) {
        let keychain = Keychain()
        keychain[string: "wif"] = wif
        
        wallet = try! Wallet(wif: wif)
    }
}
