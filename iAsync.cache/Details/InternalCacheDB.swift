//
//  InternalCacheDB.swift
//  iAsync_cache
//
//  Created by Vladimir Gorbenko on 13.08.14.
//  Copyright (c) 2014 EmbeddedSources. All rights reserved.
//

import Foundation

import iAsync_restkit
import iAsync_utils
import iAsync_reactiveKit

import ReactiveKit

private var autoremoveSchedulersByCacheName: [String:Timer] = [:]

private let internalCacheDBLockObject = NSObject()

//TODO should be private?
final internal class InternalCacheDB : KeyValueDB, CacheDB {

    let cacheDBInfo: CacheDBInfo

    init(cacheDBInfo: CacheDBInfo) {

        self.cacheDBInfo = cacheDBInfo

        super.init(cacheFileName:cacheDBInfo.fileName)
    }

    private func removeOldData() {

        let removeRarelyAccessDataDelay = cacheDBInfo.autoRemoveByLastAccessDate

        if removeRarelyAccessDataDelay > 0.0 {

            let fromDate = NSDate().dateByAddingTimeInterval(-removeRarelyAccessDataDelay)

            removeRecordsToAccessDate(fromDate)
        }

        let bytes = Int64(cacheDBInfo.autoRemoveByMaxSizeInMB) * 1024 * 1024

        if bytes > 0 {
            removeRecordsWhileTotalSizeMoreThenBytes(bytes)
        }
    }

    func runAutoRemoveDataSchedulerIfNeeds() {

        synced(internalCacheDBLockObject, { () -> () in

            if autoremoveSchedulersByCacheName[self.cacheDBInfo.dbPropertyName] != nil {
                return
            }

            let timer = Timer()
            autoremoveSchedulersByCacheName[self.cacheDBInfo.dbPropertyName] = timer

            let block = { (cancel: SimpleBlock) -> () in

                let loadDataBlock = { (progress: AnyObject -> Void) -> Result<NSNull, NSError> in

                    self.removeOldData()
                    return .Success(NSNull())
                }

                let queueName = "com.embedded_sources.dbcache.thread_to_remove_old_data"
                asyncStreamWithJob(queueName, job: loadDataBlock).on(failure: { error -> () in
                    error.writeErrorWithLogger()
                }).run()
            }
            block({})

            let _ = timer.addBlock(block, duration:3600.0, leeway:1800.0)
        })
    }

    //JTODO check using of migrateDB method when multithreaded
    func migrateDB(dbInfo: DBInfo) {

        let currentDbInfo = dbInfo.currentDbVersionsByName
        let currVersionNum   = currentDbInfo?[cacheDBInfo.dbPropertyName] as? NSNumber

        guard let currVersionNum_ = currVersionNum else { return }

        let lastVersion    = cacheDBInfo.version
        let currentVersion = currVersionNum_.integerValue

        if lastVersion > currentVersion {
            removeAllRecordsWithCallback(nil)
        }
    }
}
