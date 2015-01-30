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

@interface ADTestSearchManager : XCTestCase

@end

@interface ZLSearchManager (Test)

+ (void)setupFileDirectories;
+ (NSString *)relativeUrlForFileIndexInfoWithModuleId:(NSString *)moduleId fileId:(NSString *)fileId;
+ (void)teardownForTests;

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
        
        ZLSearchTWActionType taskActionType = [[task.jsonData objectForKey:kZLSearchTWActionTypeKey] integerValue];
        NSArray *receivedUrlArray = [task.jsonData objectForKey:kZLSearchTWFileInfoUrlArrayKey];
        
        
        XCTAssertEqual(taskActionType, ZLSearchTWActionTypeIndexFile);
        XCTAssertTrue([receivedUrlArray isEqualToArray:urlArray]);
        return YES;
    }]];
    
    BOOL success = [searchManager queueIndexFileCollectionWithURLArray:urlArray];
    XCTAssertTrue(success);
    
    [mockTaskManager verify];
    [mockTaskManagerClass stopMocking];
}

- (void)testIndexFileCollectionFailure
{
    NSString *url1 = @"url1";
    NSString *url2 = @"url2";
    
    NSArray *urlArray = @[url1, url2];
    
    ZLSearchManager *searchManager = [ZLSearchManager new];
    
    ZLTaskManager  *taskManager = [[ZLTaskManager  alloc] init];
    id mockTaskManager = [OCMockObject partialMockForObject:taskManager];
    
    id mockTaskManagerClass = [OCMockObject mockForClass:[ZLTaskManager  class]];
    [[[mockTaskManagerClass stub] andReturn:mockTaskManager] sharedInstance];
    
    [[[mockTaskManager expect] andReturnValue:OCMOCK_VALUE(NO)] queueTask:[OCMArg any]];
    
    BOOL success = [searchManager queueIndexFileCollectionWithURLArray:urlArray];
    XCTAssertFalse(success);
    
    [mockTaskManager verify];
    [mockTaskManagerClass stopMocking];
}

- (void)testIndexFileCollectionEmptyArray
{
    
    NSArray *urlArray = @[];
    
    ZLSearchManager *searchManager = [ZLSearchManager new];
    
    ZLTaskManager  *taskManager = [[ZLTaskManager  alloc] init];
    id mockTaskManager = [OCMockObject partialMockForObject:taskManager];
    
    id mockTaskManagerClass = [OCMockObject mockForClass:[ZLTaskManager  class]];
    [[[mockTaskManagerClass stub] andReturn:mockTaskManager] sharedInstance];
    
    [[mockTaskManager reject] queueTask:[OCMArg any]];
    
    BOOL success = [searchManager queueIndexFileCollectionWithURLArray:urlArray];
    XCTAssertFalse(success);
    
    [mockTaskManager verify];
    [mockTaskManagerClass stopMocking];
}

#pragma mark - Test queueIndexFile

- (void)testQueueIndexFileSuccess
{
    NSString *fileLocation = @"filething";
    
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
    }]];
    
    BOOL success = [searchManager queueIndexFileWithModuleId:moduleId fileId:fileId language:language boost:boost searchableStrings:searchableStrings fileMetadata:fileMetaData];
    
    XCTAssertTrue(success);
    
    [mockSearchManagerClass verify];
    [mockSearchManagerClass stopMocking];
    [mockSearchManager verify];
}

- (void)testQueueIndexFileSaveInfoError
{
    NSString *fileLocation = @"filething";
    
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
    [[mockSearchManager reject] queueIndexFileCollectionWithURLArray:[OCMArg any]];
    
    BOOL success = [searchManager queueIndexFileWithModuleId:moduleId fileId:fileId language:language boost:boost searchableStrings:searchableStrings fileMetadata:fileMetaData];
    
    XCTAssertFalse(success);
    
    [mockSearchManagerClass verify];
    [mockSearchManagerClass stopMocking];
    [mockSearchManager verify];
}

- (void)testQueueIndexFileQueueError
{
    NSString *fileLocation = @"filething";
    
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
    }]];
    
    BOOL success = [searchManager queueIndexFileWithModuleId:moduleId fileId:fileId language:language boost:boost searchableStrings:searchableStrings fileMetadata:fileMetaData];
    
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
    
    BOOL success = [manager queueRemoveFileWithModuleId:nil entityId:@"ent"];
    
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
    
    BOOL success = [manager queueRemoveFileWithModuleId:@"mdoul" entityId:nil];
    
    XCTAssertFalse(success);
    
    [mockTaskManager verify];
    [mockTaskManagerClass stopMocking];
}

- (void)testQueueRemoveFile
{
    ZLSearchManager *searchManager = [ZLSearchManager new];
    
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
        
        ZLSearchTWActionType taskActionType = [[task.jsonData objectForKey:kZLSearchTWActionTypeKey] integerValue];
        NSString *taskModuleId = [task.jsonData objectForKey:kZLSearchTWModuleIdKey];
        NSString *taskEntityId = [task.jsonData objectForKey:kZLSearchTWEntityIdKey];
 
        XCTAssertEqual(taskActionType, ZLSearchTWActionTypeRemoveFileFromIndex);
        XCTAssertTrue([taskModuleId isEqualToString:moduleId]);
        XCTAssertTrue([taskEntityId isEqualToString:entityId]);
        
        return YES;
    }]];
    
    BOOL success = [searchManager queueRemoveFileWithModuleId:moduleId entityId:entityId];
    
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
    
    BOOL success = [searchManager queueRemoveFileWithModuleId:moduleId entityId:entityId];
    
    XCTAssertFalse(success);
    [mockTaskManager verify];
    [mockTaskManagerClass stopMocking];
}

#pragma mark - Test resetSearchDatabase

- (void)testResetSearchDatabaseSuccess
{
    ZLSearchManager *manager = [ZLSearchManager new];
    
    ZLTaskManager  *taskManager = [[ZLTaskManager  alloc] init];
    id mockTaskManager = [OCMockObject partialMockForObject:taskManager];
    
    id mockTaskManagerClass = [OCMockObject mockForClass:[ZLTaskManager  class]];
    [[[mockTaskManagerClass stub] andReturn:mockTaskManager] sharedInstance];
    [mockTaskManager setExpectationOrderMatters:YES];
    
    [[mockTaskManager expect] stopAndWaitWithNetworkCancellationBlock:[OCMArg any]];
    [[mockTaskManager expect] removeTasksOfType:kTaskTypeSearch];
    [[mockTaskManager expect] resume];
    
    id mockSearchDatabase = [OCMockObject mockForClass:[ZLSearchDatabase class]];
    [[[mockSearchDatabase expect] andReturnValue:OCMOCK_VALUE(YES)] resetDatabase];
    
    BOOL success = [manager resetSearchDatabase];
    XCTAssertTrue(success);
    
    [mockSearchDatabase verify];
    [mockSearchDatabase stopMocking];
    [mockTaskManager verify];
    [mockTaskManagerClass stopMocking];
}

- (void)testResetSearchDatabaseFailure
{
    ZLSearchManager *manager = [ZLSearchManager new];
    
    ZLTaskManager  *taskManager = [[ZLTaskManager  alloc] init];
    id mockTaskManager = [OCMockObject partialMockForObject:taskManager];
    
    id mockTaskManagerClass = [OCMockObject mockForClass:[ZLTaskManager  class]];
    [[[mockTaskManagerClass stub] andReturn:mockTaskManager] sharedInstance];
    [mockTaskManager setExpectationOrderMatters:YES];
    
    [[mockTaskManager expect] stopAndWaitWithNetworkCancellationBlock:[OCMArg any]];
    [[mockTaskManager expect] removeTasksOfType:kTaskTypeSearch];
    [[mockTaskManager expect] resume];
    
    id mockSearchDatabase = [OCMockObject mockForClass:[ZLSearchDatabase class]];
    [[[mockSearchDatabase expect] andReturnValue:OCMOCK_VALUE(NO)] resetDatabase];
    
    BOOL success = [manager resetSearchDatabase];
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
    ZLSearchManager *manager = [ZLSearchManager new];
    NSString *searchText = @"sear";
    NSString *formattedSearchText = @"format";
    ZLSearchResult *searchResult1 = [ZLSearchResult new];
    ZLSearchResult *searchResult2 = [ZLSearchResult new];
    NSArray *expectedResults = @[searchResult1, searchResult2];
    
    NSUInteger limit = 3;
    NSUInteger offset = 1;
    
    id mockSearchDatabase = [OCMockObject mockForClass:[ZLSearchDatabase class]];
    [[[mockSearchDatabase expect] andReturn:formattedSearchText] searchableStringFromString:searchText];
    [[[mockSearchDatabase expect] andReturn:expectedResults] searchFilesWithSearchText:formattedSearchText limit:limit offset:offset error:[OCMArg anyObjectRef]];
    
    id mockSearchBackupDelegate = [OCMockObject mockForProtocol:@protocol(ZLSearchBackupProtocol)];
    [[mockSearchBackupDelegate reject] backupSearchResultsForSearchText:formattedSearchText limit:limit offset:offset];
    manager.backupSearchDelegate = mockSearchBackupDelegate;

    
    XCTestExpectation *completionBlockExpectation = [self expectationWithDescription:@"completion block expectation"];
    ZLSearchCompletionBlock completionBlock = ^void(NSArray *results, NSError *error) {
        XCTAssertTrue([NSThread isMainThread]);
        XCTAssertTrue([expectedResults isEqualToArray:results]);
        XCTAssertNil(error);
        [completionBlockExpectation fulfill];
    };
    
    BOOL success = [manager searchFilesWithSearchText:searchText limit:limit offset:offset completionBlock:completionBlock];
    XCTAssertTrue(success);
    
    [self waitForExpectationsWithTimeout:1.0 handler:nil];
    
    [mockSearchBackupDelegate verify];
    [mockSearchBackupDelegate stopMocking];
    [mockSearchDatabase verify];
    [mockSearchDatabase stopMocking];
}

- (void)testSearchFilesZeroResults
{
    ZLSearchManager *manager = [ZLSearchManager new];
    NSString *searchText = @"sear";
    NSString *formattedSearchText = @"format";
    ZLSearchResult *searchResult1 = [ZLSearchResult new];
    ZLSearchResult *searchResult2 = [ZLSearchResult new];
    NSArray *expectedResults = @[];
    NSArray *backupResults = @[searchResult1, searchResult2];
    
    NSUInteger limit = 3;
    NSUInteger offset = 1;
    
    id mockSearchDatabase = [OCMockObject mockForClass:[ZLSearchDatabase class]];
    [[[mockSearchDatabase expect] andReturn:formattedSearchText] searchableStringFromString:searchText];
    [[[mockSearchDatabase expect] andReturn:expectedResults] searchFilesWithSearchText:formattedSearchText limit:limit offset:offset error:[OCMArg anyObjectRef]];
    
    id mockSearchBackupDelegate = [OCMockObject mockForProtocol:@protocol(ZLSearchBackupProtocol)];
    [[[mockSearchBackupDelegate expect] andReturn:backupResults] backupSearchResultsForSearchText:formattedSearchText limit:limit offset:offset];
    manager.backupSearchDelegate = mockSearchBackupDelegate;
    
    XCTestExpectation *completionBlockExpectation = [self expectationWithDescription:@"completion block expectation"];
    ZLSearchCompletionBlock completionBlock = ^void(NSArray *results, NSError *error) {
        XCTAssertTrue([NSThread isMainThread]);
        XCTAssertTrue([backupResults isEqualToArray:results]);
        XCTAssertNil(error);
        [completionBlockExpectation fulfill];
    };
    
    BOOL success = [manager searchFilesWithSearchText:searchText limit:limit offset:offset completionBlock:completionBlock];
    XCTAssertTrue(success);
    
    [self waitForExpectationsWithTimeout:1.0 handler:nil];
    
    [mockSearchBackupDelegate verify];
    [mockSearchBackupDelegate stopMocking];
    [mockSearchDatabase verify];
    [mockSearchDatabase stopMocking];
}

- (void)testSearchFilesError
{
    ZLSearchManager *manager = [ZLSearchManager new];
    NSString *searchText = @"sear";
    NSString *formattedSearchText = @"format";
    ZLSearchResult *searchResult1 = [ZLSearchResult new];
    ZLSearchResult *searchResult2 = [ZLSearchResult new];
    NSArray *expectedResults = @[searchResult1, searchResult2];
    NSUInteger limit = 3;
    NSUInteger offset = 1;
    
    NSError *fakeError = [NSError errorWithDomain:@"FakeError" code:-123 userInfo:nil];
    id mockSearchDatabase = [OCMockObject mockForClass:[ZLSearchDatabase class]];
    [[[mockSearchDatabase expect] andReturn:formattedSearchText] searchableStringFromString:searchText];
    [[[mockSearchDatabase expect] andReturn:expectedResults] searchFilesWithSearchText:formattedSearchText limit:limit offset:offset error:[OCMArg setTo:fakeError]];
    
    XCTestExpectation *completionBlockExpectation = [self expectationWithDescription:@"completion block expectation"];
    ZLSearchCompletionBlock completionBlock = ^void(NSArray *results, NSError *error) {
        XCTAssertTrue([NSThread isMainThread]);
        XCTAssertNil(results);
        XCTAssertNotNil(error);
        XCTAssertEqualObjects(error, fakeError);
        [completionBlockExpectation fulfill];
    };
    
    BOOL success = [manager searchFilesWithSearchText:searchText limit:limit offset:offset completionBlock:completionBlock];
    XCTAssertTrue(success);
    
    [self waitForExpectationsWithTimeout:1.0 handler:nil];
    
    [mockSearchDatabase verify];
    [mockSearchDatabase stopMocking];
}

- (void)testSearchFilesZeroLimit
{
    ZLSearchManager *manager = [ZLSearchManager new];
    NSString *searchText = @"sear";
    NSUInteger limit = 0;
    NSUInteger offset = 11;
    
    id mockSearchDatabase = [OCMockObject mockForClass:[ZLSearchDatabase class]];
    [[mockSearchDatabase reject] searchFilesWithSearchText:[OCMArg any] limit:limit offset:offset error:[OCMArg anyObjectRef]];
    
    ZLSearchCompletionBlock completionBlock = ^void(NSArray *results, NSError *error) {
        XCTFail(@"The completion block should not execute");
    };
    
    BOOL success = [manager searchFilesWithSearchText:searchText limit:limit offset:offset completionBlock:completionBlock];
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
