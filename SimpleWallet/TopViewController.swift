//
//  TopViewController
//  SimpleWallet
//
//  Created by Hrt on 2018/08/18.
//  Copyright © 2018年 Takahiro Hirata. All rights reserved.
//

import UIKit

class TopViewController: UIViewController {

    @IBOutlet weak var createWalletButton: UIButton!
    @IBOutlet weak var restoreWalletButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        createWalletButton.backgroundColor = AppController.shared.mainColor
        createWalletButton.setTitleColor(UIColor.white, for: .normal)
        createWalletButton.layer.cornerRadius = 30

        restoreWalletButton.backgroundColor = UIColor.white
        restoreWalletButton.setTitleColor(AppController.shared.mainColor, for: .normal)
        restoreWalletButton.layer.cornerRadius = 30
        restoreWalletButton.layer.masksToBounds = true
        restoreWalletButton.layer.borderColor = AppController.shared.mainColor.cgColor
        restoreWalletButton.layer.borderWidth = 2
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func TopViewUnwindAction(for unwindSegue: UIStoryboardSegue, towardsViewController subsequentVC: UIViewController) {
    }
}
