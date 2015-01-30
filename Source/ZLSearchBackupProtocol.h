//
//  ZLSearchBackupProtocol.h
//  ZLFullTextSearch
//
//  Created by Zack Liston on 1/29/15.
//  Copyright (c) 2015 Zack Liston. All rights reserved.
//

@protocol ZLSearchBackupProtocol <NSObject>

- (NSArray *)backupSearchResultsForSearchText:(NSString *)searchText limit:(NSUInteger)limit offset:(NSUInteger)offset;

@end