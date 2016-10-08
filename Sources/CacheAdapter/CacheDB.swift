//
//  CacheDB.swift
//  iAsync_cache
//
//  Created by Vladimir Gorbenko on 22.09.14.
//  Copyright © 2014 EmbeddedSources. All rights reserved.
//

import Foundation

public protocol CacheDB {

    func dataForKey(_ key: String) -> Data?

    func dataAndLastUpdateDateForKey(_ key: String) -> (Data, Date)?

    func setData(_ data: Data?, forKey key: String)

    func removeRecordsForKey(_ key: String)

    func removeAllRecordsWithCallback(_ callback: (() -> Void)?)
}
