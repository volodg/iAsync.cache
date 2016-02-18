//
//  CacheDBInfo.swift
//  iAsync_cache
//
//  Created by Vladimir Gorbenko on 31.07.14.
//  Copyright (c) 2014 EmbeddedSources. All rights reserved.
//

import Foundation

final public class CacheDBInfo : NSObject {

    public let dbPropertyName: String

    private let info: NSDictionary

    public var fileName: String {
        return info["fileName"]! as! String
    }

    public var version: Int {
        return info["version"]! as? Int ?? 0
    }

    public var timeToLiveInHours: NSTimeInterval {
        return info["timeToLiveInHours"] as? NSTimeInterval ?? 0.0
    }

    public var autoRemoveByLastAccessDate: NSTimeInterval {

        return (autoRemove?["lastAccessDateInHours"] as? NSTimeInterval).flatMap { $0 * 3600.0 } ?? 0.0
    }

    private var autoRemove: NSDictionary? {
        return info["autoRemove"] as? NSDictionary
    }

    public var autoRemoveByMaxSizeInMB: Double {

        return (autoRemove?["maxSizeInMB"] as? NSNumber).flatMap { $0.doubleValue } ?? 0.0
    }

    public init(plistInfo: NSDictionary, dbPropertyName: String) {

        self.info = plistInfo
        self.dbPropertyName = dbPropertyName
    }
}
