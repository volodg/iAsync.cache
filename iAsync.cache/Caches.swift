//
//  Caches.swift
//  iAsync_cache
//
//  Created by Vladimir Gorbenko on 13.08.14.
//  Copyright © 2014 EmbeddedSources. All rights reserved.
//

import Foundation

import iAsync_restkit

private var sharedCachesInstance: Caches?

final public class Caches {

    public let dbInfo: DBInfo

    public static func sharedCaches() -> Caches {

        if let result = sharedCachesInstance {
            return result
        }

        let dbInfo = DBInfo.defaultDBInfo()
        let result = Caches(dbInfo: dbInfo)
        sharedCachesInstance = result

        return result
    }

    public static func setSharedCaches(_ caches: Caches) {

        sharedCachesInstance = caches
    }

    public init(dbInfo: DBInfo) {

        self.dbInfo = dbInfo
        self.setupCachesWithDBInfo()
    }

    public static func createCacheForName(_ name: String, dbInfo: DBInfo) -> CacheDB {

        let cacheInfo = dbInfo.dbInfoByNames.infoByDBName(name)!

        return InternalCacheDB(cacheDBInfo: cacheInfo)
    }

    func cacheByName(_ name: String) -> CacheDB? {

        return cacheDbByName[name]
    }

    public static func thumbnailDBName() -> String {

        return "J_THUMBNAIL_DB"
    }

    func thumbnailDB() -> CacheDB {

        return cacheByName(Caches.thumbnailDBName())!
    }

    static func createThumbnailDB(_ dbInfo: DBInfo) -> CacheDB {

        return createCacheForName(Caches.thumbnailDBName(), dbInfo: dbInfo)
    }

    func createThumbnailDB(_ dbInfo: DBInfo? = nil) -> CacheDB {

        return type(of: self).createCacheForName(Caches.thumbnailDBName(), dbInfo: dbInfo ?? self.dbInfo)
    }

    public func migrateDBs() {

        for (_, db) in cacheDbByName {

            db.migrateDB(dbInfo)
        }

        dbInfo.saveCurrentDBInfoVersions()
    }

    fileprivate var cacheDbByName: [String:InternalCacheDB] = [:]

    fileprivate func registerAndCreateCacheDBWithName(_ dbPropertyName: String, cacheDBInfo: CacheDBInfo) -> CacheDB {

        if let result = self.cacheDbByName[dbPropertyName] {
            return result
        }

        let result = InternalCacheDB(cacheDBInfo: cacheDBInfo)
        result.runAutoRemoveDataSchedulerIfNeeds()
        cacheDbByName[dbPropertyName] = result

        return result
    }

    fileprivate func setupCachesWithDBInfo() {

        for (dbName, dbInfo_) in dbInfo.dbInfoByNames.info {

            _ = self.registerAndCreateCacheDBWithName(dbName, cacheDBInfo:dbInfo_)
        }
    }
}
