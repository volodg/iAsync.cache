//
//  JCacheAdapter.swift
//  JRestKit
//
//  Created by Vladimir Gorbenko on 05.08.14.
//  Copyright (c) 2014 EmbeddedSources. All rights reserved.
//

import Foundation

import iAsync_utils
import iAsync_restkit
import iAsync_async

public typealias JCacheFactory = () -> JCacheDB

public class JCacheAdapter : JAsyncRestKitCache {
    
    private let cacheFactory  : JCacheFactory
    private let cacheQueueName: String
    
    public init(cacheFactory: JCacheFactory, cacheQueueName: String) {
        
        self.cacheQueueName = cacheQueueName
        self.cacheFactory   = cacheFactory
    }
    
    public func loaderToSetData(data: NSData, forKey key: String) -> AsyncTypes<Void, NSError>.Async {
        
        return async(job: { () -> AsyncResult<Void, NSError> in
            
            self.cacheFactory().setData(data, forKey:key)
            return AsyncResult.success(())
        }, queueName: cacheQueueName)
    }
    
    public func cachedDataLoaderForKey(key: String) -> AsyncTypes<(NSDate, NSData), NSError>.Async {
    
        return async(job: { () -> AsyncResult<(NSDate, NSData), NSError> in
            
            let result = self.cacheFactory().dataAndLastUpdateDateForKey(key)
            
            if let result = result {
                return AsyncResult.success((result.1, result.0))
            }
            
            let description = "no cached data for key: \(key)"
            return AsyncResult.failure(Error(description:description))
        }, queueName: cacheQueueName)
    }
}
