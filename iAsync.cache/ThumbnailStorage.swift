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
import iAsync_reactiveKit

import ReactiveKit

import UIKit

//alternatives:
//1 - https://github.com/rs/SDWebImage

private let cacheQueueName = "com.embedded_sources.jffcache.thumbnail_storage.cache"

private let noDataUrlStr = "nodata://jff.cache.com"

public extension NSURL {

    public static var noImageDataURL: NSURL {
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

final public class ThumbnailStorage {

    private init() {

        NSNotificationCenter.defaultCenter().addObserver(
            self,
            selector: Selector("onMemoryWarning:"),
            name: UIApplicationDidReceiveMemoryWarningNotification,
            object: nil)
    }

    private let cachedAsyncOp = MergedAsyncStream<NSURL, UIImage, AnyObject, NSError>()
    private let imagesByUrl   = NSCache()

    public func thumbnailLoaderForUrl(url: NSURL?) -> AsyncTypes<UIImage, NSError>.Async {

        guard let url = url where !url.isNoImageDataURL else { return async(error: CacheNoURLError()) }

        let loader = { (
            progressCallback: AsyncProgressCallback?,
            doneCallback    : AsyncTypes<UIImage, NSError>.DidFinishAsyncCallback?) -> AsyncHandler in

            let imageLoader = self.cachedInDBImageDataLoaderForUrl(url)

            let stream = asyncToStream(imageLoader)

            let loader = self.cachedAsyncOp.mergedStream({ stream }, key: url, getter: { () -> AsyncEvent<UIImage, AnyObject, NSError>? in
                if let image = self.imagesByUrl.objectForKey(url) as? UIImage {
                    return .Success(image)
                }
                return nil
            }, setter: { event -> Void in
                switch event {
                case .Success(let value):
                    self.imagesByUrl.setObject(value, forKey: url)
                default:
                    break
                }
            }).toAsync()

            return loader(
                progressCallback: progressCallback,
                finishCallback  : doneCallback)
        }

        return logErrorForLoader(loader)
    }

    public func resetCache() {

        imagesByUrl.removeAllObjects()
    }

    private func cachedInDBImageDataLoaderForUrl(url: NSURL) -> AsyncTypes<UIImage, NSError>.Async {

        let dataLoaderForIdentifier = { (url: NSURL) -> AsyncTypes<(NSHTTPURLResponse, NSData), NSError>.Async in

            let dataLoader = network.dataStream(url, postData: nil, headers: nil).networkStreamToAsync()

            return bindSequenceOfAsyncs(dataLoader, { response -> AsyncTypes<(NSHTTPURLResponse, NSData), NSError>.Async in
                return async(value: (response.response, response.responseData))
            })
        }

        let cacheKeyForIdentifier = { (loadDataIdentifier: NSURL) -> String in

            return loadDataIdentifier.absoluteString
        }

        let args = SmartDataLoaderFields(
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

            let resultError = CacheLoadImageError(nativeError: error)
            return async(error: resultError)
        })
    }

    private static var cacheDataLifeTimeInSeconds: NSTimeInterval {

        let dbInfoByNames = Caches.sharedCaches().dbInfo.dbInfoByNames
        let info = dbInfoByNames.infoByDBName(Caches.thumbnailDBName())!
        return info.timeToLiveInHours * 3600.0
    }

    final private class ImageCacheAdapter : CacheAdapter {

        init() {

            let cacheFactory = { () -> CacheDB in
                return Caches.sharedCaches().createThumbnailDB()
            }

            super.init(cacheFactory: cacheFactory, cacheQueueName: cacheQueueName)
        }

        override func loaderToSetData(data: NSData, forKey key: String) -> AsyncStream<Void, AnyObject, NSError> {

            let stream = super.loaderToSetData(data, forKey:key)
            return Transformer.transformStreamsType(stream, transformer: balanced)
        }

        override func cachedDataLoaderForKey(key: String) -> AsyncStream<(date: NSDate, data: NSData), AnyObject, NSError> {

            let stream = super.cachedDataLoaderForKey(key)
            return Transformer.transformStreamsType(stream, transformer: balanced)
        }
    }

    private func createImageCacheAdapter() -> ImageCacheAdapter {

        let result = ImageCacheAdapter()
        return result
    }

    @objc public func onMemoryWarning(notification: NSNotification) {

        resetCache()
    }

    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
}

//TODO try to use NSURLCache?
//example - https://github.com/Alamofire/AlamofireImage
private func imageDataToUIImageBinder() -> SmartDataLoaderFields<NSURL, UIImage, NSHTTPURLResponse>.JAsyncBinderForIdentifier {

    return { (url: NSURL) -> AsyncTypes2<(DataRequestContext<NSHTTPURLResponse>, NSData), UIImage, NSError>.AsyncBinder in

        return { (imageData: (DataRequestContext<NSHTTPURLResponse>, NSData)) -> AsyncTypes<UIImage, NSError>.Async in

            return asyncStreamWithJob { (progress: AnyObject -> Void) -> Result<UIImage, NSError> in

                let image = UIImage.safeThreadImageWithData(imageData.1)

                if let image = image {
                    return .Success(image)
                }

                let error = CanNotCreateImageError(url: url)
                return .Failure(error)
            }.toAsync()
        }
    }
}

extension UIImage {

    static func safeThreadImageWithData(data: NSData) -> UIImage? {

        class Singleton  {
            static let sharedInstance = NSLock()
        }

        Singleton.sharedInstance.lock()
        let result = UIImage(data: data)
        Singleton.sharedInstance.unlock()
        return result
    }
}

private typealias Transformer = AsyncStreamTypesTransform<Void, (date: NSDate, data: NSData), AnyObject, AnyObject, NSError, NSError>

//limit sqlite number of threads
private let cacheBalancer = LimitedAsyncStreamsQueue<StrategyFifo<Transformer.PackedValueT, Transformer.PackedNextT, Transformer.PackedErrorT>>()

private func balanced(stream: Transformer.PackedAsyncStream) -> Transformer.PackedAsyncStream {

    return cacheBalancer.balancedStream(stream, barrier:false)
}
