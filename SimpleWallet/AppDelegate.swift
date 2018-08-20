//
//  AppDelegate.swift
//  SimpleWallet
//
//  Created by Akifumi Fujita on 2018/08/17.
//  Copyright © 2018年 Akifumi Fujita. All rights reserved.
//

import UIKit
import BitcoinKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?


    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {

        let address: Address = try! AddressFactory.create("bchtest:qpytf7xczxf2mxa3gd6s30rthpts0tmtgyw8ud2sy3")
        timeLock(toAddress: address, amount: 300)
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }

    private func timeLock(toAddress: Address, amount: Int64) {
        // 1. おつり用のアドレスを決める
        let changeAddress: Address = AppController.shared.wallet!.publicKey.toCashaddr()
        
        // 2. UTXOの取得
        let legacyAddress: String = AppController.shared.wallet!.publicKey.toLegacy().description
        APIClient().getUnspentOutputs(withAddresses: [legacyAddress], completionHandler: { [weak self] (unspentOutputs: [UnspentOutput]) in
            guard let strongSelf = self else {
                return
            }
            let utxos = unspentOutputs.map { $0.asUnspentTransaction() }
            let unsignedTx = strongSelf.createUnsignedTx(toAddress: toAddress, amount: amount, changeAddress: changeAddress, utxos: utxos)
            let signedTx = strongSelf.signTx(unsignedTx: unsignedTx, keys: [AppController.shared.wallet!.privateKey])
            let rawTx = signedTx.serialized().hex
            
            // 7. 署名されたtxをbroadcastする
            APIClient().postTx(withRawTx: rawTx, completionHandler: { (txid, error) in
                if let txid = txid {
                    print("txid = \(txid)")
                    print("txhash: https://test-bch-insight.bitpay.com/tx/\(txid)")
                } else {
                    print("error post \(error ?? "error = nil")")
                }
            })
        })
    }
    
    public func selectTx(from utxos: [UnspentTransaction], amount: Int64) -> (utxos: [UnspentTransaction], fee: Int64) {
        return (utxos, 500)
    }
    
    public func createUnsignedTx(toAddress: Address, amount: Int64, changeAddress: Address, utxos: [UnspentTransaction]) -> UnsignedTransaction {
        // 3. 送金に必要なUTXOの選択
        let (utxos, fee) = selectTx(from: utxos, amount: amount)
        let totalAmount: Int64 = utxos.reduce(0) { $0 + $1.output.value }
        let change: Int64 = totalAmount - amount - fee
        
        // 4. LockScriptを書いて、TransactionOutputを作成する
        //let lockScriptTo = Script(address: toAddress)!
        let lockScriptChange = Script(address: changeAddress)!
        
        // 上のBitcoin Scriptを自分で書いてみよー！
//        let lockScriptTo = try! Script()
//            .append(.OP_DUP)
//            .append(.OP_HASH160)
//            .appendData(toAddress.data)
//            .append(.OP_EQUALVERIFY)
//            .append(.OP_CHECKSIG)
        let lockScriptTo = try! Script()
            .append(.OP_IF)
            .append(.OP_DUP)
            .append(.OP_HASH160)
            .appendData(MockKey.keyA.pubkeyHash)
            .append(.OP_ELSE)
            .append(.OP_DUP)
            .append(.OP_HASH160)
            .appendData(Data(from: Date(timeIntervalSinceNow: 3600*24*365*AppController.shared.year).timeIntervalSince1970))
            .append(.OP_CHECKLOCKTIMEVERIFY)
            .append(.OP_DROP)
            .append(.OP_DUP)
            .append(.OP_HASH160)
            .appendData(MockKey.keyB.pubkeyHash)
            .append(.OP_EQUALVERIFY)
            .append(.OP_CHECKSIG)
            .append(.OP_ENDIF)
            .append(.OP_EQUALVERIFY)
            .append(.OP_CHECKSIG)
        
        // OP_RETURNのOutputを作成する
        
        // OP_CLTVのOutputを作成する
        
        let toOutput = TransactionOutput(value: amount, lockingScript: lockScriptTo.data)
        let changeOutput = TransactionOutput(value: change, lockingScript: lockScriptChange.data)
        
        // 5. UTXOとTransactionOutputを合わせて、UnsignedTransactionを作る
        let unsignedInputs = utxos.map { TransactionInput(previousOutput: $0.outpoint, signatureScript: Data(), sequence: UInt32.max) }
        let tx = Transaction(version: 1, inputs: unsignedInputs, outputs: [toOutput, changeOutput], lockTime: 0)
        return UnsignedTransaction(tx: tx, utxos: utxos)
    }
    
    // 6. 署名する
    public func signTx(unsignedTx: UnsignedTransaction, keys: [PrivateKey]) -> Transaction {
        var inputsToSign = unsignedTx.tx.inputs
        var transactionToSign: Transaction {
            return Transaction(version: unsignedTx.tx.version, inputs: inputsToSign, outputs: unsignedTx.tx.outputs, lockTime: unsignedTx.tx.lockTime)
        }
        
        // Signing
        let hashType = SighashType.BCH.ALL
        for (i, utxo) in unsignedTx.utxos.enumerated() {
            let pubkeyHash: Data = Script.getPublicKeyHash(from: utxo.output.lockingScript)
            
            let keysOfUtxo: [PrivateKey] = keys.filter { $0.publicKey().pubkeyHash == pubkeyHash }
            guard let key = keysOfUtxo.first else {
                continue
            }
            
            let sighash: Data = transactionToSign.signatureHash(for: utxo.output, inputIndex: i, hashType: SighashType.BCH.ALL)
            let signature: Data = try! Crypto.sign(sighash, privateKey: key)
            let txin = inputsToSign[i]
            let pubkey = key.publicKey()
            
            // unlockScriptを作る
            let unlockScript = try! Script()
//                .appendData(SighashType.BCH.ALL)
                .appendData(signature)
                .appendData(AppController.shared.wallet!.publicKey.raw)
                .append(.OP_CHECKSIG)
            
            // TODO: sequenceの更新
            inputsToSign[i] = TransactionInput(previousOutput: txin.previousOutput, signatureScript: unlockScript.data, sequence: txin.sequence)
        }
        return transactionToSign
    }
    
    struct complexUnlockScriptBuilder: SingleKeyScriptBuilder {
        func build(with sigWithHashType: Data, key: MockKey) -> Script {
            
            let bool = key == .keyA ? OpCode.OP_TRUE : OpCode.OP_FALSE
            
            return try! Script()
                .appendData(sigWithHashType)
                .appendData(key.pubkey.raw)
                .append(bool)
            
        }
    }

}

