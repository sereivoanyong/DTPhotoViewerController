//
//  DTCollectionViewFlowLayout.swift
//  DTPhotoViewerController
//
//  Created by Vo Duc Tung on 1/17/17.
//

import UIKit

final class DTCollectionViewFlowLayout: UICollectionViewFlowLayout {
  
    var currentIndex: Int?
    
    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        invalidateLayout()
        return true
    }
    
    override func targetContentOffset(forProposedContentOffset proposedContentOffset: CGPoint) -> CGPoint {
        if let index = currentIndex, let collectionView {
            currentIndex = nil
            return CGPoint(x: CGFloat(index) * collectionView.frame.size.width, y: 0)
        }
        
        return super.targetContentOffset(forProposedContentOffset: proposedContentOffset)
    }
}
