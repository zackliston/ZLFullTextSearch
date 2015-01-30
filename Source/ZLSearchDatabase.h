//
//  ZLSearchDatabase.h
//  ZLFullTextSearch
//
//  Created by Zack Liston on 1/29/15.
//  Copyright (c) 2015 Zack Liston. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ZLSearchDatabase : NSObject

+ (BOOL)indexFileWithModuleId:(NSString *)moduleId entityId:(NSString *)entityId language:(NSString *)language boost:(double)boost searchableStrings:(NSDictionary *)searchableStrings fileMetadata:(NSDictionary *)fileMetadata;
+ (BOOL)removeFileWithModuleId:(NSString *)moduleId entityId:(NSString *)entityId;
+ (BOOL)resetDatabase;

+ (NSArray *)searchFilesWithSearchText:(NSString *)searchText limit:(NSUInteger)limit offset:(NSUInteger)offset error:(NSError **)error;

+ (NSString *)searchableStringFromString:(NSString *)oldString;

#warning Temporary, once the api is ready we won't need this anymore
+ (NSString *)plainTextFromHTML:(NSString *)html;

@end