//
//  BalanceViewController.swift
//  SimpleWallet
//
//  Created by Hrt on 2018/08/18.
//  Copyright © 2018年 Takahiro Hirata. All rights reserved.
//

import UIKit
import BitcoinKit
import AVFoundation

class BalanceViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {

    var wallet: Wallet?
    let captureSession = AVCaptureSession()
    var videoPreviewLayer:AVCaptureVideoPreviewLayer?
    //var qrCodeFrameView:UIView？
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var lineView: UIView!
    @IBOutlet weak var balanceLabel: UILabel!
    @IBOutlet weak var addressLabel: UILabel!
    @IBOutlet weak var qrCodeImageView: UIImageView!
    @IBOutlet weak var segmentedControl: UISegmentedControl!
    @IBOutlet weak var baseView: UIView!
    @IBOutlet var cameraView: UIView!
    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var qrCodeLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        guard let _ = AppController.shared.wallet else {
            createWallet()
            return
        }
        
        titleLabel.tintColor = AppController.shared.mainColor
        lineView.backgroundColor = AppController.shared.mainColor
        balanceLabel.textColor = AppController.shared.mainColor
        segmentedControl.tintColor = AppController.shared.mainColor
        
        baseView.layer.cornerRadius = 30
        baseView.layer.masksToBounds = true
        baseView.layer.borderColor = AppController.shared.mainColor.cgColor
        baseView.layer.backgroundColor = UIColor.white.cgColor
        baseView.layer.borderWidth = 1
    
        qrCodeLabel.isHidden = true
        qrCodeLabel.text = ""
        let deviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: AVMediaType.video, position: .back)
        guard let captureDevice = deviceDiscoverySession.devices.first else {
            print("Failed to get the camera device")
            return
        }
        do {
            let input = try AVCaptureDeviceInput(device: captureDevice)
            captureSession.addInput(input)
            let captureMetadataOutput = AVCaptureMetadataOutput()
            captureSession.addOutput(captureMetadataOutput)
            captureMetadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            captureMetadataOutput.metadataObjectTypes = [AVMetadataObject.ObjectType.qr]
            videoPreviewLayer = AVCaptureVideoPreviewLayer.init(session: captureSession)
            videoPreviewLayer?.videoGravity = AVLayerVideoGravity.resizeAspectFill
            videoPreviewLayer?.frame = cameraView.layer.bounds
            cameraView.layer.addSublayer(videoPreviewLayer!)
            self.captureSession.startRunning()
        } catch {
            print(error)
            return
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        videoPreviewLayer?.frame = cameraView.layer.bounds
        view.bringSubview(toFront: baseView)
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        if metadataObjects.count == 0 {
            return
        }
        let metadataObj = metadataObjects[0] as! AVMetadataMachineReadableCodeObject
        if metadataObj.type == AVMetadataObject.ObjectType.qr {
            if metadataObj.stringValue != nil {
                qrCodeLabel.text = metadataObj.stringValue
            }
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewWillAppear(_ animated: Bool) {
        updateUI()
    }
    
    private func updateUI() {
        getAddress()
        getBalance()
    }
    
    @IBAction func segmentedControlChanged(_ sender: UISegmentedControl) {
        if sender.selectedSegmentIndex == 0 {
            baseView.isHidden = false
            //containerView.isHidden = true
            qrCodeLabel.isHidden = true
        } else {
            baseView.isHidden = true
            //containerView.isHidden = false
            view.bringSubview(toFront: baseView)
            qrCodeLabel.isHidden = false
        }
    }
    
    // walletの作成
    private func createWallet() {
        let privateKey = PrivateKey(network: .testnet)
        let wif = privateKey.toWIF()
        AppController.shared.importWallet(wif: wif)
    }
    
    // Addressの表示
    private func getAddress() {
        let pubkey = AppController.shared.wallet!.publicKey
        let base58Address = pubkey.toLegacy()
        print("base58Address: \(base58Address)")
        let cashAddr = pubkey.toCashaddr().cashaddr
        print("cashAddr: \(cashAddr)")
        addressLabel.text = cashAddr
        qrCodeImageView.image = generateVisualCode(address: cashAddr)
    }
    
    // 残高を確認する
    private func getBalance() {
        APIClient().getUnspentOutputs(withAddresses: [AppController.shared.wallet!.publicKey.toLegacy().description], completionHandler: { [weak self] (utxos: [UnspentOutput]) in
            let balance = utxos.reduce(0) { $0 + $1.amount }
            DispatchQueue.main.async { self?.balanceLabel.text = "\(balance) tBCH" }
        })
    }
    
    private func generateVisualCode(address: String) -> UIImage? {
        let parameters: [String : Any] = [
            "inputMessage": address.data(using: .utf8)!,
            "inputCorrectionLevel": "L"
        ]
        let filter = CIFilter(name: "CIQRCodeGenerator", withInputParameters: parameters)
        
        guard let outputImage = filter?.outputImage else {
            return nil
        }
        
        let scaledImage = outputImage.transformed(by: CGAffineTransform(scaleX: 6, y: 6))
        guard let cgImage = CIContext().createCGImage(scaledImage, from: scaledImage.extent) else {
            return nil
        }
        
        return UIImage(cgImage: cgImage)
    }
}
