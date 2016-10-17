//
//  KeyValueDB.swift
//  iAsync_cache
//
//  Created by Vladimir Gorbenko on 11.08.14.
//  Copyright © 2014 EmbeddedSources. All rights reserved.
//

import Foundation

import let iAsync_utils.iAsync_utils_logger
import func iAsync_utils.dispatch_queue_get_or_create

private let createRecords =
"CREATE TABLE IF NOT EXISTS records ( " +
    "record_id TEXT primary key" +
    ", file_link varchar(100)" +
    ", update_time real" +
", access_time real );"

private extension String {

    //todo rename?
    func cacheDBFileLinkPathWithFolder(_ folder: String) -> String {

        let result = (folder as NSString).appendingPathComponent(self)
        return result
    }

    //todo rename?
    func cacheDBFileLinkRemoveFileWithFolder(_ folder: String) {

        let path = cacheDBFileLinkPathWithFolder(folder)
        do {
            try FileManager.default.removeItem(atPath: path)
        } catch {
            print("iAsync_utils.DBError: can not remove file: \(path)")
        }
    }

    //todo rename?
    func cacheDBFileLinkSaveData(_ data: Data, folder: String) {

        let path = cacheDBFileLinkPathWithFolder(folder)
        let url = URL(fileURLWithPath:path, isDirectory:false)
        try? data.write(to: url, options: [])
        path.addSkipBackupAttribute()
    }

    //todo rename?
    func cacheDBFileLinkDataWithFolder(_ folder: String) -> Data? {

        let path = cacheDBFileLinkPathWithFolder(folder)
        do {
            let result = try Data(contentsOf: URL(fileURLWithPath: path), options: .mappedIfSafe)
            return result
        } catch {
            return nil
        }
    }
}

//todo rename?
private func fileSizeForPath(_ path: String) -> Int64? {

    let fileDictionary: [FileAttributeKey : Any]?
    do {
        fileDictionary = try FileManager.default.attributesOfItem(atPath: path)
    } catch let error as NSError {
        iAsync_utils_logger.logError("no file attributes for file with path: \(path) error: \(error)", context: #function)
        fileDictionary = nil
    } catch _ {
        iAsync_utils_logger.logError("no file attributes for file with path: \(path)", context: #function)
        fileDictionary = nil
    }

    return (fileDictionary?[FileAttributeKey.size] as? NSNumber)?.int64Value
}

internal class KeyValueDB {

    private let cacheFileName: String

    private var _db: JSQLiteDB?
    private var db: JSQLiteDB {
        if let db = _db {

            return db
        }

        let db = JSQLiteDB(dbName: cacheFileName)

        _db = db

        db.dispatchQueue.async(flags: .barrier, execute: {
            _ = self.db.execQuery(createRecords)
            return ()
        })

        return db
    }

    init(cacheFileName: String) {

        self.cacheFileName = cacheFileName
    }

    func dataFor(key: String) -> Data? {

        let result = dataAndLastUpdateDateFor(key: key)
        return result?.0
    }

    func dataAndLastUpdateDateFor(key recordId: String) -> (Data, Date)? {

        let linkIndex: Int32 = 0
        let dateIndex: Int32 = 1

        let query = "SELECT file_link, update_time FROM records WHERE record_id='\(recordId)';";

        var result: (Data, Date)?

        db.dispatchQueue.sync(execute: {

            //var statement: UnsafeMutablePointer<Void> = nil
            var statement: OpaquePointer? = nil

            if self.db.prepareQuery(query, statement:&statement) {
                if bridging_sqlite3_step(statement) == BRIDGING_SQLITE_ROW {

                    let str = bridging_sqlite3_column_text(statement, linkIndex)
                    let fileLink = String(cString: UnsafePointer<UInt8>(str!))
                    let data = fileLink.cacheDBFileLinkDataWithFolder(self.db.folder)

                    if let data = data {
                        let dateInetrval = bridging_sqlite3_column_double(statement, dateIndex)
                        let updateDate = Date(timeIntervalSince1970:dateInetrval)
                        result = (data, updateDate)
                    }
                }
                bridging_sqlite3_finalize(statement)
            }
        })

        if let result = result {
            updateAccessTime(recordId)
            return result
        }

        return nil
    }

    func set(data: Data?, forKey recordId: String) {

        let fileLink = fileLinkForRecordId(recordId)

        if let fileLink = fileLink {
            if let data = data {
                update(data: data, forRecord:recordId, fileLink:fileLink)
            } else {
                removeRecordsForRecordId(recordId, fileLink:fileLink)
            }
            return
        }

        if let data = data {
            addData(data, forRecord:recordId)
        }
    }

    private func update(data: Data, forRecord recordId: String, fileLink: String) {

        fileLink.cacheDBFileLinkSaveData(data, folder:self.db.folder)

        let updateQuery = "UPDATE records SET update_time='\(currentTime)', access_time='\(currentTime)' WHERE record_id='\(recordId)';"

        db.dispatchQueue.async(flags: .barrier, execute: {

            var statement: OpaquePointer? = nil
            if self.prepareQuery(updateQuery, statement:&statement) {
                if bridging_sqlite3_step(statement) != BRIDGING_SQLITE_DONE {
                    NSLog("\(updateQuery) - \(self.errorMessage)")
                }

                bridging_sqlite3_finalize(statement)
            }
        })
    }

    //todo rename?
    func removeRecordsToUpdateDate(_ date: Date) {

        removeRecordsToDate(date, dateFieldName:"update_time")
    }

    //todo rename?
    func removeRecordsToAccessDate(_ date: Date) {

        removeRecordsToDate(date, dateFieldName:"access_time")
    }

    func removeRecordsFor(key recordId: String) {

        if let fileLink = fileLinkForRecordId(recordId) {

            removeRecordsForRecordId(recordId, fileLink:fileLink)
        }
    }

    //todo rename?
    func removeRecordsWhileTotalSizeMoreThenBytes(_ sizeInBytes: Int64) {

        let selectQuery = "SELECT file_link FROM records ORDER BY access_time" //ORDER BY ASC is default

        db.dispatchQueue.async(flags: .barrier, execute: {

            let totalSize = self.folderSize()
            var filesRemoved: Int64 = 0

            if totalSize > sizeInBytes {

                var sizeToRemove = totalSize - sizeInBytes

                var statement: OpaquePointer? = nil

                let selectQuery2 = "\(selectQuery);"
                if self.db.prepareQuery(selectQuery2, statement:&statement) {

                    while bridging_sqlite3_step(statement) == BRIDGING_SQLITE_ROW && sizeToRemove > 0 {

                        autoreleasepool {

                            let str = bridging_sqlite3_column_text(statement, 0)
                            let fileLink = String(cString: UnsafePointer<UInt8>(str!))

                            //remove file
                            let filePath = fileLink.cacheDBFileLinkPathWithFolder(self.db.folder)
                            let fileSize = fileSizeForPath(filePath) ?? 0

                            filesRemoved += 1
                            if sizeToRemove > fileSize {
                                sizeToRemove -= fileSize
                            } else {
                                sizeToRemove = 0
                            }

                            do {
                                try FileManager.default.removeItem(atPath: filePath)
                            } catch {
                                print("iAsync_utils.DBError2: can not remove file: \(filePath)")
                            }
                        }
                    }
                    bridging_sqlite3_finalize(statement)
                }
            }

            //////////

            if filesRemoved > 0 {

                let removeQuery = "DELETE FROM records WHERE file_link IN (\(selectQuery) LIMIT \(filesRemoved));"

                var statement: OpaquePointer? = nil
                if self.prepareQuery(removeQuery, statement:&statement) {
                    if bridging_sqlite3_step(statement) != BRIDGING_SQLITE_DONE {
                        NSLog("\(removeQuery) - \(self.errorMessage)")
                    }

                    bridging_sqlite3_finalize(statement)
                }
            }
        })
    }

    func removeAllRecordsWith(callback: (() -> ())?) {

        ///First remove all files
        let query = "SELECT file_link FROM records;"

        db.dispatchQueue.async(flags: .barrier, execute: {

            var statement: OpaquePointer? = nil
            if self.db.prepareQuery(query, statement:&statement) {
                while bridging_sqlite3_step(statement) == BRIDGING_SQLITE_ROW {

                    autoreleasepool {

                        let str = bridging_sqlite3_column_text(statement, 0)
                        let fileLink = String(cString: UnsafePointer<UInt8>(str!))

                        //JTODO remove files in separate tread, do nont wait it
                        fileLink.cacheDBFileLinkRemoveFileWithFolder(self.db.folder)
                    }
                }
                bridging_sqlite3_finalize(statement)
            }

            // remove records in sqlite
            let removeQuery = "DELETE * FROM records;"

            if self.prepareQuery(removeQuery, statement:&statement) {
                if bridging_sqlite3_step(statement) != BRIDGING_SQLITE_DONE {
                    NSLog("\(removeQuery) - \(self.errorMessage)")
                }

                bridging_sqlite3_finalize(statement)
            }

            callback?()
        })
    }

    private var currentTime: TimeInterval {
        return Date().timeIntervalSince1970
    }

    //todo rename?
    private func execQuery(_ sql: String) -> Bool {
        return db.execQuery(sql)
    }

    //todo rename?
    private func prepareQuery(_ sql: String, statement: UnsafeMutablePointer<OpaquePointer?>) -> Bool {
        return db.prepareQuery(sql, statement: statement)
    }

    private var errorMessage: String? {
        return db.errorMessage
    }

    //todo rename?
    private func updateAccessTime(_ recordID: String) {

        db.dispatchQueue.async(flags: .barrier, execute: {
            _ = self.execQuery("UPDATE records SET access_time='\(self.currentTime)' WHERE record_id='\(recordID)';")
            return ()
        })
    }

    //todo rename?
    private func fileLinkForRecordId(_ recordId: String) -> String? {

        let query = "SELECT file_link FROM records WHERE record_id='\(recordId)';"

        var result: String?

        db.dispatchQueue.sync(execute: {

            var statement: OpaquePointer? = nil
            if self.db.prepareQuery(query, statement:&statement) {
                if bridging_sqlite3_step(statement) == BRIDGING_SQLITE_ROW {
                    let address = bridging_sqlite3_column_text(statement, 0)
                    result = String(cString: UnsafePointer<UInt8>(address!))
                }
                bridging_sqlite3_finalize(statement)
            }
        })

        return result
    }

    //todo rename?
    private func removeRecordsForRecordId(_ recordId: Any, fileLink: String) {

        fileLink.cacheDBFileLinkRemoveFileWithFolder(self.db.folder)

        let removeQuery = "DELETE FROM records WHERE record_id='\(recordId)';"

        db.dispatchQueue.async(flags: .barrier, execute: {

            var statement: OpaquePointer? = nil
            if self.prepareQuery(removeQuery, statement:&statement) {
                if bridging_sqlite3_step(statement) != BRIDGING_SQLITE_DONE {
                    NSLog("\(removeQuery) - \(self.errorMessage)")
                }

                bridging_sqlite3_finalize(statement)
            }
        })
    }

    //todo rename?
    private func addData(_ data: Data, forRecord recordId: String) {

        let fileLink = UUID().uuidString

        let addQuery = "INSERT INTO records (record_id, file_link, update_time, access_time) VALUES ('\(recordId)', '\(fileLink)', '\(currentTime)', '\(currentTime)');"

        db.dispatchQueue.async(flags: .barrier, execute: {

            var statement: OpaquePointer? = nil
            if self.prepareQuery(addQuery, statement:&statement) {
                if bridging_sqlite3_step(statement) == BRIDGING_SQLITE_DONE {
                    fileLink.cacheDBFileLinkSaveData(data, folder:self.db.folder)
                } else {
                    NSLog("\(addQuery) - \(self.errorMessage)")
                }

                bridging_sqlite3_finalize(statement)
            } else {
                NSLog("\(addQuery) - \(self.errorMessage)")
            }
        })
    }

    //JTODO test !!!!
    //todo rename?
    private func removeRecordsToDate(_ date: Date, dateFieldName fieldName: String) {

        ///First remove all files
        let query = "SELECT file_link FROM records WHERE \(fieldName) < '\(date.timeIntervalSince1970)';"

        db.dispatchQueue.async(flags: .barrier, execute: {

            var statement: OpaquePointer? = nil

            if self.db.prepareQuery(query, statement:&statement) {
                while bridging_sqlite3_step(statement) == BRIDGING_SQLITE_ROW {

                    autoreleasepool {

                        let str = bridging_sqlite3_column_text(statement, 0)
                        let fileLink = String(cString: UnsafePointer<UInt8>(str!))

                        fileLink.cacheDBFileLinkRemoveFileWithFolder(self.db.folder)
                    }
                }
                bridging_sqlite3_finalize(statement)
            }

            //////////

            let removeQuery = "DELETE FROM records WHERE \(fieldName) < '\(date.timeIntervalSince1970)';"

            var queryStatement: OpaquePointer? = nil

            if self.prepareQuery(removeQuery, statement:&queryStatement) {
                if bridging_sqlite3_step(queryStatement) != BRIDGING_SQLITE_DONE {
                    NSLog("\(removeQuery) - \(self.errorMessage)")
                }

                bridging_sqlite3_finalize(queryStatement)
            }
        })
    }

    private func folderSize() -> Int64 {

        let folderPath  = self.db.folder
        let fileManager = FileManager.default
        let filesEnumerator = fileManager.enumerator(atPath: folderPath)

        var fileSize: Int64 = 0

        if let filesEnumerator = filesEnumerator {

            while let fileName = filesEnumerator.nextObject() as? String {

                autoreleasepool {

                    let path = (folderPath as NSString).appendingPathComponent(fileName)
                    fileSize += fileSizeForPath(path) ?? 0
                }
            }
        }

        return fileSize
    }
}

//todo rename?
private func getOrCreateDispatchQueueForFile(_ file: String) -> DispatchQueue {

    let queueName = "com.embedded_sources.dynamic.\(file)"
    let result = dispatch_queue_get_or_create(label: queueName, attr: DispatchQueue.Attributes.concurrent)
    return result
}

final private class JSQLiteDB {

    private var db: OpaquePointer? = nil
    let dispatchQueue: DispatchQueue

    fileprivate let folder: String

    deinit {
        bridging_sqlite3_close(db)
    }

    init(dbName: String) {

        dispatchQueue = getOrCreateDispatchQueueForFile(dbName)

        let dbPath = dbName.documentsPath

        folder = dbPath.folder

        dispatchQueue.sync(flags: .barrier, execute: {

            let manager = FileManager.default

            if !manager.fileExists(atPath: self.folder) {

                do {
                    try manager.createDirectory(
                        atPath: self.folder,
                        withIntermediateDirectories: true,
                        attributes: nil)
                } catch {
                    iAsync_utils_logger.logError("unexpected system state 3", context: #function)
                }
            }

            let openResult = dbPath.path.withCString { cStr -> Bool in

                let result = bridging_sqlite3_open(cStr, &self.db) == BRIDGING_SQLITE_OK
                if !result {
                    print("open - \(self.errorMessage) path: \(dbPath)")
                }
                return result
            }

            if !openResult {
                assert(false)
                return
            }

            dbPath.addSkipBackupAttribute()

            let cacheSizePragma = "PRAGMA cache_size = 1000"

            let pragmaResult = cacheSizePragma.withCString { cStr in

                return bridging_sqlite3_exec(self.db, cStr, nil, nil, nil) == BRIDGING_SQLITE_OK
            }

            if !pragmaResult {
                NSLog("Error: failed to execute pragma statement: \(cacheSizePragma) with message '\(self.errorMessage)'.")
                //assert(false)
            }
        })
    }

    //todo rename?
    func prepareQuery(_ sql: String, statement: UnsafeMutablePointer<OpaquePointer?>) -> Bool {

        return sql.withCString { cStr in

            return bridging_sqlite3_prepare_v2(self.db, cStr, -1, statement, nil) == BRIDGING_SQLITE_OK
        }
    }

    //todo rename?
    func execQuery(_ sql: String) -> Bool {

        return sql.withCString { cStr in

            var errorMessage: UnsafeMutablePointer<Int8>? = nil

            if bridging_sqlite3_exec(self.db, cStr, nil, nil, &errorMessage) != BRIDGING_SQLITE_OK {

                let logStr = "\(sql) error: \(errorMessage)"
                NSLog(logStr)
                bridging_sqlite3_free(errorMessage)
                return false
            }

            return true
        }
    }

    var errorMessage: String? {
        return String(cString: bridging_sqlite3_errmsg(db))
    }
}
