//
//  ZLSearchManager.m
//  ZLFullTextSearch
//
//  Created by Zack Liston on 1/29/15.
//  Copyright (c) 2015 Zack Liston. All rights reserved.
//

#import "ZLSearchManager.h"
#import "ZLSearchDatabase.h"
#import "ZLSearchTaskWorker.h"
#import "ZLTaskManager.h"
#import "ZLInternalWorkItem.h"
#import "ZLSearchResult.h"

NSString *const kZLSearchIndexInfoDirectoryName = @"ZLSearchIndexInfo";

NSString *const kTaskTypeSearch = @"com.agilemd.tasktype.search";
NSInteger const kMajorPrioritySearch = 1000;
NSInteger const kMinorPrioritySearchIndexFile = 1000;
NSInteger const kMinorPrioritySearchRemoveFile = 10000;

NSString *const kZLSearchableStringWeight0 = @"weight0";
NSString *const kZLSearchableStringWeight1 = @"weight1";
NSString *const kZLSearchableStringWeight2 = @"weight2";
NSString *const kZLSearchableStringWeight3 = @"weight3";
NSString *const kZLSearchableStringWeight4 = @"weight4";

NSString *const kZLFileMetadataTitle = @"title";
NSString *const kZLFileMetadataSubtitle = @"subtitle";
NSString *const kZLFileMetadataURI = @"uri";
NSString *const kZLFileMetadataFileType = @"filetype";
NSString *const kZLFileMetadataImageURI = @"imageuri";

@interface ZLSearchManager ()

@property (nonatomic, strong) NSDictionary *searchDatabaseDictionary;

@end

@implementation ZLSearchManager

#pragma mark - Public Methods
#pragma mark Initialization

static ZLSearchManager *_sharedInstance;

#pragma mark - Initialization

static dispatch_once_t onceToken;
+ (ZLSearchManager *)sharedInstance
{
    dispatch_once(&onceToken, ^{
        _sharedInstance = [ZLSearchManager new];
        [self setupFileDirectories];
    });
    return _sharedInstance;
}

#pragma mark - Getters/Setters

- (ZLSearchDatabase *)searchDatabaseForName:(NSString *)searchDatabaseName
{
    if (!searchDatabaseName.length) {
        NSLog(@"Cannot get a searchDatabase with a nil name");
        return nil;
    }
    ZLSearchDatabase *database = [self.searchDatabaseDictionary objectForKey:searchDatabaseName];
    if (!database) {
        [self setupSearchDatabaseWithName:searchDatabaseName];
    }
    return [self.searchDatabaseDictionary objectForKey:searchDatabaseName];
}

#pragma mark - Setup

- (void)setupSearchDatabaseWithName:(NSString *)searchDatabaseName
{
    if (!searchDatabaseName.length) {
        NSLog(@"Cannot setup a searchDatabase with a nil name");
        return;
    }
    
    if (![self.searchDatabaseDictionary objectForKey:searchDatabaseName]) {
        ZLSearchDatabase *database = [[ZLSearchDatabase alloc] initWithDatabaseName:searchDatabaseName];
        if (self.searchDatabaseDictionary) {
            NSMutableDictionary *tempDictionary = [self.searchDatabaseDictionary mutableCopy];
            [tempDictionary setObject:database forKey:searchDatabaseName];
            self.searchDatabaseDictionary = [tempDictionary copy];
        } else {
            self.searchDatabaseDictionary = @{searchDatabaseName:database};
        }
    }
}


+ (void)setupFileDirectories
{
    NSString *cachesDirectory = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
    NSString *searchIndexInfoDirectory = [cachesDirectory stringByAppendingPathComponent:kZLSearchIndexInfoDirectoryName];
    
    NSError *createIndexInfoError;
    [[NSFileManager defaultManager] createDirectoryAtPath:searchIndexInfoDirectory withIntermediateDirectories:YES attributes:nil error:&createIndexInfoError];
    if (createIndexInfoError) {
        NSLog(@"Error creating directory for search index info in SearchManager %@", searchIndexInfoDirectory);
    }
}

#pragma mark - Getters/Setters

- (void)setSearchResultFavoriteDelegateForLocalSearchResults:(id<ZLSearchResultIsFavoritedProtocol>)delegate
{
    self.searchResultFavoriteDelegate = delegate;
}

#pragma mark Queueing Search Tasks

+ (NSString *)saveIndexFileInfoToFileWithModuleId:(NSString *)moduleId fileId:(NSString *)fileId language:(NSString *)language boost:(double)boost searchableStrings:(NSDictionary *)searchableStrings fileMetadata:(NSDictionary *)fileMetadata error:(NSError *__autoreleasing *)error
{
    // Check to see if there's any searchable text the user provided according to our described keys in ADSearchDatabase.h
    // If the dictionary is nil validSearchableText.length will be < 1 so we don't also have to check to see if the dictionary is nil
    BOOL hasValidSearchableText = NO;
    for (NSString *key in searchableStrings.allKeys) {
        if ([key isEqualToString:kZLSearchableStringWeight0] || [key isEqualToString:kZLSearchableStringWeight1] || [key isEqualToString:kZLSearchableStringWeight2] || [key isEqualToString:kZLSearchableStringWeight3] || [key isEqualToString:kZLSearchableStringWeight4]) {
            NSString *object = [searchableStrings objectForKey:key];
            if (object.length) {
                hasValidSearchableText = YES;
            }
        }
    }
    
    if (moduleId.length < 1 || fileId.length < 1 || language.length < 1 || !hasValidSearchableText) {
        if (error) {
            *error = [NSError errorWithDomain:@"Missing required fields" code:1 userInfo:nil];
        }
        return nil;
    }
    
    NSMutableDictionary *taskJsonData = [@{kZLSearchTWModuleIdKey:moduleId, kZLSearchTWEntityIdKey:fileId, kZLSearchTWLanguageKey:language, kZLSearchTWBoostKey:[NSNumber numberWithDouble:boost], kZLSearchTWSearchableStringsKey:searchableStrings} mutableCopy];
    
    // It is possible that no fileMetadata was provided.
    if (fileMetadata) {
        [taskJsonData setObject:fileMetadata forKey:kZLSearchTWFileMetadataKey];
    }
    
    NSString *relativeUrl = [ZLSearchManager relativeUrlForFileIndexInfoWithModuleId:moduleId fileId:fileId];
    NSString *absoluteUrl = [ZLSearchManager absoluteUrlForFileInfoFromRelativeUrl:relativeUrl];
    
    BOOL success = [NSKeyedArchiver archiveRootObject:taskJsonData toFile:absoluteUrl];
    if (!success) {
        if (error) {
            *error = [NSError errorWithDomain:@"Could not save file index data to file" code:1 userInfo:nil];
        }
        return nil;
    }
    
    return relativeUrl;
}

- (BOOL)queueIndexFileCollectionWithURLArray:(NSArray *)urlArray searchDatabaseName:(NSString *)searchDatabaseName
{
    if (!urlArray.count) {
        NSLog(@"Error in queueIndexFileCollection in searchManager. Url array contained no urls.");
        return NO;
    }
    if (!searchDatabaseName.length) {
        NSLog(@"You must provide a searchDatabase name in queueIndexFile...");
        return NO;
    }
    
    NSDictionary *jsonData = @{kZLSearchTWFileInfoUrlArrayKey:urlArray, kZLSearchTWActionTypeKey:[NSNumber numberWithInteger:ZLSearchTWActionTypeIndexFile], kZLSearchTWDatabaseNameKey:searchDatabaseName};
    ZLTask *task = [[ZLTask alloc] initWithTaskType:kTaskTypeSearch jsonData:jsonData];
    task.majorPriority = kMajorPrioritySearch;
    task.minorPriority = kMinorPrioritySearchIndexFile;
    task.requiresInternet = NO;
    task.shouldHoldAndRestartAfterMaxRetries = YES;
    
    
    return [[ZLTaskManager sharedInstance] queueTask:task];
}

- (BOOL)queueIndexFileWithModuleId:(NSString *)moduleId fileId:(NSString *)fileId language:(NSString *)language boost:(double)boost searchableStrings:(NSDictionary *)searchableStrings fileMetadata:(NSDictionary *)fileMetadata searchDatabaseName:(NSString *)searchDatabaseName
{
    NSError *saveError;
    NSString *fileLocation = [ZLSearchManager saveIndexFileInfoToFileWithModuleId:moduleId fileId:fileId language:language boost:boost searchableStrings:searchableStrings fileMetadata:fileMetadata error:&saveError];
    if (saveError) {
        NSLog(@"Error saving file info to disk in queueIndexFile(...) %@", saveError);
        return NO;
    }
    
    return [self queueIndexFileCollectionWithURLArray:@[fileLocation] searchDatabaseName:searchDatabaseName];
}

- (BOOL)queueRemoveFileWithModuleId:(NSString *)moduleId entityId:(NSString *)entityId searchDatabaseName:(NSString *)searchDatabaseName
{
    BOOL success = YES;
    
    if (moduleId.length < 1 || entityId.length < 1) {
        success = NO;
        return success;
    }
    
    if (!searchDatabaseName.length) {
        NSLog(@"You must provide a searchDatabase name in queueRemoveFile...");
        return NO;
    }

    
    NSDictionary *taskJsonData = @{kZLSearchTWModuleIdKey:moduleId, kZLSearchTWEntityIdKey:entityId, kZLSearchTWActionTypeKey:[NSNumber numberWithInteger:ZLSearchTWActionTypeRemoveFileFromIndex], kZLSearchTWDatabaseNameKey:searchDatabaseName};
    ZLTask *task = [[ZLTask alloc] initWithTaskType:kTaskTypeSearch jsonData:taskJsonData];
    task.requiresInternet = NO;
    task.majorPriority = kMajorPrioritySearch;
    task.minorPriority = kMinorPrioritySearchRemoveFile;
    task.shouldHoldAndRestartAfterMaxRetries = YES;
    
    success = [[ZLTaskManager sharedInstance] queueTask:task];
    
    return success;
}

#pragma mark Reset

- (BOOL)resetSearchDatabaseWithName:(NSString *)searchDatabaseName
{
    [[ZLTaskManager sharedInstance] stopAndWaitWithNetworkCancellationBlock:^{

    }];
    [[ZLTaskManager sharedInstance] removeTasksOfType:kTaskTypeSearch];
    
    [self moveThenDeleteFileInfoInBackground];
    [ZLSearchManager setupFileDirectories];
    
    [[ZLTaskManager sharedInstance] resume];
    ZLSearchDatabase *database = [self searchDatabaseForName:searchDatabaseName];
    
    return [database resetDatabase];
}

#pragma mark Search

- (BOOL)searchFilesWithSearchText:(NSString *)searchText limit:(NSUInteger)limit offset:(NSUInteger)offset searchDatabaseName:(NSString *)searchDatabaseName completionBlock:(ZLSearchCompletionBlock)completionBlock
{
    BOOL success = YES;
    if (limit < 1) {
        success = NO;
        return success;
    }
    
    searchText = [ZLSearchDatabase searchableStringFromString:searchText];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        ZLSearchDatabase *database = [self searchDatabaseForName:searchDatabaseName];
        
        NSError *error;
        NSArray *searchSuggestions;
        NSArray *results = [database searchFilesWithSearchText:searchText limit:limit offset:offset preferPhraseSearching:YES searchSuggestions:&searchSuggestions error:&error];
        
        if (results.count) {
            [results makeObjectsPerformSelector:@selector(setFavoriteDelegate:) withObject:self.searchResultFavoriteDelegate];
        } else {
            results = [self.backupSearchDelegate backupSearchResultsForSearchText:searchText limit:limit offset:offset];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                NSLog(@"Error searching in ADSearchManager %@", error);
                completionBlock(nil, nil, error);
            } else {
                completionBlock(results, searchSuggestions, nil);
            }
        });
    });
    
    return success;
}

- (BOOL)searchFilesWithSearchText:(NSString *)searchText limit:(NSUInteger)limit offset:(NSUInteger)offset searchDatabaseName:(NSString *)searchDatabaseName completionBlock:(ZLSearchCompletionBlock)completionBlock remoteSearchCompletionBlock:(ZLSearchCompletionBlock)remoteSearchCompletionBlock
{
    BOOL localSuccess = [self searchFilesWithSearchText:searchText limit:limit offset:offset searchDatabaseName:searchDatabaseName completionBlock:completionBlock];
    BOOL remoteSuccess = [self.remoteSearchDelegate remoteSearchWithSearchText:searchText limit:limit offset:offset completionBlock:remoteSearchCompletionBlock];
    
    return (localSuccess && remoteSuccess);
}

#pragma mark - Helpers

+ (NSString *)relativeUrlForFileIndexInfoWithModuleId:(NSString *)moduleId fileId:(NSString *)fileId
{
    if (!moduleId.length || !fileId.length) {
        return nil;
    }
    
    return [NSString stringWithFormat:@"%@/%@.%@.json", kZLSearchIndexInfoDirectoryName, moduleId,fileId];
}

+ (NSString *)absoluteUrlForFileInfoFromRelativeUrl:(NSString *)relativeUrl
{
    NSString *cachesDirectory = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
    return [NSString stringWithFormat:@"%@/%@", cachesDirectory, relativeUrl];
}

- (BOOL)moveThenDeleteFileInfoInBackground
{
    BOOL success = YES;
    NSString *cachesDirectory = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
    NSString *path = [NSString stringWithFormat:@"%@/%@", cachesDirectory, kZLSearchIndexInfoDirectoryName];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
        __block NSString *filename = [[path componentsSeparatedByString:@"/"] lastObject];
        NSString *tmpPath = [NSString stringWithFormat:@"%@%@", NSTemporaryDirectory(), filename];
        NSError *error;
        [[NSFileManager defaultManager] moveItemAtPath:path toPath:tmpPath error:&error];
        if (error) {
            NSLog(@"Error moving item from %@ to %@ %@", path, tmpPath, error);
            success = NO;
        }
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
            NSFileManager *manager = [NSFileManager new];
            NSError *removeError;
            [manager removeItemAtPath:tmpPath error:&removeError];
            if (removeError) {
                NSLog(@"Error removing file at path %@ %@", tmpPath, removeError);
            }
        });
    }
    
    return success;
}

#pragma mark - Private Methods
#pragma mark ZLManager Methods

- (ZLTaskWorker *)taskWorkerForWorkItem:(ZLInternalWorkItem *)workItem
{
    ZLTaskWorker *worker;
    
    if ([workItem.taskType isEqualToString:kTaskTypeSearch]) {
        ZLSearchTaskWorker *searchWorker = [[ZLSearchTaskWorker alloc] init];
        searchWorker.delegate = self.searchTaskWorkerDelegate;
        worker = searchWorker;
        
    } else {
        NSLog(@"ADSearchManager asked to create an unsupported taskType %@", workItem.taskType);
        return nil;
    }
    [worker setupWithWorkItem:workItem];
    return worker;
}

#pragma mark - Teardown for Tests

+ (void)teardownForTests
{
    onceToken = 0;
}

@end
