//
//  UIImageView+CachedAsyncImageLoader.swift
//  iAsync_cache
//
//  Created by Vladimir Gorbenko on 26.09.14.
//  Copyright (c) 2014 EmbeddedSources. All rights reserved.
//

import Foundation

import iAsync_utils

import UIKit
import ReactiveKit

private var iAsync_AsycImageProperties: Void?

private class Properties {
    var dispose = DisposeBag()
}

public extension UIImageView {

    private var iAsync_cache_Properties: Properties {
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

    func setImageWithURL(url: NSURL?, placeholder: UIImage? = nil, noImage: UIImage? = nil, callBack:((UIImage?)->Void)? = nil) {

        image = placeholder

        guard let url = url else { return }

        let onSuccess = { [weak self] (result: UIImage) -> () in

            callBack?(result)
            self?.image = result
        }
        let onFailure = { [weak self] (error: NSError) -> () in

            if error is AsyncInterruptedError {
                callBack?(nil)
                return
            }

            callBack?(noImage)
            self?.image = noImage
        }

        iAsync_cache_Properties.dispose.dispose()

        let thumb  = thumbnailStorage.thumbnailStreamForUrl(url)
        let stream = thumb.on(success: { onSuccess($0) }, failure: { onFailure($0) })
        stream.run().disposeIn(iAsync_cache_Properties.dispose)
    }
}
