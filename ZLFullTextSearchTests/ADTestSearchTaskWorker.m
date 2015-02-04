//
//  ADTestSearchTaskWorker.m
//  AgileSDK
//
//  Created by Zack Liston on 1/19/15.
//  Copyright (c) 2015 AgileMD. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>
#import "ZLSearchTaskWorker.h"
#import "ZLSearchManager.h"
#import "ZLInternalWorkItem.h"
#import "OCMock/OCMock.h"
#import "ZLSearchDatabase.h"

@interface ADTestSearchTaskWorker : XCTestCase

@end

@interface ZLSearchTaskWorker (Test)

@property (nonatomic, assign) ZLSearchTWActionType type;
@property (nonatomic, strong) NSArray *urlArray;
@property (nonatomic, strong) NSMutableArray *succeededIndexFileInfoDictionaries;
@property (nonatomic, strong) ZLSearchDatabase *searchDatabase;

- (NSDictionary *)preparedSearchStringsFromSearchableStrings:(NSDictionary *)rawSearchableStrings;
- (BOOL)indexFileFromUrl:(NSString *)url;
- (NSString *)absoluteUrlForFileInfoFromRelativeUrl:(NSString *)relativeUrl;


@end

@implementation ADTestSearchTaskWorker

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

#pragma mark - Test Initialization
- (void)testInitialization
{
    ZLSearchTaskWorker *worker = [[ZLSearchTaskWorker alloc] init];
    XCTAssertNotNil(worker);
    XCTAssertFalse(worker.isConcurrent);
}

#pragma mark - Test setup

- (void)testSetupWithWorkItem
{
    ZLSearchTWActionType actionType = ZLSearchTWActionTypeRemoveFileFromIndex;
    NSArray *urlArray = @[@"array"];
    
    ZLInternalWorkItem *workItem = [ZLInternalWorkItem new];
    workItem.jsonData = @{kZLSearchTWActionTypeKey:[NSNumber numberWithInteger:actionType], kZLSearchTWFileInfoUrlArrayKey:urlArray};
    
    ZLSearchTaskWorker *taskWorker = [ZLSearchTaskWorker new];
    [taskWorker setupWithWorkItem:workItem];
    
    XCTAssertEqualObjects(taskWorker.workItem, workItem);
    XCTAssertEqual(taskWorker.type, actionType);
    XCTAssertTrue([taskWorker.urlArray isEqualToArray:urlArray]);
}

#pragma mark - Test main
#pragma mark Test IndexType
- (void)testMainIndexFileSuccess
{
    ZLSearchTWActionType actionType = ZLSearchTWActionTypeIndexFile;
    NSString *url1 = @"url1";
    NSString *url2 = @"url2";
    NSArray *urlArray = @[url1, url2];
    
    ZLSearchTaskWorker *taskWorker = [ZLSearchTaskWorker new];
    taskWorker.urlArray = urlArray;
    taskWorker.type = actionType;
    
    id mockWorker = [OCMockObject partialMockForObject:taskWorker];
    [[[mockWorker expect] andReturnValue:OCMOCK_VALUE(YES)] indexFileFromUrl:url1];
    [[[mockWorker expect] andReturnValue:OCMOCK_VALUE(YES)] indexFileFromUrl:url2];
    [[mockWorker expect] taskFinishedWasSuccessful:YES];
    
    
    [taskWorker main];
    
    [mockWorker verify];
}

- (void)testMainIndexFileFailure
{
    ZLSearchTWActionType actionType = ZLSearchTWActionTypeIndexFile;
    NSString *url1 = @"url1";
    NSString *url2 = @"url2";
    NSArray *urlArray = @[url1, url2];
    
    ZLSearchTaskWorker *taskWorker = [ZLSearchTaskWorker new];
    
    ZLInternalWorkItem *workItem = [ZLInternalWorkItem new];
    workItem.jsonData = @{kZLSearchTWFileInfoUrlArrayKey:urlArray, kZLSearchTWActionTypeKey:[NSNumber numberWithInteger:actionType]};
    [taskWorker setupWithWorkItem:workItem];
    
    id mockWorker = [OCMockObject partialMockForObject:taskWorker];
    [[[mockWorker expect] andReturnValue:OCMOCK_VALUE(YES)] indexFileFromUrl:url1];
    [[[mockWorker expect] andReturnValue:OCMOCK_VALUE(NO)] indexFileFromUrl:url2];
    [[mockWorker expect] taskFinishedWasSuccessful:NO];
    
    
    [taskWorker main];
    
    [mockWorker verify];
}

#pragma mark Test RemoveFileType
- (void)testMainRemoveFileSuccess
{
    ZLSearchTWActionType actionType = ZLSearchTWActionTypeRemoveFileFromIndex;
    NSString *moduleId = @"mdoiii";
    NSString *entityId = @"entszdf";
    
    ZLInternalWorkItem *workItem = [ZLInternalWorkItem new];
    NSDictionary *jsonData = @{kZLSearchTWActionTypeKey:[NSNumber numberWithInteger:actionType], kZLSearchTWModuleIdKey:moduleId, kZLSearchTWEntityIdKey:entityId};
    workItem.jsonData = jsonData;
    
    ZLSearchTaskWorker *worker = [ZLSearchTaskWorker new];
    [worker setupWithWorkItem:workItem];
    
    ZLSearchDatabase *searchDatabase = [ZLSearchDatabase new];
    id mockSearchDatabase = [OCMockObject partialMockForObject:searchDatabase];
    worker.searchDatabase = mockSearchDatabase;
    
    [[[mockSearchDatabase expect] andReturnValue:OCMOCK_VALUE(YES)] removeFileWithModuleId:moduleId entityId:entityId];
    
    id mockWorker = [OCMockObject partialMockForObject:worker];
    [[mockWorker expect] taskFinishedWasSuccessful:YES];
    
    [worker main];
    
    [mockWorker verify];
    [mockSearchDatabase verify];
    [mockSearchDatabase stopMocking];
}

- (void)testMainRemoveFileFailure
{
    ZLSearchTWActionType actionType = ZLSearchTWActionTypeRemoveFileFromIndex;
    NSString *moduleId = @"mdoiii";
    NSString *entityId = @"entszdf";
    
    ZLInternalWorkItem *workItem = [ZLInternalWorkItem new];
    NSDictionary *jsonData = @{kZLSearchTWActionTypeKey:[NSNumber numberWithInteger:actionType], kZLSearchTWModuleIdKey:moduleId, kZLSearchTWEntityIdKey:entityId};
    workItem.jsonData = jsonData;
    
    ZLSearchTaskWorker *worker = [ZLSearchTaskWorker new];
    [worker setupWithWorkItem:workItem];
    
    ZLSearchDatabase *searchDatabase = [ZLSearchDatabase new];
    id mockSearchDatabase = [OCMockObject partialMockForObject:searchDatabase];
    worker.searchDatabase = mockSearchDatabase;
    
    [[[mockSearchDatabase expect] andReturnValue:OCMOCK_VALUE(NO)] removeFileWithModuleId:moduleId entityId:entityId];
    
    id mockWorker = [OCMockObject partialMockForObject:worker];
    [[mockWorker expect] taskFinishedWasSuccessful:NO];
    
    [worker main];
    
    [mockWorker verify];
    [mockSearchDatabase verify];
    [mockSearchDatabase stopMocking];
}

#pragma mark - Test indexFileFromURL

- (void)testIndexFileFromUrl
{
    NSString *relativeUrl = @"uasdiii";
    NSString *absoluteUrl = @"absoluteURLLL";
    
    NSString *moduleId = @"modilsdf";
    NSString *fileId = @"fileadsf";
    NSString *language = @"enn";
    double boost = 12.3;
    
    NSDictionary *expectedSuccessDictionary = @{kZLSearchTWModuleIdKey:moduleId, kZLSearchTWEntityIdKey:fileId, @"url":relativeUrl};
    
    NSDictionary *searchableStrings = @{@"key2":@"value3"};
    NSDictionary *metadata = @{@"keymeta":@"valueMeta"};
    
    NSDictionary *preparedSearchableStrings = @{@"prepared":@"yes"};
    
    NSDictionary *indexInfo = @{kZLSearchTWModuleIdKey:moduleId, kZLSearchTWEntityIdKey:fileId, kZLSearchTWLanguageKey:language, kZLSearchTWBoostKey:[NSNumber numberWithDouble:boost], kZLSearchTWSearchableStringsKey:searchableStrings, kZLSearchTWFileMetadataKey:metadata};
   
    id mockUnarchieve = [OCMockObject mockForClass:[NSKeyedUnarchiver class]];
    [[[mockUnarchieve expect] andReturn:indexInfo] unarchiveObjectWithFile:absoluteUrl];
    
  
    ZLSearchTaskWorker *worker = [ZLSearchTaskWorker new];
    id mockWorker = [OCMockObject partialMockForObject:worker];
    [[[mockWorker expect] andReturn:preparedSearchableStrings] preparedSearchStringsFromSearchableStrings:searchableStrings];
    
    id mockSearchManager = [OCMockObject mockForClass:[ZLSearchManager class]];
    [[[mockSearchManager expect] andReturn:absoluteUrl] absoluteUrlForFileInfoFromRelativeUrl:relativeUrl];
    
    ZLSearchDatabase *searchDatabase = [ZLSearchDatabase new];
    id mockSearchDatabase = [OCMockObject partialMockForObject:searchDatabase];
    worker.searchDatabase = mockSearchDatabase;
    
    [[[mockSearchDatabase expect] andReturnValue:OCMOCK_VALUE(YES)] indexFileWithModuleId:moduleId entityId:fileId language:language boost:boost searchableStrings:preparedSearchableStrings fileMetadata:metadata];
    
    BOOL success = [worker indexFileFromUrl:relativeUrl];
    XCTAssertTrue(success);
    
    XCTAssertEqual(worker.succeededIndexFileInfoDictionaries.count, 1);
    NSDictionary *actualSuccessDictioanry = [worker.succeededIndexFileInfoDictionaries objectAtIndex:0];
    XCTAssertTrue([actualSuccessDictioanry isEqualToDictionary:expectedSuccessDictionary]);
    
    [mockWorker verify];
    [mockUnarchieve verify];
    [mockUnarchieve stopMocking];
    [mockSearchDatabase verify];
    [mockSearchDatabase stopMocking];
    [mockSearchManager verify];
    [mockSearchManager stopMocking];
}

- (void)testIndexFileFromUrlNoFile
{
    NSString *relativeUrl = @"uasdiii";
    NSString *absoluteUrl = @"absoluteURLLL";
    
    id mockUnarchieve = [OCMockObject mockForClass:[NSKeyedUnarchiver class]];
    [[[mockUnarchieve expect] andReturn:nil] unarchiveObjectWithFile:absoluteUrl];
    
    ZLSearchTaskWorker *worker = [ZLSearchTaskWorker new];

    id mockWorker = [OCMockObject partialMockForObject:worker];
    [[mockWorker reject] preparedSearchStringsFromSearchableStrings:[OCMArg any]];
   
    id mockSearchManager = [OCMockObject mockForClass:[ZLSearchManager class]];
    [[[mockSearchManager expect] andReturn:absoluteUrl] absoluteUrlForFileInfoFromRelativeUrl:relativeUrl];
    
    
    id mockSearchDatabase = [OCMockObject mockForClass:[ZLSearchDatabase class]];
    [[mockSearchDatabase reject] indexFileWithModuleId:[OCMArg any] entityId:[OCMArg any] language:[OCMArg any] boost:0.0 searchableStrings:[OCMArg any] fileMetadata:[OCMArg any]];
    
    BOOL success = [worker indexFileFromUrl:relativeUrl];
    XCTAssertTrue(success);
    XCTAssertEqual(worker.succeededIndexFileInfoDictionaries.count, 0);
    
    [mockWorker verify];
    [mockUnarchieve verify];
    [mockUnarchieve stopMocking];
    [mockSearchDatabase verify];
    [mockSearchDatabase stopMocking];
    [mockSearchManager verify];
    [mockSearchManager stopMocking];
}

- (void)testIndexFileFromUrlIndexFailed
{
    NSString *relativeUrl = @"uasdiii";
    NSString *absoluteUrl = @"absoluteURLLL";
    
    NSString *moduleId = @"modilsdf";
    NSString *fileId = @"fileadsf";
    NSString *language = @"enn";
    double boost = 12.3;
    NSDictionary *searchableStrings = @{@"key2":@"value3"};
    NSDictionary *metadata = @{@"keymeta":@"valueMeta"};
    
    NSDictionary *preparedSearchableStrings = @{@"prepared":@"yes"};
    
    NSDictionary *indexInfo = @{kZLSearchTWModuleIdKey:moduleId, kZLSearchTWEntityIdKey:fileId, kZLSearchTWLanguageKey:language, kZLSearchTWBoostKey:[NSNumber numberWithDouble:boost], kZLSearchTWSearchableStringsKey:searchableStrings, kZLSearchTWFileMetadataKey:metadata};
    
    id mockUnarchieve = [OCMockObject mockForClass:[NSKeyedUnarchiver class]];
    [[[mockUnarchieve expect] andReturn:indexInfo] unarchiveObjectWithFile:absoluteUrl];
    
    ZLSearchTaskWorker *worker = [ZLSearchTaskWorker new];

    id mockWorker = [OCMockObject partialMockForObject:worker];
    [[[mockWorker expect] andReturn:preparedSearchableStrings] preparedSearchStringsFromSearchableStrings:searchableStrings];
    
    id mockSearchManager = [OCMockObject mockForClass:[ZLSearchManager class]];
    [[[mockSearchManager expect] andReturn:absoluteUrl] absoluteUrlForFileInfoFromRelativeUrl:relativeUrl];

    
    ZLSearchDatabase *searchDatabase = [ZLSearchDatabase new];
    id mockSearchDatabase = [OCMockObject partialMockForObject:searchDatabase];
    worker.searchDatabase = mockSearchDatabase;
    [[[mockSearchDatabase expect] andReturnValue:OCMOCK_VALUE(NO)] indexFileWithModuleId:moduleId entityId:fileId language:language boost:boost searchableStrings:preparedSearchableStrings fileMetadata:metadata];
    
    BOOL success = [worker indexFileFromUrl:relativeUrl];
    XCTAssertFalse(success);
    XCTAssertEqual(worker.succeededIndexFileInfoDictionaries.count, 0);
    
    [mockWorker verify];
    [mockUnarchieve verify];
    [mockUnarchieve stopMocking];
    [mockSearchDatabase verify];
    [mockSearchDatabase stopMocking];
    [mockSearchManager verify];
    [mockSearchManager stopMocking];
}

#pragma mark - Test preparedStrings

- (void)testPreparedStringForSearchableStrings
{
    NSString *key1 = @"key1";
    NSString *value1 = @"value1 keies";
    NSString *key2 = @"key2";
    NSString *value2 = @"value23 iiidlsd";
    
    NSString *newValue1 = @"newvalue1 keies";
    NSString *newValue2 = @"new value23 iiidlsd";
    
    NSDictionary *oldSearchableStrings = @{key1:value1, key2:value2};
    
    id mockSearchDatabase = [OCMockObject mockForClass:[ZLSearchDatabase class]];
    [[[mockSearchDatabase expect] andReturn:newValue1] searchableStringFromString:value1];
    [[[mockSearchDatabase expect] andReturn:newValue2] searchableStringFromString:value2];
    
    ZLSearchTaskWorker *worker = [ZLSearchTaskWorker new];
    NSDictionary *newStrings = [worker preparedSearchStringsFromSearchableStrings:oldSearchableStrings];
    
    XCTAssertEqual(oldSearchableStrings.count, newStrings.count);
    XCTAssertTrue([[newStrings objectForKey:key1] isEqualToString:newValue1]);
    XCTAssertTrue([[newStrings objectForKey:key2] isEqualToString:newValue2]);
    
    [mockSearchDatabase verify];
    [mockSearchDatabase stopMocking];
}

#pragma mark - Test taskFinishedWasSuccessful

- (void)testTaskFinishedWasSuccessfulIndexType
{
    NSString *entityId1 = @"ent";
    NSString *entityId2 = @"ent2";
    NSString *moduleId1 = @"mod1";
    NSString *moduleId2 = @"mod2";
    NSArray *expectedModuleIdArray = @[moduleId1, moduleId2];
    NSArray *expectedEntityIdArray = @[entityId1, entityId2];
    NSString *url1 = @"url1";
    NSString *url2 = @"url2";
    NSString *url3 = @"url3";
    NSString *absoluteUrl1 = @"absUrl1";
    NSString *absoluteUrl2 = @"absUrl2";
    
    NSDictionary *success1 = @{kZLSearchTWEntityIdKey:entityId1, kZLSearchTWModuleIdKey:moduleId1, @"url":url1};
    NSDictionary *success2 = @{kZLSearchTWEntityIdKey:entityId2, kZLSearchTWModuleIdKey:moduleId2, @"url":url2};
    
    id mockDelegate = [OCMockObject mockForProtocol:@protocol(ZLSearchTaskWorkerProtocol)];
    [[mockDelegate expect] searchTaskWorkerIndexedFilesWithModuleIds:[OCMArg checkWithBlock:^BOOL(id obj) {
        NSArray *moduleIdArray = (NSArray *)obj;
        XCTAssertTrue([moduleIdArray isEqualToArray:expectedModuleIdArray]);
        
        return YES;
    }] fileIds:[OCMArg checkWithBlock:^BOOL(id obj) {
        NSArray *fileIdArray = (NSArray *)obj;
        XCTAssertTrue([fileIdArray isEqualToArray:expectedEntityIdArray]);
        
        return YES;
    }]];
    
    id mockSearchManager = [OCMockObject mockForClass:[ZLSearchManager class]];
    [[[mockSearchManager expect] andReturn:absoluteUrl1] absoluteUrlForFileInfoFromRelativeUrl:url1];
    [[[mockSearchManager expect] andReturn:absoluteUrl2] absoluteUrlForFileInfoFromRelativeUrl:url2];
    
    NSFileManager *fileManager = [NSFileManager new];
    id mockFileManager = [OCMockObject partialMockForObject:fileManager];
    [[[mockFileManager expect] andReturnValue:OCMOCK_VALUE(YES)] removeItemAtPath:absoluteUrl1 error:[OCMArg anyObjectRef]];
    [[[mockFileManager expect] andReturnValue:OCMOCK_VALUE(YES)] removeItemAtPath:absoluteUrl2 error:[OCMArg anyObjectRef]];
    
    id mockFileManagerClass = [OCMockObject mockForClass:[NSFileManager class]];
    [[[mockFileManagerClass stub] andReturn:mockFileManager] defaultManager];

    ZLSearchTaskWorker *worker = [ZLSearchTaskWorker new];
    [worker setupWithWorkItem:[ZLInternalWorkItem new]];
    worker.delegate = mockDelegate;
    worker.succeededIndexFileInfoDictionaries = [@[success1, success2] mutableCopy];
    worker.type = ZLSearchTWActionTypeIndexFile;
    worker.workItem.jsonData = @{kZLSearchTWFileInfoUrlArrayKey:@[url1, url2, url3]};
    
    [worker taskFinishedWasSuccessful:YES];
    
    NSArray *newUrls = [worker.workItem.jsonData objectForKey:kZLSearchTWFileInfoUrlArrayKey];
    XCTAssertEqual(newUrls.count, 1);
    XCTAssertTrue([[newUrls firstObject] isEqualToString:url3]);
    
    [mockFileManager verify];
    [mockFileManagerClass stopMocking];
    [mockSearchManager verify];
    [mockSearchManager stopMocking];
    [mockDelegate verify];
    [mockDelegate stopMocking];
}

@end
