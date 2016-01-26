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

        let doneCallback = { [weak self] (result: AsyncResult<UIImage, NSError>) -> () in

            guard let self_ = self else { return }

            switch result {
            case .Success(let value):

                let image = value

                callBack?(image)

                self_.jffSetImage(image, url:url)
            case .Failure:

                callBack?(noImage)

                self_.jffSetImage(noImage, url:url)
            case .Interrupted:
                callBack?(nil)
                break
            case .Unsubscribed:
                callBack?(nil)
                break
            }
        }

        let storage = thumbnailStorage
        let loader  = storage.thumbnailLoaderForUrl(url)
        runAsync(loader, onFinish: doneCallback)
    }
}
