//
//  ThumbnailStorage.swift
//  iAsync_cache
//
//  Created by Vladimir Gorbenko on 22.09.14.
//  Copyright © 2014 EmbeddedSources. All rights reserved.
//

import Foundation

import iAsync_utils
import iAsync_network
import iAsync_restkit
import iAsync_reactiveKit

import ReactiveKit

import UIKit

//alternatives:
//1 - https://github.com/rs/SDWebImage

private let cacheQueueName = "com.embedded_sources.cache.thumbnail_storage.cache"

private let noDataUrlStr = "nodata://embedded.cache.com"

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
            selector: #selector(ThumbnailStorage.onMemoryWarning(_:)),
            name    : UIApplicationDidReceiveMemoryWarningNotification,
            object  : nil)
    }

    private let cachedAsyncOp2 = MergedAsyncStream<NSURL, NSData, AnyObject, ErrorWithContext>()
    private let cachedAsyncOp  = MergedAsyncStream<NSURL, UIImage, AnyObject, ErrorWithContext>()
    private let imagesByUrl    = NSCache()

    public typealias AsyncT = AsyncStream<UIImage, AnyObject, ErrorWithContext>

    public func putToCachedData(data: NSData, key: String) -> AsyncStream<Void, AnyObject, ErrorWithContext> {

        return createImageCacheAdapter().loaderToSetData(data, forKey: key)
    }

    public func imageDataStreamForUrl(url: NSURL?) -> AsyncStream<NSData, AnyObject, ErrorWithContext> {

        guard let url = url where !url.isNoImageDataURL else {
            let contextError = ErrorWithContext(error: CacheNoURLError(), context: #function)
            return AsyncStream.failed(with: contextError)
        }

        let stream: AsyncStream<NSData, AnyObject, ErrorWithContext> = create(producer: { observer -> DisposableType? in

            let cachedStream = self.cachedInDBImageDataStreamForUrl(url).map { $0.1 }

            let stream = self.cachedAsyncOp2.mergedStream({ cachedStream }, key: url)

            return stream.observe(on: nil, observer: observer)
        })

        return stream.logError()
    }

    public func imageStreamForUrl(url: NSURL?) -> AsyncStream<UIImage, AnyObject, ErrorWithContext> {

        guard let url = url where !url.isNoImageDataURL else {
            let contextError = ErrorWithContext(error: CacheNoURLError(), context: #function)
            return AsyncStream.failed(with: contextError)
        }

        let stream: AsyncT = create(producer: { observer -> DisposableType? in

            let cachedStream = self.cachedInDBImageDataStreamForUrl(url).map { $0.0 }

            let stream = self.cachedAsyncOp.mergedStream({ cachedStream }, key: url, getter: { () -> AsyncEvent<UIImage, AnyObject, ErrorWithContext>? in
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

    private func cachedInDBImageDataStreamForUrl(url: NSURL) -> AsyncStream<(UIImage, NSData), AnyObject, ErrorWithContext> {

        let dataStream = network.dataStream(url, postData: nil, headers: nil).mapNext { info -> AnyObject in
            switch info {
            case .Download(let chunk):
                return chunk
            case .Upload(let chunk):
                return chunk
            }
        }.map { ($0.response, $0.responseData) }

        let args = SmartDataStreamFields(
            dataStream     : dataStream                   ,
            analyzerForData: imageDataToUIImageBinder(url),
            cacheKey       : url.absoluteString           ,
            cache          : createImageCacheAdapter()    ,
            strategy       : .CacheFirst(self.dynamicType.cacheDataLifeTimeInSeconds))

        let stream = jSmartDataStreamWithCache(args).fixAndLogError()
        return stream.mapError { ErrorWithContext(error: CacheLoadImageError(nativeError: $0.error), context: "\($0.context)" + " + " + #function) }
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

        override func loaderToSetData(data: NSData, forKey key: String) -> AsyncStream<Void, AnyObject, ErrorWithContext> {

            let stream = super.loaderToSetData(data, forKey:key)
            return Transformer.transformStreamsType(stream, transformer: balanced)
        }

        override func cachedDataStreamForKey(key: String) -> AsyncStream<(date: NSDate, data: NSData), AnyObject, ErrorWithContext> {

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
private func imageDataToUIImageBinder(url: NSURL) -> SmartDataStreamFields<(UIImage, NSData), NSHTTPURLResponse>.AnalyzerType {

    return { imageData -> AsyncStream<(UIImage, NSData), AnyObject, ErrorWithContext> in

        return asyncStreamWithJob { _ -> Result<(UIImage, NSData), ErrorWithContext> in

            let image = UIImage.safeThreadImageWithData(imageData.1)

            if let image = image {
                return .Success((image, imageData.1))
            }

            let error = CanNotCreateImageError(url: url)
            let contextError = ErrorWithContext(error: error, context: #function)
            return .Failure(contextError)
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

private typealias Transformer = AsyncStreamTypesTransform<Void, (date: NSDate, data: NSData), AnyObject, AnyObject, ErrorWithContext, ErrorWithContext>

//limit sqlite number of threads
private let cacheBalancer = LimitedAsyncStreamsQueue<StrategyFifo<Transformer.PackedValueT, Transformer.PackedNextT, Transformer.PackedErrorT>>()

private func balanced(stream: Transformer.PackedAsyncStream) -> Transformer.PackedAsyncStream {

    return cacheBalancer.balancedStream(stream, barrier:false)
}
