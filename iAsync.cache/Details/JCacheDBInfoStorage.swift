//
//  JCacheDBInfoStorage.swift
//  iAsync_cache
//
//  Created by Vladimir Gorbenko on 29.07.14.
//  Copyright (c) 2014 EmbeddedSources. All rights reserved.
//

import Foundation

public class JCacheDBInfoStorage : NSObject {
    
    internal let info: [String:JCacheDBInfo]
    
    public func infoByDBName(dbName: String) -> JCacheDBInfo? {
        
        return info[dbName]
    }
    
    init(plistInfo: NSDictionary) {
        
        var info: [String:JCacheDBInfo] = [:]
        
        plistInfo.enumerateKeysAndObjectsUsingBlock( { (key: AnyObject!, value: AnyObject!, stop: UnsafeMutablePointer<ObjCBool>) -> () in
            
            let keyStr = key as! String
            info[keyStr] = JCacheDBInfo(plistInfo:value as! NSDictionary, dbPropertyName:keyStr)
        })
        
        self.info = info
    }
}
