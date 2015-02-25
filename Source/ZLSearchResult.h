//
//  ZLSearchResult.h
//  ZLFullTextSearch
//
//  Created by Zack Liston on 1/29/15.
//  Copyright (c) 2015 Zack Liston. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "ZLSearchResultIsFavoritedProtocol.h"

@interface ZLSearchResult : NSObject

@property (nonatomic, strong, readonly) NSString *title;
@property (nonatomic, strong, readonly) NSString *subtitle;
@property (nonatomic, strong, readonly) NSString *parentTitle;
@property (nonatomic, strong, readonly) NSString *uri;
@property (nonatomic, strong, readonly) NSString *type;
@property (nonatomic, strong, readonly) NSString *imageUri;
@property (nonatomic, strong) UIImage *image;
@property (nonatomic, assign, readonly) BOOL isFavorited;
@property (nonatomic, strong, readonly) NSString *entityId;

@property (nonatomic, weak) id<ZLSearchResultIsFavoritedProtocol>favoriteDelegate;


- (void)setupWithTitle:(NSString *)title subtitle:(NSString *)subtitle parentTitle:(NSString *)parentTitle uri:(NSString *)uri type:(NSString *)type imageUri:(NSString *)imageUri fileId:(NSString *)fileId moduleId:(NSString *)moduleId;
@end

