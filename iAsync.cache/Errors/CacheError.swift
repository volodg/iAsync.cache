//
//  CacheError.swift
//  iAsync_cache
//
//  Created by Vladimir Gorbenko on 22.09.14.
//  Copyright (c) 2014 EmbeddedSources. All rights reserved.
//

import Foundation

import iAsync_utils

public class CacheError : Error {
    
    public override class func iAsyncErrorsDomain() -> String {
        return "com.just_for_fun.cache.library"
    }
}