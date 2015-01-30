//
//  ZLSearchResultIsFavoritedProtocol.h
//  ZLFullTextSearch
//
//  Created by Zack Liston on 1/29/15.
//  Copyright (c) 2015 Zack Liston. All rights reserved.
//

@class ZLSearchResult;
@protocol ZLSearchResultIsFavoritedProtocol <NSObject>

- (BOOL)isSearchResultFavorited:(ZLSearchResult *)searchResult;

@end
