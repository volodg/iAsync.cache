//
//  CacheDB.swift
//  iAsync_cache
//
//  Created by Vladimir Gorbenko on 22.09.14.
//  Copyright © 2014 EmbeddedSources. All rights reserved.
//

import Foundation

public protocol CacheDB {

    func dataFor(key: String) -> Data?

    func dataAndLastUpdateDateFor(key: String) -> (Data, Date)?

    func set(data: Data?, forKey key: String)

    func removeRecordsFor(key: String)

    func removeAllRecordsWith(callback: (() -> Void)?)
}
