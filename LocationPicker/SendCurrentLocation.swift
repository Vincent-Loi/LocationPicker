//
//  SendCurrentLocation.swift
//  LocationPicker
//
//  Created by Terenze Pro on 26/11/2016.
//  Copyright © 2016 almassapargali. All rights reserved.
//

import UIKit

class SendCurrentLocation: UIView {
    
    var didSelectLocation: (()->())!
    
    override func awakeFromNib() {
        self.translatesAutoresizingMaskIntoConstraints = true
    }
    
    @IBAction func onCurrentLocation(_ sender: Any) {
        didSelectLocation()
    }
    
    
    
}
