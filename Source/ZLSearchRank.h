//
//  ZLSearchRank.h
//  ZLFullTextSearch
//
//  Created by Zack Liston on 1/29/15.
//  Copyright (c) 2015 Zack Liston. All rights reserved.
//

#ifndef __ZLFullTextSearch__ZLSearchRank__
#define __ZLFullTextSearch__ZLSearchRank__

#include <stdio.h>

double rank(unsigned int *aMatchinfo, double boost, double weights[]);

#endif /* defined(__ZLFullTextSearch__ZLSearchRank__) */
