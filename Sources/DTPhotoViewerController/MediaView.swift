//
//  MediaView.swift
//  DTPhotoViewerController
//
//  Created by Sereivoan Yong on 6/12/24.
//

import UIKit
import AVKit
import GSPlayer
import Kingfisher
import Combine

open class MediaView: UIView {

  open var mediaSizeSubject = PassthroughSubject<CGSize?, Never>()

  var cancellable: AnyCancellable?

  open var mediaSize: CGSize? {
    didSet {
      mediaSizeSubject.send(mediaSize)
    }
  }

  open var configuresVideoPlayer: Bool = true

  private let imageOptions: KingfisherOptionsInfo = [.scaleFactor(UIScreen.main.scale), .cacheOriginalImage, .transition(.fade(0.2))]

  open var media: Media? {
    willSet {
      mediaSize = nil
    }
    didSet {
      guard let media else { return }
      switch media.type {
      case .image:
        videoPlayerView?.removeFromSuperview()
        videoPlayerView = nil
        videoThumbnailImageView?.removeFromSuperview()
        videoThumbnailImageView = nil

        imageView = UIImageView(frame: bounds)
        imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        imageView.contentMode = .scaleAspectFill
        addSubview(imageView)

        imageView.kf.setImage(with: media.url, options: imageOptions) { [unowned self] result in
          switch result {
          case .success(let result):
            mediaSize = result.image.size
          case .failure:
            break
          }
        }

      case .video:
        imageView?.removeFromSuperview()
        imageView = nil

        videoThumbnailImageView = UIImageView(frame: bounds)
        videoThumbnailImageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        videoThumbnailImageView.contentMode = .scaleAspectFill
        addSubview(videoThumbnailImageView)

        if configuresVideoPlayer {
          videoPlayerView = VideoPlayerView()
          videoPlayerView.frame = bounds
          videoPlayerView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
          addSubview(videoPlayerView)
        }

        let generator = AVAssetImageGenerator(asset: media.urlAsset)
        generator.appliesPreferredTrackTransform = true
        let imageDataProvider = AVAssetImageDataProvider(assetImageGenerator: generator, time: .zero)
        videoThumbnailImageView.kf.setImage(with: imageDataProvider, options: imageOptions) { [unowned self] result in
          switch result {
          case .success(let result):
            mediaSize = result.image.size
          case .failure:
            break
          }
        }
      }
    }
  }

  /* Image */

  open var imageView: UIImageView!

  /* Video */

  open var videoThumbnailImageView: UIImageView!

  open var videoPlayerView: VideoPlayerView!

}
