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

    public override func copyWithZone(zone: NSZone) -> AnyObject {

        return self.dynamicType.init(nativeError: nativeError)
    }

    override public var logTarget: Int {
        return nativeError.logTarget
    }

    override public var errorLogText: String {
        let result = "\(self.dynamicType) : \(localizedDescription), domain : \(domain) code : \(code) nativeError: \(nativeError.errorLog)"
        return result
    }
}
