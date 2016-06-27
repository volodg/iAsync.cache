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

    private let url: NSURL

    public required init(url: NSURL) {

        self.url = url
        super.init(description: "can not create image with given data")
    }

    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func copyWithZone(zone: NSZone) -> AnyObject {

        return self.dynamicType.init(url: url)
    }

    override public var logTarget: Int { return LogTarget.Logger.rawValue }

    override public var errorLog: NSDictionary {

        var result = super.errorLog as! [String:String]
        result["RequestURL"] = url.description
        return result
    }
}
