//
//  CacheDBInfoStorage.swift
//  iAsync_cache
//
//  Created by Vladimir Gorbenko on 29.07.14.
//  Copyright (c) 2014 EmbeddedSources. All rights reserved.
//

import Foundation

final public class CacheDBInfoStorage {

    internal let info: [String:CacheDBInfo]

    public func infoByDBName(dbName: String) -> CacheDBInfo? {

        return info[dbName]
    }

    init(plistInfo: NSDictionary) {

        var info: [String:CacheDBInfo] = [:]

        for (key, value) in plistInfo {
            let keyStr = key as! String
            info[keyStr] = CacheDBInfo(plistInfo:value as! NSDictionary, dbPropertyName:keyStr)
        }

        self.info = info
    }
}
