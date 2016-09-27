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

import ReactiveKit_old//???

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

public class CacheAdapter : AsyncRestKitCache {

    private let cacheFactory  : CacheFactory
    private let cacheQueueName: String

    public init(cacheFactory: CacheFactory, cacheQueueName: String) {

        self.cacheQueueName = cacheQueueName
        self.cacheFactory   = cacheFactory
    }

    public func loaderToSetData(data: NSData, forKey key: String) -> AsyncStream<Void, AnyObject, ErrorWithContext> {

        return asyncStreamWithJob(cacheQueueName, job: { _ -> Result<Void, ErrorWithContext> in

            self.cacheFactory().setData(data, forKey:key)
            return .Success(())
        })
    }

    public func cachedDataStreamForKey(key: String) -> AsyncStream<(date: NSDate, data: NSData), AnyObject, ErrorWithContext> {

        return asyncStreamWithJob(cacheQueueName, job: { _ -> Result<(date: NSDate, data: NSData), ErrorWithContext> in

            let result = self.cacheFactory().dataAndLastUpdateDateForKey(key)

            if let result = result {
                return .Success((date: result.1, data: result.0))
            }

            let contextError = ErrorWithContext(error: NoCacheDataError(key: key), context: #function)
            return .Failure(contextError)
        })
    }
}
