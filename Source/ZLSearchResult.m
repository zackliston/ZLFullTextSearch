//
//  ZLSearchResult.m
//  ZLFullTextSearch
//
//  Created by Zack Liston on 1/29/15.
//  Copyright (c) 2015 Zack Liston. All rights reserved.
//

#import "ZLSearchResult.h"
#import "FMDB.h"
#import "ZLSearchDatabaseConstants.h"

@interface ZLSearchResult ()

@property (nonatomic, strong, readonly) NSString *moduleId;

@end

@implementation ZLSearchResult
@synthesize image = _image;

#pragma mark - Initialization

- (id)initWithFMResultSet:(FMResultSet *)resultSet
{
    self = [super init];
    if (self) {
        _title = [resultSet stringForColumn:kZLSearchDBTitleKey];
        _subtitle = [resultSet stringForColumn:kZLSearchDBSubtitleKey];
        _uri = [resultSet stringForColumn:kZLSearchDBUriKey];
        _type = [resultSet stringForColumn:kZLSearchDBTypeKey];
        _imageUri = [resultSet stringForColumn:kZLSearchDBImageUriKey];
        _entityId = [resultSet stringForColumn:kZLSearchDBEntityIdKey];
        _moduleId = [resultSet stringForColumn:kZLSearchDBModuleIdKey];
    }
    
    return self;
}

- (void)setupWithTitle:(NSString *)title subtitle:(NSString *)subtitle uri:(NSString *)uri type:(NSString *)type imageUri:(NSString *)imageUri fileId:(NSString *)fileId moduleId:(NSString *)moduleId
{
    _title = title;
    _subtitle = subtitle;
    _uri = uri;
    _type = type;
    _imageUri = imageUri;
    _entityId = fileId;
    _moduleId = moduleId;
}

#pragma mark - Getters/Setters

- (UIImage *)image
{
    if (!_image) {
        
        NSError *error;
        NSString *cachesDirectory = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
        NSString *imagePath = [NSString stringWithFormat:@"%@/%@", cachesDirectory, self.imageUri];
        
        NSData *data = [NSData dataWithContentsOfFile:imagePath options:0 error:&error];
        if (!error) {
            _image = [UIImage imageWithData:data];
        }
        
        if (!_image && self.imageUri.length) {
            NSError *error;
            NSData *data = [NSData dataWithContentsOfFile:self.imageUri options:0 error:&error];
            if (error) {
                // NSLog(@"Error getting cover art for module %@ %@ ", self.title, error);
            } else {
                _image = [UIImage imageWithData:data];
            }
        }
    }
    return _image;
}

- (BOOL)isFavorited
{
    return [self.favoriteDelegate isSearchResultFavorited:self];
}

@end
