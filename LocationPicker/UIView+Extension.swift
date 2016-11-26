//
//  UIView+Extension.swift
//  LocationPicker
//
//  Created by Terenze Pro on 26/11/2016.
//  Copyright © 2016 almassapargali. All rights reserved.
//

import Foundation
import UIKit

extension UIView {
    class func fromNib<T : UIView>() -> T {
        let bundle = Bundle(for: SendCurrentLocation.self)
        return bundle.loadNibNamed(String(describing: T.self), owner: nil, options: nil)![0] as! T
    }
}

