//
//  ThumbnailStorage.swift
//  iAsync_cache
//
//  Created by Vladimir Gorbenko on 22.09.14.
//  Copyright (c) 2014 EmbeddedSources. All rights reserved.
//

import Foundation

import iAsync_network
import iAsync_restkit
import iAsync_async
import iAsync_utils

import UIKit

private let cacheQueueName = "com.embedded_sources.jffcache.thumbnail_storage.cache"

private let noDataUrlStr = "nodata://jff.cache.com"

public extension NSURL {
    
    public class var noImageDataURL: NSURL {
        struct Static {
            static let instance = NSURL(string: noDataUrlStr)!
        }
        return Static.instance
    }
    
    public var isNoImageDataURL: Bool {
        return self.absoluteString == noDataUrlStr
    }
}

public var thumbnailStorage = ThumbnailStorage()

public class ThumbnailStorage : NSObject {
    
    private override init() {
        
        super.init()
        
        NSNotificationCenter.defaultCenter().addObserver(
            self,
            selector: Selector("onMemoryWarning:"),
            name: UIApplicationDidReceiveMemoryWarningNotification,
            object: nil)
    }
    
    private let cachedAsyncOp = JCachedAsync<NSURL, UIImage, NSError>()
    private let imagesByUrl   = NSCache()
    
    //TODO add load balancer here
    public func thumbnailLoaderForUrl(url: NSURL?) -> AsyncTypes<UIImage, NSError>.Async {
        
        if let url = url {
            
            if url.isNoImageDataURL {
                return async(error: JCacheNoURLError())
            }
            
            let loader = { (
                progressCallback: AsyncProgressCallback?,
                stateCallback   : AsyncChangeStateCallback?,
                doneCallback    : AsyncTypes<UIImage, NSError>.DidFinishAsyncCallback?) -> JAsyncHandler in
                
                let imageLoader = self.cachedInDBImageDataLoaderForUrl(url)
                
                let setter = { (value: AsyncResult<UIImage, NSError>) -> () in
                    
                    if let value = value.value {
                        self.imagesByUrl.setObject(value, forKey: url)
                    }
                }
                
                let getter = { () -> AsyncResult<UIImage, NSError>? in
                    
                    if let image = self.imagesByUrl.objectForKey(url) as? UIImage {
                        return AsyncResult.success(image)
                    }
                    
                    return nil
                }
                
                let loader = self.cachedAsyncOp.asyncOpWithPropertySetter(
                    setter,
                    getter   : getter,
                    uniqueKey: url   ,
                    loader   : imageLoader)
                
                return loader(
                    progressCallback: progressCallback,
                    stateCallback   : stateCallback,
                    finishCallback  : doneCallback)
            }
            
            return logErrorForLoader(loader)
        }
        
        return async(error: JCacheNoURLError())
    }
    
    public func tryThumbnailLoaderForUrls(urls: [NSURL]) -> AsyncTypes<UIImage, NSError>.Async {
        
        if urls.count == 0 {
            return async(error: JCacheNoURLError())
        }
        
        let loaders = urls.map { (url: NSURL) -> AsyncTypes<UIImage, NSError>.Async in
            
            return self.thumbnailLoaderForUrl(url)
        }
        
        return trySequenceOfAsyncsArray(loaders)
    }
    
    public func resetCache() {
        
        imagesByUrl.removeAllObjects()
    }
    
    private func cachedInDBImageDataLoaderForUrl(url: NSURL) -> AsyncTypes<UIImage, NSError>.Async {
        
        let dataLoaderForIdentifier = { (url: NSURL) -> AsyncTypes<(NSHTTPURLResponse, NSData), NSError>.Async in
            
            let dataLoader = perkyURLResponseLoader(url, postData: nil, headers: nil)
            return dataLoader
        }
        
        let cacheKeyForIdentifier = { (loadDataIdentifier: NSURL) -> String in
            
            return loadDataIdentifier.absoluteString
        }
        
        let args = JSmartDataLoaderFields(
            loadDataIdentifier        : url                       ,
            dataLoaderForIdentifier   : dataLoaderForIdentifier   ,
            analyzerForData           : imageDataToUIImageBinder(),
            cacheKeyForIdentifier     : cacheKeyForIdentifier     ,
            ignoreFreshDataLoadFail   : true                      ,
            cache                     : createImageCacheAdapter() ,
            cacheDataLifeTimeInSeconds: self.dynamicType.cacheDataLifeTimeInSeconds
        )
        
        let loader = jSmartDataLoaderWithCache(args)
        
        return bindTrySequenceOfAsyncs(loader, { (error: NSError) -> AsyncTypes<UIImage, NSError>.Async in
            
            let resultError = JCacheLoadImageError(nativeError: error)
            return async(error: resultError)
        })
    }
    
    private class var cacheDataLifeTimeInSeconds: NSTimeInterval {
        
        let dbInfoByNames = Caches.sharedCaches().dbInfo.dbInfoByNames
        let info = dbInfoByNames.infoByDBName(Caches.thumbnailDBName())!
        return info.timeToLiveInHours * 3600.0
    }
    
    private class ImageCacheAdapter : CacheAdapter {
        
        init() {
            
            let cacheFactory = { () -> JCacheDB in
                return Caches.sharedCaches().createThumbnailDB()
            }
            
            super.init(cacheFactory: cacheFactory, cacheQueueName: cacheQueueName)
        }
        
        override func loaderToSetData(data: NSData, forKey key: String) -> AsyncTypes<Void, NSError>.Async {
            
            let loader = super.loaderToSetData(data, forKey:key)
            return Transformer.transformLoadersType1(loader, transformer: balanced)
        }
        
        override func cachedDataLoaderForKey(key: String) -> AsyncTypes<(NSDate, NSData), NSError>.Async {
            
            let loader = super.cachedDataLoaderForKey(key)
            return Transformer.transformLoadersType2(loader, transformer: balanced)
        }
    }
    
    private func createImageCacheAdapter() -> ImageCacheAdapter {
        
        let result = ImageCacheAdapter()
        return result
    }
    
    public func onMemoryWarning(notification: NSNotification) {
        
        resetCache()
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
}

//TODO try to use NSURLCache
private func imageDataToUIImageBinder() -> JSmartDataLoaderFields<NSURL, UIImage, NSHTTPURLResponse>.JAsyncBinderForIdentifier
{
    return { (url: NSURL) -> AsyncTypes2<(DataRequestContext<NSHTTPURLResponse>, NSData), UIImage, NSError>.AsyncBinder in
        
        return { (imageData: (DataRequestContext<NSHTTPURLResponse>, NSData)) -> AsyncTypes<UIImage, NSError>.Async in
            
            return async(job:{ () -> AsyncResult<UIImage, NSError> in
                
                let image = UIImage(data: imageData.1)
                
                if let image = image {
                    return AsyncResult.success(image)
                }
                
                let error = CanNotCreateImageError(url: url)
                return AsyncResult.failure(error)
            })
        }
    }
}

private typealias Transformer = AsyncTypesTransform<Void, (NSDate, NSData), NSError>

//limit sqlite number of threads
private let cacheBalancer = LimitedLoadersQueue<JStrategyFifo<Transformer.PackedType, NSError>>()

private func balanced(loader: AsyncTypes<Transformer.PackedType, NSError>.Async) -> AsyncTypes<Transformer.PackedType, NSError>.Async
{
    return cacheBalancer.balancedLoaderWithLoader(loader, barrier:false)
}
