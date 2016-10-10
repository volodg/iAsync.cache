//
//  UIImageView+CachedAsyncImageStream.swift
//  iAsync_cache
//
//  Created by Vladimir Gorbenko on 26.09.14.
//  Copyright © 2014 EmbeddedSources. All rights reserved.
//

import Foundation

import iAsync_utils
import iAsync_reactiveKit

import UIKit

import class ReactiveKit.DisposeBag

private var iAsync_AsycImageProperties: Void?

private class Properties {
    var dispose = DisposeBag()
}

public extension UIImageView {

    fileprivate var iAsync_cache_Properties: Properties {
        get {
            if let result = objc_getAssociatedObject(self, &iAsync_AsycImageProperties) as? Properties {
                return result
            }
            let result = Properties()
            self.iAsync_cache_Properties = result
            return result
        }
        set (newValue) {
            objc_setAssociatedObject(self, &iAsync_AsycImageProperties, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    func setImageWith(url: URL?, placeholder: UIImage? = nil, noImage: UIImage? = nil, callBack:((UIImage?)->Void)? = nil) {

        let thumbStream: AsyncStream<UIImage, AnyObject, ErrorWithContext>
        if let url = url {
            thumbStream = thumbnailStorage.imageStreamFor(url: url)
        } else {
            let contextError = ErrorWithContext(error: CacheNoURLError(), context: #function)
            thumbStream = AsyncStream.failed(with: contextError)
        }

        setImageWith(thumbStream: thumbStream, placeholder: placeholder, noImage: noImage, callBack: callBack)
    }

    func setImageWith(thumbStream: AsyncStream<UIImage, AnyObject, ErrorWithContext>, placeholder: UIImage? = nil, noImage: UIImage? = nil, callBack:((UIImage?)->Void)? = nil) {

        image = placeholder

        iAsync_cache_Properties.dispose.dispose()

        let stream = thumbStream.on(success: { [weak self] result in

            self?.setImageOrNotifyVia(callback: callBack, image: result)
        }, failure: { [weak self] error -> () in

            if error.error is AsyncInterruptedError {
                callBack?(nil)
                return
            }

            self?.setImageOrNotifyVia(callback: callBack, image: noImage)
        })
        stream.run().disposeIn(iAsync_cache_Properties.dispose)
    }

    fileprivate func setImageOrNotifyVia(callback :((UIImage?)->Void)?, image :UIImage?) {

        if let callback_ = callback {

            callback_(image)
        } else {

            self.image = image
        }
    }
}
