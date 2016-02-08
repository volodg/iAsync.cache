//
//  UIImageView+CachedAsyncImageLoader.swift
//  iAsync_cache
//
//  Created by Vladimir Gorbenko on 26.09.14.
//  Copyright (c) 2014 EmbeddedSources. All rights reserved.
//

import Foundation

import iAsync_async
import iAsync_utils

import UIKit

private var iAsync_AsycImageURLHolder: Void?

public extension UIImageView {

    private var iAsync_cache_AsycImageURL: NSURL? {
        get {
            return objc_getAssociatedObject(self, &iAsync_AsycImageURLHolder) as? NSURL
        }
        set (newValue) {
            objc_setAssociatedObject(self, &iAsync_AsycImageURLHolder, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    private func jffSetImage(image: UIImage?, url: NSURL) {

        if image == nil || iAsync_cache_AsycImageURL != url {
            return
        }

        self.image = image
    }

    func setImageWithURL(url: NSURL?, placeholder: UIImage? = nil, noImage: UIImage? = nil, callBack:((UIImage?)->Void)? = nil) {

        image = placeholder

        iAsync_cache_AsycImageURL = url

        guard let url = url else { return }

        let onSuccess = { [weak self] (result: UIImage) -> () in

            let image = result
            callBack?(image)
            self?.jffSetImage(image, url:url)
        }
        let onFailure = { [weak self] (error: NSError) -> () in

            if error is AsyncInterruptedError {
                callBack?(nil)
                return
            }

            callBack?(noImage)
            self?.jffSetImage(noImage, url:url)
        }

        let thumb = thumbnailStorage.thumbnailStreamForUrl(url)
        let stream = thumb.on(success: { onSuccess($0) }, failure: { onFailure($0) })
        stream.run()
    }
}
