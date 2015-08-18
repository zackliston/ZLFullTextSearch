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
#import <CoreSpotlight/CoreSpotlight.h>
#import <UIKit/UIKit.h>

#define SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(v)  ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedAscending)

NSString *const kZLSearchTWActionTypeKey = @"action";

NSString *const kZLSearchTWFileInfoUrlArrayKey = @"urlArray";

NSString *const kZLSearchTWModuleIdKey = @"moduleId";
NSString *const kZLSearchTWEntityIdKey = @"entityId";
NSString *const kZLSearchTWLanguageKey = @"language";
NSString *const kZLSearchTWBoostKey = @"boost";
NSString *const kZLSearchTWSearchableStringsKey = @"searchableStrings";
NSString *const kZLSearchTWFileMetadataKey = @"fileMetadata";
NSString *const kZLSearchTWDatabaseNameKey = @"databaseName";
NSString *const kZLSearchTWIndexSpotlightKey = @"indexOnSpotlight";

@interface ZLSearchTaskWorker ()

@property (nonatomic, assign) ZLSearchTWActionType type;
@property (nonatomic, strong) NSArray *urlArray;
@property (nonatomic, strong) NSMutableArray *succeededIndexFileInfoDictionaries;
@property (nonatomic, strong) ZLSearchDatabase *searchDatabase;
@property (nonatomic, assign) BOOL shouldIndexOnSpotlight;
@property (nonatomic, strong) NSMutableArray *spotlightItems;
@property (nonatomic, strong) NSString *searchDatabaseName;
@end

@implementation ZLSearchTaskWorker

#pragma mark - Initialization

- (id)init {
    self = [super init];
    if (self) {
        self.isConcurrent = YES;
    }
    return self;
}

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
    self.shouldIndexOnSpotlight = [[workItem.jsonData objectForKey:kZLSearchTWIndexSpotlightKey] boolValue];
    self.searchDatabaseName = [workItem.jsonData objectForKey:kZLSearchTWDatabaseNameKey];
    self.searchDatabase = [[ZLSearchManager sharedInstance] searchDatabaseForName:self.searchDatabaseName];
    
    if (self.shouldIndexOnSpotlight)  {
        self.spotlightItems = [NSMutableArray new];
    }
}

#pragma mark - Main

- (void)start
{
    self.isFinished = NO;
    self.isExecuting = YES;
    if (self.cancelled) {
        [self taskFinishedWasSuccessful:NO];
        return;
    }
    
    BOOL success = YES;
    
    if (self.type == ZLSearchTWActionTypeRemoveFileFromIndex) {
        NSString *moduleId = [self.workItem.jsonData objectForKey:kZLSearchTWModuleIdKey];
        NSString *fileId = [self.workItem.jsonData objectForKey:kZLSearchTWEntityIdKey];
        NSDictionary *metadata = [self.workItem.jsonData objectForKey:kZLSearchTWFileMetadataKey];
        
        success = [self.searchDatabase removeFileWithModuleId:moduleId entityId:fileId];
        if (!success) {
            [self taskFinishedWasSuccessful:success];
            return;
        }
        
        [self asynchronouslyRemoveFileFromSpotlightIndexWithFileId:fileId moduleId:moduleId metadata:metadata];
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
        if (!success) {
            [self taskFinishedWasSuccessful:success];
            return;
        }
        
        if (self.shouldIndexOnSpotlight) {
            [self asynchronouslyIndexSpotlightItems:self.spotlightItems];
        } else {
            [self taskFinishedWasSuccessful:success];
        }
    }
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
        
        if (self.shouldIndexOnSpotlight) {
            [self queueSpotlightItemWithFileId:entityId moduleId:moduleId searchableStrings:searchableStrings metadata:metadata];
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

#pragma mark - Spotlight Helpers

- (void)queueSpotlightItemWithFileId:(NSString *)fileId moduleId:(NSString *)moduleId searchableStrings:(NSDictionary *)searchableStrings metadata:(NSDictionary *)metadata {
    if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"9.0")) {
        if (self.spotlightIdentiferDelegate) {
            NSString *text = @"";
            for (NSString *searchableString in searchableStrings.allValues) {
                text = [text stringByAppendingFormat:@" %@", searchableString];
            }
            
            NSString *cachesDirectory = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
            NSString *imagePath = [NSString stringWithFormat:@"%@/%@", cachesDirectory, metadata[kZLFileMetadataImageURI]];
            
            NSString *identifier = [self.spotlightIdentiferDelegate identifierWithFileId:fileId moduleId:moduleId fileMetadata:metadata];
            CSSearchableItemAttributeSet *attrSet = [[CSSearchableItemAttributeSet alloc] initWithItemContentType:@"data"];
            attrSet.title = metadata[kZLFileMetadataTitle];
            attrSet.thumbnailURL = [NSURL URLWithString:imagePath];
            [attrSet setTextContent:text];
            
            CSSearchableItem *item = [[CSSearchableItem alloc] initWithUniqueIdentifier:identifier domainIdentifier:self.searchDatabaseName attributeSet:attrSet];
            NSDate *today = [NSDate date];
            NSDate *expiration = [today dateByAddingTimeInterval:60*60*24*365*10];
            item.expirationDate = expiration;
            
            [self.spotlightItems addObject:item];
        } else {
            NSLog(@"We can only index on spotlight if a spotlightIdentiferDelegate has been specified on the SearchManager. Not indexing");
        }
    } else {
        NSLog(@"We can only index on spotlight if it is iOS 9 or greater. Not indexing");
    }

}

- (void)asynchronouslyIndexSpotlightItems:(NSArray *)spotlightItems {
    if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"9.0")) {
        [[CSSearchableIndex defaultSearchableIndex] indexSearchableItems:spotlightItems completionHandler:^(NSError * _Nullable error) {
            if (error) {
                NSLog(@"Error indexing items on spotlight : %@", error);
                [self taskFinishedWasSuccessful:NO];
            } else {
                [self taskFinishedWasSuccessful:YES];
            }
        }];
    } else {
        [self taskFinishedWasSuccessful:YES];
    }
}

- (void)asynchronouslyRemoveFileFromSpotlightIndexWithFileId:(NSString *)fileId moduleId:(NSString *)moduleId metadata:(NSDictionary *)metadata {
    if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"9.0")) {
        if (!self.spotlightIdentiferDelegate) {
            NSLog(@"Could not remvoe file from spotlight index because the identifer delegate was not set");
            [self taskFinishedWasSuccessful:YES];
            return;
        }
        
        NSString *identifier = [self.spotlightIdentiferDelegate identifierWithFileId:fileId moduleId:moduleId fileMetadata:metadata];
        [[CSSearchableIndex defaultSearchableIndex] deleteSearchableItemsWithIdentifiers:@[identifier] completionHandler:^(NSError * _Nullable error) {
            if (error) {
                NSLog(@"Error removing file from spotlight index : %@", error);
                [self taskFinishedWasSuccessful:NO];
            } else {
                [self taskFinishedWasSuccessful:YES];
            }
        }];
    } else {
        [self taskFinishedWasSuccessful:YES];
    }
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
        
        newString = [ZLSearchDatabase searchableStringFromString:oldString];
        [newSearchableStrings setObject:newString forKey:key];
    }
    
    return newSearchableStrings;
}

@end