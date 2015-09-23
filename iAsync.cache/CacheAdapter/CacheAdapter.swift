//
//  CacheAdapter.swift
//  JRestKit
//
//  Created by Vladimir Gorbenko on 05.08.14.
//  Copyright (c) 2014 EmbeddedSources. All rights reserved.
//

import Foundation

import iAsync_utils
import iAsync_restkit
import iAsync_async

public typealias CacheFactory = () -> JCacheDB

public class CacheAdapter : AsyncRestKitCache {
    
    private let cacheFactory  : CacheFactory
    private let cacheQueueName: String
    
    public init(cacheFactory: CacheFactory, cacheQueueName: String) {
        
        self.cacheQueueName = cacheQueueName
        self.cacheFactory   = cacheFactory
    }
    
    public func loaderToSetData(data: NSData, forKey key: String) -> AsyncTypes<Void, NSError>.Async {
        
        return async(job: { () -> AsyncResult<Void, NSError> in
            
            self.cacheFactory().setData(data, forKey:key)
            return .Success(())
        }, queueName: cacheQueueName)
    }
    
    public func cachedDataLoaderForKey(key: String) -> AsyncTypes<(NSDate, NSData), NSError>.Async {
    
        return async(job: { () -> AsyncResult<(NSDate, NSData), NSError> in
            
            let result = self.cacheFactory().dataAndLastUpdateDateForKey(key)
            
            if let result = result {
                return .Success((result.1, result.0))
            }
            
            let description = "no cached data for key: \(key)"
            return .Failure(Error(description:description))
        }, queueName: cacheQueueName)
    }
}