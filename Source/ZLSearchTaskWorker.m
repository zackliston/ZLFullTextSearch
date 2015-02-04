//
//  ZLSearchTaskWorker.m
//  ZLFullTextSearch
//
//  Created by Zack Liston on 1/29/15.
//  Copyright (c) 2015 Zack Liston. All rights reserved.
//

#import "ZLSearchTaskWorker.h"
#import "ZLSearchManager.h"
#import "ZLInternalWorkItem.h"
#import "ZLSearchDatabase.h"

NSString *const kZLSearchTWActionTypeKey = @"action";

NSString *const kZLSearchTWFileInfoUrlArrayKey = @"urlArray";

NSString *const kZLSearchTWModuleIdKey = @"moduleId";
NSString *const kZLSearchTWEntityIdKey = @"entityId";
NSString *const kZLSearchTWLanguageKey = @"language";
NSString *const kZLSearchTWBoostKey = @"boost";
NSString *const kZLSearchTWSearchableStringsKey = @"searchableStrings";
NSString *const kZLSearchTWFileMetadataKey = @"fileMetadata";
NSString *const kZLSearchTWDatabaseNameKey = @"databaseName";

@interface ZLSearchTaskWorker ()

@property (nonatomic, assign) ZLSearchTWActionType type;
@property (nonatomic, strong) NSArray *urlArray;
@property (nonatomic, strong) NSMutableArray *succeededIndexFileInfoDictionaries;
@property (nonatomic, strong) ZLSearchDatabase *searchDatabase;

@end

@implementation ZLSearchTaskWorker

#pragma mark - Getters/Setters

- (NSMutableArray *)succeededIndexFileInfoDictionaries
{
    if (!_succeededIndexFileInfoDictionaries) {
        _succeededIndexFileInfoDictionaries = [NSMutableArray new];
    }
    return _succeededIndexFileInfoDictionaries;
}

#pragma mark - Setup

- (void)setupWithWorkItem:(ZLInternalWorkItem *)workItem
{
    [super setupWithWorkItem:workItem];
    self.type = [[workItem.jsonData objectForKey:kZLSearchTWActionTypeKey] integerValue];
    self.urlArray = [workItem.jsonData objectForKey:kZLSearchTWFileInfoUrlArrayKey];
    
    NSString *searchDatabaseName = [workItem.jsonData objectForKey:kZLSearchTWDatabaseNameKey];
    self.searchDatabase = [[ZLSearchManager sharedInstance] searchDatabaseForName:searchDatabaseName];
}

#pragma mark - Main

- (void)main
{
    if (self.cancelled) {
        [self taskFinishedWasSuccessful:NO];
        return;
    }
    
    BOOL success = YES;
    
    if (self.type == ZLSearchTWActionTypeRemoveFileFromIndex) {
        NSString *moduleId = [self.workItem.jsonData objectForKey:kZLSearchTWModuleIdKey];
        NSString *fileId = [self.workItem.jsonData objectForKey:kZLSearchTWEntityIdKey];
        
        success = [self.searchDatabase removeFileWithModuleId:moduleId entityId:fileId];
        
    } else if (self.type == ZLSearchTWActionTypeIndexFile) {
        for (NSString *url in self.urlArray) {
            if (self.cancelled) {
                [self taskFinishedWasSuccessful:NO];
                return;
            }
            
            BOOL indexSuccess = [self indexFileFromUrl:url];
            if (!indexSuccess) {
                success = indexSuccess;
            }
        }
    }
    
    [self taskFinishedWasSuccessful:success];
}

- (BOOL)indexFileFromUrl:(NSString *)url
{
    @autoreleasepool {
        NSString *absoluteUrl = [ZLSearchManager absoluteUrlForFileInfoFromRelativeUrl:url];
        
        id object = [NSKeyedUnarchiver unarchiveObjectWithFile:absoluteUrl];
        if (![object isKindOfClass:[NSDictionary class]]) {
            NSLog(@"Error getting file index info from %@", absoluteUrl);
            return YES;
        }
        
        NSDictionary *jsonData = (NSDictionary *)object;
        NSString *moduleId = [jsonData objectForKey:kZLSearchTWModuleIdKey];
        NSString *entityId = [jsonData objectForKey:kZLSearchTWEntityIdKey];
        NSString *language = [jsonData objectForKey:kZLSearchTWLanguageKey];
        double boost = [[jsonData objectForKey:kZLSearchTWBoostKey] doubleValue];
        NSDictionary *searchableStrings = [jsonData objectForKey:kZLSearchTWSearchableStringsKey];
        NSDictionary *metadata = [jsonData objectForKey:kZLSearchTWFileMetadataKey];
        
        if (self.cancelled) {
            return NO;
        }
        NSDictionary *preparedSearchableStrings = [self preparedSearchStringsFromSearchableStrings:searchableStrings];
        
        if (self.cancelled) {
            return NO;
        }
        BOOL success = [self.searchDatabase indexFileWithModuleId:moduleId entityId:entityId language:language boost:boost searchableStrings:preparedSearchableStrings fileMetadata:metadata];
        if (success) {
            NSDictionary *fileInfo = @{kZLSearchTWModuleIdKey:moduleId, kZLSearchTWEntityIdKey:entityId, @"url":url};
            [self.succeededIndexFileInfoDictionaries addObject:fileInfo];
        }
        return success;
    }
}

#pragma mark - Task Succeeded

- (void)taskFinishedWasSuccessful:(BOOL)wasSuccessful
{
    if (self.cancelled) {
        [super taskFinishedWasSuccessful:NO];
        return;
    }
    
    if (self.type == ZLSearchTWActionTypeRemoveFileFromIndex) {
        [super taskFinishedWasSuccessful:wasSuccessful];
        return;
    }
    
    NSMutableArray *remainingUrls = [[self.workItem.jsonData objectForKey:kZLSearchTWFileInfoUrlArrayKey] mutableCopy];
    
    for (NSDictionary *indexFileInfo in self.succeededIndexFileInfoDictionaries) {
        NSString *url = [indexFileInfo objectForKey:@"url"];
        
        NSString *absoluteUrl = [ZLSearchManager absoluteUrlForFileInfoFromRelativeUrl:url];
        NSError *removeError;
        [[NSFileManager defaultManager] removeItemAtPath:absoluteUrl error:&removeError];
        if (removeError) {
            NSLog(@"Error removing file index info after indexing %@", removeError);
        }
        [remainingUrls removeObject:url];
    }
    
    NSArray *entityIds = [self.succeededIndexFileInfoDictionaries valueForKeyPath:kZLSearchTWEntityIdKey];
    NSArray *moduleIds = [self.succeededIndexFileInfoDictionaries valueForKeyPath:kZLSearchTWModuleIdKey];
    [self.delegate searchTaskWorkerIndexedFilesWithModuleIds:moduleIds fileIds:entityIds];
    
    // Update the URLs array so we minimize unneccessary repeatation
    NSMutableDictionary *mutableJsonData = [self.workItem.jsonData mutableCopy];
    [mutableJsonData setObject:[remainingUrls copy] forKey:kZLSearchTWFileInfoUrlArrayKey];
    self.workItem.jsonData = [mutableJsonData copy];
    
    [super taskFinishedWasSuccessful:wasSuccessful];
}

#pragma mark - Helpers

- (NSDictionary *)preparedSearchStringsFromSearchableStrings:(NSDictionary *)rawSearchableStrings
{
    NSMutableDictionary *newSearchableStrings = [NSMutableDictionary new];
    for (NSString *key in rawSearchableStrings.allKeys) {
        if (self.cancelled) {
            return nil;
        }
        
        NSString *oldString = [rawSearchableStrings objectForKey:key];
        NSString *newString = @"";
        
#warning remove after beta when we have API response
#ifdef TEST
        newString = [ADSearchDatabase searchableStringFromString:oldString];
#else
        newString = [ZLSearchDatabase plainTextFromHTML:oldString];
        newString = [ZLSearchDatabase searchableStringFromString:newString];
#endif
        [newSearchableStrings setObject:newString forKey:key];
    }
    
    return newSearchableStrings;
}

@end