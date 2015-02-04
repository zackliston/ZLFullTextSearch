//
//  ZLSearchManager.h
//  ZLFullTextSearch
//
//  Created by Zack Liston on 1/29/15.
//  Copyright (c) 2015 Zack Liston. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ZLManager.h"
#import "ZLSearchResultIsFavoritedProtocol.h"
#import "ZLSearchBackupProtocol.h"
#import "ZLSearchTaskWorkerProtocol.h"

typedef NS_ENUM(NSInteger, ZLSearchTWActionType) {
    ZLSearchTWActionTypeIndexFile,
    ZLSearchTWActionTypeRemoveFileFromIndex
};

typedef void (^ZLSearchCompletionBlock)(NSArray *searchResults, NSArray *searchSuggestions, NSError *error);

FOUNDATION_EXPORT NSString *const kTaskTypeSearch;
FOUNDATION_EXPORT NSInteger const kMajorPrioritySearch;
FOUNDATION_EXPORT NSInteger const kMinorPrioritySearchIndexFile;
FOUNDATION_EXPORT NSInteger const kMinorPrioritySearchRemoveFile;

FOUNDATION_EXPORT NSString *const kZLSearchableStringWeight0;
FOUNDATION_EXPORT NSString *const kZLSearchableStringWeight1;
FOUNDATION_EXPORT NSString *const kZLSearchableStringWeight2;
FOUNDATION_EXPORT NSString *const kZLSearchableStringWeight3;
FOUNDATION_EXPORT NSString *const kZLSearchableStringWeight4;

FOUNDATION_EXPORT NSString *const kZLFileMetadataTitle;
FOUNDATION_EXPORT NSString *const kZLFileMetadataSubtitle;
FOUNDATION_EXPORT NSString *const kZLFileMetadataURI;
FOUNDATION_EXPORT NSString *const kZLFileMetadataFileType;
FOUNDATION_EXPORT NSString *const kZLFileMetadataImageURI;

@class ZLTask;
@class ZLSearchDatabase;
@interface ZLSearchManager : ZLManager

@property (nonatomic, weak) id<ZLSearchResultIsFavoritedProtocol>searchResultFavoriteDelegate;
@property (nonatomic, weak) id<ZLSearchBackupProtocol>backupSearchDelegate;
@property (nonatomic, weak) id<ZLSearchTaskWorkerProtocol>searchTaskWorkerDelegate;

+ (ZLSearchManager *)sharedInstance;
- (void)setupSearchDatabaseWithName:(NSString *)searchDatabaseName;
- (ZLSearchDatabase *)searchDatabaseForName:(NSString *)searchDatabaseName;

+ (NSString *)saveIndexFileInfoToFileWithModuleId:(NSString *)moduleId fileId:(NSString *)fileId language:(NSString *)language boost:(double)boost searchableStrings:(NSDictionary *)searchableStrings fileMetadata:(NSDictionary *)fileMetadata error:(NSError **)error;

- (BOOL)queueIndexFileCollectionWithURLArray:(NSArray *)urlArray searchDatabaseName:(NSString *)searchDatabaseName;
- (BOOL)queueIndexFileWithModuleId:(NSString *)moduleId fileId:(NSString *)fileId language:(NSString *)language boost:(double)boost searchableStrings:(NSDictionary *)searchableStrings fileMetadata:(NSDictionary *)fileMetadata searchDatabaseName:(NSString *)searchDatabaseName;
- (BOOL)queueRemoveFileWithModuleId:(NSString *)moduleId entityId:(NSString *)entityId searchDatabaseName:(NSString *)searchDatabaseName;
- (BOOL)resetSearchDatabaseWithName:(NSString *)searchDatabaseName;
- (BOOL)searchFilesWithSearchText:(NSString *)searchText limit:(NSUInteger)limit offset:(NSUInteger)offset completionBlock:(ZLSearchCompletionBlock)completionBlock searchDatabaseName:(NSString *)searchDatabaseName;

+ (NSString *)absoluteUrlForFileInfoFromRelativeUrl:(NSString *)relativeUrl;

@end