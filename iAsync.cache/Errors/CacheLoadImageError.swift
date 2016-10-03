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

    override public var canRepeatError: Bool {
        return nativeError.canRepeatError
    }

    required public init(nativeError: NSError) {

        self.nativeError = nativeError
        super.init(description: "J_CACHE_LOAD_IMAGE_ERROR")
    }

    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /*override public var logTarget: Int {
        return nativeError.logTarget
    }

    override open var errorLogText: String {
        let result = "\(type(of: self)) : \(localizedDescription), domain : \(domain) code : \(code) nativeError: \(nativeError.errorLog)"
        return result
    }*/
}
