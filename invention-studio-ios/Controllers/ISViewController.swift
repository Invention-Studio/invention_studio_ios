//
//  ISViewController.swift
//  invention-studio-ios
//
//  Created by Nick's Creative Studio on 2/25/18.
//  Copyright © 2018 Invention Studio at Georgia Tech. All rights reserved.
//

import UIKit

class ISViewController: UIViewController {

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        view.backgroundColor = Theme.background
        view.tintColor = Theme.accentPrimary
        
        self.view.setNeedsDisplay()
    }
}
