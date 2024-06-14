//
//  Media.swift
//  DTPhotoViewerController
//
//  Created by Sereivoan Yong on 6/12/24.
//

import UIKit
import AVKit

public enum MediaType {

  case image, video
}

final public class Media {

  public let url: URL
  public let type: MediaType
  public let urlAsset: AVURLAsset!

  init(url: URL, type: MediaType, urlAsset: AVURLAsset? = nil) {
    self.url = url
    self.type = type
    self.urlAsset = urlAsset
  }

  public static func image(url: URL) -> Media {
    return Media(url: url, type: .image)
  }

  public static func video(url: URL, urlAsset: AVURLAsset? = nil) -> Media {
    if let urlAsset {
      assert(url == urlAsset.url)
    }
    return Media(url: url, type: .video, urlAsset: urlAsset ?? AVURLAsset(url: url, options: nil))
  }
}
