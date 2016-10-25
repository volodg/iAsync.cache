//
//  AsyncStreamType+CacheAdditions.swift
//  iAsync_cache
//
//  Created by Gorbenko Vladimir on 18/02/16.
//  Copyright © 2016 EmbeddedSources. All rights reserved.
//

import Foundation

import iAsync_utils
import iAsync_network
import iAsync_restkit
import iAsync_reactiveKit

public extension AsyncStreamType where ValueT == NetworkResponse, ErrorT == ErrorWithContext {

    func toJson() -> AsyncStream<Any, AnyObject, ErrorWithContext> {

        let stream = self.mapNext2AnyObject()
        return stream.flatMap { JsonTools.jsonStream(forData: $0.responseData, context: $0) }
    }
}

public extension AsyncStreamType where ErrorT == ErrorWithContext {

    public func fixWithDefReconnect() -> AsyncStream<ValueT, NextT, ErrorT> {

        return self.retry(3, delay: .seconds(2), until: { result -> Bool in

            switch result {
            case .success:
                return true
            case .failure(let error):
                return !(error.error.canRepeatError || error.error.isNetworkError)
            }
        })
    }

    public func fixAndLogError() -> AsyncStream<ValueT, NextT, ErrorT> {

        return fixWithDefReconnect().logError()
    }
}
