//
//  SendViewController.swift
//  SampleWallet
//
//  Created by Akifumi Fujita on 2018/08/17.
//  Copyright © 2018年 Akifumi Fujita. All rights reserved.
//

import UIKit
import BitcoinKit

class SendViewController: UIViewController {
    
    @IBAction func
        sendButtonTapped(_ sender: Any) {
        // 送金をする
        // AddressFactoryでString型のアドレスをAddress型に変換してくれます
        let address: Address = try! AddressFactory.create("bchtest:qpytf7xczxf2mxa3gd6s30rthpts0tmtgyw8ud2sy3")
        sendCoins(toAddress: address, amount: 300)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let script = try! Script()
            .append(.OP_5)
            .append(.OP_5)
            .append(.OP_EQUAL)
        let context = ScriptExecutionContext()
        context.verbose = true
        try! script.execute(with: context)
    }
    
    private func sendCoins(toAddress: Address, amount: Int64) {
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
        let lockScriptTo = try! Script()
            .append(.OP_DUP)
            .append(.OP_HASH160)
            .appendData(toAddress.data)
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
            //let unlockingScript = Script.buildPublicKeyUnlockingScript(signature: signature, pubkey: pubkey, hashType: hashType)
            let lockScript = Script(data: utxo.output.lockingScript)!
            
            let unlockScript  = try! Script()
                .appendData(signature + UInt8(hashType))
                .appendData(pubkey.raw)
            
            let context = ScriptExecutionContext(transaction: transactionToSign, utxoToVerify: utxo.output, inputIndex: UInt32(i))!
            context.verbose = true
            try! ScriptMachine.verify(lockScript: lockScript, unlockScript: unlockScript, context: context)
            
            
            // TODO: sequenceの更新
            inputsToSign[i] = TransactionInput(previousOutput: txin.previousOutput, signatureScript: unlockScript.data, sequence: txin.sequence)
        }
        return transactionToSign
    }
    
    // multisigアドレスを作ってみよう！
    private func createMultisigAddress() -> Address {
        let publicKeyA = AppController.shared.wallet!.publicKey
        let publicKeyB = try! Wallet(wif: "cP1uBo6EsiBayFLu3E5mst5eDg7KNGRJbndbckRfV14votPZu4oU").publicKey
        let publicKeyC = try! Wallet(wif: "cSxjgWLm5F4CY1YjEbTSYPPaeZWF9dsUx6S87sU6FfsMGj4aH3vH").publicKey
        
        return try! Cashaddr.init("sample") // これは消して下さい
    }
    
    private func string2ExpiryTime(dateString: String) -> Data {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let date = formatter.date(from: dateString)!
        let dateUnix: TimeInterval = date.timeIntervalSince1970
        return Data(from: Int32(dateUnix).littleEndian)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
}
