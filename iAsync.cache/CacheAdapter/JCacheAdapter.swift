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
    
    private let cacheFactory: JCacheFactory
    private let cacheQueueName: String
    
    public init(cacheFactory: JCacheFactory, cacheQueueName: String) {
        
        self.cacheQueueName = cacheQueueName
        self.cacheFactory   = cacheFactory
    }
    
    public func loaderToSetData(data: NSData, forKey key: String) -> AsyncTypes<NSNull, NSError>.Async {
        
        return asyncWithSyncOperationAndQueue({ () -> AsyncResult<NSNull, NSError> in
            
            self.cacheFactory().setData(data, forKey:key)
            return AsyncResult.success(NSNull())
        }, cacheQueueName)
    }
    
    public func cachedDataLoaderForKey(key: String) -> AsyncTypes<JRestKitCachedData, NSError>.Async {
    
        return asyncWithSyncOperationAndQueue({ () -> AsyncResult<JRestKitCachedData, NSError> in
            
            let result = self.cacheFactory().dataAndLastUpdateDateForKey(key)
            
            if let result = result {
                let result = JResponseDataWithUpdateData(data: result.0, updateDate: result.1)
                return AsyncResult.success(result)
            }
            
            let description = "no cached data for key: \(key)"
            return AsyncResult.failure(Error(description:description))
        }, cacheQueueName)
    }
}
