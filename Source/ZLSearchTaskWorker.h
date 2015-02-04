//
//  ZLSearchTaskWorker.h
//  ZLFullTextSearch
//
//  Created by Zack Liston on 1/29/15.
//  Copyright (c) 2015 Zack Liston. All rights reserved.
//

#import "ZLTaskWorker.h"
#import "ZLSearchTaskWorkerProtocol.h"

FOUNDATION_EXPORT NSString *const kZLSearchTWActionTypeKey;

FOUNDATION_EXPORT NSString *const kZLSearchTWFileInfoUrlArrayKey;

FOUNDATION_EXPORT NSString *const kZLSearchTWModuleIdKey;
FOUNDATION_EXPORT NSString *const kZLSearchTWEntityIdKey;
FOUNDATION_EXPORT NSString *const kZLSearchTWLanguageKey;
FOUNDATION_EXPORT NSString *const kZLSearchTWBoostKey;
FOUNDATION_EXPORT NSString *const kZLSearchTWSearchableStringsKey;
FOUNDATION_EXPORT NSString *const kZLSearchTWFileMetadataKey;
FOUNDATION_EXPORT NSString *const kZLSearchTWDatabaseNameKey;

@interface ZLSearchTaskWorker : ZLTaskWorker

@property (nonatomic, weak) id<ZLSearchTaskWorkerProtocol>delegate;

@end
