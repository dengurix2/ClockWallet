//
//  SettingGuideViewController.swift
//  SimpleWallet
//
//  Created by Hrt on 2018/08/18.
//  Copyright © 2018年 Takahiro Hirata. All rights reserved.
//

import UIKit
import AVFoundation

class SettingGuideViewController: UIViewController, UITextFieldDelegate,
    UIPickerViewDelegate, UIPickerViewDataSource, AVCaptureMetadataOutputObjectsDelegate
{
    let dataList = ["1", "2", "3", "4", "5", "6", "7", "8", "9","10"]
    let captureSession = AVCaptureSession()
    var videoPreviewLayer:AVCaptureVideoPreviewLayer?
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var baseView: UIView!
    @IBOutlet weak var tenYearLabel: UILabel!
    @IBOutlet weak var yearLabel: UILabel!
    @IBOutlet weak var addressTextField: UITextField!
    @IBOutlet weak var qrcodeButton: UIButton!
    @IBOutlet weak var yearPickerView: UIPickerView!
    @IBOutlet weak var cameraView: UIView!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        titleLabel.textColor = AppController.shared.mainColor
        
        baseView.layer.cornerRadius = 30
        baseView.layer.masksToBounds = true
        baseView.layer.borderColor = AppController.shared.mainColor.cgColor
        baseView.layer.backgroundColor = UIColor.clear.cgColor
        baseView.layer.borderWidth = 1

        yearPickerView.delegate = self
        yearPickerView.dataSource = self
        yearPickerView.backgroundColor = AppController.shared.mainColor
        yearPickerView.layer.cornerRadius = 5
        yearPickerView.layer.masksToBounds = true

        tenYearLabel.backgroundColor = AppController.shared.mainColor
        tenYearLabel.textColor = UIColor.white
        tenYearLabel.layer.cornerRadius = 15
        tenYearLabel.layer.masksToBounds = true

        yearLabel.textColor = AppController.shared.mainColor
        
        addressTextField.delegate = self
        addressTextField.layer.cornerRadius = 15
        addressTextField.layer.masksToBounds = true
        addressTextField.layer.borderColor = AppController.shared.mainColor.cgColor
        addressTextField.layer.borderWidth = 2
        
        qrcodeButton.setTitleColor(AppController.shared.mainColor, for: .normal)
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
        
        cameraView.isHidden = true
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        if metadataObjects.count == 0 {
            return
        }
        
        // Get the metadata object.
        let metadataObj = metadataObjects[0] as! AVMetadataMachineReadableCodeObject
        
        if metadataObj.type == AVMetadataObject.ObjectType.qr {
            if metadataObj.stringValue != nil {
                addressTextField.text = metadataObj.stringValue
                cameraView.isHidden = true
            }
        }
    }
    
    @IBAction func cameraButtonTapped(_ sender: UIButton) {
        if cameraView.isHidden == true {
            cameraView.isHidden = false
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        addressTextField.resignFirstResponder()
        return true
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        addressTextField.resignFirstResponder()
    }
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return dataList.count
    }

    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return dataList[row]
    }
    
    func pickerView(_ pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusing view: UIView?) -> UIView {
        let label = UILabel(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.size.width, height: 50))
        label.textAlignment = .center
        label.text = dataList[row]
        label.font = UIFont.systemFont(ofSize: 35)
        label.textColor = .white
        return label
    }
    
    func pickerView(_ pickerView: UIPickerView, rowHeightForComponent component: Int) -> CGFloat {
        return 60
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        let year = row - 1
        print("year \(year)")
        AppController.shared.year = Double(year)
    }
}
