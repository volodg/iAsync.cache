//
//  UIImageView+CachedAsyncImageLoader.swift
//  JCache
//
//  Created by Vladimir Gorbenko on 26.09.14.
//  Copyright (c) 2014 EmbeddedSources. All rights reserved.
//

import Foundation

import iAsync_utils

import UIKit
import Result

private var jffAsycImageURLHolder: Void?

public extension UIImageView {
    
    private var jffAsycImageURL: NSURL? {
        get {
            return objc_getAssociatedObject(self, &jffAsycImageURLHolder) as? NSURL
        }
        set (newValue) {
            objc_setAssociatedObject(self, &jffAsycImageURLHolder, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    private func jffSetImage(image: UIImage?, url: NSURL) {
        
        if image == nil || jffAsycImageURL != url {
            return
        }
        
        self.image = image
    }
    
    func setImageWithURL(url: NSURL?, placeholder: UIImage?) {
        
        image = placeholder
        
        jffAsycImageURL = url
        
        if let url = url {
            
            let doneCallback = { [weak self] (result: Result<UIImage, NSError>) -> () in
                
                if let self_ = self {
                    
                    switch result {
                    case let .Success(value):
                        let image = value
                        self_.jffSetImage(image, url:url)
                    case let .Failure(error):
                        self_.jffSetImage(nil, url:url)
                    }
                }
            }
            
            let storage = jThumbnailStorage
            let loader  = storage.thumbnailLoaderForUrl(url)
            let cancel  = loader(
                progressCallback: nil,
                stateCallback: nil,
                finishCallback: doneCallback)
        }
    }
}
