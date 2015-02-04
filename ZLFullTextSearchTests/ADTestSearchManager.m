//
//  ADTestSearchManager.m
//  AgileSDK
//
//  Created by Zack Liston on 1/19/15.
//  Copyright (c) 2015 AgileMD. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>
#import "ZLSearchManager.h"
#import "ZLSearchDatabase.h"
#import "ZLTaskManager.h"
#import "OCMock.h"
#import "ZLSearchTaskWorker.h"
#import "ZLInternalWorkItem.h"
#import "ZLSearchResult.h"
#import "FMDB.h"

@interface ADTestSearchManager : XCTestCase

@end

@interface ZLSearchManager (Test)

@property (nonatomic, strong) NSDictionary *searchDatabaseDictionary;

+ (void)setupFileDirectories;
+ (NSString *)relativeUrlForFileIndexInfoWithModuleId:(NSString *)moduleId fileId:(NSString *)fileId;
+ (void)teardownForTests;

@end

@interface ZLSearchDatabase (Test)

@property (nonatomic, strong) FMDatabaseQueue *queue;

@end


@implementation ADTestSearchManager

- (void)setUp {
    [super setUp];
    [ZLSearchManager teardownForTests];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

#pragma mark - Test sharedInstance

- (void)testSharedInstance
{
    id mockSearchManager = [OCMockObject mockForClass:[ZLSearchManager class]];
    [[mockSearchManager expect] setupFileDirectories];
    ZLSearchManager *manager1 = [ZLSearchManager sharedInstance];
    ZLSearchManager *manager2 = [ZLSearchManager sharedInstance];
    
    XCTAssertNotNil(manager1);
    XCTAssertEqualObjects(manager1, manager2);
    
    [mockSearchManager verify];
    [mockSearchManager stopMocking];
}

#pragma mark - Test searchDatabaseForName

- (void)testSearchDatabaseForNameNoName
{
    ZLSearchManager *manager = [ZLSearchManager new];
    
    ZLSearchDatabase *database = [manager searchDatabaseForName:nil];
    XCTAssertNil(database);
}

- (void)testSearchDatabaseForNameNoMatchingDatabase
{
    ZLSearchManager *manager = [ZLSearchManager new];
    ZLSearchDatabase *database = [ZLSearchDatabase new];
    manager.searchDatabaseDictionary = @{@"key":database};
    
    ZLSearchDatabase *returnedDatabase = [manager searchDatabaseForName:@"n/a"];
    XCTAssertNil(returnedDatabase);
}

- (void)testSearchDatabaseForNameMatchingDatabase
{
    NSString *name = @"dbName";
    
    ZLSearchManager *manager = [ZLSearchManager new];
    ZLSearchDatabase *nonMatchingDatabase = [ZLSearchDatabase new];
    ZLSearchDatabase *matchingDatabase = [ZLSearchDatabase new];
    manager.searchDatabaseDictionary = @{@"key":nonMatchingDatabase, name:matchingDatabase};
    
    ZLSearchDatabase *returnedDatabase = [manager searchDatabaseForName:name];
    XCTAssertNotNil(returnedDatabase);
    XCTAssertEqualObjects(returnedDatabase, matchingDatabase);
}

#pragma mark - Test setupSearchDatabaseWithName

- (void)testSetupSearchDatabaseWithNameNoName
{
    ZLSearchManager *manager = [ZLSearchManager new];
    XCTAssertNil(manager.searchDatabaseDictionary);
    
    [manager setupSearchDatabaseWithName:nil];
    
     XCTAssertNil(manager.searchDatabaseDictionary);
}

- (void)testSetupSearchDatabaseWithNameSuccess
{
    NSString *dbName = @"nameo";
    ZLSearchManager *manager = [ZLSearchManager new];
    XCTAssertNil(manager.searchDatabaseDictionary);
    
    [manager setupSearchDatabaseWithName:dbName];
    ZLSearchDatabase *database = [manager.searchDatabaseDictionary objectForKey:dbName];
    XCTAssertNotNil(database);
    XCTAssertTrue([database.queue.path rangeOfString:dbName].location != NSNotFound);
    XCTAssertEqual(manager.searchDatabaseDictionary.allValues.count, 1);
}

- (void)testSetupSearchDatabaseWithNameDuplicate
{
    NSString *dbName = @"nameo";
    ZLSearchManager *manager = [ZLSearchManager new];
    XCTAssertNil(manager.searchDatabaseDictionary);
    
    [manager setupSearchDatabaseWithName:dbName];
    [manager setupSearchDatabaseWithName:dbName];
    
    ZLSearchDatabase *database = [manager.searchDatabaseDictionary objectForKey:dbName];
    XCTAssertNotNil(database);
    XCTAssertTrue([database.queue.path rangeOfString:dbName].location != NSNotFound);
    XCTAssertEqual(manager.searchDatabaseDictionary.allValues.count, 1);
}

- (void)testSetupSearchDatabaseWithNameMutliple
{
    NSString *dbName = @"nameo";
    NSString *dbName2 = @"name2";
    ZLSearchManager *manager = [ZLSearchManager new];
    XCTAssertNil(manager.searchDatabaseDictionary);
    
    [manager setupSearchDatabaseWithName:dbName];
    [manager setupSearchDatabaseWithName:dbName2];
    
    ZLSearchDatabase *database = [manager.searchDatabaseDictionary objectForKey:dbName];
    XCTAssertNotNil(database);
    XCTAssertTrue([database.queue.path rangeOfString:dbName].location != NSNotFound);
    
    ZLSearchDatabase *database2 = [manager.searchDatabaseDictionary objectForKey:dbName2];
    XCTAssertNotNil(database2);
    XCTAssertTrue([database2.queue.path rangeOfString:dbName2].location != NSNotFound);
    
    XCTAssertEqual(manager.searchDatabaseDictionary.allValues.count, 2);
}

#pragma mark - Test setup file directories

- (void)testSetupFileDirectories
{
    
    NSString *cachesDirectory = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
    NSString *searchIndexDirectory = [cachesDirectory stringByAppendingPathComponent:@"ZLSearchIndexInfo"];
    
    NSFileManager *fileManager = [NSFileManager new];
    id mockFileManager = [OCMockObject partialMockForObject:fileManager];
    
    [[mockFileManager expect] createDirectoryAtPath:searchIndexDirectory withIntermediateDirectories:YES attributes:nil error:[OCMArg anyObjectRef]];
    
    id mockFileManagerClass = [OCMockObject mockForClass:[NSFileManager class]];
    [[[mockFileManagerClass stub] andReturn:mockFileManager] defaultManager];
    
    [ZLSearchManager setupFileDirectories];
    
    [mockFileManager verify];
    [mockFileManagerClass stopMocking];
}

#pragma mark - Test save index file info to file

- (void)testSaveIndexFileInfoNoModuleId
{
    id mockArchiever = [OCMockObject mockForClass:[NSKeyedArchiver class]];
    [[mockArchiever reject] archiveRootObject:[OCMArg any] toFile:[OCMArg any]];
    
    NSError *error;
    NSString *url = [ZLSearchManager saveIndexFileInfoToFileWithModuleId:nil fileId:@"file" language:@"en" boost:1.2 searchableStrings:@{kZLSearchableStringWeight0:@"search"} fileMetadata:nil error:&error];
    
    XCTAssertNil(url);
    XCTAssertNotNil(error);
    
    [mockArchiever verify];
    [mockArchiever stopMocking];
}

- (void)testSaveIndexFileInfoNoEntityId
{
    id mockArchiever = [OCMockObject mockForClass:[NSKeyedArchiver class]];
    [[mockArchiever reject] archiveRootObject:[OCMArg any] toFile:[OCMArg any]];
    
    NSError *error;
    NSString *url = [ZLSearchManager saveIndexFileInfoToFileWithModuleId:@"modu" fileId:nil language:@"en" boost:1.2 searchableStrings:@{kZLSearchableStringWeight0:@"search"} fileMetadata:nil error:&error];
    
    XCTAssertNil(url);
    XCTAssertNotNil(error);
    
    [mockArchiever verify];
    [mockArchiever stopMocking];

}

- (void)testSaveIndexFileInfoNoLanguage
{
    id mockArchiever = [OCMockObject mockForClass:[NSKeyedArchiver class]];
    [[mockArchiever reject] archiveRootObject:[OCMArg any] toFile:[OCMArg any]];
    
    NSError *error;
    NSString *url = [ZLSearchManager saveIndexFileInfoToFileWithModuleId:@"modu" fileId:@"file" language:nil boost:1.2 searchableStrings:@{kZLSearchableStringWeight0:@"search"} fileMetadata:nil error:&error];
    
    XCTAssertNil(url);
    XCTAssertNotNil(error);
    
    [mockArchiever verify];
    [mockArchiever stopMocking];
}

- (void)testSaveIndexFileInfoNoAppropriateSearchableStrings
{
    id mockArchiever = [OCMockObject mockForClass:[NSKeyedArchiver class]];
    [[mockArchiever reject] archiveRootObject:[OCMArg any] toFile:[OCMArg any]];
    
    NSError *error;
    NSString *url = [ZLSearchManager saveIndexFileInfoToFileWithModuleId:@"modu" fileId:@"file" language:@"hello" boost:1.2 searchableStrings:@{@"invalidField":@"search"} fileMetadata:nil error:&error];
    
    XCTAssertNil(url);
    XCTAssertNotNil(error);
    
    [mockArchiever verify];
    [mockArchiever stopMocking];
}

- (void)testSaveIndexFileSuccess
{
    NSString *moduleId = @"moduleIdasdf";
    NSString *fileId = @"idForEntity";
    NSString *language = @"english";
    double boost = 883.2;
    NSDictionary *searchableStrings = @{kZLSearchableStringWeight4:@"searchMe"};
    NSDictionary *fileMetaData = @{kZLFileMetadataTitle:@"title"};
    
    NSString *relativeurl = @"fileLocation.asdf.dk";
    NSString *absoluteUrl = @"absoluteYo";
     id mockSearchManager = [OCMockObject mockForClass:[ZLSearchManager class]];
    [[[mockSearchManager expect] andReturn:relativeurl] relativeUrlForFileIndexInfoWithModuleId:moduleId fileId:fileId];
    [[[mockSearchManager expect] andReturn:absoluteUrl] absoluteUrlForFileInfoFromRelativeUrl:relativeurl];
    
    id mockArchiever = [OCMockObject mockForClass:[NSKeyedArchiver class]];
    
    [[[mockArchiever expect] andReturnValue:OCMOCK_VALUE(YES)] archiveRootObject:[OCMArg checkWithBlock:^BOOL(id obj) {
        NSDictionary *info = (NSDictionary *)obj;
        
        NSString *taskModuleId = [info objectForKey:kZLSearchTWModuleIdKey];
        NSString *taskEntityId = [info objectForKey:kZLSearchTWEntityIdKey];
        NSString *taskLanguage = [info objectForKey:kZLSearchTWLanguageKey];
        double taskBoost = [[info objectForKey:kZLSearchTWBoostKey] doubleValue];
        NSDictionary *taskSearchableStrings = [info objectForKey:kZLSearchTWSearchableStringsKey];
        NSDictionary *taskFileMetadata = [info objectForKey:kZLSearchTWFileMetadataKey];
        
        XCTAssertTrue([taskModuleId isEqualToString:moduleId]);
        XCTAssertTrue([taskEntityId isEqualToString:fileId]);
        XCTAssertTrue([taskLanguage isEqualToString:language]);
        XCTAssertEqualWithAccuracy(taskBoost, boost, 0.01);
        XCTAssertTrue([taskSearchableStrings isEqualToDictionary:searchableStrings]);
        XCTAssertTrue([taskFileMetadata isEqualToDictionary:taskFileMetadata]);
        
        return YES;
    }] toFile:absoluteUrl];
    
    NSError *error;
    NSString *returnedUrl = [ZLSearchManager saveIndexFileInfoToFileWithModuleId:moduleId fileId:fileId language:language boost:boost searchableStrings:searchableStrings fileMetadata:fileMetaData error:&error];
    
    XCTAssertNil(error);
    XCTAssertTrue([returnedUrl isEqualToString:relativeurl]);
    
   
    [mockArchiever verify];
    [mockArchiever stopMocking];
    [mockSearchManager verify];
    [mockSearchManager stopMocking];
}

- (void)testSaveIndexFileFailure
{
    NSString *moduleId = @"moduleIdasdf";
    NSString *fileId = @"idForEntity";
    NSString *language = @"english";
    double boost = 883.2;
    NSDictionary *searchableStrings = @{kZLSearchableStringWeight4:@"searchMe"};
    NSDictionary *fileMetaData = @{kZLFileMetadataTitle:@"title"};
    
    NSString *fileLocation = @"fileLocation.asdf.dk";
    
    id mockSearchManager = [OCMockObject mockForClass:[ZLSearchManager class]];
    [[[mockSearchManager expect] andReturn:fileLocation] relativeUrlForFileIndexInfoWithModuleId:moduleId fileId:fileId];
    
    id mockArchiever = [OCMockObject mockForClass:[NSKeyedArchiver class]];
    [[[mockArchiever expect] andReturnValue:OCMOCK_VALUE(NO)] archiveRootObject:[OCMArg any] toFile:[OCMArg any]];
    
    NSError *error;
    NSString *returnedUrl = [ZLSearchManager saveIndexFileInfoToFileWithModuleId:moduleId fileId:fileId language:language boost:boost searchableStrings:searchableStrings fileMetadata:fileMetaData error:&error];
    
    XCTAssertNotNil(error);
    XCTAssertNil(returnedUrl);
    
    [mockSearchManager verify];
    [mockSearchManager stopMocking];
    [mockArchiever verify];
    [mockArchiever stopMocking];
}

#pragma mark - Test queue index file collection

- (void)testIndexFileCollectionSuccess
{
    NSString *url1 = @"url1";
    NSString *url2 = @"url2";
    NSString *dbName = @"dbName";
    
    NSArray *urlArray = @[url1, url2];
    
    ZLSearchManager *searchManager = [ZLSearchManager new];
    
    ZLTaskManager  *taskManager = [[ZLTaskManager  alloc] init];
    id mockTaskManager = [OCMockObject partialMockForObject:taskManager];
    
    id mockTaskManagerClass = [OCMockObject mockForClass:[ZLTaskManager  class]];
    [[[mockTaskManagerClass stub] andReturn:mockTaskManager] sharedInstance];
    
    [[[mockTaskManager expect] andReturnValue:OCMOCK_VALUE(YES)] queueTask:[OCMArg checkWithBlock:^BOOL(id obj) {
        ZLTask *task = (ZLTask *)obj;
        XCTAssertTrue([task.taskType isEqualToString:kTaskTypeSearch]);
        XCTAssertEqual(task.majorPriority, kMajorPrioritySearch);
        XCTAssertEqual(task.minorPriority, kMinorPrioritySearchIndexFile);
        XCTAssertEqual(task.requiresInternet, NO);
        XCTAssertEqual(task.maxNumberOfRetries, kZLDefaultMaxRetryCount);
        XCTAssertTrue(task.shouldHoldAndRestartAfterMaxRetries);
        XCTAssertTrue([[task.jsonData objectForKey:kZLSearchTWDatabaseNameKey] isEqualToString:dbName]);
        
        ZLSearchTWActionType taskActionType = [[task.jsonData objectForKey:kZLSearchTWActionTypeKey] integerValue];
        NSArray *receivedUrlArray = [task.jsonData objectForKey:kZLSearchTWFileInfoUrlArrayKey];
        
        
        XCTAssertEqual(taskActionType, ZLSearchTWActionTypeIndexFile);
        XCTAssertTrue([receivedUrlArray isEqualToArray:urlArray]);
        return YES;
    }]];
    
    BOOL success = [searchManager queueIndexFileCollectionWithURLArray:urlArray searchDatabaseName:dbName];
    XCTAssertTrue(success);
    
    [mockTaskManager verify];
    [mockTaskManagerClass stopMocking];
}

- (void)testIndexFileCollectionFailure
{
    NSString *url1 = @"url1";
    NSString *url2 = @"url2";
    NSString *dbName = @"dbName";
    
    NSArray *urlArray = @[url1, url2];
    
    ZLSearchManager *searchManager = [ZLSearchManager new];
    
    ZLTaskManager  *taskManager = [[ZLTaskManager  alloc] init];
    id mockTaskManager = [OCMockObject partialMockForObject:taskManager];
    
    id mockTaskManagerClass = [OCMockObject mockForClass:[ZLTaskManager  class]];
    [[[mockTaskManagerClass stub] andReturn:mockTaskManager] sharedInstance];
    
    [[[mockTaskManager expect] andReturnValue:OCMOCK_VALUE(NO)] queueTask:[OCMArg any]];
    
    BOOL success = [searchManager queueIndexFileCollectionWithURLArray:urlArray searchDatabaseName:dbName];
    XCTAssertFalse(success);
    
    [mockTaskManager verify];
    [mockTaskManagerClass stopMocking];
}

- (void)testIndexFileCollectionEmptyArray
{
    NSString *dbName = @"dbName";
    NSArray *urlArray = @[];
    
    ZLSearchManager *searchManager = [ZLSearchManager new];
    
    ZLTaskManager  *taskManager = [[ZLTaskManager  alloc] init];
    id mockTaskManager = [OCMockObject partialMockForObject:taskManager];
    
    id mockTaskManagerClass = [OCMockObject mockForClass:[ZLTaskManager  class]];
    [[[mockTaskManagerClass stub] andReturn:mockTaskManager] sharedInstance];
    
    [[mockTaskManager reject] queueTask:[OCMArg any]];
    
    BOOL success = [searchManager queueIndexFileCollectionWithURLArray:urlArray searchDatabaseName:dbName];
    XCTAssertFalse(success);
    
    [mockTaskManager verify];
    [mockTaskManagerClass stopMocking];
}

#pragma mark - Test queueIndexFile

- (void)testQueueIndexFileSuccess
{
    NSString *fileLocation = @"filething";
    NSString *dbName = @"dbName";
    
    NSString *moduleId = @"moduleIdasdf";
    NSString *fileId = @"idForEntity";
    NSString *language = @"english";
    double boost = 883.2;
    NSDictionary *searchableStrings = @{kZLSearchableStringWeight4:@"searchMe"};
    NSDictionary *fileMetaData = @{kZLFileMetadataTitle:@"title"};
    
    ZLSearchManager *searchManager = [ZLSearchManager new];
    id mockSearchManager = [OCMockObject partialMockForObject:searchManager];
    
    id mockSearchManagerClass = [OCMockObject mockForClass:[ZLSearchManager class]];
    [[[mockSearchManagerClass stub] andReturn:mockSearchManager] sharedInstance];
    
    [[[mockSearchManagerClass expect] andReturn:fileLocation] saveIndexFileInfoToFileWithModuleId:moduleId fileId:fileId language:language boost:boost searchableStrings:searchableStrings fileMetadata:fileMetaData error:[OCMArg anyObjectRef]];
    [[[mockSearchManager expect] andReturnValue:OCMOCK_VALUE(YES)] queueIndexFileCollectionWithURLArray:[OCMArg checkWithBlock:^BOOL(id obj) {
        NSArray *urlArray = (NSArray *)obj;
        XCTAssertEqual(urlArray.count, 1);
        NSString *expectedUrl = [urlArray firstObject];
        
        XCTAssertTrue([expectedUrl isEqualToString:fileLocation]);
        
        return YES;
    }] searchDatabaseName:dbName];
    
    BOOL success = [searchManager queueIndexFileWithModuleId:moduleId fileId:fileId language:language boost:boost searchableStrings:searchableStrings fileMetadata:fileMetaData searchDatabaseName:dbName];
    
    XCTAssertTrue(success);
    
    [mockSearchManagerClass verify];
    [mockSearchManagerClass stopMocking];
    [mockSearchManager verify];
}

- (void)testQueueIndexFileSaveInfoError
{
    NSString *fileLocation = @"filething";
    NSString *dbName = @"dbname";
    NSString *moduleId = @"moduleIdasdf";
    NSString *fileId = @"idForEntity";
    NSString *language = @"english";
    double boost = 883.2;
    NSDictionary *searchableStrings = @{kZLSearchableStringWeight4:@"searchMe"};
    NSDictionary *fileMetaData = @{kZLFileMetadataTitle:@"title"};
    
    ZLSearchManager *searchManager = [ZLSearchManager new];
    id mockSearchManager = [OCMockObject partialMockForObject:searchManager];
    
    id mockSearchManagerClass = [OCMockObject mockForClass:[ZLSearchManager class]];
    [[[mockSearchManagerClass stub] andReturn:mockSearchManager] sharedInstance];
    
    NSError *fakeError = [NSError errorWithDomain:@"FakeError" code:-123 userInfo:nil];
    
    [[[mockSearchManagerClass expect] andReturn:fileLocation] saveIndexFileInfoToFileWithModuleId:moduleId fileId:fileId language:language boost:boost searchableStrings:searchableStrings fileMetadata:fileMetaData error:[OCMArg setTo:fakeError]];
    [[mockSearchManager reject] queueIndexFileCollectionWithURLArray:[OCMArg any] searchDatabaseName:dbName];
    
    BOOL success = [searchManager queueIndexFileWithModuleId:moduleId fileId:fileId language:language boost:boost searchableStrings:searchableStrings fileMetadata:fileMetaData searchDatabaseName:dbName];
    
    XCTAssertFalse(success);
    
    [mockSearchManagerClass verify];
    [mockSearchManagerClass stopMocking];
    [mockSearchManager verify];
}

- (void)testQueueIndexFileQueueError
{
    NSString *fileLocation = @"filething";
    
    NSString *dbName = @"dbName";
    NSString *moduleId = @"moduleIdasdf";
    NSString *fileId = @"idForEntity";
    NSString *language = @"english";
    double boost = 883.2;
    NSDictionary *searchableStrings = @{kZLSearchableStringWeight4:@"searchMe"};
    NSDictionary *fileMetaData = @{kZLFileMetadataTitle:@"title"};
    
    ZLSearchManager *searchManager = [ZLSearchManager new];
    id mockSearchManager = [OCMockObject partialMockForObject:searchManager];
    
    id mockSearchManagerClass = [OCMockObject mockForClass:[ZLSearchManager class]];
    [[[mockSearchManagerClass stub] andReturn:mockSearchManager] sharedInstance];
    
    [[[mockSearchManagerClass expect] andReturn:fileLocation] saveIndexFileInfoToFileWithModuleId:moduleId fileId:fileId language:language boost:boost searchableStrings:searchableStrings fileMetadata:fileMetaData error:[OCMArg anyObjectRef]];
    [[[mockSearchManager expect] andReturnValue:OCMOCK_VALUE(NO)] queueIndexFileCollectionWithURLArray:[OCMArg checkWithBlock:^BOOL(id obj) {
        NSArray *urlArray = (NSArray *)obj;
        XCTAssertEqual(urlArray.count, 1);
        NSString *expectedUrl = [urlArray firstObject];
        
        XCTAssertTrue([expectedUrl isEqualToString:fileLocation]);
        
        return YES;
    }] searchDatabaseName:dbName];
    
    BOOL success = [searchManager queueIndexFileWithModuleId:moduleId fileId:fileId language:language boost:boost searchableStrings:searchableStrings fileMetadata:fileMetaData searchDatabaseName:dbName];
    
    XCTAssertFalse(success);
    
    [mockSearchManagerClass verify];
    [mockSearchManagerClass stopMocking];
    [mockSearchManager verify];
}


#pragma mark - Test queueRemoveFile

- (void)testQueueRemoveFileNoModuleId
{
    ZLSearchManager *manager = [ZLSearchManager new];
    
    ZLTaskManager  *taskManager = [[ZLTaskManager  alloc] init];
    id mockTaskManager = [OCMockObject partialMockForObject:taskManager];
    
    id mockTaskManagerClass = [OCMockObject mockForClass:[ZLTaskManager  class]];
    [[[mockTaskManagerClass stub] andReturn:mockTaskManager] sharedInstance];
    [[mockTaskManager reject] queueTask:[OCMArg any]];
    
    BOOL success = [manager queueRemoveFileWithModuleId:nil entityId:@"ent" searchDatabaseName:@"any"];
    
    XCTAssertFalse(success);
    
    [mockTaskManager verify];
    [mockTaskManagerClass stopMocking];
}

- (void)testQueueRemoveFileNoEntityId
{
    ZLSearchManager *manager = [ZLSearchManager new];
    
    ZLTaskManager  *taskManager = [[ZLTaskManager  alloc] init];
    id mockTaskManager = [OCMockObject partialMockForObject:taskManager];
    
    id mockTaskManagerClass = [OCMockObject mockForClass:[ZLTaskManager  class]];
    [[[mockTaskManagerClass stub] andReturn:mockTaskManager] sharedInstance];
    [[mockTaskManager reject] queueTask:[OCMArg any]];
    
    BOOL success = [manager queueRemoveFileWithModuleId:@"mdoul" entityId:nil searchDatabaseName:@"any"];
    
    XCTAssertFalse(success);
    
    [mockTaskManager verify];
    [mockTaskManagerClass stopMocking];
}

- (void)testQueueRemoveFile
{
    ZLSearchManager *searchManager = [ZLSearchManager new];
    NSString *dbName = @"dbName";
    
    ZLTaskManager  *taskManager = [[ZLTaskManager  alloc] init];
    id mockTaskManager = [OCMockObject partialMockForObject:taskManager];
    
    id mockTaskManagerClass = [OCMockObject mockForClass:[ZLTaskManager  class]];
    [[[mockTaskManagerClass stub] andReturn:mockTaskManager] sharedInstance];
    
    NSString *moduleId = @"moduleIdasdf";
    NSString *entityId = @"idForEntity";
    
    [[[mockTaskManager expect] andReturnValue:OCMOCK_VALUE(YES)] queueTask:[OCMArg checkWithBlock:^BOOL(id obj) {
        ZLTask *task = (ZLTask *)obj;
        
        XCTAssertTrue([task.taskType isEqualToString:kTaskTypeSearch]);
        XCTAssertEqual(task.majorPriority, kMajorPrioritySearch);
        XCTAssertEqual(task.minorPriority, kMinorPrioritySearchRemoveFile);
        XCTAssertEqual(task.requiresInternet, NO);
        XCTAssertEqual(task.maxNumberOfRetries, kZLDefaultMaxRetryCount);
        XCTAssertTrue(task.shouldHoldAndRestartAfterMaxRetries);
        
         XCTAssertTrue([[task.jsonData objectForKey:kZLSearchTWDatabaseNameKey] isEqualToString:dbName]);
        ZLSearchTWActionType taskActionType = [[task.jsonData objectForKey:kZLSearchTWActionTypeKey] integerValue];
        NSString *taskModuleId = [task.jsonData objectForKey:kZLSearchTWModuleIdKey];
        NSString *taskEntityId = [task.jsonData objectForKey:kZLSearchTWEntityIdKey];
        
        XCTAssertEqual(taskActionType, ZLSearchTWActionTypeRemoveFileFromIndex);
        XCTAssertTrue([taskModuleId isEqualToString:moduleId]);
        XCTAssertTrue([taskEntityId isEqualToString:entityId]);
        
        return YES;
    }]];
    
    BOOL success = [searchManager queueRemoveFileWithModuleId:moduleId entityId:entityId searchDatabaseName:dbName];
    
    XCTAssertTrue(success);
    [mockTaskManager verify];
    [mockTaskManagerClass stopMocking];
}

- (void)testQueueRemoveFileFail
{
    ZLSearchManager *searchManager = [ZLSearchManager new];
    
    ZLTaskManager  *taskManager = [[ZLTaskManager  alloc] init];
    id mockTaskManager = [OCMockObject partialMockForObject:taskManager];
    
    id mockTaskManagerClass = [OCMockObject mockForClass:[ZLTaskManager  class]];
    [[[mockTaskManagerClass stub] andReturn:mockTaskManager] sharedInstance];
    
    NSString *moduleId = @"moduleIdasdf";
    NSString *entityId = @"idForEntity";
    
    [[[mockTaskManager expect] andReturnValue:OCMOCK_VALUE(NO)] queueTask:[OCMArg any]];
    
    BOOL success = [searchManager queueRemoveFileWithModuleId:moduleId entityId:entityId searchDatabaseName:@"any"];
    
    XCTAssertFalse(success);
    [mockTaskManager verify];
    [mockTaskManagerClass stopMocking];
}

#pragma mark - Test resetSearchDatabase

- (void)testResetSearchDatabaseSuccess
{
    NSString *dbName = @"dbName";
    ZLSearchManager *manager = [ZLSearchManager new];
   
    ZLTaskManager  *taskManager = [[ZLTaskManager  alloc] init];
    id mockTaskManager = [OCMockObject partialMockForObject:taskManager];
    
    id mockTaskManagerClass = [OCMockObject mockForClass:[ZLTaskManager  class]];
    [[[mockTaskManagerClass stub] andReturn:mockTaskManager] sharedInstance];
    [mockTaskManager setExpectationOrderMatters:YES];
    
    [[mockTaskManager expect] stopAndWaitWithNetworkCancellationBlock:[OCMArg any]];
    [[mockTaskManager expect] removeTasksOfType:kTaskTypeSearch];
    [[mockTaskManager expect] resume];
    
    ZLSearchDatabase *database = [ZLSearchDatabase new];
    id mockSearchDatabase = [OCMockObject partialMockForObject:database];
    [[[mockSearchDatabase expect] andReturnValue:OCMOCK_VALUE(YES)] resetDatabase];
    
    id mockSearchManager = [OCMockObject partialMockForObject:manager];
    [[[mockSearchManager stub] andReturn:mockSearchDatabase] searchDatabaseForName:dbName];
    
    BOOL success = [manager resetSearchDatabaseWithName:dbName];
    XCTAssertTrue(success);
    
    [mockSearchDatabase verify];
    [mockTaskManager verify];
    [mockTaskManagerClass stopMocking];
}

- (void)testResetSearchDatabaseFailure
{
    NSString *dbName = @"dbNaee";
    ZLSearchManager *manager = [ZLSearchManager new];
    
    ZLTaskManager  *taskManager = [[ZLTaskManager  alloc] init];
    id mockTaskManager = [OCMockObject partialMockForObject:taskManager];
    
    id mockTaskManagerClass = [OCMockObject mockForClass:[ZLTaskManager  class]];
    [[[mockTaskManagerClass stub] andReturn:mockTaskManager] sharedInstance];
    [mockTaskManager setExpectationOrderMatters:YES];
    
    [[mockTaskManager expect] stopAndWaitWithNetworkCancellationBlock:[OCMArg any]];
    [[mockTaskManager expect] removeTasksOfType:kTaskTypeSearch];
    [[mockTaskManager expect] resume];
    
    ZLSearchDatabase *database = [ZLSearchDatabase new];
    id mockSearchDatabase = [OCMockObject partialMockForObject:database];
    [[[mockSearchDatabase expect] andReturnValue:OCMOCK_VALUE(NO)] resetDatabase];
    
    id mockSearchManager = [OCMockObject partialMockForObject:manager];
    [[[mockSearchManager stub] andReturn:mockSearchDatabase] searchDatabaseForName:dbName];
    
    BOOL success = [manager resetSearchDatabaseWithName:dbName];
    
    XCTAssertFalse(success);
    
    [mockSearchDatabase verify];
    [mockSearchDatabase stopMocking];
    [mockTaskManager verify];
    [mockTaskManagerClass stopMocking];
}

#pragma mark - Test relativeUrl for file index info

- (void)testRelativeUrlForFileIndexInfo
{
    NSString *moduleId = @"msdif";
    NSString *fileId = @"fileadsf";
    
    NSString *expectedUrl = [NSString stringWithFormat:@"ZLSearchIndexInfo/%@.%@.json", moduleId, fileId];
    
    NSString *url = [ZLSearchManager relativeUrlForFileIndexInfoWithModuleId:moduleId fileId:fileId];
    
    XCTAssertTrue([expectedUrl isEqualToString:url]);
}

- (void)testRelativeUrlForFileIndexInfoNoModuleId
{
    NSString *moduleId = @"";
    NSString *fileId = @"sdfi";
    
    NSString *url = [ZLSearchManager relativeUrlForFileIndexInfoWithModuleId:moduleId fileId:fileId];
    XCTAssertNil(url);
}

- (void)testRelativeUrlForFileIndexInfoNoFileId
{
    NSString *moduleId = @"mod";
    NSString *fileId = nil;
    
    NSString *url = [ZLSearchManager relativeUrlForFileIndexInfoWithModuleId:moduleId fileId:fileId];
    XCTAssertNil(url);
}
#pragma mark - Test searchFiles

- (void)testSearchFilesSuccess
{
    NSString *dbName = @"dbNamee";
    
    ZLSearchManager *manager = [ZLSearchManager new];
    NSString *searchText = @"sear";
    NSString *formattedSearchText = @"format";
    ZLSearchResult *searchResult1 = [ZLSearchResult new];
    ZLSearchResult *searchResult2 = [ZLSearchResult new];
    NSArray *expectedResults = @[searchResult1, searchResult2];
    NSArray *suggestions = @[@"one", @"two"];
    
    NSUInteger limit = 3;
    NSUInteger offset = 1;
    
    ZLSearchDatabase *database = [ZLSearchDatabase new];                 
    id mockSearchDatabase = [OCMockObject partialMockForObject:database];
    [[[mockSearchDatabase expect] andReturn:expectedResults] searchFilesWithSearchText:formattedSearchText limit:limit offset:offset searchSuggestions:[OCMArg setTo:suggestions] error:[OCMArg anyObjectRef]];
    
    id mockSearchManager = [OCMockObject partialMockForObject:manager];
    [[[mockSearchManager stub] andReturn:mockSearchDatabase] searchDatabaseForName:dbName];

    id mockSearchBackupDelegate = [OCMockObject mockForProtocol:@protocol(ZLSearchBackupProtocol)];
    [[mockSearchBackupDelegate reject] backupSearchResultsForSearchText:formattedSearchText limit:limit offset:offset];
    manager.backupSearchDelegate = mockSearchBackupDelegate;

    
    XCTestExpectation *completionBlockExpectation = [self expectationWithDescription:@"completion block expectation"];
    ZLSearchCompletionBlock completionBlock = ^void(NSArray *results, NSArray *searchSuggestions, NSError *error) {
        XCTAssertTrue([NSThread isMainThread]);
        XCTAssertTrue([expectedResults isEqualToArray:results]);
        XCTAssertTrue([searchSuggestions isEqualToArray:suggestions]);
        XCTAssertNil(error);
        [completionBlockExpectation fulfill];
    };
    
    
    id mockSearchDatabaseClass = [OCMockObject mockForClass:[ZLSearchDatabase class]];
    [[[mockSearchDatabaseClass expect] andReturn:formattedSearchText] searchableStringFromString:searchText];
    
    BOOL success = [manager searchFilesWithSearchText:searchText limit:limit offset:offset completionBlock:completionBlock searchDatabaseName:dbName];
    XCTAssertTrue(success);
    
    [self waitForExpectationsWithTimeout:1.0 handler:nil];
    
    [mockSearchBackupDelegate verify];
    [mockSearchBackupDelegate stopMocking];
    [mockSearchDatabase verify];
    [mockSearchDatabaseClass verify];
    [mockSearchDatabaseClass stopMocking];
}

- (void)testSearchFilesZeroResults
{
    NSString *dbName = @"dbName";
    
    ZLSearchManager *manager = [ZLSearchManager new];
    NSString *searchText = @"sear";
    NSString *formattedSearchText = @"format";
    ZLSearchResult *searchResult1 = [ZLSearchResult new];
    ZLSearchResult *searchResult2 = [ZLSearchResult new];
    NSArray *expectedResults = @[];
    NSArray *backupResults = @[searchResult1, searchResult2];
    
    NSUInteger limit = 3;
    NSUInteger offset = 1;
    
    ZLSearchDatabase *database = [ZLSearchDatabase new];
    id mockSearchDatabase = [OCMockObject partialMockForObject:database];
    [[[mockSearchDatabase expect] andReturn:expectedResults] searchFilesWithSearchText:formattedSearchText limit:limit offset:offset searchSuggestions:[OCMArg anyObjectRef] error:[OCMArg anyObjectRef]];
    
    id mockSearchManager = [OCMockObject partialMockForObject:manager];
    [[[mockSearchManager stub] andReturn:mockSearchDatabase] searchDatabaseForName:dbName];
   
    
    id mockSearchBackupDelegate = [OCMockObject mockForProtocol:@protocol(ZLSearchBackupProtocol)];
    [[[mockSearchBackupDelegate expect] andReturn:backupResults] backupSearchResultsForSearchText:formattedSearchText limit:limit offset:offset];
    manager.backupSearchDelegate = mockSearchBackupDelegate;
    
    XCTestExpectation *completionBlockExpectation = [self expectationWithDescription:@"completion block expectation"];
    ZLSearchCompletionBlock completionBlock = ^void(NSArray *results, NSArray *searchSuggestions, NSError *error) {
        XCTAssertTrue([NSThread isMainThread]);
        XCTAssertTrue([backupResults isEqualToArray:results]);
        XCTAssertNil(error);
        [completionBlockExpectation fulfill];
    };
    
    id mockSearchDatabaseClass = [OCMockObject mockForClass:[ZLSearchDatabase class]];
    [[[mockSearchDatabaseClass expect] andReturn:formattedSearchText] searchableStringFromString:searchText];

    BOOL success = [manager searchFilesWithSearchText:searchText limit:limit offset:offset completionBlock:completionBlock searchDatabaseName:dbName];
    XCTAssertTrue(success);
    
    [self waitForExpectationsWithTimeout:1.0 handler:nil];
    
    [mockSearchBackupDelegate verify];
    [mockSearchBackupDelegate stopMocking];
    [mockSearchDatabase verify];
    [mockSearchDatabaseClass verify];
    [mockSearchDatabaseClass stopMocking];
}

- (void)testSearchFilesError
{
    NSString *dbName = @"dbName";
    ZLSearchManager *manager = [ZLSearchManager new];
    NSString *searchText = @"sear";
    NSString *formattedSearchText = @"format";
    ZLSearchResult *searchResult1 = [ZLSearchResult new];
    ZLSearchResult *searchResult2 = [ZLSearchResult new];
    NSArray *expectedResults = @[searchResult1, searchResult2];
    NSUInteger limit = 3;
    NSUInteger offset = 1;
    
    NSError *fakeError = [NSError errorWithDomain:@"FakeError" code:-123 userInfo:nil];
    
    
    ZLSearchDatabase *database = [ZLSearchDatabase new];
    id mockSearchDatabase = [OCMockObject partialMockForObject:database];
    [[[mockSearchDatabase expect] andReturn:expectedResults] searchFilesWithSearchText:formattedSearchText limit:limit offset:offset searchSuggestions:[OCMArg anyObjectRef] error:[OCMArg setTo:fakeError]];
   
    id mockSearchManager = [OCMockObject partialMockForObject:manager];
    [[[mockSearchManager stub] andReturn:mockSearchDatabase] searchDatabaseForName:dbName];

    XCTestExpectation *completionBlockExpectation = [self expectationWithDescription:@"completion block expectation"];
    ZLSearchCompletionBlock completionBlock = ^void(NSArray *results, NSArray *searchSuggestions, NSError *error) {
        XCTAssertTrue([NSThread isMainThread]);
        XCTAssertNil(results);
        XCTAssertNotNil(error);
        XCTAssertEqualObjects(error, fakeError);
        [completionBlockExpectation fulfill];
    };
    
    id mockSearchDatabaseClass = [OCMockObject mockForClass:[ZLSearchDatabase class]];
    [[[mockSearchDatabaseClass expect] andReturn:formattedSearchText] searchableStringFromString:searchText];
    
    BOOL success = [manager searchFilesWithSearchText:searchText limit:limit offset:offset completionBlock:completionBlock searchDatabaseName:dbName];
    XCTAssertTrue(success);
    
    [self waitForExpectationsWithTimeout:1.0 handler:nil];
    
    [mockSearchDatabase verify];
    [mockSearchDatabaseClass verify];
    [mockSearchDatabaseClass stopMocking];
}

- (void)testSearchFilesZeroLimit
{
    NSString *dbName = @"dbNamee";
    ZLSearchManager *manager = [ZLSearchManager new];
    NSString *searchText = @"sear";
    NSUInteger limit = 0;
    NSUInteger offset = 11;
    
    ZLSearchDatabase *database = [ZLSearchDatabase new];
    id mockSearchDatabase = [OCMockObject partialMockForObject:database];
    [[mockSearchDatabase reject] searchFilesWithSearchText:[OCMArg any] limit:limit offset:offset searchSuggestions:[OCMArg anyObjectRef] error:[OCMArg anyObjectRef]];
    
    id mockSearchManager = [OCMockObject partialMockForObject:manager];
    [[[mockSearchManager stub] andReturn:mockSearchDatabase] searchDatabaseForName:dbName];
    
    
    ZLSearchCompletionBlock completionBlock = ^void(NSArray *results, NSArray *searchSuggestions, NSError *error) {
        XCTFail(@"The completion block should not execute");
    };
    
    BOOL success = [manager searchFilesWithSearchText:searchText limit:limit offset:offset completionBlock:completionBlock searchDatabaseName:dbName];
    XCTAssertFalse(success);
    
    [mockSearchDatabase verify];
    [mockSearchDatabase stopMocking];
}

#pragma mark - Test taskworker for workItem
- (void)testTaskWorkerForWorkItem
{
    id delegate = (id<ZLSearchTaskWorkerProtocol>)[NSObject new];
    
    ZLSearchManager *manager = [ZLSearchManager new];
    manager.searchTaskWorkerDelegate = delegate;
    
    ZLInternalWorkItem *workItem = [ZLInternalWorkItem new];
    workItem.taskType = kTaskTypeSearch;
    
    ZLSearchTaskWorker *worker = (ZLSearchTaskWorker *)[manager taskWorkerForWorkItem:workItem];
    XCTAssertEqualObjects(worker.delegate, delegate);
    XCTAssertNotNil(worker);
    XCTAssertTrue([worker isKindOfClass:[ZLSearchTaskWorker class]]);
    XCTAssertEqualObjects(workItem, worker.workItem);
}

- (void)testTaskWorkerForWorkItemWrongType
{
    ZLSearchManager *manager = [ZLSearchManager new];
    
    ZLInternalWorkItem *workItem = [ZLInternalWorkItem new];
    workItem.taskType = @"unidentified";
    
    ZLTaskWorker *worker = [manager taskWorkerForWorkItem:workItem];
    
    XCTAssertNil(worker);
}

#pragma mark - Test absoluteUrlFromRelative

- (void)testAbsoluteUrlFromRelativeUrlForFileInfo
{
    NSString *relativeUrl = @"rell";
    NSString *cachesDirectory = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
    
    NSString *expectedUrl = [NSString stringWithFormat:@"%@/%@", cachesDirectory, relativeUrl];
    
    NSString *returnedUrl = [ZLSearchManager absoluteUrlForFileInfoFromRelativeUrl:relativeUrl];
    
    XCTAssertTrue([returnedUrl isEqualToString:expectedUrl]);
}

@end
