//
//  ADTestSearchDatabase.m
//  AgileSDK
//
//  Created by Zack Liston on 1/20/15.
//  Copyright (c) 2015 AgileMD. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>
#import "ZLSearchDatabaseConstants.h"
#import "ZLSearchDatabase.h"
#import "FMDB.h"
#import "ZLSearchManager.h"
#import "OCMock/OCMock.h"
#import "ZLSearchResult.h"

@interface ADTestSearchDatabase : XCTestCase

@end

@interface ZLSearchResult (Test)

@property (nonatomic, strong, readonly) NSString *imageUri;
@property (nonatomic, strong, readonly) NSString *entityId;
@property (nonatomic, strong, readonly) NSString *moduleId;

@end

@interface ZLSearchDatabase (Test)

@property (nonatomic, strong) FMDatabaseQueue *queue;
+ (NSString *)stringWithLastWordHavingPrefixOperatorFromString:(NSString *)oldString;
- (BOOL)doesFileExistWithModuleId:(NSString *)moduleId entityId:(NSString *)entityId;

@end

@interface ADTestSearchDatabase ()

@property (nonatomic, strong) ZLSearchDatabase *database;

@end

@implementation ADTestSearchDatabase

- (void)setUp {
    [super setUp];
    self.database = [[ZLSearchDatabase alloc] initWithDatabaseName:@"testDB"];

    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
    [self.database resetDatabase];
    self.database = nil;
}

#pragma mark - Test Initialize/SharedQueue

- (void)testGettingInitialSharedQueue
{
    FMDatabaseQueue *queue = self.database.queue;

    XCTAssertNotNil(queue, @"Shared queue should not be nil after sharedQueue is called");
    
    NSString *cachesDirectory = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject];
    NSString *path = [[NSString alloc] initWithString:[cachesDirectory stringByAppendingPathComponent:@"testDB"]];
    
    XCTAssertTrue([queue.path isEqualToString:path], @"Queue database path %@ should be the same as the specified path %@", queue.path, path);
    
    [queue inDatabase:^(FMDatabase *db) {
        [db open];
    
        NSString *indexQuery = [NSString stringWithFormat:@"SELECT * FROM %@", kZLSearchDBIndexTableName];
        FMResultSet *indexSet = [db executeQuery:indexQuery];
        XCTAssertFalse(db.hadError, @"There was an error getting the table from the database %@", [db lastError]);
        XCTAssertEqual([[indexSet.columnNameToIndexMap objectForKey:kZLSearchDBModuleIdKey] integerValue], 0);
        XCTAssertEqual([[indexSet.columnNameToIndexMap objectForKey:kZLSearchDBEntityIdKey] integerValue], 1);
        XCTAssertEqual([[indexSet.columnNameToIndexMap objectForKey:kZLSearchDBLanguageKey] integerValue], 2);
        XCTAssertEqual([[indexSet.columnNameToIndexMap objectForKey:kZLSearchDBBoostKey] integerValue], 3);
        XCTAssertEqual([[indexSet.columnNameToIndexMap objectForKey:kZLSearchDBWeight0Key] integerValue], 4);
        XCTAssertEqual([[indexSet.columnNameToIndexMap objectForKey:kZLSearchDBWeight1Key] integerValue], 5);
        XCTAssertEqual([[indexSet.columnNameToIndexMap objectForKey:kZLSearchDBWeight2Key] integerValue], 6);
        XCTAssertEqual([[indexSet.columnNameToIndexMap objectForKey:kZLSearchDBWeight3Key] integerValue], 7);
        XCTAssertEqual([[indexSet.columnNameToIndexMap objectForKey:kZLSearchDBWeight4Key] integerValue], 8);
       
        
        NSString *metaDataQuery = [NSString stringWithFormat:@"SELECT * FROM %@", kZLSearchDBMetadataTableName];
        FMResultSet *metaDataSet = [db executeQuery:metaDataQuery];
        XCTAssertFalse(db.hadError, @"There was an error getting the table from the database %@", [db lastError]);
        XCTAssertEqual([[metaDataSet.columnNameToIndexMap objectForKey:kZLSearchDBModuleIdKey] integerValue], 0);
        XCTAssertEqual([[metaDataSet.columnNameToIndexMap objectForKey:kZLSearchDBEntityIdKey] integerValue], 1);
        XCTAssertEqual([[metaDataSet.columnNameToIndexMap objectForKey:kZLSearchDBTitleKey] integerValue], 2);
        XCTAssertEqual([[metaDataSet.columnNameToIndexMap objectForKey:kZLSearchDBSubtitleKey] integerValue], 3);
        XCTAssertEqual([[metaDataSet.columnNameToIndexMap objectForKey:kZLSearchDBUriKey] integerValue], 4);
        XCTAssertEqual([[metaDataSet.columnNameToIndexMap objectForKey:kZLSearchDBTypeKey] integerValue], 5);
        XCTAssertEqual([[metaDataSet.columnNameToIndexMap objectForKey:kZLSearchDBImageUriKey] integerValue], 6);

        
        XCTAssertFalse(db.shouldCacheStatements, @"The database should not cache statements");
        XCTAssertTrue(db.logsErrors, @"The database should log errors");
        
        [db closeOpenResultSets];
        [db close];
    }];
}

#pragma mark - Test indexFile

- (void)testIndexFileAllWeightsAllMetadata
{
    NSString *moduleId = @"moduleIdTestOne";
    NSString *entityId = @"entityIdTestOne";
    NSString *language = @"language";
    double boost = 2.3;
    NSString *weightZero = @"weight zero";
    NSString *weightOne = @"weight one";
    NSString *weightTwo = @"weight two";
    NSString *weightThree = @"weight three";
    NSString *weightFour = @"weight four";
    
    NSString *title = @"meta title";
    NSString *subtitle = @"meta subtitle";
    NSString *uri = @"meta uri";
    NSString *type = @"meta type";
    NSString *imageUri = @"meta image uri";
    
    NSDictionary *searchableStrings = @{kZLSearchableStringWeight0:weightZero, kZLSearchableStringWeight1:weightOne, kZLSearchableStringWeight2:weightTwo, kZLSearchableStringWeight3:weightThree, kZLSearchableStringWeight4:weightFour};
    NSDictionary *searchMetadata = @{kZLFileMetadataTitle:title, kZLFileMetadataSubtitle:subtitle, kZLFileMetadataURI:uri, kZLFileMetadataFileType:type, kZLFileMetadataImageURI:imageUri};
    
    id mockSearchDatabase = [OCMockObject partialMockForObject:self.database];
    [[[mockSearchDatabase expect] andReturnValue:OCMOCK_VALUE(NO) ] doesFileExistWithModuleId:moduleId entityId:entityId];
    [[mockSearchDatabase reject] removeFileWithModuleId:[OCMArg any] entityId:[OCMArg any]];
    
    BOOL success = [self.database indexFileWithModuleId:moduleId entityId:entityId language:language boost:boost searchableStrings:searchableStrings fileMetadata:searchMetadata];
    
    XCTAssertTrue(success);
    
    FMDatabaseQueue *queue = self.database.queue;
    
    [queue inDatabase:^(FMDatabase *db) {
        [db open];
        
        NSString *query = [NSString stringWithFormat:@"SELECT * FROM %@ WHERE %@ == '%@' AND %@ == '%@'", kZLSearchDBIndexTableName, kZLSearchDBModuleIdKey,moduleId, kZLSearchDBEntityIdKey, entityId];
        FMResultSet *set = [db executeQuery:query];
        
        XCTAssertTrue([set next], @"The query should have returned at least one row");
        
        XCTAssertTrue([moduleId isEqualToString:[set stringForColumn:kZLSearchDBModuleIdKey]]);
        XCTAssertTrue([entityId isEqualToString:[set stringForColumn:kZLSearchDBEntityIdKey]]);
        XCTAssertTrue([language isEqualToString:[set stringForColumn:kZLSearchDBLanguageKey]]);
        XCTAssertEqualWithAccuracy(boost, [set doubleForColumn:kZLSearchDBBoostKey], 0.01);
        XCTAssertTrue([weightZero isEqualToString:[set stringForColumn:kZLSearchDBWeight0Key]]);
        XCTAssertTrue([weightOne isEqualToString:[set stringForColumn:kZLSearchDBWeight1Key]]);
        XCTAssertTrue([weightTwo isEqualToString:[set stringForColumn:kZLSearchDBWeight2Key]]);
        XCTAssertTrue([weightThree isEqualToString:[set stringForColumn:kZLSearchDBWeight3Key]]);
        XCTAssertTrue([weightFour isEqualToString:[set stringForColumn:kZLSearchDBWeight4Key]]);
    
        XCTAssertFalse([set next], @"The query should NOT have returned more than one row");
        
        [db closeOpenResultSets];
        [db close];
    }];
    
    [queue inDatabase:^(FMDatabase *db) {
        [db open];
        NSString *query = [NSString stringWithFormat:@"SELECT * FROM %@ WHERE %@ == '%@' AND %@ == '%@'", kZLSearchDBMetadataTableName, kZLSearchDBModuleIdKey, moduleId, kZLSearchDBEntityIdKey, entityId];
        FMResultSet *set = [db executeQuery:query];
        
        XCTAssertTrue([set next], @"The query should have returned at least one row");
        
        XCTAssertTrue([moduleId isEqualToString:[set stringForColumn:kZLSearchDBModuleIdKey]]);
        XCTAssertTrue([entityId isEqualToString:[set stringForColumn:kZLSearchDBEntityIdKey]]);
        XCTAssertTrue([uri isEqualToString:[set stringForColumn:kZLSearchDBUriKey]]);
        XCTAssertTrue([title isEqualToString:[set stringForColumn:kZLSearchDBTitleKey]]);
        XCTAssertTrue([subtitle isEqualToString:[set stringForColumn:kZLSearchDBSubtitleKey]]);
        XCTAssertTrue([type isEqualToString:[set stringForColumn:kZLSearchDBTypeKey]]);
        XCTAssertTrue([imageUri isEqualToString:[set stringForColumn:kZLSearchDBImageUriKey]]);
        
        XCTAssertFalse([set next], @"The query should NOT have returned more than one row");
        
        [db closeOpenResultSets];
        [db close];
    }];
    
    [mockSearchDatabase verify];
    [mockSearchDatabase stopMocking];
}

- (void)testIndexFileSomeWeightsAllMetadata
{
    NSString *moduleId = @"moduleIdTestOne";
    NSString *entityId = @"entityIdTestOne";
    NSString *language = @"language";
    double boost = 2.3;
    NSString *weightZero = @"and weight zero";
    NSString *weightTwo = @"weight two";
    NSString *weightThree = @"weight three";
    
    NSString *title = @"meta title";
    NSString *subtitle = @"meta subtitle";
    NSString *uri = @"meta uri";
    NSString *type = @"meta type";
    NSString *imageUri = @"meta image uri";
    
    NSDictionary *searchableStrings = @{kZLSearchableStringWeight0:weightZero, kZLSearchableStringWeight2:weightTwo, kZLSearchableStringWeight3:weightThree};
    NSDictionary *searchMetadata = @{kZLFileMetadataTitle:title, kZLFileMetadataSubtitle:subtitle, kZLFileMetadataURI:uri, kZLFileMetadataFileType:type, kZLFileMetadataImageURI:imageUri};
    
    id mockSearchDatabase = [OCMockObject partialMockForObject:self.database];
    [[[mockSearchDatabase expect] andReturnValue:OCMOCK_VALUE(NO) ] doesFileExistWithModuleId:moduleId entityId:entityId];
     [[mockSearchDatabase reject] removeFileWithModuleId:[OCMArg any] entityId:[OCMArg any]];
    
    BOOL success = [self.database indexFileWithModuleId:moduleId entityId:entityId language:language boost:boost searchableStrings:searchableStrings fileMetadata:searchMetadata];
    
    XCTAssertTrue(success);
    
    FMDatabaseQueue *queue = self.database.queue;
    
    [queue inDatabase:^(FMDatabase *db) {
        [db open];
        NSString *query = [NSString stringWithFormat:@"SELECT * FROM %@ WHERE %@ == '%@' AND %@ == '%@'", kZLSearchDBIndexTableName, kZLSearchDBModuleIdKey,moduleId, kZLSearchDBEntityIdKey, entityId];
        FMResultSet *set = [db executeQuery:query];
        
        XCTAssertTrue([set next], @"The query should have returned at least one row");
        
        XCTAssertTrue([moduleId isEqualToString:[set stringForColumn:kZLSearchDBModuleIdKey]]);
        XCTAssertTrue([entityId isEqualToString:[set stringForColumn:kZLSearchDBEntityIdKey]]);
        XCTAssertTrue([language isEqualToString:[set stringForColumn:kZLSearchDBLanguageKey]]);
        XCTAssertEqualWithAccuracy(boost, [set doubleForColumn:kZLSearchDBBoostKey], 0.01);
        XCTAssertTrue([weightZero isEqualToString:[set stringForColumn:kZLSearchDBWeight0Key]]);
        XCTAssertNil([set stringForColumn:kZLSearchDBWeight1Key]);
        XCTAssertTrue([weightTwo isEqualToString:[set stringForColumn:kZLSearchDBWeight2Key]]);
        XCTAssertTrue([weightThree isEqualToString:[set stringForColumn:kZLSearchDBWeight3Key]]);
        XCTAssertNil([set stringForColumn:kZLSearchDBWeight4Key]);
        
        XCTAssertFalse([set next], @"The query should NOT have returned more than one row");
        
        [db closeOpenResultSets];
        [db close];
    }];
    
    [queue inDatabase:^(FMDatabase *db) {
        [db open];
        NSString *query = [NSString stringWithFormat:@"SELECT * FROM %@ WHERE %@ == '%@' AND %@ == '%@'", kZLSearchDBMetadataTableName, kZLSearchDBModuleIdKey, moduleId, kZLSearchDBEntityIdKey, entityId];
        FMResultSet *set = [db executeQuery:query];
        
        XCTAssertTrue([set next], @"The query should have returned at least one row");
        
        XCTAssertTrue([moduleId isEqualToString:[set stringForColumn:kZLSearchDBModuleIdKey]]);
        XCTAssertTrue([entityId isEqualToString:[set stringForColumn:kZLSearchDBEntityIdKey]]);
        XCTAssertTrue([uri isEqualToString:[set stringForColumn:kZLSearchDBUriKey]]);
        XCTAssertTrue([title isEqualToString:[set stringForColumn:kZLSearchDBTitleKey]]);
        XCTAssertTrue([subtitle isEqualToString:[set stringForColumn:kZLSearchDBSubtitleKey]]);
        XCTAssertTrue([type isEqualToString:[set stringForColumn:kZLSearchDBTypeKey]]);
        XCTAssertTrue([imageUri isEqualToString:[set stringForColumn:kZLSearchDBImageUriKey]]);
        
        XCTAssertFalse([set next], @"The query should NOT have returned more than one row");
        
        [db closeOpenResultSets];
        [db close];
    }];
    [mockSearchDatabase verify];
    [mockSearchDatabase stopMocking];
}

- (void)testIndexFileAllWeightsNoMetadata
{
    NSString *moduleId = @"moduleIdTestOne";
    NSString *entityId = @"entityIdTestOne";
    NSString *language = @"language";
    double boost = 2.3;
    NSString *weightZero = @"weight zero";
    NSString *weightOne = @"weight one";
    NSString *weightTwo = @"weight two";
    NSString *weightThree = @"weight three";
    NSString *weightFour = @"weight four";
    
    
    NSDictionary *searchableStrings = @{kZLSearchableStringWeight0:weightZero, kZLSearchableStringWeight1:weightOne, kZLSearchableStringWeight2:weightTwo, kZLSearchableStringWeight3:weightThree, kZLSearchableStringWeight4:weightFour};
    NSDictionary *searchMetadata = nil;
    
    id mockSearchDatabase = [OCMockObject partialMockForObject:self.database];
    [[[mockSearchDatabase expect] andReturnValue:OCMOCK_VALUE(NO) ] doesFileExistWithModuleId:moduleId entityId:entityId];
     [[mockSearchDatabase reject] removeFileWithModuleId:[OCMArg any] entityId:[OCMArg any]];
    
    BOOL success = [self.database indexFileWithModuleId:moduleId entityId:entityId language:language boost:boost searchableStrings:searchableStrings fileMetadata:searchMetadata];
    
    XCTAssertTrue(success);
    
    FMDatabaseQueue *queue = self.database.queue;
    
    [queue inDatabase:^(FMDatabase *db) {
        [db open];
        NSString *query = [NSString stringWithFormat:@"SELECT * FROM %@ WHERE %@ == '%@' AND %@ == '%@'", kZLSearchDBIndexTableName, kZLSearchDBModuleIdKey,moduleId, kZLSearchDBEntityIdKey, entityId];
        FMResultSet *set = [db executeQuery:query];
        
        XCTAssertTrue([set next], @"The query should have returned at least one row");
        
        XCTAssertTrue([moduleId isEqualToString:[set stringForColumn:kZLSearchDBModuleIdKey]]);
        XCTAssertTrue([entityId isEqualToString:[set stringForColumn:kZLSearchDBEntityIdKey]]);
        XCTAssertTrue([language isEqualToString:[set stringForColumn:kZLSearchDBLanguageKey]]);
        XCTAssertEqualWithAccuracy(boost, [set doubleForColumn:kZLSearchDBBoostKey], 0.01);
        XCTAssertTrue([weightZero isEqualToString:[set stringForColumn:kZLSearchDBWeight0Key]]);
        XCTAssertTrue([weightOne isEqualToString:[set stringForColumn:kZLSearchDBWeight1Key]]);
        XCTAssertTrue([weightTwo isEqualToString:[set stringForColumn:kZLSearchDBWeight2Key]]);
        XCTAssertTrue([weightThree isEqualToString:[set stringForColumn:kZLSearchDBWeight3Key]]);
        XCTAssertTrue([weightFour isEqualToString:[set stringForColumn:kZLSearchDBWeight4Key]]);
        
        XCTAssertFalse([set next], @"The query should NOT have returned more than one row");
        
        [db closeOpenResultSets];
        [db close];
    }];
    
    [queue inDatabase:^(FMDatabase *db) {
        [db open];
        NSString *query = [NSString stringWithFormat:@"SELECT * FROM %@ WHERE %@ == '%@' AND %@ == '%@'", kZLSearchDBMetadataTableName, kZLSearchDBModuleIdKey, moduleId, kZLSearchDBEntityIdKey, entityId];
        FMResultSet *set = [db executeQuery:query];
        
        XCTAssertTrue([set next], @"The query should have returned at least one row");
        
        XCTAssertTrue([moduleId isEqualToString:[set stringForColumn:kZLSearchDBModuleIdKey]]);
        XCTAssertTrue([entityId isEqualToString:[set stringForColumn:kZLSearchDBEntityIdKey]]);
        XCTAssertNil([set stringForColumn:kZLSearchDBUriKey]);
        XCTAssertNil([set stringForColumn:kZLSearchDBTitleKey]);
        XCTAssertNil([set stringForColumn:kZLSearchDBSubtitleKey]);
        XCTAssertNil([set stringForColumn:kZLSearchDBTypeKey]);
        XCTAssertNil([set stringForColumn:kZLSearchDBImageUriKey]);
        
        XCTAssertFalse([set next], @"The query should NOT have returned more than one row");
        
        [db closeOpenResultSets];
        [db close];
    }];
    [mockSearchDatabase verify];
    [mockSearchDatabase stopMocking];
}

- (void)testIndexFileSomeWeightsNoMetadata
{
    NSString *moduleId = @"moduleIdTestOne";
    NSString *entityId = @"entityIdTestOne";
    NSString *language = @"language";
    double boost = 2.3;
    NSString *weightOne = @"weight one";
    
    
    NSDictionary *searchableStrings = @{kZLSearchableStringWeight1:weightOne};
    NSDictionary *searchMetadata = nil;
    
    id mockSearchDatabase = [OCMockObject partialMockForObject:self.database];
    [[[mockSearchDatabase expect] andReturnValue:OCMOCK_VALUE(NO) ] doesFileExistWithModuleId:moduleId entityId:entityId];
     [[mockSearchDatabase reject] removeFileWithModuleId:[OCMArg any] entityId:[OCMArg any]];
    
    BOOL success = [self.database indexFileWithModuleId:moduleId entityId:entityId language:language boost:boost searchableStrings:searchableStrings fileMetadata:searchMetadata];
    
    XCTAssertTrue(success);
    
    FMDatabaseQueue *queue = self.database.queue;
    
    [queue inDatabase:^(FMDatabase *db) {
        [db open];
        NSString *query = [NSString stringWithFormat:@"SELECT * FROM %@ WHERE %@ == '%@' AND %@ == '%@'", kZLSearchDBIndexTableName, kZLSearchDBModuleIdKey,moduleId, kZLSearchDBEntityIdKey, entityId];
        FMResultSet *set = [db executeQuery:query];
        
        XCTAssertTrue([set next], @"The query should have returned at least one row");
        
        XCTAssertTrue([moduleId isEqualToString:[set stringForColumn:kZLSearchDBModuleIdKey]]);
        XCTAssertTrue([entityId isEqualToString:[set stringForColumn:kZLSearchDBEntityIdKey]]);
        XCTAssertTrue([language isEqualToString:[set stringForColumn:kZLSearchDBLanguageKey]]);
        XCTAssertEqualWithAccuracy(boost, [set doubleForColumn:kZLSearchDBBoostKey], 0.01);
        XCTAssertNil([set stringForColumn:kZLSearchDBWeight0Key]);
        XCTAssertTrue([weightOne isEqualToString:[set stringForColumn:kZLSearchDBWeight1Key]]);
        XCTAssertNil([set stringForColumn:kZLSearchDBWeight2Key]);
        XCTAssertNil([set stringForColumn:kZLSearchDBWeight3Key]);
        XCTAssertNil([set stringForColumn:kZLSearchDBWeight4Key]);
        
        XCTAssertFalse([set next], @"The query should NOT have returned more than one row");
        
        [db closeOpenResultSets];
        [db close];
    }];
    
    [queue inDatabase:^(FMDatabase *db) {
        [db open];
        NSString *query = [NSString stringWithFormat:@"SELECT * FROM %@ WHERE %@ == '%@' AND %@ == '%@'", kZLSearchDBMetadataTableName, kZLSearchDBModuleIdKey, moduleId, kZLSearchDBEntityIdKey, entityId];
        FMResultSet *set = [db executeQuery:query];
        
        XCTAssertTrue([set next], @"The query should have returned at least one row");
        
        XCTAssertTrue([moduleId isEqualToString:[set stringForColumn:kZLSearchDBModuleIdKey]]);
        XCTAssertTrue([entityId isEqualToString:[set stringForColumn:kZLSearchDBEntityIdKey]]);
        XCTAssertNil([set stringForColumn:kZLSearchDBUriKey]);
        XCTAssertNil([set stringForColumn:kZLSearchDBTitleKey]);
        XCTAssertNil([set stringForColumn:kZLSearchDBSubtitleKey]);
        XCTAssertNil([set stringForColumn:kZLSearchDBTypeKey]);
        XCTAssertNil([set stringForColumn:kZLSearchDBImageUriKey]);
        
        XCTAssertFalse([set next], @"The query should NOT have returned more than one row");
        
        [db closeOpenResultSets];
        [db close];
    }];
    [mockSearchDatabase verify];
    [mockSearchDatabase stopMocking];
}

- (void)testIndexFileNoWeights
{
    NSString *moduleId = @"moduleIdTestOne";
    NSString *entityId = @"entityIdTestOne";
    NSString *language = @"language";
    double boost = 2.3;
    NSString *weightOne = @"weight one";
    
    NSDictionary *searchableStrings = @{@"otherKey":weightOne};
    NSDictionary *searchMetadata = nil;
    
    id mockQueue = [OCMockObject partialMockForObject:self.database.queue];
    [[mockQueue reject] inTransaction:[OCMArg any]];
    [[mockQueue reject] inDatabase:[OCMArg any]];
    BOOL success = [self.database indexFileWithModuleId:moduleId entityId:entityId language:language boost:boost searchableStrings:searchableStrings fileMetadata:searchMetadata];
    
    [mockQueue verify];
    [mockQueue stopMocking];
    XCTAssertFalse(success);
}

- (void)testIndexFileNoModuleId
{
    NSString *moduleId = nil;
    NSString *entityId = @"entityIdTestOne";
    NSString *language = @"language";
    double boost = 2.3;
    NSString *weightOne = @"weight one";
    
    NSDictionary *searchableStrings = @{kZLSearchableStringWeight1:weightOne};
    NSDictionary *searchMetadata = nil;
    
    id mockQueue = [OCMockObject partialMockForObject:self.database.queue];
    [[mockQueue reject] inTransaction:[OCMArg any]];
    [[mockQueue reject] inDatabase:[OCMArg any]];
    BOOL success = [self.database indexFileWithModuleId:moduleId entityId:entityId language:language boost:boost searchableStrings:searchableStrings fileMetadata:searchMetadata];
    
    [mockQueue verify];
    [mockQueue stopMocking];
    XCTAssertFalse(success);
}

- (void)testIndexFileNoEntityId
{
    NSString *moduleId = @"module";
    NSString *entityId = nil;
    NSString *language = @"language";
    double boost = 2.3;
    NSString *weightOne = @"weight one";
    
    NSDictionary *searchableStrings = @{kZLSearchableStringWeight1:weightOne};
    NSDictionary *searchMetadata = nil;
    
    id mockQueue = [OCMockObject partialMockForObject:self.database.queue];
    [[mockQueue reject] inTransaction:[OCMArg any]];
    [[mockQueue reject] inDatabase:[OCMArg any]];
    BOOL success = [self.database indexFileWithModuleId:moduleId entityId:entityId language:language boost:boost searchableStrings:searchableStrings fileMetadata:searchMetadata];
    
    [mockQueue verify];
    [mockQueue stopMocking];
    XCTAssertFalse(success);
}

- (void)testIndexFileNoLanguage
{
    NSString *moduleId = @"module";
    NSString *entityId = @"entity";
    NSString *language = nil;
    double boost = 2.3;
    NSString *weightOne = @"weight one";
    
    NSDictionary *searchableStrings = @{kZLSearchableStringWeight1:weightOne};
    NSDictionary *searchMetadata = nil;
    
    id mockQueue = [OCMockObject partialMockForObject:self.database.queue];
    [[mockQueue reject] inTransaction:[OCMArg any]];
    [[mockQueue reject] inDatabase:[OCMArg any]];
    BOOL success = [self.database indexFileWithModuleId:moduleId entityId:entityId language:language boost:boost searchableStrings:searchableStrings fileMetadata:searchMetadata];
    
    [mockQueue verify];
    [mockQueue stopMocking];
    XCTAssertFalse(success);
}

- (void)testIndexFileAlreadyExists
{
    NSString *moduleId = @"moduleIdTestOne";
    NSString *entityId = @"entityIdTestOne";
    NSString *language = @"language";
    double boost = 2.3;
    NSString *weightZero = @"weight zero";
    NSString *weightOne = @"weight one";
    NSString *weightTwo = @"weight two";
    NSString *weightThree = @"weight three";
    NSString *weightFour = @"weight four";
    
    NSString *title = @"meta title";
    NSString *subtitle = @"meta subtitle";
    NSString *uri = @"meta uri";
    NSString *type = @"meta type";
    NSString *imageUri = @"meta image uri";
    
    NSDictionary *searchableStrings = @{kZLSearchableStringWeight0:weightZero, kZLSearchableStringWeight1:weightOne, kZLSearchableStringWeight2:weightTwo, kZLSearchableStringWeight3:weightThree, kZLSearchableStringWeight4:weightFour};
    NSDictionary *searchMetadata = @{kZLFileMetadataTitle:title, kZLFileMetadataSubtitle:subtitle, kZLFileMetadataURI:uri, kZLFileMetadataFileType:type, kZLFileMetadataImageURI:imageUri};
    
    id mockSearchDatabase = [OCMockObject partialMockForObject:self.database];
    [[[mockSearchDatabase expect] andReturnValue:OCMOCK_VALUE(YES)] doesFileExistWithModuleId:moduleId entityId:entityId];
    [[[mockSearchDatabase expect] andReturnValue:OCMOCK_VALUE(YES)] removeFileWithModuleId:moduleId entityId:entityId];
    
    
    BOOL success = [self.database indexFileWithModuleId:moduleId entityId:entityId language:language boost:boost searchableStrings:searchableStrings fileMetadata:searchMetadata];
    
    XCTAssertTrue(success);
    
    FMDatabaseQueue *queue = self.database.queue;
    
    [queue inDatabase:^(FMDatabase *db) {
        [db open];
        NSString *query = [NSString stringWithFormat:@"SELECT * FROM %@ WHERE %@ == '%@' AND %@ == '%@'", kZLSearchDBIndexTableName, kZLSearchDBModuleIdKey,moduleId, kZLSearchDBEntityIdKey, entityId];
        FMResultSet *set = [db executeQuery:query];
        
        XCTAssertTrue([set next], @"The query should have returned at least one row");
        
        XCTAssertTrue([moduleId isEqualToString:[set stringForColumn:kZLSearchDBModuleIdKey]]);
        XCTAssertTrue([entityId isEqualToString:[set stringForColumn:kZLSearchDBEntityIdKey]]);
        XCTAssertTrue([language isEqualToString:[set stringForColumn:kZLSearchDBLanguageKey]]);
        XCTAssertEqualWithAccuracy(boost, [set doubleForColumn:kZLSearchDBBoostKey], 0.01);
        XCTAssertTrue([weightZero isEqualToString:[set stringForColumn:kZLSearchDBWeight0Key]]);
        XCTAssertTrue([weightOne isEqualToString:[set stringForColumn:kZLSearchDBWeight1Key]]);
        XCTAssertTrue([weightTwo isEqualToString:[set stringForColumn:kZLSearchDBWeight2Key]]);
        XCTAssertTrue([weightThree isEqualToString:[set stringForColumn:kZLSearchDBWeight3Key]]);
        XCTAssertTrue([weightFour isEqualToString:[set stringForColumn:kZLSearchDBWeight4Key]]);
        
        XCTAssertFalse([set next], @"The query should NOT have returned more than one row");
        
        [db closeOpenResultSets];
        [db close];
    }];
    
    [queue inDatabase:^(FMDatabase *db) {
        [db open];
        NSString *query = [NSString stringWithFormat:@"SELECT * FROM %@ WHERE %@ == '%@' AND %@ == '%@'", kZLSearchDBMetadataTableName, kZLSearchDBModuleIdKey, moduleId, kZLSearchDBEntityIdKey, entityId];
        FMResultSet *set = [db executeQuery:query];
        
        XCTAssertTrue([set next], @"The query should have returned at least one row");
        
        XCTAssertTrue([moduleId isEqualToString:[set stringForColumn:kZLSearchDBModuleIdKey]]);
        XCTAssertTrue([entityId isEqualToString:[set stringForColumn:kZLSearchDBEntityIdKey]]);
        XCTAssertTrue([uri isEqualToString:[set stringForColumn:kZLSearchDBUriKey]]);
        XCTAssertTrue([title isEqualToString:[set stringForColumn:kZLSearchDBTitleKey]]);
        XCTAssertTrue([subtitle isEqualToString:[set stringForColumn:kZLSearchDBSubtitleKey]]);
        XCTAssertTrue([type isEqualToString:[set stringForColumn:kZLSearchDBTypeKey]]);
        XCTAssertTrue([imageUri isEqualToString:[set stringForColumn:kZLSearchDBImageUriKey]]);
        
        XCTAssertFalse([set next], @"The query should NOT have returned more than one row");
        
        [db closeOpenResultSets];
        [db close];
    }];
    
    [mockSearchDatabase verify];
    [mockSearchDatabase stopMocking];
}

#pragma mark - Test removeFile

- (void)testRemoveFile
{
    NSString *moduleId = @"moduleIdTestOne";
    NSString *entityId = @"entityIdTestOne";
    NSString *language = @"language";
    double boost = 2.3;
    NSString *weightZero = @"weight zero";
    NSString *weightOne = @"weight one";
    NSString *weightTwo = @"weight two";
    NSString *weightThree = @"weight three";
    NSString *weightFour = @"weight four";
    
    NSString *title = @"meta title";
    NSString *subtitle = @"meta subtitle";
    NSString *uri = @"meta uri";
    NSString *type = @"meta type";
    NSString *imageUri = @"meta image uri";
    
    NSDictionary *searchableStrings = @{kZLSearchableStringWeight0:weightZero, kZLSearchableStringWeight1:weightOne, kZLSearchableStringWeight2:weightTwo, kZLSearchableStringWeight3:weightThree, kZLSearchableStringWeight4:weightFour};
    NSDictionary *searchMetadata = @{kZLFileMetadataTitle:title, kZLFileMetadataSubtitle:subtitle, kZLFileMetadataURI:uri, kZLFileMetadataFileType:type, kZLFileMetadataImageURI:imageUri};

    BOOL addSuccess = [self.database indexFileWithModuleId:moduleId entityId:entityId language:language boost:boost searchableStrings:searchableStrings fileMetadata:searchMetadata];
    XCTAssertTrue(addSuccess);
    
    BOOL removeSuccess = [self.database removeFileWithModuleId:moduleId entityId:entityId];
    XCTAssertTrue(removeSuccess);

    FMDatabaseQueue *queue = self.database.queue;
    
    [queue inDatabase:^(FMDatabase *db) {
        [db open];
        NSString *query = [NSString stringWithFormat:@"SELECT * FROM %@ WHERE %@ == '%@' AND %@ == '%@'", kZLSearchDBIndexTableName, kZLSearchDBModuleIdKey,moduleId, kZLSearchDBEntityIdKey, entityId];
        FMResultSet *set = [db executeQuery:query];
        
        XCTAssertFalse([set next], @"The query should have returned at least one row");
        
        [db closeOpenResultSets];
        [db close];
    }];
    
    [queue inDatabase:^(FMDatabase *db) {
        [db open];
        NSString *query = [NSString stringWithFormat:@"SELECT * FROM %@ WHERE %@ == '%@' AND %@ == '%@'", kZLSearchDBMetadataTableName, kZLSearchDBModuleIdKey, moduleId, kZLSearchDBEntityIdKey, entityId];
        FMResultSet *set = [db executeQuery:query];
        
        XCTAssertFalse([set next], @"The query should NOT have returned more than one row");
        
        [db closeOpenResultSets];
        [db close];
    }];

}

- (void)testRemoveFileNoModuleId
{
    NSString *moduleId = @"moduleIdTestOne";
    NSString *entityId = @"entityIdTestOne";
    NSString *language = @"language";
    double boost = 2.3;
    NSString *weightZero = @"weight zero";
    NSString *weightOne = @"weight one";
    NSString *weightTwo = @"weight two";
    NSString *weightThree = @"weight three";
    NSString *weightFour = @"weight four";
    
    NSString *title = @"meta title";
    NSString *subtitle = @"meta subtitle";
    NSString *uri = @"meta uri";
    NSString *type = @"meta type";
    NSString *imageUri = @"meta image uri";
    
    NSDictionary *searchableStrings = @{kZLSearchableStringWeight0:weightZero, kZLSearchableStringWeight1:weightOne, kZLSearchableStringWeight2:weightTwo, kZLSearchableStringWeight3:weightThree, kZLSearchableStringWeight4:weightFour};
    NSDictionary *searchMetadata = @{kZLFileMetadataTitle:title, kZLFileMetadataSubtitle:subtitle, kZLFileMetadataURI:uri, kZLFileMetadataFileType:type, kZLFileMetadataImageURI:imageUri};
    
    BOOL addSuccess = [self.database indexFileWithModuleId:moduleId entityId:entityId language:language boost:boost searchableStrings:searchableStrings fileMetadata:searchMetadata];
    XCTAssertTrue(addSuccess);
    
    id mockQueue = [OCMockObject partialMockForObject:self.database.queue];
    [[mockQueue reject] inTransaction:[OCMArg any]];
    [[mockQueue reject] inDatabase:[OCMArg any]];
    
    
    BOOL removeSuccess = [self.database removeFileWithModuleId:nil entityId:entityId];
    XCTAssertFalse(removeSuccess);
    
    [mockQueue verify];
    [mockQueue stopMocking];
}

- (void)testRemoveFileNoEntityId
{
    NSString *moduleId = @"moduleIdTestOne";
    NSString *entityId = @"entityIdTestOne";
    NSString *language = @"language";
    double boost = 2.3;
    NSString *weightZero = @"weight zero";
    NSString *weightOne = @"weight one";
    NSString *weightTwo = @"weight two";
    NSString *weightThree = @"weight three";
    NSString *weightFour = @"weight four";
    
    NSString *title = @"meta title";
    NSString *subtitle = @"meta subtitle";
    NSString *uri = @"meta uri";
    NSString *type = @"meta type";
    NSString *imageUri = @"meta image uri";
    
    NSDictionary *searchableStrings = @{kZLSearchableStringWeight0:weightZero, kZLSearchableStringWeight1:weightOne, kZLSearchableStringWeight2:weightTwo, kZLSearchableStringWeight3:weightThree, kZLSearchableStringWeight4:weightFour};
    NSDictionary *searchMetadata = @{kZLFileMetadataTitle:title, kZLFileMetadataSubtitle:subtitle, kZLFileMetadataURI:uri, kZLFileMetadataFileType:type, kZLFileMetadataImageURI:imageUri};
    
    BOOL addSuccess = [self.database indexFileWithModuleId:moduleId entityId:entityId language:language boost:boost searchableStrings:searchableStrings fileMetadata:searchMetadata];
    XCTAssertTrue(addSuccess);
    
    id mockQueue = [OCMockObject partialMockForObject:self.database.queue];
    [[mockQueue reject] inTransaction:[OCMArg any]];
    [[mockQueue reject] inDatabase:[OCMArg any]];
    
    
    BOOL removeSuccess = [self.database removeFileWithModuleId:moduleId entityId:nil];
    XCTAssertFalse(removeSuccess);
    
    [mockQueue verify];
    [mockQueue stopMocking];
}

#pragma mark - Test Search

- (void)testSearch
{
    NSString *moduleId1 = @"mdoule1";
    NSString *moduleId2= @"mdoule2";
    NSString *moduleId3 = @"mdoule3";
    NSString *moduleId4 = @"mdoule4";
    NSString *moduleId5 = @"mdoule5";
    NSString *moduleId6 = @"mdoule6";
    NSArray *resultModuleIds = @[moduleId1, moduleId2, moduleId3, moduleId4, moduleId5];
    
    NSString *language = @"en";
    double boost = 1.0;
    
    NSString *entityId1 = @"entityId1";
    NSString *entityId2 = @"entityId2";
    NSString *entityId3 = @"entityId3";
    NSString *entityId4 = @"entityId4";
    NSString *entityId5 = @"entityId5";
    NSString *entityId6 = @"entityId6";
    NSArray *resultEntityIds = @[entityId1, entityId2, entityId3, entityId4, entityId5];
    
    NSString *searchableString = @"hello world";
    NSDictionary *search1 = @{kZLSearchableStringWeight4:searchableString};
    NSDictionary *search2 = @{kZLSearchableStringWeight0:searchableString};
    NSDictionary *search3 = @{kZLSearchableStringWeight0:searchableString};
    NSDictionary *search4 = @{kZLSearchableStringWeight0:searchableString};
    NSDictionary *search5 = @{kZLSearchableStringWeight0:searchableString};
    NSDictionary *search6 = @{kZLSearchableStringWeight3:@"no mathc"};
    
    [self.database indexFileWithModuleId:moduleId1 entityId:entityId1 language:language boost:boost searchableStrings:search1 fileMetadata:nil];
    [self.database indexFileWithModuleId:moduleId2 entityId:entityId2 language:language boost:boost searchableStrings:search2 fileMetadata:nil];
    [self.database indexFileWithModuleId:moduleId3 entityId:entityId3 language:language boost:boost searchableStrings:search3 fileMetadata:nil];
    [self.database indexFileWithModuleId:moduleId4 entityId:entityId4 language:language boost:boost searchableStrings:search4 fileMetadata:nil];
    [self.database indexFileWithModuleId:moduleId5 entityId:entityId5 language:language boost:boost searchableStrings:search5 fileMetadata:nil];
    [self.database indexFileWithModuleId:moduleId6 entityId:entityId6 language:language boost:boost searchableStrings:search6 fileMetadata:nil];

    NSError *error;
    NSArray *results = [self.database searchFilesWithSearchText:@"hello" limit:10 offset:0 preferPhraseSearching:YES searchSuggestions:nil error:&error];
    
    XCTAssertNil(error);
    XCTAssertEqual(results.count, 5);
    
    for (ZLSearchResult *searchResult in results) {
        XCTAssertTrue([resultEntityIds containsObject:searchResult.entityId]);
        XCTAssertTrue([resultModuleIds containsObject:searchResult.moduleId]);
    }
}

- (void)testSearchPopulatesSearchResultAppropriately
{
    NSString *moduleId = @"mdoule";
    NSString *language = @"en";
    double boost = 1.0;
    
    NSString *entityId1 = @"entityId1";
    NSString *entityId2 = @"entityId2";
    
    NSString *searchableString = @"hello world";
    NSDictionary *search1 = @{kZLSearchableStringWeight0:searchableString};
    NSDictionary *search2 = @{kZLSearchableStringWeight3:@"nope"};
    
    NSString *title = @"aTitle";
    NSString *subtitle = @"aSubtitle";
    NSString *type = @"aType";
    NSString *uri = @"aUri";
    NSString *imageUri = @"anImageUri";
    
    NSDictionary *meta1 = @{kZLFileMetadataTitle:title, kZLFileMetadataSubtitle:subtitle, kZLFileMetadataFileType:type, kZLFileMetadataURI:uri, kZLFileMetadataImageURI:imageUri};
    NSDictionary *meta2 = @{kZLFileMetadataTitle:@"wrongTitle", kZLFileMetadataSubtitle:@"wrongSubtitle", kZLFileMetadataFileType:@"wrongType", kZLFileMetadataURI:@"wrongURI", kZLFileMetadataImageURI:@"wrongImageUri"};
    
    [self.database indexFileWithModuleId:moduleId entityId:entityId1 language:language boost:boost searchableStrings:search1 fileMetadata:meta1];
    [self.database indexFileWithModuleId:moduleId entityId:entityId2 language:language boost:boost searchableStrings:search2 fileMetadata:meta2];
    
    NSError *error;
    NSArray *results = [self.database searchFilesWithSearchText:@"hello w" limit:10 offset:0 preferPhraseSearching:YES searchSuggestions:nil error:&error];
    
    XCTAssertNil(error);
    XCTAssertEqual(results.count, 1);
    
    ZLSearchResult *searchResult = [results objectAtIndex:0];
    XCTAssertTrue([searchResult.title isEqualToString:title]);
    XCTAssertTrue([searchResult.subtitle isEqualToString:subtitle]);
    XCTAssertTrue([searchResult.type isEqualToString:type]);
    XCTAssertTrue([searchResult.uri isEqualToString:uri]);
    XCTAssertTrue([searchResult.imageUri isEqualToString:imageUri]);
    XCTAssertTrue([searchResult.entityId isEqualToString:entityId1]);
}

- (void)testSearchRespectsLimit
{
    NSString *moduleId = @"mdoule";
    NSString *language = @"en";
    double boost = 1.0;
    
    NSString *entityId1 = @"entityId1";
    NSString *entityId2 = @"entityId2";
    NSString *entityId3 = @"entityId3";
    NSString *entityId4 = @"entityId4";
    NSString *entityId5 = @"entityId5";
    NSString *entityId6 = @"entityId6";
    NSArray *resultEntityIds = @[entityId1, entityId2, entityId3, entityId4, entityId5];
    
    NSString *searchableString = @"hello world";
    NSDictionary *search1 = @{kZLSearchableStringWeight0:searchableString};
    NSDictionary *search2 = @{kZLSearchableStringWeight1:searchableString};
    NSDictionary *search3 = @{kZLSearchableStringWeight2:searchableString};
    NSDictionary *search4 = @{kZLSearchableStringWeight3:searchableString};
    NSDictionary *search5 = @{kZLSearchableStringWeight4:searchableString};
    NSDictionary *search6 = @{kZLSearchableStringWeight3:@"nope"};
    
    [self.database indexFileWithModuleId:moduleId entityId:entityId1 language:language boost:boost searchableStrings:search1 fileMetadata:nil];
    [self.database indexFileWithModuleId:moduleId entityId:entityId2 language:language boost:boost searchableStrings:search2 fileMetadata:nil];
    [self.database indexFileWithModuleId:moduleId entityId:entityId3 language:language boost:boost searchableStrings:search3 fileMetadata:nil];
    [self.database indexFileWithModuleId:moduleId entityId:entityId4 language:language boost:boost searchableStrings:search4 fileMetadata:nil];
    [self.database indexFileWithModuleId:moduleId entityId:entityId5 language:language boost:boost searchableStrings:search5 fileMetadata:nil];
    [self.database indexFileWithModuleId:moduleId entityId:entityId6 language:language boost:boost searchableStrings:search6 fileMetadata:nil];
    
    NSError *error;
    NSUInteger limit = 2;
    NSArray *results = [self.database searchFilesWithSearchText:@"hello w" limit:limit offset:0 preferPhraseSearching:YES searchSuggestions:nil error:&error];
    
    XCTAssertNil(error);
    XCTAssertEqual(results.count, limit);
    
    for (ZLSearchResult *searchResult in results) {
        XCTAssertTrue([resultEntityIds containsObject:searchResult.entityId]);
    }
}

#pragma mark - Test Helpers

- (void)testStringWithLastWordPrefixedFromString
{
    NSString *oldString = @"this is a test ";
    
    NSString *newString = [ZLSearchDatabase stringWithLastWordHavingPrefixOperatorFromString:oldString];
    
    XCTAssertTrue([newString isEqualToString:@"this is a test*"]);
}

- (void)testDoesFileAlreadyExistDoesExist
{
    NSString *moduleId = @"moduleIdTestOne";
    NSString *entityId = @"entityIdTestOne";
    NSString *language = @"language";
    double boost = 2.3;
    NSString *weightZero = @"weight zero";
    NSString *weightOne = @"weight one";
    NSString *weightTwo = @"weight two";
    NSString *weightThree = @"weight three";
    NSString *weightFour = @"weight four";
    
    NSString *title = @"meta title";
    NSString *subtitle = @"meta subtitle";
    NSString *uri = @"meta uri";
    NSString *type = @"meta type";
    NSString *imageUri = @"meta image uri";
    
    NSDictionary *searchableStrings = @{kZLSearchableStringWeight0:weightZero, kZLSearchableStringWeight1:weightOne, kZLSearchableStringWeight2:weightTwo, kZLSearchableStringWeight3:weightThree, kZLSearchableStringWeight4:weightFour};
    NSDictionary *searchMetadata = @{kZLFileMetadataTitle:title, kZLFileMetadataSubtitle:subtitle, kZLFileMetadataURI:uri, kZLFileMetadataFileType:type, kZLFileMetadataImageURI:imageUri};
    
    [self.database indexFileWithModuleId:moduleId entityId:entityId language:language boost:boost searchableStrings:searchableStrings fileMetadata:searchMetadata];
    
    BOOL doesExist = [self.database doesFileExistWithModuleId:moduleId entityId:entityId];
    XCTAssertTrue(doesExist);
}

- (void)testDoesFileAlreadyExistDoesNotExist
{
    NSString *moduleId = @"moduleIdTestOne";
    NSString *entityId = @"entityIdTestOne";
    
    BOOL doesExist = [self.database doesFileExistWithModuleId:moduleId entityId:entityId];
    XCTAssertFalse(doesExist);
}


@end
