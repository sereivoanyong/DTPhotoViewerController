//
//  DTScrollView.swift
//  DTPhotoViewerController
//
//  Created by Vo Duc Tung on 1/18/17.
//

import UIKit

final public class DTScrollView: UIScrollView {
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        panGestureRecognizer.delegate = self
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
}

// MARK: - UIGestureRecognizerDelegate

extension DTScrollView: UIGestureRecognizerDelegate {

    public override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer == panGestureRecognizer {
            if gestureRecognizer.numberOfTouches == 1 && zoomScale == 1.0 {
                return false
            }
        }
        
        return true
    }
}