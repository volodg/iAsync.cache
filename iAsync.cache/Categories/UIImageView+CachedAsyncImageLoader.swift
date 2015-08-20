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
    
    func setImageWithURL(url: NSURL?, placeholder: UIImage?) {
        
        image = placeholder
        
        iAsync_cache_AsycImageURL = url
        
        if let url = url {
            
            let doneCallback = { [weak self] (result: AsyncResult<UIImage, NSError>) -> () in
                
                if let self_ = self {
                    
                    switch result {
                    case let .Success(value):
                        let image = value
                        self_.jffSetImage(image, url:url)
                    case .Failure(_):
                        self_.jffSetImage(nil, url:url)
                    case .Interrupted:
                        break
                    case .Unsubscribed:
                        break
                    }
                }
            }
            
            let storage = thumbnailStorage
            let loader  = storage.thumbnailLoaderForUrl(url)
            runAsync(loader, onFinish: doneCallback)
        }
    }
}
