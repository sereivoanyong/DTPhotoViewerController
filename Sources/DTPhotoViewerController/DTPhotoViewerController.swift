//
//  DTPhotoViewerController.swift
//  DTPhotoViewerController
//
//  Created by Vo Duc Tung on 4/29/16.
//

import UIKit
import AVKit
import Photos
import Kingfisher
import Combine

private let kPhotoCollectionViewCellIdentifier = "Cell"

open class DTPhotoViewerController: UIViewController {

    /// Scroll direction
    /// Default is `.horizontal`.
    open var scrollDirection: UICollectionView.ScrollDirection {
        get { return collectionViewLayout.scrollDirection }
        set { collectionViewLayout.scrollDirection = newValue }
    }
    
    /// Datasource
    /// Providing number of image items to controller and how to confiure image for each image view in it.
    open weak var dataSource: DTPhotoViewerControllerDataSource?

    /// Delegate
    open weak var delegate: DTPhotoViewerControllerDelegate?

    /// Indicates if status bar should be hidden after photo viewer controller is presented.
    /// Default is `true`.
    open var shouldHideStatusBarOnPresent: Bool = true

    /// Indicates status bar animation style when changing hidden status
    /// Default is `.fade`.
    open var statusBarAnimationStyle: UIStatusBarAnimation = .fade

    /// Indicates status bar style when photo viewer controller is being presenting
    /// Default is `.default`.
    open var statusBarStyleOnPresenting: UIStatusBarStyle = .default
    
    /// Indicates status bar style after photo viewer controller is being dismissing
    /// Include when pan gesture recognizer is active.
    /// Default is `.lightContent`.
    open var statusBarStyleOnDismissing: UIStatusBarStyle = .lightContent
    
    /// Background color of the viewer.
    /// Default is `.black`.
    open var backgroundColor: UIColor = .black {
        didSet {
            backgroundView?.backgroundColor = backgroundColor
        }
    }
    
    /// Indicates if referencedView should be shown or hidden automatically during presentation and dismissal.
    /// Setting automaticallyUpdateReferencedViewVisibility to false means you need to update isHidden property of this view by yourself.
    /// Setting automaticallyUpdateReferencedViewVisibility will also set referencedView isHidden property to false.
    /// Default is `true`.
    open var automaticallyUpdateReferencedViewVisibility: Bool = true {
        didSet {
            if !automaticallyUpdateReferencedViewVisibility {
                referencedView?.isHidden = false
            }
        }
    }
    
    /// Indicates where image should be scaled smaller when being dragged.
    /// Default is `true`.
    open var scaleWhileDragging: Bool = true

    /// This variable sets original frame of image view to animate from
    open private(set) var referenceSize: CGSize = .zero
    
    /// This is the image view that is mainly used for the presentation and dismissal effect.
    /// How it animates from the original view to fullscreen and vice versa.
    public private(set) var mediaView: MediaView

    /// The view where photo viewer originally animates from.
    /// Provide this correctly so that you can have a nice effect.
    public weak private(set) var referencedView: UIView? {
        willSet {
            // Unhide old referenced view and hide the new one
            referencedView?.isHidden = false
        }
        didSet {
            if automaticallyUpdateReferencedViewVisibility {
                referencedView?.isHidden = true
            }
        }
    }

    let collectionViewLayout: DTCollectionViewFlowLayout = {
        let collectionViewLayout = DTCollectionViewFlowLayout()
        collectionViewLayout.minimumLineSpacing = 0
        collectionViewLayout.minimumInteritemSpacing = 0
        collectionViewLayout.scrollDirection = .horizontal
        collectionViewLayout.sectionInset = .zero
        return collectionViewLayout
    }()

    /// Collection view.
    /// This will be used when displaying multiple images.
    var collectionView: UICollectionView!
    public var scrollView: UIScrollView {
        return collectionView
    }
    
    /// View used for fading effect during presentation and dismissal animation or when controller is being dragged.
    public private(set) var backgroundView: UIView!

    /// Pan gesture for dragging controller
    public private(set) var panGestureRecognizer: UIPanGestureRecognizer!

    /// Double tap gesture
    public private(set) var doubleTapGestureRecognizer: UITapGestureRecognizer!

    /// Single tap gesture
    public private(set) var singleTapGestureRecognizer: UITapGestureRecognizer!

    private var _shouldHideStatusBar = false
    private var _shouldUseStatusBarStyle = false
    private var imageObservation: AnyCancellable?

    /// Transition animator
    /// Customizable if you wish to provide your own transitions.
    open var animator: DTPhotoViewerBaseAnimator = DTPhotoAnimator()
    
    public init(referencedView: UIView?, media: Media?) {
        self.referencedView = referencedView

        // Image view
        mediaView = MediaView(frame: .zero)
        mediaView.configuresVideoPlayer = false
        mediaView.media = media
        super.init(nibName: nil, bundle: nil)

        modalPresentationStyle = .overFullScreen
        modalPresentationCapturesStatusBarAppearance = true
        transitioningDelegate = self
    }
    
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    open override func viewDidLoad() {
        super.viewDidLoad()
        
        //Background view
        backgroundView = UIView(frame: view.bounds)
        backgroundView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        backgroundView.alpha = 0
        backgroundView.backgroundColor = backgroundColor
        view.addSubview(backgroundView)

        // Image view
        if let referencedView {
            // Content mode should be identical between image view and reference view
            mediaView.contentMode = referencedView.contentMode
        }
        // Configure this block for changing image size when image changed
        imageObservation = mediaView.mediaSizeSubject.sink { [weak self] _ in
            guard let self else { return }
            layoutImageView()
        }
        mediaView.frame = frameForReferencedView()
        mediaView.clipsToBounds = true
        view.addSubview(mediaView)

        // Collection view
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: collectionViewLayout)
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.backgroundColor = .clear
        collectionView.register(DTPhotoCollectionViewCell.self, forCellWithReuseIdentifier: kPhotoCollectionViewCellIdentifier)
        collectionView.contentInsetAdjustmentBehavior = .never
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.showsVerticalScrollIndicator = false
        collectionView.isPagingEnabled = true
        collectionView.dataSource = self
        collectionView.delegate = self
        view.addSubview(collectionView)

        // Double tap gesture recognizer
        doubleTapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(_handleDoubleTapGesture))
        doubleTapGestureRecognizer.numberOfTapsRequired = 2
        doubleTapGestureRecognizer.numberOfTouchesRequired = 1
        collectionView.addGestureRecognizer(doubleTapGestureRecognizer)

        // Tap gesture recognizer
        singleTapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(_handleTapGesture))
        singleTapGestureRecognizer.numberOfTapsRequired = 1
        singleTapGestureRecognizer.numberOfTouchesRequired = 1
        singleTapGestureRecognizer.require(toFail: doubleTapGestureRecognizer)
        collectionView.addGestureRecognizer(singleTapGestureRecognizer)

        // Pan gesture recognizer
        panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(_handlePanGesture))
        panGestureRecognizer.maximumNumberOfTouches = 1
        view.isUserInteractionEnabled = true
        view.addGestureRecognizer(panGestureRecognizer)
    }
    
    open override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        
        // Update image view frame everytime view changes frame
        layoutImageView()
    }

    private func layoutImageView() {
        // Update image frame whenever image changes and when the imageView is not being visible
        // imageView is only being visible during presentation or dismissal
        // For that reason, we should not update frame of imageView no matter what.
        guard let mediaSize = mediaView.mediaSize, mediaView.isHidden else { return }
        mediaView.frame.size = imageViewSize(for: mediaSize)
        mediaView.center = view.center

        // No datasource, only 1 item in collection view --> reloadData
        if dataSource == nil {
            collectionView.reloadData()
        }
    }

    open override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        // Update layout
        collectionViewLayout.currentIndex = currentMediaIndex
    }
    
    open override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if !animated {
            presentingAnimation()
            presentationAnimationDidFinish()
        } else {
            presentationAnimationWillStart()
        }
    }
    
    open override func viewWillDisappear(_ animated: Bool) {
        // Update image view before animation
        updateImageView(scrollView: scrollView)
        
        super.viewWillDisappear(animated)
        
        if !animated {
            dismissingAnimation()
            dismissalAnimationDidFinish()
        } else {
            dismissalAnimationWillStart()
        }
    }
    
    open override var prefersStatusBarHidden: Bool {
        if shouldHideStatusBarOnPresent {
            return _shouldHideStatusBar
        }
        return false
    }
    
    open override var preferredStatusBarUpdateAnimation: UIStatusBarAnimation {
        return statusBarAnimationStyle
    }
    
    open override var preferredStatusBarStyle: UIStatusBarStyle {
        if _shouldUseStatusBarStyle {
            return statusBarStyleOnPresenting
        }
        return statusBarStyleOnDismissing
    }
    
    // MARK: Private methods
    private func startAnimation() {
        // Hide reference image view
        if automaticallyUpdateReferencedViewVisibility {
            referencedView?.isHidden = true
        }
        
        // Animate to center
        _animateToCenter()
    }
    
    func _animateToCenter() {
        UIView.animate(withDuration: animator.presentingDuration, animations: {
            self.presentingAnimation()
        }) { (finished) in
            // Presenting animation ended
            self.presentationAnimationDidFinish()
        }
    }
    
    func _hideImageView(_ imageViewHidden: Bool) {
        // Hide image view should show collection view and vice versa
        mediaView.isHidden = imageViewHidden
        scrollView.isHidden = !imageViewHidden
    }
    
    func _dismiss() {
        dismiss(animated: true, completion: nil)
    }
    
    @objc func _handleTapGesture(_ gesture: UITapGestureRecognizer) {
        // Method to override
        didReceiveTapGesture()
        
        // Delegate method
        delegate?.photoViewerControllerDidReceiveTapGesture?(self)
    }
    
    @objc func _handleDoubleTapGesture(_ gesture: UITapGestureRecognizer) {
        // Method to override
        didReceiveDoubleTapGesture()
        
        // Delegate method
        delegate?.photoViewerControllerDidReceiveDoubleTapGesture?(self)
        
        let indexPath = IndexPath(item: currentMediaIndex, section: 0)
        
        if let cell = collectionView.cellForItem(at: indexPath) as? DTPhotoCollectionViewCell {
            // Double tap
            // imageViewerControllerDidDoubleTapImageView()
            
            if cell.scrollView.zoomScale == cell.scrollView.minimumZoomScale {
                let location = gesture.location(in: view)
                let center = cell.mediaView.convert(location, from: view)

                // Zoom in
                cell.minimumZoomScale = 1.0
                let rect = zoomRect(for: cell.mediaView, scale: cell.scrollView.maximumZoomScale, center: center)
                cell.scrollView.zoom(to: rect, animated: true)
            } else {
                // Zoom out
                cell.minimumZoomScale = 1.0
                cell.scrollView.setZoomScale(cell.scrollView.minimumZoomScale, animated: true)
            }
        }
    }
    
    private func frameForReferencedView() -> CGRect {
        if let referencedView, let superview = referencedView.superview {
            var frame = superview.convert(referencedView.frame, to: view)

            if abs(frame.size.width - referencedView.frame.size.width) > 1 {
                // This is workaround for bug in ios 8, everything is double.
                frame = CGRect(x: frame.origin.x/2, y: frame.origin.y/2, width: frame.size.width/2, height: frame.size.height/2)
            }

            return frame
        }
        
        // Work around when there is no reference view, dragging might behave oddly
        // Should be fixed in the future
        let defaultSize: CGFloat = 1
        return CGRect(x: view.frame.midX - defaultSize/2, y: view.frame.midY - defaultSize/2, width: defaultSize, height: defaultSize)
    }

    private func currentPhotoIndex(for scrollView: UIScrollView) -> Int {
        if scrollDirection == .horizontal {
            if scrollView.frame.width == 0 {
                return 0
            }
            if view.isRightToLeft() {
                return Int(round((scrollView.contentSize.width - scrollView.frame.width - scrollView.contentOffset.x) / scrollView.frame.width))
            } else {
                return Int(round(scrollView.contentOffset.x / scrollView.frame.width))
            }
        } else {
            if scrollView.frame.height == 0 {
                return 0
            }
            return Int(scrollView.contentOffset.y / scrollView.frame.height)
        }
    }
    
    // Update zoom inside UICollectionViewCell
    private func _updateZoomScaleForSize(cell: DTPhotoCollectionViewCell, size: CGSize) {
        let widthScale = size.width / cell.mediaView.bounds.width
        let heightScale = size.height / cell.mediaView.bounds.height
        let zoomScale = min(widthScale, heightScale)
        
        cell.maximumZoomScale = zoomScale
    }
    
    private func zoomRect(for imageView: MediaView, scale: CGFloat, center: CGPoint) -> CGRect {
        var zoomRect: CGRect = .zero

        // The zoom rect is in the content view's coordinates.
        // At a zoom scale of 1.0, it would be the size of the
        // imageScrollView's bounds.
        // As the zoom scale decreases, so more content is visible,
        // the size of the rect grows.
        zoomRect.size.height = imageView.frame.size.height / scale
        zoomRect.size.width  = imageView.frame.size.width  / scale
        
        // choose an origin so as to get the right center.
        zoomRect.origin.x = center.x - (zoomRect.size.width  / 2.0)
        zoomRect.origin.y = center.y - (zoomRect.size.height / 2.0)
        
        return zoomRect
    }
    
    @objc func _handlePanGesture(_ gesture: UIPanGestureRecognizer) {
        if let gestureView = gesture.view {
            switch gesture.state {
            case .began:
                
                // Delegate method
                delegate?.photoViewerController?(self, willBeginPanGestureRecognizer: panGestureRecognizer)
                
                // Update image view when starting to drag
                updateImageView(scrollView: scrollView)
                
                // Make status bar visible when beginning to drag image view
                updateStatusBar(isHidden: false, defaultStatusBarStyle: false)
                
                // Hide collection view & display image view
                _hideImageView(false)
                
                // Method to override
                willBegin(panGestureRecognizer: panGestureRecognizer)
                
            case .changed:
                let translation = gesture.translation(in: gestureView)
                mediaView.center = CGPoint(x: view.center.x + translation.x, y: view.center.y + translation.y)
                
                //Change opacity of background view based on vertical distance from center
                let yDistance = abs(mediaView.center.y - view.center.y)
                var alpha = 1.0 - yDistance/(gestureView.center.y)
                
                if alpha < 0 {
                    alpha = 0
                }
                
                backgroundView.alpha = alpha
                
                // Scale image
                // Should not go smaller than max ratio
                if let mediaSize = mediaView.mediaSize, scaleWhileDragging {
                    let referenceSize = frameForReferencedView().size
                    
                    // If alpha = 0, then scale is max ratio, if alpha = 1, then scale is 1
                    let scale = alpha
                    
                    // imageView.transform = CGAffineTransformMakeScale(scale, scale)
                    // Do not use transform to scale down image view
                    // Instead change width & height
                    if scale < 1 && scale >= 0 {
                        let maxSize = imageViewSize(for: mediaSize)
                        let scaleSize = CGSize(width: maxSize.width * scale, height: maxSize.height * scale)
                        
                        if scaleSize.width >= referenceSize.width || scaleSize.height >= referenceSize.height {
                            mediaView.frame.size = scaleSize
                        }
                    }
                }
                
            default:
                // Animate back to center
                if backgroundView.alpha < 0.8 {
                    _dismiss()
                } else {
                    _animateToCenter()
                }
                
                // Method to override
                didEnd(panGestureRecognizer: panGestureRecognizer)
                
                // Delegate method
                delegate?.photoViewerController?(self, didEndPanGestureRecognizer: panGestureRecognizer)
            }
        }
    }
    
    private func imageViewSize(for size: CGSize?) -> CGSize {
        if let size {
            let rect = AVMakeRect(aspectRatio: size, insideRect: view.bounds)
            return rect.size
        }
        
        return .zero
    }
    
    func presentingAnimation() {
        // Hide reference view
        if automaticallyUpdateReferencedViewVisibility {
            referencedView?.isHidden = true
        }
        
        // Calculate final frame
        var destinationFrame: CGRect = .zero
        destinationFrame.size = imageViewSize(for: mediaView.mediaSize)

        // Animate image view to the center
        mediaView.frame = destinationFrame
        mediaView.center = view.center
        
        // Change status bar to black style
        updateStatusBar(isHidden: true, defaultStatusBarStyle: true)
        
        // Animate background alpha
        backgroundView.alpha = 1.0
    }
    
    private func updateStatusBar(isHidden: Bool, defaultStatusBarStyle isDefaultStyle: Bool) {
        _shouldUseStatusBarStyle = isDefaultStyle
        _shouldHideStatusBar = isHidden
        setNeedsStatusBarAppearanceUpdate()
    }
    
    func dismissingAnimation() {
        mediaView.frame = frameForReferencedView()
        backgroundView.alpha = 0
    }
    
    func presentationAnimationDidFinish() {
        // Method to override
        didEndPresentingAnimation()
        
        // Delegate method
        delegate?.photoViewerControllerDidEndPresentingAnimation?(self)
        
        // Hide animating image view and show collection view
        _hideImageView(true)
    }
    
    func presentationAnimationWillStart() {
        // Hide collection view and show image view
        _hideImageView(false)
    }
    
    func dismissalAnimationWillStart() {
        // Hide collection view and show image view
        _hideImageView(false)
    }
    
    func dismissalAnimationDidFinish() {
        if automaticallyUpdateReferencedViewVisibility {
            referencedView?.isHidden = false
        }
    }
    
    // MARK: Public behavior methods
    open func didScrollToPhoto(at index: Int) {
        
    }
    
    open func didZoomOnPhoto(at index: Int, atScale scale: CGFloat) {
        
    }
    
    open func didEndZoomingOnPhoto(at index: Int, atScale scale: CGFloat) {
        
    }
    
    open func willZoomOnPhoto(at index: Int) {
        
    }
    
    open func didReceiveTapGesture() {
        
    }
    
    open func didReceiveDoubleTapGesture() {
        
    }
    
    open func willBegin(panGestureRecognizer gestureRecognizer: UIPanGestureRecognizer) {
        
    }
    
    open func didEnd(panGestureRecognizer gestureRecognizer: UIPanGestureRecognizer) {
        
    }
    
    open func didEndPresentingAnimation() {
        
    }
}

// MARK: - UIViewControllerTransitioningDelegate

extension DTPhotoViewerController: UIViewControllerTransitioningDelegate {

    public func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return animator
    }
    
    public func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return animator
    }
}

// MARK: - UICollectionViewDataSource

extension DTPhotoViewerController: UICollectionViewDataSource {

    // MARK: Public methods
    public var currentMediaIndex: Int {
        return currentPhotoIndex(for: scrollView)
    }
    
    public var zoomScale: CGFloat {
        let index = currentMediaIndex
        let indexPath = IndexPath(item: index, section: 0)
        
        if let cell = collectionView.cellForItem(at: indexPath) as? DTPhotoCollectionViewCell {
            return cell.scrollView.zoomScale
        }
        
        return 1.0
    }
    
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if let dataSource {
            return dataSource.numberOfMedia(in: self)
        }
        return 1
    }
    
    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let dataSource else { fatalError() }
        let media = dataSource.mediaViewerController(self, mediaAt: indexPath.item)
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: kPhotoCollectionViewCellIdentifier, for: indexPath) as! DTPhotoCollectionViewCell
        dataSource.mediaViewerController(self, configure: cell, with: media, at: indexPath.item)
        cell.delegate = self
        return cell
    }
}

// MARK: - Open methods

extension DTPhotoViewerController {

    // For each reuse identifier that the collection view will use, register either a class or a nib from which to instantiate a cell.
    // If a nib is registered, it must contain exactly 1 top level object which is a DTPhotoCollectionViewCell.
    // If a class is registered, it will be instantiated via alloc/initWithFrame:
    public func registerClassPhotoViewer(_ cellClass: DTPhotoCollectionViewCell.Type) {
        collectionView.register(cellClass, forCellWithReuseIdentifier: kPhotoCollectionViewCellIdentifier)
    }
    
    public func registerNibForPhotoViewer(_ nib: UINib?) {
        collectionView.register(nib, forCellWithReuseIdentifier: kPhotoCollectionViewCellIdentifier)
    }
    
    // Update data before calling theses methods
    public func reloadData() {
        collectionView.reloadData()
    }
    
    public func insertPhotos(at indexes: [Int], completion: ((Bool) -> Void)?) {
        let indexPaths = indexPathsForIndexes(indexes: indexes)
        
        collectionView.performBatchUpdates({
            self.collectionView.insertItems(at: indexPaths)
        }, completion: completion)
    }
    
    public func deletePhotos(at indexes: [Int], completion: ((Bool) -> Void)?) {
        let indexPaths = indexPathsForIndexes(indexes: indexes)
        
        collectionView.performBatchUpdates({
            self.collectionView.deleteItems(at: indexPaths)
        }, completion: completion)
    }
    
    public func reloadPhotos(at indexes: [Int]) {
        let indexPaths = indexPathsForIndexes(indexes: indexes)
        
        collectionView.reloadItems(at: indexPaths)
    }
    
    public func movePhoto(at index: Int, to newIndex: Int) {
        let indexPath = IndexPath(item: index, section: 0)
        let newIndexPath = IndexPath(item: newIndex, section: 0)
        
        collectionView.moveItem(at: indexPath, to: newIndexPath)
    }
    
    public func scrollToPhoto(at index: Int, animated: Bool) {
        guard collectionView.numberOfItems(inSection: 0) > index else { return }
        let indexPath = IndexPath(item: index, section: 0)

        let position: UICollectionView.ScrollPosition

        if scrollDirection == .vertical {
            position = .bottom
        } else {
            position = .right
        }

        collectionView.scrollToItem(at: indexPath, at: position, animated: animated)

        if !animated {
            // Need to call these methods since scrollView delegate method won't be called when not animated
            // Method to override
            didScrollToPhoto(at: index)

            // Call delegate
            delegate?.photoViewerController?(self, didScrollToPhotoAt: index)
        }
    }
    
    // Helper for indexpaths
    func indexPathsForIndexes(indexes: [Int]) -> [IndexPath] {
        return indexes.map { IndexPath(item: $0, section: 0) }
    }
}

// MARK: - DTPhotoCollectionViewCellDelegate

extension DTPhotoViewerController: DTPhotoCollectionViewCellDelegate {

    public func collectionViewCellDidZoomOnPhoto(_ cell: DTPhotoCollectionViewCell, atScale scale: CGFloat) {
        guard let indexPath = collectionView.indexPath(for: cell) else { return }
        // Method to override
        didZoomOnPhoto(at: indexPath.item, atScale: scale)

        // Call delegate
        delegate?.photoViewerController?(self, didZoomOnPhotoAtIndex: indexPath.item, atScale: scale)
    }
    
    public func collectionViewCellDidEndZoomingOnPhoto(_ cell: DTPhotoCollectionViewCell, atScale scale: CGFloat) {
        guard let indexPath = collectionView.indexPath(for: cell) else { return }
        // Method to override
        didEndZoomingOnPhoto(at: indexPath.item, atScale: scale)

        // Call delegate
        delegate?.photoViewerController?(self, didEndZoomingOnPhotoAtIndex: indexPath.item, atScale: scale)
    }
    
    public func collectionViewCellWillZoomOnPhoto(_ cell: DTPhotoCollectionViewCell) {
        guard let indexPath = collectionView.indexPath(for: cell) else { return }
        // Method to override
        willZoomOnPhoto(at: indexPath.item)

        // Call delegate
        delegate?.photoViewerController?(self, willZoomOnPhotoAtIndex: indexPath.item)
    }
}

// MARK: - UICollectionViewDelegateFlowLayout

extension DTPhotoViewerController: UICollectionViewDelegateFlowLayout {

    open func scrollViewDidScroll(_ scrollView: UIScrollView) {
        delegate?.photoViewerController?(self, scrollViewDidScroll: scrollView)
    }
    
    open func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        let index = currentMediaIndex
        
        // Method to override
        didScrollToPhoto(at: index)
        
        // Call delegate
        delegate?.photoViewerController?(self, didScrollToPhotoAt: index)
    }
    
    open func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return collectionView.frame.size
    }
    
    open func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return mediaView
    }
    
    open func scrollViewDidZoom(_ scrollView: UIScrollView) {
        updateFrame(for: view.frame.size)

        // Disable pan gesture if zoom scale is not 1
        if scrollView.zoomScale != 1 {
            panGestureRecognizer.isEnabled = false
        } else {
            panGestureRecognizer.isEnabled = true
        }
    }
    
    open func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            let index = currentMediaIndex
            didScrollToPhoto(at: index)
            
            // Call delegate
            delegate?.photoViewerController?(self, didScrollToPhotoAt: index)
        }
    }
    
    open func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        let index = currentMediaIndex
        didScrollToPhoto(at: index)
        
        // Call delegate
        delegate?.photoViewerController?(self, didScrollToPhotoAt: index)
    }
    
    // MARK: Helpers
    
    private func updateFrame(for size: CGSize) {

        let y = max(0, (size.height - mediaView.frame.height) / 2)
        let x = max(0, (size.width - mediaView.frame.width) / 2)
        
        mediaView.frame.origin = CGPoint(x: x, y: y)
    }
    
    // Update image view image
    func updateImageView(scrollView: UIScrollView) {
        let index = currentMediaIndex

        if let dataSource {

            // Update image view before pan gesture happens
            if dataSource.numberOfMedia(in: self) > 0 {
                mediaView.media = dataSource.mediaViewerController(self, mediaAt: index)
            }

            // Change referenced image view
            if let view = dataSource.mediaViewerController(self, referencedViewForMediaAt: index) {
                referencedView = view
            }
        }
    }
}
