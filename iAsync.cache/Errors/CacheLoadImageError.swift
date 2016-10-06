//
//  CacheLoadImageError.swift
//  iAsync_cache
//
//  Created by Vladimir Gorbenko on 22.09.14.
//  Copyright © 2014 EmbeddedSources. All rights reserved.
//

import Foundation

import iAsync_utils

final public class CacheLoadImageError : CacheError {

    public let nativeError: NSError

    required public init(nativeError: NSError) {

        self.nativeError = nativeError
        super.init(description: "J_CACHE_LOAD_IMAGE_ERROR")
    }

    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

public extension LoggedObject where Self : CacheLoadImageError {

    var logTarget: LogTarget {

        if let obj = nativeError as? LoggedObject {
            return obj.logTarget
        }

        return LogTarget.nothing
    }

    var errorLogText: String {

        let errorLog = (nativeError as? LoggedObject)?.errorLogText ?? "\(nativeError)"

        let result = "\(type(of: self)) : \(localizedDescription), domain : \(domain) code : \(code) nativeError: \(errorLog)"
        return result
    }
}

extension CanRepeatError where Self : CacheLoadImageError {

    public var canRepeatError: Bool {

        if let error_ = nativeError as? CanRepeatError {
            return error_.canRepeatError
        }
        return false
    }
}
