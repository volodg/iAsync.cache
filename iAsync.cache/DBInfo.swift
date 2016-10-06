//
//  DBInfo.swift
//  iAsync_cache
//
//  Created by Vladimir Gorbenko on 11.08.14.
//  Copyright © 2014 EmbeddedSources. All rights reserved.
//

import Foundation

import iAsync_utils

private var dbInfoOnce: Int = 0
private var dbInfoInstance: DBInfo!

final public class DBInfo {

    public let dbInfoByNames: CacheDBInfoStorage

    fileprivate var _currentDbVersionsByName: NSDictionary?
    var currentDbVersionsByName: NSDictionary? {

        if let result = _currentDbVersionsByName {
            return result
        }

        return synced(self, { () -> NSDictionary? in

            if let result = self._currentDbVersionsByName {
                return result
            }

            let path = DBInfo.currentDBInfoFilePath()
            let currentDbInfo = path.dictionaryContent()

            if let currentDbInfo = currentDbInfo , currentDbInfo.count > 0 {
                self._currentDbVersionsByName = currentDbInfo
            }
            return self._currentDbVersionsByName
        })
    }

    public init(infoPath: String) {

        let infoDictionary = NSDictionary(contentsOfFile: infoPath)
        dbInfoByNames = CacheDBInfoStorage(plistInfo: infoDictionary!)
    }

    init(infoDictionary: NSDictionary) {

        dbInfoByNames = CacheDBInfoStorage(plistInfo: infoDictionary)
    }

    internal static func defaultDBInfo() -> DBInfo {

        struct Static {
            static let instance = Static.createJDBInfo()

            fileprivate static func createJDBInfo() -> DBInfo {
                let bundle      = Bundle(for: DBInfo.self)
                let defaultPath = bundle.path(forResource: "JCacheDBInfo", ofType:"plist")
                return DBInfo(infoPath: defaultPath!)
            }
        }
        return Static.instance
    }

    func saveCurrentDBInfoVersions() {

        synced(self, { () -> () in

            let mutableCurrentVersions = NSMutableDictionary()

            for (key, info) in self.dbInfoByNames.info {
                mutableCurrentVersions[key] = info.version
            }

            let currentVersions = mutableCurrentVersions.copy() as! NSDictionary

            if let currentDbVersionsByName = self.currentDbVersionsByName {
                if currentDbVersionsByName.isEqual(currentVersions) {
                    return
                }
            }

            self._currentDbVersionsByName = currentVersions

            let path = DBInfo.currentDBInfoFilePath()
            _ = path.writeToFile(currentVersions)
            path.addSkipBackupAttribute()
        })
    }

    static func currentDBInfoFilePath() -> DocumentPath {
        return "JCurrentDBVersions.data".documentsPath
    }
}
