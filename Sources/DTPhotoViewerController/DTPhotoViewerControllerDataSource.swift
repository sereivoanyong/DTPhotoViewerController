//
//  DTPhotoViewerControllerDataSource.swift
//  DTPhotoViewerController
//
//  Created by Vo Duc Tung on 1/17/17.
//

import UIKit

public protocol DTPhotoViewerControllerDataSource: NSObjectProtocol {
  
    /// Total number of photo in viewer.
    func numberOfMedia(in mediaViewerController: DTPhotoViewerController) -> Int

    func mediaViewerController(_ mediaViewerController: DTPhotoViewerController, mediaAt index: Int) -> Media

    func mediaViewerController(_ mediaViewerController: DTPhotoViewerController, configure cell: DTPhotoCollectionViewCell, with media: Media, at index: Int)

    /// This method provide the specific referenced view for each photo item in viewer that will be used for smoother dismissal transition.
    func mediaViewerController(_ mediaViewerController: DTPhotoViewerController, referencedViewForMediaAt index: Int) -> UIView?
}

extension DTPhotoViewerControllerDataSource {

    public func mediaViewerController(_ mediaViewerController: DTPhotoViewerController, configure cell: DTPhotoCollectionViewCell, with media: Media, at index: Int) {
        cell.mediaView.media = media
    }

    public func mediaViewerController(_ mediaViewerController: DTPhotoViewerController, referencedViewForMediaAt index: Int) -> UIView? {
        return nil
    }
}
