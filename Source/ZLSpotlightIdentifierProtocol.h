//
//  ZLSpotlightIdentifierProtocol.h
//  ZLFullTextSearch
//
//  Created by Zack Liston on 8/18/15.
//  Copyright © 2015 Zack Liston. All rights reserved.
//

@protocol ZLSpotlightIdentiferProtocol <NSObject>

- (NSString *)identifierWithFileId:(NSString *)fileId moduleId:(NSString *)moduleId fileMetadata:(NSDictionary *)metadata;

@end
