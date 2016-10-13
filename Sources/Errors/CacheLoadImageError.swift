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

    public let nativeError: UtilsError

    required public init(nativeError: UtilsError) {

        self.nativeError = nativeError
        super.init(description: "J_CACHE_LOAD_IMAGE_ERROR")
    }

    override open var logTarget: LogTarget {

        return nativeError.logTarget
    }

    override open var errorLogText: String {

        let result = "\(type(of: self)) : \(localizedDescription) nativeError: \(nativeError.errorLogText)"
        return result
    }

    override open var canRepeatError: Bool {

        return nativeError.canRepeatError || nativeError.isNetworkError
    }
}
