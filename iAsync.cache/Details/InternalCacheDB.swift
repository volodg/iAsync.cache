//
//  InternalCacheDB.swift
//  iAsync_cache
//
//  Created by Vladimir Gorbenko on 13.08.14.
//  Copyright © 2014 EmbeddedSources. All rights reserved.
//

import Foundation

import iAsync_restkit
import iAsync_utils
import func iAsync_reactiveKit.asyncStreamWithJob

import enum ReactiveKit.Result

private var autoremoveSchedulersByCacheName: [String:iAsync_utils.Timer] = [:]

private let internalCacheDBLockObject = NSObject()

//TODO should be private?
final internal class InternalCacheDB : KeyValueDB, CacheDB {

    let cacheDBInfo: CacheDBInfo

    init(cacheDBInfo: CacheDBInfo) {

        self.cacheDBInfo = cacheDBInfo

        super.init(cacheFileName: cacheDBInfo.fileName)
    }

    fileprivate func removeOldData() {

        let removeRarelyAccessDataDelay = cacheDBInfo.autoRemoveByLastAccessDate

        if removeRarelyAccessDataDelay > 0.0 {

            let fromDate = Date().addingTimeInterval(-removeRarelyAccessDataDelay)

            removeRecordsToAccessDate(fromDate)
        }

        let bytes = Int64(cacheDBInfo.autoRemoveByMaxSizeInMB) * 1024 * 1024

        if bytes > 0 {
            removeRecordsWhileTotalSizeMoreThenBytes(bytes)
        }
    }

    func runAutoRemoveDataSchedulerIfNeeds() {

        synced(internalCacheDBLockObject, { () -> () in

            let dbPropertyName = self.cacheDBInfo.dbPropertyName

            if autoremoveSchedulersByCacheName[dbPropertyName] != nil {
                return
            }

            let timer = Timer()
            autoremoveSchedulersByCacheName[dbPropertyName] = timer

            let block = { (cancel: (() -> ())) in

                let loadDataBlock = { (progress: (AnyObject) -> Void) -> Result<Void, ErrorWithContext> in

                    self.removeOldData()
                    return .success(())
                }

                let queueName = "com.embedded_sources.dbcache.thread_to_remove_old_data"
                _ = asyncStreamWithJob(queueName, job: loadDataBlock).logError().run()
            }
            block({})

            let _ = timer.addBlock(block, delay:.seconds(3600))
        })
    }

    func migrateDB(_ dbInfo: DBInfo) {

        let currentDbInfo  = dbInfo.currentDbVersionsByName
        let currVersionNum = currentDbInfo?[cacheDBInfo.dbPropertyName] as? NSNumber

        guard let currVersionNum_ = currVersionNum else { return }

        let lastVersion    = cacheDBInfo.version
        let currentVersion = currVersionNum_.intValue

        if lastVersion > currentVersion {
            removeAllRecordsWithCallback(nil)
        }
    }
}
