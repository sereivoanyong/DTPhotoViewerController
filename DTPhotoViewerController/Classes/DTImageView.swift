//
//  DTImageView.swift
//  Pods
//
//  Created by Admin on 17/01/2017.
//
//

import UIKit

open class DTImageView: UIImageView {

    open override var image: UIImage? {
        didSet {
            imageChangeBlock?(image)
        }
    }
    
    var imageChangeBlock: ((UIImage?) -> Void)?
}
