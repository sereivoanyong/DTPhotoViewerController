//
//  ViewController.swift
//  DTPhotoViewerController
//
//  Created by Tung Vo on 05/07/2016.
//  Copyright (c) 2016 Tung Vo. All rights reserved.
//

import DTPhotoViewerController
import UIKit

private let kCollectionViewCellIdentifier = "Cell"
private let kNumberOfRows: Int = 3
private let kRowSpacing: CGFloat = 5
private let kColumnSpacing: CGFloat = 5

/// Class CollectionViewCell
/// Add extra UI element to photo.
public class CollectionViewCell: UICollectionViewCell {
    public private(set) var mediaView: MediaView!

    weak var delegate: DTPhotoCollectionViewCellDelegate?

    override public init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        mediaView = MediaView(frame: .zero)
        mediaView.configuresVideoPlayer = false
        mediaView.contentMode = .scaleAspectFit
        mediaView.layer.cornerRadius = 10
        mediaView.layer.masksToBounds = true
        mediaView.backgroundColor = UIColor.white
        contentView.addSubview(mediaView)
        contentView.backgroundColor = .clear
        backgroundColor = .clear
    }

    override public func layoutSubviews() {
        super.layoutSubviews()
        let margin = CGFloat(5)
        mediaView.frame = CGRect(x: margin, y: margin, width: bounds.size.width - 2 * margin, height: bounds.size.height - 2 * margin)
    }
}

/// Class ViewController
/// Display collection of photos
class ViewController: UICollectionViewController, UICollectionViewDelegateFlowLayout {
    fileprivate var selectedImageIndex: Int = 0

    var media: [Media] = [
      .video(url: URL(string: "https://files.testfile.org/Video%20MP4%2FSand%20-%20testfile.org.mp4")!),
      .image(url: URL(string: "https://images.macrumors.com/t/_XfmeApFjtR9z9hzFYq33FFDQUY=/1600x0/article-new/2024/01/SharePlay-Music-Control-Expanding-Feature-2.jpg")!),
    ]

    init() {
        let flowLayout = UICollectionViewFlowLayout()
        flowLayout.scrollDirection = .vertical
        flowLayout.minimumInteritemSpacing = kColumnSpacing
        flowLayout.minimumLineSpacing = kRowSpacing
        flowLayout.sectionInset = UIEdgeInsets(top: kRowSpacing, left: kColumnSpacing, bottom: kRowSpacing, right: kColumnSpacing)

        super.init(collectionViewLayout: flowLayout)

//        for index in 0...9 {
//            //swiftlint:disable force_unwrapping
//            media.append(.image(url: Bundle.main.url(forResource: "mario\(index % 5 + 1)", withExtension: "png")!))
//        }

        collectionView?.register(CollectionViewCell.self, forCellWithReuseIdentifier: kCollectionViewCellIdentifier)

        if #available(iOS 11.0, *) {
            collectionView?.contentInsetAdjustmentBehavior = .never
        } else {
            automaticallyAdjustsScrollViewInsets = false
        }

        title = "Example"
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        collectionViewLayout.invalidateLayout()
    }

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return media.count
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: kCollectionViewCellIdentifier, for: indexPath) as! CollectionViewCell
        cell.mediaView.media = media[indexPath.item]
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let flowLayout = collectionViewLayout as! UICollectionViewFlowLayout
        let width = collectionView.frame.width - flowLayout.sectionInset.left - flowLayout.sectionInset.right - flowLayout.minimumInteritemSpacing * CGFloat(kNumberOfRows - 1)
        let itemSize = floor(width / CGFloat(kNumberOfRows))
        return CGSize(width: itemSize, height: itemSize)
    }

    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        selectedImageIndex = indexPath.row

        if let cell = collectionView.cellForItem(at: indexPath) as? CollectionViewCell {
            let viewController = SimplePhotoViewerController(referencedView: cell.mediaView, media: media[indexPath.item])
            viewController.dataSource = self
            viewController.delegate = self
            present(viewController, animated: true, completion: nil)
        }
    }
}

// MARK: DTPhotoViewerControllerDataSource
extension ViewController: DTPhotoViewerControllerDataSource {

    func numberOfMedia(in mediaViewerController: DTPhotoViewerController) -> Int {
        return media.count
    }

    func mediaViewerController(_ mediaViewerController: DTPhotoViewerController, mediaAt index: Int) -> Media {
        return media[index]
    }

    func mediaViewerController(_ mediaViewerController: DTPhotoViewerController, configure cell: DTPhotoCollectionViewCell, with media: Media, at index: Int) {
        cell.mediaView.media = media
        // Set text for each item
        if let cell = cell as? CustomPhotoCollectionViewCell {
          cell.extraLabel.text = "Image no \(index + 1)"
        }
    }

    func mediaViewerController(_ mediaViewerController: DTPhotoViewerController, referencedViewForMediaAt index: Int) -> UIView? {
        let indexPath = IndexPath(item: index, section: 0)
        if let cell = collectionView?.cellForItem(at: indexPath) as? CollectionViewCell {
            return cell.mediaView
        }

        return nil
    }
}

// MARK: DTPhotoViewerControllerDelegate
extension ViewController: SimplePhotoViewerControllerDelegate {
    func photoViewerControllerDidEndPresentingAnimation(_ photoViewerController: DTPhotoViewerController) {
        photoViewerController.scrollToPhoto(at: selectedImageIndex, animated: false)
    }

    func photoViewerController(_ photoViewerController: DTPhotoViewerController, didScrollToPhotoAt index: Int) {
        selectedImageIndex = index
        if let collectionView {
            let indexPath = IndexPath(item: selectedImageIndex, section: 0)

            // If cell for selected index path is not visible
            if !collectionView.indexPathsForVisibleItems.contains(indexPath) {
                // Scroll to make cell visible
                collectionView.scrollToItem(at: indexPath, at: .bottom, animated: false)
            }
        }
    }

    func simplePhotoViewerController(_ viewController: SimplePhotoViewerController, savePhotoAt index: Int) {
//        UIImageWriteToSavedPhotosAlbum(images[index], nil, nil, nil)
    }
}
