//
//  CacheAdapter.swift
//  iAsync_cache
//
//  Created by Vladimir Gorbenko on 05.08.14.
//  Copyright © 2014 EmbeddedSources. All rights reserved.
//

import Foundation

import iAsync_utils
import iAsync_restkit
import struct iAsync_reactiveKit.AsyncStream
import func iAsync_reactiveKit.asyncStreamWithJob

import enum ReactiveKit.Result

public typealias CacheFactory = () -> CacheDB

public class NoCacheDataError : SilentError {

    init(key: String) {
        let description = "no cached data for key: \(key)"
        super.init(description: description)
    }

    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

open class CacheAdapter : AsyncRestKitCache {

    fileprivate let cacheFactory  : CacheFactory
    fileprivate let cacheQueueName: String

    public init(cacheFactory: @escaping CacheFactory, cacheQueueName: String) {

        self.cacheQueueName = cacheQueueName
        self.cacheFactory   = cacheFactory
    }

    public func loaderToSet(data: Data, forKey key: String) -> AsyncStream<Void, AnyObject, ErrorWithContext> {

        return asyncStreamWithJob(cacheQueueName, job: { _ -> Result<Void, ErrorWithContext> in

            self.cacheFactory().set(data: data, forKey:key)
            return .success(())
        })
    }

    public func cachedDataStreamFor(key: String) -> AsyncStream<(date: Date, data: Data), AnyObject, ErrorWithContext> {

        return asyncStreamWithJob(cacheQueueName, job: { _ -> Result<(date: Date, data: Data), ErrorWithContext> in

            let result = self.cacheFactory().dataAndLastUpdateDateFor(key: key)

            if let result = result {
                return .success((date: result.1, data: result.0))
            }

            let contextError = ErrorWithContext(error: NoCacheDataError(key: key), context: #function)
            return .failure(contextError)
        })
    }
}
