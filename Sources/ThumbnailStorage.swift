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

import enum ReactiveKit.Result
import protocol ReactiveKit.Disposable

import UIKit

//alternatives:
//1 - https://github.com/rs/SDWebImage

private let cacheQueueName = "com.embedded_sources.cache.thumbnail_storage.cache"

private let noDataUrlStr = "nodata://embedded.cache.com"

public extension URL {

    public static var noImageDataURL: URL {
        struct Static {
            static let instance = URL(string: noDataUrlStr)!
        }
        return Static.instance
    }

    public var isNoImageDataURL: Bool {
        return self.absoluteString == noDataUrlStr
    }
}

public var thumbnailStorage = ThumbnailStorage()

final public class ThumbnailStorage {

    fileprivate init() {

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(ThumbnailStorage.onMemoryWarning(_:)),
            name    : NSNotification.Name.UIApplicationDidReceiveMemoryWarning,
            object  : nil)
    }

    fileprivate let cachedAsyncOp2 = MergedAsyncStream<URL, Data, AnyObject, ErrorWithContext>()
    fileprivate let cachedAsyncOp  = MergedAsyncStream<URL, UIImage, AnyObject, ErrorWithContext>()
    fileprivate let imagesByUrl    = NSCache<NSURL, UIImage>()

    public typealias AsyncT = AsyncStream<UIImage, AnyObject, ErrorWithContext>

    public func putToCache(data: Data, key: String) -> AsyncStream<Void, AnyObject, ErrorWithContext> {

        return createImageCacheAdapter().loaderToSet(data: data, forKey: key)
    }

    public func imageDataStreamFor(url: URL?) -> AsyncStream<Data, AnyObject, ErrorWithContext> {

        guard let url = url , !url.isNoImageDataURL else {
            let contextError = ErrorWithContext(error: CacheNoURLError(), context: #function)
            return AsyncStream.failed(with: contextError)
        }

        let stream: AsyncStream<Data, AnyObject, ErrorWithContext> = AsyncStream { observer -> Disposable in

            let cachedStream = self.cachedInDBImageDataStreamFor(url: url).map { $0.1 }

            let stream = self.cachedAsyncOp2.mergedStream({ cachedStream }, key: url)

            return stream.observe(observer)
        }

        return stream.logError()
    }

    public func imageStreamFor(url: URL?) -> AsyncStream<UIImage, AnyObject, ErrorWithContext> {

        guard let url = url , !url.isNoImageDataURL else {
            let contextError = ErrorWithContext(error: CacheNoURLError(), context: #function)
            return AsyncStream.failed(with: contextError)
        }

        let stream: AsyncT = AsyncT { observer -> Disposable in

            let cachedStream = self.cachedInDBImageDataStreamFor(url: url).map { $0.0 }

            let stream = self.cachedAsyncOp.mergedStream({ cachedStream }, key: url, getter: { () -> AsyncEvent<UIImage, AnyObject, ErrorWithContext>? in
                if let image = self.imagesByUrl.object(forKey: url as NSURL) {
                    return .success(image)
                }
                return nil
            }, setter: { event in
                switch event {
                case .success(let value):
                    self.imagesByUrl.setObject(value, forKey: url as NSURL)
                default:
                    break
                }
            })

            return stream.observe(observer)
        }

        return stream.logError()
    }

    public func resetCache() {

        imagesByUrl.removeAllObjects()
    }

    fileprivate func cachedInDBImageDataStreamFor(url: URL) -> AsyncStream<(UIImage, Data), AnyObject, ErrorWithContext> {

        let dataStream = network.dataStreamWith(url: url).mapNext { info -> AnyObject in
            switch info {
            case .download(let chunk):
                return chunk
            case .upload(let chunk):
                return chunk
            }
        }.map { ($0.response, $0.responseData) }

        let args = SmartDataStreamFields(
            dataStream     : dataStream                   ,
            analyzerForData: imageDataToUIImageBinderFor(url: url),
            cacheKey       : url.absoluteString           ,
            cache          : createImageCacheAdapter()    ,
            strategy       : .cacheFirst(type(of: self).cacheDataLifeTimeInSeconds))

        let stream = jSmartDataStreamWith(cacheArgs: args).fixAndLogError()
        return stream.mapError { ErrorWithContext(error: CacheLoadImageError(nativeError: $0.error), context: "\($0.context)" + " + " + #function) }
    }

    fileprivate static var cacheDataLifeTimeInSeconds: TimeInterval {

        let dbInfoByNames = Caches.sharedCaches().dbInfo.dbInfoByNames
        let info = dbInfoByNames.infoBy(dbName: Caches.thumbnailDBName())!
        return info.timeToLiveInHours * 3600.0
    }

    final fileprivate class ImageCacheAdapter : CacheAdapter {

        init() {

            let cacheFactory = { () -> CacheDB in
                return Caches.sharedCaches().createThumbnailDBFor(dbInfo: nil)
            }

            super.init(cacheFactory: cacheFactory, cacheQueueName: cacheQueueName)
        }

        override func loaderToSet(data: Data, forKey key: String) -> AsyncStream<Void, AnyObject, ErrorWithContext> {

            let stream = super.loaderToSet(data: data, forKey:key)
            return Transformer.transform(stream: stream, transformer: balanced)
        }

        override func cachedDataStreamFor(key: String) -> AsyncStream<(date: Date, data: Data), AnyObject, ErrorWithContext> {

            let stream = super.cachedDataStreamFor(key: key)
            return Transformer.transform(stream: stream, transformer: balanced)
        }
    }

    fileprivate func createImageCacheAdapter() -> ImageCacheAdapter {

        let result = ImageCacheAdapter()
        return result
    }

    @objc public func onMemoryWarning(_ notification: Notification) {

        resetCache()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

//TODO try to use NSURLCache?
//example - https://github.com/Alamofire/AlamofireImage
private func imageDataToUIImageBinderFor(url: URL) -> SmartDataStreamFields<(UIImage, Data), HTTPURLResponse>.AnalyzerType {

    return { imageData -> AsyncStream<(UIImage, Data), AnyObject, ErrorWithContext> in

        return asyncStreamWithJob { _ -> Result<(UIImage, Data), ErrorWithContext> in

            let image = UIImage.safeThreadImageWith(data: imageData.1)

            if let image = image {
                return .success((image, imageData.1))
            }

            let error = CanNotCreateImageError(url: url)
            let contextError = ErrorWithContext(error: error, context: #function)
            return .failure(contextError)
        }
    }
}

extension UIImage {

    static func safeThreadImageWith(data: Data) -> UIImage? {

        final class Singleton  {
            static let sharedInstance = NSLock()
        }

        Singleton.sharedInstance.lock()
        let result = UIImage(data: data)
        Singleton.sharedInstance.unlock()
        return result
    }
}

private typealias Transformer = AsyncStreamTypesTransform<Void, (date: Date, data: Data), AnyObject, AnyObject, ErrorWithContext, ErrorWithContext>

//limit sqlite number of threads
private let cacheBalancer = LimitedAsyncStreamsQueue<StrategyFifo<Transformer.PackedValueT, Transformer.PackedNextT, Transformer.PackedErrorT>>()

private func balanced(stream: Transformer.PackedAsyncStream) -> Transformer.PackedAsyncStream {

    return cacheBalancer.balancedStream(stream, barrier:false)
}
