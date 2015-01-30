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

@interface ZLSearchTaskWorker ()

@property (nonatomic, assign) ZLSearchTWActionType type;
@property (nonatomic, strong) NSArray *urlArray;

@end

@implementation ZLSearchTaskWorker

#pragma mark - Setup

- (void)setupWithWorkItem:(ZLInternalWorkItem *)workItem
{
    [super setupWithWorkItem:workItem];
    self.type = [[workItem.jsonData objectForKey:kZLSearchTWActionTypeKey] integerValue];
    self.urlArray = [workItem.jsonData objectForKey:kZLSearchTWFileInfoUrlArrayKey];
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
        
        success = [ZLSearchDatabase removeFileWithModuleId:moduleId entityId:fileId];
        
    } else if (self.type == ZLSearchTWActionTypeIndexFile) {
        NSMutableArray *remainingUrls = [self.urlArray mutableCopy];
        
        for (NSString *url in self.urlArray) {
            if (self.cancelled) {
                [self taskFinishedWasSuccessful:NO];
                return;
            }
            
            BOOL indexSuccess = [self indexFileFromUrl:url];
            if (indexSuccess) {
                // Remove the url so we don't keep retrying to index files that succeed
                // If others haven't
                [remainingUrls removeObject:url];
                
                NSString *absoluteUrl = [ZLSearchManager absoluteUrlForFileInfoFromRelativeUrl:url];
                NSError *removeError;
                [[NSFileManager defaultManager] removeItemAtPath:absoluteUrl error:&removeError];
                if (removeError) {
                    NSLog(@"Error removing file index info after indexing %@", removeError);
                }
            } else {
                success = indexSuccess;
            }
            
            // Update the URLs array so we minimize unneccessary repeatation
            NSMutableDictionary *mutableJsonData = [self.workItem.jsonData mutableCopy];
            [mutableJsonData setObject:[remainingUrls copy] forKey:kZLSearchTWFileInfoUrlArrayKey];
            self.workItem.jsonData = [mutableJsonData copy];
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
        BOOL success = [ZLSearchDatabase indexFileWithModuleId:moduleId entityId:entityId language:language boost:boost searchableStrings:preparedSearchableStrings fileMetadata:metadata];
        
        if (success) {
            [self.delegate searchTaskWorkerIndexedFileWithModuleId:moduleId fileId:entityId];
        }
        
        return success;
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