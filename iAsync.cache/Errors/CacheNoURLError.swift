//
//  CacheNoURLError.swift
//  iAsync_cache
//
//  Created by Vladimir Gorbenko on 22.09.14.
//  Copyright © 2014 EmbeddedSources. All rights reserved.
//

import Foundation

import iAsync_utils

final public class CacheNoURLError : CacheError {

    override init() {

        let str = "iAsync_CACHE_NO_URL_ERROR"
        super.init(description: str)
    }

    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    //override public var logTarget: Int { return LogTarget.Nothing.rawValue }
}
