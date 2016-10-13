//
//  CanNotCreateImageError.swift
//  iAsync_cache
//
//  Created by Vladimir Gorbenko on 04.10.14.
//  Copyright © 2014 EmbeddedSources. All rights reserved.
//

import Foundation

import iAsync_utils

final public class CanNotCreateImageError : CacheError {

    private let url: URL

    public required init(url: URL) {

        self.url = url
        super.init(description: "can not create image with given data")
    }

    open override var errorLog: [String:String] {

        var result = super.errorLog
        result["RequestURL"] = url.description
        return result
    }

    open override var logTarget: LogTarget { return LogTarget.logger }
}
