//
//  AsyncStreamType+Additions.swift
//  iAsync_cache
//
//  Created by Gorbenko Vladimir on 18/02/16.
//  Copyright (c) 2016 EmbeddedSources. All rights reserved.
//

import Foundation

import iAsync_restkit
import iAsync_network
import iAsync_reactiveKit

public extension NSError {

    var canRepeateError: Bool {
        return self.isNetworkError
            || self is HttpError
            || self is JsonParserError
            || self is ParseJsonDataError
            || self is CanNotCreateImageError
    }
}

public extension AsyncStreamType where Self.Value == NetworkResponse, Self.Error == NSError {

    func toJson() -> AsyncStream<AnyObject, AnyObject, NSError> {

        let stream = self.mapNext2AnyObject()
        return stream.flatMap { JsonTools.jsonLoader($0.responseData, context: $0) }
    }
}

public extension AsyncStreamType where Error == NSError {

    public func withDefReconnect() -> AsyncStream<Value, Next, Error> {

        return self.retry(3, delay: 2.0, until: { result -> Bool in

            switch result {
            case .Success:
                return true
            case .Failure(let error):
                return !error.canRepeateError
            }
        })
    }

    public func fixAndLogError() -> AsyncStream<Value, Next, Error> {

        return withDefReconnect().logError()
    }
}
