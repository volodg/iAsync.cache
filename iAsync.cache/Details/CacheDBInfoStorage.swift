//
//  CacheDBInfoStorage.swift
//  iAsync_cache
//
//  Created by Vladimir Gorbenko on 29.07.14.
//  Copyright © 2014 EmbeddedSources. All rights reserved.
//

import Foundation

import iAsync_utils

final public class CacheDBInfoStorage {

    internal let info: [String:CacheDBInfo]

    public func infoByDBName(_ dbName: String) -> CacheDBInfo? {

        return info[dbName]
    }

    init(plistInfo: NSDictionary) {

        var info: [String:CacheDBInfo] = [:]

        for (key, value) in plistInfo {
            if let keyStr = key as? String {
                if let plistInfo = value as? NSDictionary {
                    info[keyStr] = CacheDBInfo(plistInfo: plistInfo, dbPropertyName: keyStr)
                } else {
                    iAsync_utils_logger.logError("plistInfo: \(plistInfo) not a NSDictionary", context: #function)
                }
            } else {
                iAsync_utils_logger.logError("key: \(key) not a string", context: #function)
            }
        }

        self.info = info
    }
}
