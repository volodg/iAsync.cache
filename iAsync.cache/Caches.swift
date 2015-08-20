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

public class Caches : NSObject {
    
    public let dbInfo: DBInfo
    
    public class func sharedCaches() -> Caches {
        
        if let result = sharedCachesInstance {
            return result
        }
        
        let dbInfo = DBInfo.defaultDBInfo()
        let result = Caches(dbInfo:dbInfo)
        sharedCachesInstance = result
        
        return result
    }
    
    public class func setSharedCaches(caches: Caches) {
        
        sharedCachesInstance = caches
    }
    
    public init(dbInfo: DBInfo) {
        
        self.dbInfo = dbInfo
        super.init()
        self.setupCachesWithDBInfo()
    }
    
    public class func createCacheForName(name: String, dbInfo: DBInfo) -> JCacheDB {
        
        let cacheInfo = dbInfo.dbInfoByNames.infoByDBName(name)!
        
        return JInternalCacheDB(cacheDBInfo:cacheInfo)
    }
    
    func cacheByName(name: String) -> JCacheDB? {
        
        return cacheDbByName[name]
    }
    
    public class func thumbnailDBName() -> String {
        
        return "J_THUMBNAIL_DB"
    }
    
    func thumbnailDB() -> JCacheDB {
        
        return cacheByName(Caches.thumbnailDBName())!
    }
    
    class func createThumbnailDB(dbInfo: DBInfo) -> JCacheDB {
        
        return createCacheForName(Caches.thumbnailDBName(), dbInfo: dbInfo)
    }
    
    func createThumbnailDB(dbInfo: DBInfo? = nil) -> JCacheDB {
        
        return self.dynamicType.createCacheForName(Caches.thumbnailDBName(), dbInfo: dbInfo ?? self.dbInfo)
    }
    
    public func migrateDBs() {
        
        for (_, db) in cacheDbByName {
            
            db.migrateDB(dbInfo)
        }
        
        dbInfo.saveCurrentDBInfoVersions()
    }
    
    private var cacheDbByName: [String:JInternalCacheDB] = [:]
    
    private func registerAndCreateCacheDBWithName(dbPropertyName: String, cacheDBInfo: JCacheDBInfo) -> JCacheDB {
        
        if let result = self.cacheDbByName[dbPropertyName] {
            
            return result
        }
        
        let result = JInternalCacheDB(cacheDBInfo:cacheDBInfo)
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
