//
//  ZLSearchTaskWorkerProtocol.h
//  ZLFullTextSearch
//
//  Created by Zack Liston on 1/29/15.
//  Copyright (c) 2015 Zack Liston. All rights reserved.
//

@protocol ZLSearchTaskWorkerProtocol <NSObject>

- (void)searchTaskWorkerIndexedFileWithModuleId:(NSString *)moduleId fileId:(NSString *)fileId;

@end
