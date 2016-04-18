//
//  AsyncStreamType+Additions.swift
//  iAsync_cache
//
//  Created by Gorbenko Vladimir on 18/02/16.
//  Copyright (c) 2016 EmbeddedSources. All rights reserved.
//

import Foundation

import iAsync_utils
import iAsync_restkit
import iAsync_network

import protocol iAsync_reactiveKit.AsyncStreamType
import struct iAsync_reactiveKit.AsyncStream

public extension NSError {

    var canRepeateError: Bool {
        return self.isNetworkError
            || self is HttpError
            || self is NSNoNetworkError
            || self is JsonParserError
            || self is ParseJsonDataError
            || self is CanNotCreateImageError
    }
}

public extension AsyncStreamType where Self.Value == NetworkResponse, Self.Error == ErrorWithContext {

    func toJson() -> AsyncStream<AnyObject, AnyObject, ErrorWithContext> {

        let stream = self.mapNext2AnyObject()
        return stream.flatMap { JsonTools.jsonStream($0.responseData, context: $0) }
    }
}

public extension AsyncStreamType where Error == ErrorWithContext {

    public func withDefReconnect() -> AsyncStream<Value, Next, Error> {

        return self.retry(3, delay: 2.0, until: { result -> Bool in

            switch result {
            case .Success:
                return true
            case .Failure(let error):
                return !error.error.canRepeateError
            }
        })
    }

    public func fixAndLogError() -> AsyncStream<Value, Next, Error> {

        return withDefReconnect().logError()
    }
}
