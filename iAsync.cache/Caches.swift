//
//  Caches.swift
//  iAsync_cache
//
//  Created by Vladimir Gorbenko on 13.08.14.
//  Copyright (c) 2014 EmbeddedSources. All rights reserved.
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
        let result = Caches(dbInfo:dbInfo)
        sharedCachesInstance = result
        
        return result
    }
    
    public static func setSharedCaches(caches: Caches) {
        
        sharedCachesInstance = caches
    }
    
    public init(dbInfo: DBInfo) {
        
        self.dbInfo = dbInfo
        self.setupCachesWithDBInfo()
    }
    
    public static func createCacheForName(name: String, dbInfo: DBInfo) -> CacheDB {
        
        let cacheInfo = dbInfo.dbInfoByNames.infoByDBName(name)!
        
        return InternalCacheDB(cacheDBInfo:cacheInfo)
    }
    
    func cacheByName(name: String) -> CacheDB? {
        
        return cacheDbByName[name]
    }
    
    public static func thumbnailDBName() -> String {
        
        return "J_THUMBNAIL_DB"
    }
    
    func thumbnailDB() -> CacheDB {
        
        return cacheByName(Caches.thumbnailDBName())!
    }
    
    static func createThumbnailDB(dbInfo: DBInfo) -> CacheDB {
        
        return createCacheForName(Caches.thumbnailDBName(), dbInfo: dbInfo)
    }
    
    func createThumbnailDB(dbInfo: DBInfo? = nil) -> CacheDB {
        
        return self.dynamicType.createCacheForName(Caches.thumbnailDBName(), dbInfo: dbInfo ?? self.dbInfo)
    }
    
    public func migrateDBs() {
        
        for (_, db) in cacheDbByName {
            
            db.migrateDB(dbInfo)
        }
        
        dbInfo.saveCurrentDBInfoVersions()
    }
    
    private var cacheDbByName: [String:InternalCacheDB] = [:]
    
    private func registerAndCreateCacheDBWithName(dbPropertyName: String, cacheDBInfo: CacheDBInfo) -> CacheDB {
        
        if let result = self.cacheDbByName[dbPropertyName] {
            return result
        }
        
        let result = InternalCacheDB(cacheDBInfo:cacheDBInfo)
        result.runAutoRemoveDataSchedulerIfNeeds()
        cacheDbByName[dbPropertyName] = result
        
        return result
    }
    
    private func setupCachesWithDBInfo() {
        
        for (dbName, dbInfo_) in dbInfo.dbInfoByNames.info {
            
            self.registerAndCreateCacheDBWithName(dbName, cacheDBInfo:dbInfo_)
        }
    }
}
