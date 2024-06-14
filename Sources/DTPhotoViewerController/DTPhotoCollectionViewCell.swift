//
//  DTPhotoCollectionViewCell.swift
//  DTPhotoViewerController
//
//  Created by Vo Duc Tung on 1/17/17.
//

import UIKit
import Combine

public protocol DTPhotoCollectionViewCellDelegate: NSObjectProtocol {

    func collectionViewCellDidZoomOnPhoto(_ cell: DTPhotoCollectionViewCell, atScale scale: CGFloat)
    func collectionViewCellWillZoomOnPhoto(_ cell: DTPhotoCollectionViewCell)
    func collectionViewCellDidEndZoomingOnPhoto(_ cell: DTPhotoCollectionViewCell, atScale scale: CGFloat)
}

open class DTPhotoCollectionViewCell: UICollectionViewCell {

    public let scrollView: DTScrollView = DTScrollView(frame: .zero)
    public let mediaView: MediaView = MediaView(frame: .zero)

    private var imageObservation: AnyCancellable?

    // default is 1.0
    open var minimumZoomScale: CGFloat = 1.0 {
        willSet {
            if mediaView.mediaSize == nil {
                scrollView.minimumZoomScale = 1.0
            } else {
                scrollView.minimumZoomScale = newValue
            }
        }
        didSet {
            correctCurrentZoomScaleIfNeeded()
        }
    }
    
    // default is 3.0.
    open var maximumZoomScale: CGFloat = 3.0 {
        willSet {
            if mediaView.media == nil {
                scrollView.maximumZoomScale = 1.0
            } else {
                scrollView.maximumZoomScale = newValue
            }
        }
        didSet {
            correctCurrentZoomScaleIfNeeded()
        }
    }
    
    weak var delegate: DTPhotoCollectionViewCellDelegate?
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }
    
    open override func prepareForReuse() {
        super.prepareForReuse()
        scrollView.zoomScale = 1.0
    }
    
    private func commonInit() {
        backgroundColor = .clear
        isUserInteractionEnabled = true

        scrollView.frame = contentView.bounds
        scrollView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.minimumZoomScale = minimumZoomScale
        scrollView.maximumZoomScale = 1.0 // Not allow zooming when there is no image
        scrollView.delegate = self
        contentView.addSubview(scrollView)

        // Layout subviews every time getting new image
        imageObservation = mediaView.mediaSizeSubject.sink { [weak self] _ in
            guard let self else { return }
            // Update image frame whenever image changes
            if mediaView.mediaSize == nil {
                scrollView.minimumZoomScale = 1.0
                scrollView.maximumZoomScale = 1.0
            } else {
                scrollView.minimumZoomScale = minimumZoomScale
                scrollView.maximumZoomScale = maximumZoomScale
                setNeedsLayout()
            }
            correctCurrentZoomScaleIfNeeded()
        }
        mediaView.contentMode = .scaleAspectFit
        scrollView.addSubview(mediaView)
    }
    
    private func correctCurrentZoomScaleIfNeeded() {
        if scrollView.zoomScale < scrollView.minimumZoomScale {
            scrollView.zoomScale = scrollView.minimumZoomScale
        }
        
        if scrollView.zoomScale > scrollView.maximumZoomScale {
            scrollView.zoomScale = scrollView.maximumZoomScale
        }
    }
    
    open override func layoutSubviews() {
        super.layoutSubviews()
        
        // Set the aspect ration of the image
        if let mediaSize = mediaView.mediaSize {
            let horizontalScale = mediaSize.width / scrollView.frame.width
            let verticalScale = mediaSize.height / scrollView.frame.height
            let factor = max(horizontalScale, verticalScale)
            
            //Divide the size by the greater of the vertical or horizontal shrinkage factor
            let width = mediaSize.width / factor
            let height = mediaSize.height / factor
            
            if scrollView.zoomScale != 1 {
                // If current zoom scale is not at default value, we need to maintain
                // imageView's size while laying out subviews
                
                // Calculate new zoom scale corresponding to current default size to maintain
                // imageView's size
                let newZoomScale = scrollView.zoomScale * mediaView.bounds.width / width
                
                // Update scrollView's maximumZoomScale or minimumZoomScale if needed
                // in order to ensure that updating its zoomScale works.
                if newZoomScale > scrollView.maximumZoomScale {
                    scrollView.maximumZoomScale = newZoomScale
                } else if newZoomScale < scrollView.minimumZoomScale {
                    scrollView.minimumZoomScale = newZoomScale
                }
                
                // Reset scrollView's maximumZoomScale or minimumZoomScale if needed
                if newZoomScale <= maximumZoomScale, scrollView.maximumZoomScale > maximumZoomScale {
                    scrollView.maximumZoomScale = maximumZoomScale
                }
                
                if newZoomScale >= minimumZoomScale, scrollView.minimumZoomScale < minimumZoomScale {
                    scrollView.minimumZoomScale = minimumZoomScale
                }
                
                // After updating scrollView's zoomScale, imageView's size will be updated
                // We need to revert it back to its original size.
                let imageViewSize = mediaView.frame.size
                scrollView.zoomScale = newZoomScale
                mediaView.frame.size = imageViewSize // CGSize(width: width * newZoomScale, height: height * newZoomScale)
                scrollView.contentSize = imageViewSize
            } else {
                // If current zoom scale is at default value, just update imageView's size
                let x = (scrollView.frame.width - width) / 2
                let y = (scrollView.frame.height - height) / 2
                
                mediaView.frame = CGRect(x: x, y: y, width: width, height: height)
            }
        }
    }
}

// MARK: - UIScrollViewDelegate

extension DTPhotoCollectionViewCell: UIScrollViewDelegate {

    public func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return mediaView
    }
    
    public func scrollViewWillBeginZooming(_ scrollView: UIScrollView, with view: UIView?) {
        delegate?.collectionViewCellWillZoomOnPhoto(self)
    }
    
    public func scrollViewDidZoom(_ scrollView: UIScrollView) {
        updateImageViewFrameForSize(contentView.frame.size)

        delegate?.collectionViewCellDidZoomOnPhoto(self, atScale: scrollView.zoomScale)
    }
    
    public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        
    }
    
    public func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
        delegate?.collectionViewCellDidEndZoomingOnPhoto(self, atScale: scale)
    }
    
    private func updateImageViewFrameForSize(_ size: CGSize) {
        
        let y = max(0, (size.height - mediaView.frame.height) / 2)
        let x = max(0, (size.width - mediaView.frame.width) / 2)
        
        mediaView.frame.origin = CGPoint(x: x, y: y)
    }
}
