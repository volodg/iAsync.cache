//
//  DBInfo.swift
//  iAsync_cache
//
//  Created by Vladimir Gorbenko on 11.08.14.
//  Copyright (c) 2014 EmbeddedSources. All rights reserved.
//

import Foundation

import iAsync_utils

private var dbInfoOnce: dispatch_once_t = 0
private var dbInfoInstance: DBInfo!

final public class DBInfo {
    
    public let dbInfoByNames: JCacheDBInfoStorage
    
    private var _currentDbVersionsByName: NSDictionary?
    var currentDbVersionsByName: NSDictionary? {
            
        if let result = _currentDbVersionsByName {
            return result
        }
            
        return synced(self, { () -> NSDictionary? in
            if let result = self._currentDbVersionsByName {
                return result
            }
                
            let path = DBInfo.currentDBInfoFilePath()
            let currentDbInfo: NSDictionary? = NSDictionary(contentsOfFile:path)
                
            if let currentDbInfo = currentDbInfo {
                if currentDbInfo.count > 0 {
                    self._currentDbVersionsByName = currentDbInfo
                }
            }
            return self._currentDbVersionsByName
        })
    }
    
    public init(infoPath: String) {
        
        let infoDictionary = NSDictionary(contentsOfFile:infoPath)
        dbInfoByNames = JCacheDBInfoStorage(plistInfo:infoDictionary!)//TODO fix "!"
    }
    
    init(infoDictionary: NSDictionary) {
        
        dbInfoByNames = JCacheDBInfoStorage(plistInfo:infoDictionary)
    }
    
    //TODO internal?
    public static func defaultDBInfo() -> DBInfo {
        
        struct Static {
            static let instance = Static.createJDBInfo()
            
            private static func createJDBInfo() -> DBInfo {
                let bundle      = NSBundle(forClass: DBInfo.self)
                let defaultPath = bundle.pathForResource("JCacheDBInfo", ofType:"plist")
                return DBInfo(infoPath:defaultPath!)
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
            
            let currentVersions: NSDictionary = mutableCurrentVersions.copy() as! NSDictionary
            
            if let currentDbVersionsByName = self.currentDbVersionsByName {
                if currentDbVersionsByName.isEqual(currentVersions) {
                    return
                }
            }
            
            self._currentDbVersionsByName = currentVersions
            
            let path = DBInfo.currentDBInfoFilePath()
            currentVersions.writeToFile(path, atomically:true)
            path.addSkipBackupAttribute()
        })
    }
    
    static func currentDBInfoFilePath() -> String {
        return String.documentsPathByAppendingPathComponent("JCurrentDBVersions.data")
    }
}