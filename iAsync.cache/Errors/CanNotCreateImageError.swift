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

    fileprivate let url: URL

    public required init(url: URL) {

        self.url = url
        super.init(description: "can not create image with given data")
    }

    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /*swift3
     override public var errorLog: [String:String] {

        var result = super.errorLog
        result["RequestURL"] = url.description
        return result
    }*/
}

public extension LoggedObject where Self : CanNotCreateImageError {

    var logTarget: LogTarget { return LogTarget.logger }
}
