//
//  CacheAdapter.swift
//  iAsync_cache
//
//  Created by Vladimir Gorbenko on 05.08.14.
//  Copyright (c) 2014 EmbeddedSources. All rights reserved.
//

import Foundation

import iAsync_utils
import iAsync_restkit
import iAsync_async
import iAsync_reactiveKit

import ReactiveKit

public typealias CacheFactory = () -> CacheDB

public class CacheAdapter : AsyncRestKitCache {

    private let cacheFactory  : CacheFactory
    private let cacheQueueName: String

    public init(cacheFactory: CacheFactory, cacheQueueName: String) {

        self.cacheQueueName = cacheQueueName
        self.cacheFactory   = cacheFactory
    }

    public func loaderToSetData(data: NSData, forKey key: String) -> AsyncTypes<Void, NSError>.Async {

        return asyncStreamWithJob(cacheQueueName, job: { (progress: AnyObject -> Void) -> Result<Void, NSError> in

            self.cacheFactory().setData(data, forKey:key)
            return .Success(())
        }).toAsync()
    }

    public func cachedDataLoaderForKey(key: String) -> AsyncTypes<(date: NSDate, data: NSData), NSError>.Async {

        return asyncStreamWithJob(cacheQueueName, job: { (progress: AnyObject -> Void) -> Result<(date: NSDate, data: NSData), NSError> in

            let result = self.cacheFactory().dataAndLastUpdateDateForKey(key)

            if let result = result {
                return .Success((date: result.1, data: result.0))
            }

            let description = "no cached data for key: \(key)"
            return .Failure(SilentError(description:description))
        }).toAsync()
    }
}
