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
import iAsync_utils
import struct iAsync_reactiveKit.AsyncStream
import class iAsync_reactiveKit.StrategyFifo
import class iAsync_reactiveKit.MergedAsyncStream
import class iAsync_reactiveKit.LimitedAsyncStreamsQueue
import enum iAsync_reactiveKit.AsyncEvent
import enum iAsync_reactiveKit.AsyncStreamTypesTransform
import func iAsync_reactiveKit.create
import func iAsync_reactiveKit.asyncStreamWithJob

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
            selector: "onMemoryWarning:",
            name    : UIApplicationDidReceiveMemoryWarningNotification,
            object  : nil)
    }

    private let cachedAsyncOp = MergedAsyncStream<NSURL, UIImage, AnyObject, NSError>()
    private let imagesByUrl   = NSCache()

    public typealias AsyncT = AsyncStream<UIImage, AnyObject, NSError>

    public func putToCachedData(data: NSData, key: String) -> AsyncStream<Void, AnyObject, NSError> {

        return createImageCacheAdapter().loaderToSetData(data, forKey: key)
    }

    public func thumbnailStreamForUrl(url: NSURL?) -> AsyncT {

        guard let url = url where !url.isNoImageDataURL else { return AsyncT.failed(with: CacheNoURLError()) }

        let stream: AsyncT = create(producer: { observer -> DisposableType? in

            let cachedStream = self.cachedInDBImageDataStreamForUrl(url)

            let stream = self.cachedAsyncOp.mergedStream({ cachedStream }, key: url, getter: { () -> AsyncEvent<UIImage, AnyObject, NSError>? in
                if let image = self.imagesByUrl.objectForKey(url) as? UIImage {
                    return .Success(image)
                }
                return nil
            }, setter: { event in
                switch event {
                case .Success(let value):
                    self.imagesByUrl.setObject(value, forKey: url)
                default:
                    break
                }
            })

            return stream.observe(on: nil, observer: observer)
        })

        return stream.logError()
    }

    public func resetCache() {

        imagesByUrl.removeAllObjects()
    }

    private func cachedInDBImageDataStreamForUrl(url: NSURL) -> AsyncT {

        let dataStream = network.dataStream(url, postData: nil, headers: nil).mapNext { info -> AnyObject in
            switch info {
            case .Download(let chunk):
                return chunk
            case .Upload(let chunk):
                return chunk
            }
        }.map { ($0.response, $0.responseData) }

        let args = SmartDataStreamFields(
            dataStream        : dataStream                   ,
            analyzerForData   : imageDataToUIImageBinder(url),
            cacheKey          : url.absoluteString           ,
            cache             : createImageCacheAdapter()    ,
            strategy          : .CacheFirst(self.dynamicType.cacheDataLifeTimeInSeconds)
        )

        let stream = jSmartDataStreamWithCache(args).fixAndLogError()
        return stream.mapError { CacheLoadImageError(nativeError: $0) }
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

        override func cachedDataStreamForKey(key: String) -> AsyncStream<(date: NSDate, data: NSData), AnyObject, NSError> {

            let stream = super.cachedDataStreamForKey(key)
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
private func imageDataToUIImageBinder(url: NSURL) -> SmartDataStreamFields<UIImage, NSHTTPURLResponse>.AnalyzerType {

    return { (imageData: (DataRequestContext<NSHTTPURLResponse>, NSData)) -> AsyncStream<UIImage, AnyObject, NSError> in

        return asyncStreamWithJob { _ -> Result<UIImage, NSError> in

            let image = UIImage.safeThreadImageWithData(imageData.1)

            if let image = image {
                return .Success(image)
            }

            let error = CanNotCreateImageError(url: url)
            return .Failure(error)
        }
    }
}

extension UIImage {

    static func safeThreadImageWithData(data: NSData) -> UIImage? {

        final class Singleton  {
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
