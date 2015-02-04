//
//  ZLSearchDatabase.m
//  ZLFullTextSearch
//
//  Created by Zack Liston on 1/29/15.
//  Copyright (c) 2015 Zack Liston. All rights reserved.
//

#import "ZLSearchDatabase.h"
#import "ZLSearchDatabaseConstants.h"
#import "FMDB.h"
#import "FMDatabase+FTS3.h"
#import "FMTokenizers.h"
#import "ZLSearchManager.h"
#import "ZLSearchResult.h"
#include "ZLSearchRank.h"


@interface ZLSearchResult (DatabaseInitializer)
- (id)initWithFMResultSet:(FMResultSet *)resultSet;
@end

@interface ZLSearchDatabase ()

@property (nonatomic, strong) FMDatabaseQueue *queue;
@property (nonatomic, strong) NSString *databaseName;

@end

@implementation ZLSearchDatabase

#pragma mark - Initialization

- (id)initWithDatabaseName:(NSString *)databaseName
{
    self = [super init];
    if (self) {
        self.databaseName = databaseName;
        [self setupDatabaseQueueWithName:databaseName];
    }
    return self;
}

#pragma mark - Getters/Setters

+ (NSSet *)stopWords
{
    return [NSSet setWithArray:@[@"and", @"are", @"as", @"at", @"be", @"because", @"been", @"but", @"by", @"for", @"however", @"to", @"in", @"this", @"if", @"not", @"of", @"on", @"or",@"so", @"the", @"there", @"was", @"were", @"whatever",@"whether", @"would"]];
}

- (void)setupDatabaseQueueWithName:(NSString *)databaseName;
{
    NSString *cachesDirectory = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject];
    NSString *path = [[NSString alloc] initWithString:[cachesDirectory stringByAppendingPathComponent:databaseName]];
    
    self.queue = [[FMDatabaseQueue alloc] initWithPath:path flags:SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FILEPROTECTION_NONE];
    
    [self.queue inDatabase:^(FMDatabase *db) {
        [db open];
        [ZLSearchDatabase createTablesForDatabase:db];
        [ZLSearchDatabase issueAutomergeCommandForDatabase:db];
        [ZLSearchDatabase registerRankingFunctionForDatabase:db];
    }];
}

#pragma mark - Public Methods

- (BOOL)indexFileWithModuleId:(NSString *)moduleId entityId:(NSString *)entityId language:(NSString *)language boost:(double)boost searchableStrings:(NSDictionary *)searchableStrings fileMetadata:(NSDictionary *)fileMetadata
{
    
    __block BOOL success = YES;
    
    // Check to see if there's any searchable text the user provided according to our described keys in ADSearchDatabase.h
    // If the dictionary is nil validSearchableText.length will be < 1 so we don't also have to check to see if the dictionary is nil
    NSString *validSearchableText = @"";
    for (NSString *key in searchableStrings.allKeys) {
        if ([key isEqualToString:kZLSearchableStringWeight0] || [key isEqualToString:kZLSearchableStringWeight1] || [key isEqualToString:kZLSearchableStringWeight2] || [key isEqualToString:kZLSearchableStringWeight3] || [key isEqualToString:kZLSearchableStringWeight4]) {
            NSString *object = [searchableStrings objectForKey:key];
            validSearchableText = [validSearchableText stringByAppendingString:object];
        }
    }
    
    if (moduleId.length < 1 || entityId.length < 1 || language.length < 1 || validSearchableText.length < 1) {
        success = NO;
        return success;
    }
    
    BOOL doesFileAlreadyExist = [self doesFileExistWithModuleId:moduleId entityId:entityId];
    if (doesFileAlreadyExist) {
        [self removeFileWithModuleId:moduleId entityId:entityId];
    }
    
    [self.queue inTransaction:^(FMDatabase *db, BOOL *rollback) {
        [db open];
        
        NSString *indexInsertString = [ZLSearchDatabase insertStringForIndexWithSearchableStrings:searchableStrings];
        NSDictionary *indexValuesDictionary = [ZLSearchDatabase insertDictionaryForIndexWithModuleID:moduleId entityId:entityId language:language boost:boost searchableStrings:searchableStrings];
        
        success = [db executeUpdate:indexInsertString withParameterDictionary:indexValuesDictionary];
        if (!success) {
            NSLog(@"Error inserting values into index table. Rolling back. %@", [db lastError]);
            *rollback = YES;
        }
        
        NSString *metadataInsertString = [ZLSearchDatabase insertStringForMetadataWithFileMetadata:fileMetadata];
        NSDictionary *metadataValuesDictionary = [ZLSearchDatabase insertDictionaryForMetadataWithModuleId:moduleId entityId:entityId metadata:fileMetadata];
        
        success = [db executeUpdate:metadataInsertString withParameterDictionary:metadataValuesDictionary];
        if (!success) {
            NSLog(@"Error inserting values into metadata table. Rolling back. %@", [db lastError]);
            *rollback = YES;
        }
        
        [db closeOpenResultSets];
    }];
    
    return success;
}

- (BOOL)removeFileWithModuleId:(NSString *)moduleId entityId:(NSString *)entityId
{
    __block BOOL success = YES;
    
    if (moduleId.length < 1 || entityId.length < 1) {
        success = NO;
        return success;
    }
    
    [self.queue inTransaction:^(FMDatabase *db, BOOL *rollback) {
        [db open];
        NSString *indexDeleteCommand = [NSString stringWithFormat:@"DELETE FROM %@ WHERE %@ = ? AND %@ = ?", kZLSearchDBIndexTableName, kZLSearchDBModuleIdKey, kZLSearchDBEntityIdKey];
        
        success = [db executeUpdate:indexDeleteCommand, moduleId, entityId];
        if (!success) {
            NSLog(@"Error deleting row from index table. Rolling back. %@", [db lastError]);
            *rollback = YES;
        }
        
        NSString *metadataDeleteCommand = [NSString stringWithFormat:@"DELETE FROM %@ WHERE %@ = ? AND %@ = ?", kZLSearchDBMetadataTableName, kZLSearchDBModuleIdKey, kZLSearchDBEntityIdKey];
        success = [db executeUpdate:metadataDeleteCommand, moduleId, entityId];
        if (!success) {
            NSLog(@"Error deleting row from metadata table. Rolling back. %@", [db lastError]);
            *rollback = YES;
        }
        
        [db closeOpenResultSets];
    }];
    
    return success;
}

- (NSArray *)searchFilesWithSearchText:(NSString *)searchText limit:(NSUInteger)limit offset:(NSUInteger)offset searchSuggestions:(NSArray *__autoreleasing *)searchSuggestions error:(NSError *__autoreleasing *)error
{
    __block NSMutableArray *formattedResults = [NSMutableArray new];
    __block NSMutableDictionary *snippetDictionary = [NSMutableDictionary new];
    
    [self.queue inDatabase:^(FMDatabase *db) {
        [db open];
        
        NSString *formattedSearchText = [ZLSearchDatabase stringWithLastWordHavingPrefixOperatorFromString:searchText];
        
        NSString *matchString = [NSString stringWithFormat:@"%@", formattedSearchText];
        int searchWordCount = (int)[matchString componentsSeparatedByString:@" "].count+1;
        NSString *snippetColumnName = @"snippet";
        
        NSString *queryString = [NSString stringWithFormat:@"SELECT %@, %@, %@, %@, %@, %@, %@, %@, rank FROM %@ JOIN ("
                                 "SELECT docid, rank(matchinfo(%@, 'pcnalx'), %@.%@) AS rank, "
                                 "snippet(%@, '', '', '', -1, %i) AS %@ "
                                 "FROM %@ "
                                 "WHERE %@ MATCH ? "
                                 "ORDER BY rank DESC "
                                 "LIMIT %i OFFSET %i "
                                 ") AS ranktable USING(docid) LEFT JOIN %@ AS fulltable USING(%@, %@) "
                                 "ORDER BY ranktable.rank DESC;", kZLSearchDBModuleIdKey, kZLSearchDBEntityIdKey, kZLSearchDBTitleKey, kZLSearchDBSubtitleKey, kZLSearchDBUriKey, kZLSearchDBTypeKey, kZLSearchDBImageUriKey, snippetColumnName, kZLSearchDBIndexTableName, kZLSearchDBIndexTableName, kZLSearchDBIndexTableName, kZLSearchDBBoostKey, kZLSearchDBIndexTableName, searchWordCount, snippetColumnName, kZLSearchDBIndexTableName, kZLSearchDBIndexTableName, (int)limit, (int)offset,kZLSearchDBMetadataTableName, kZLSearchDBModuleIdKey, kZLSearchDBEntityIdKey];
        
        FMResultSet *resultSet = [db executeQuery:queryString, matchString];
        if (!resultSet) {
            if (*error) {
                *error = [db lastError];
            }
        }
        
        while ([resultSet next]) {
            NSString *snippet = [[resultSet stringForColumn:snippetColumnName] lowercaseString];
            snippetDictionary = [self addSuggestionToDictionary:snippetDictionary fromSnippet:snippet inReferenceToSearchText:searchText];
            
            ZLSearchResult *searchResult = [[ZLSearchResult alloc] initWithFMResultSet:resultSet];
            [formattedResults addObject:searchResult];
        }
        [db closeOpenResultSets];
    }];
    
    if (searchSuggestions) {
        *searchSuggestions = [snippetDictionary keysSortedByValueUsingComparator:^NSComparisonResult(id obj1, id obj2) {
            int number1 = [(NSNumber *)obj1 intValue];
            int number2 = [(NSNumber *)obj2 intValue];
            return number1 < number2;
        }];
    }
    
    return [formattedResults copy];
}

- (NSMutableDictionary *)addSuggestionToDictionary:(NSMutableDictionary *)suggestionDictionary fromSnippet:(NSString *)snippet inReferenceToSearchText:(NSString *)searchText
{
    
    NSMutableSet *formattedSnippetWords = [NSMutableSet new];
    for (NSString *word in [snippet componentsSeparatedByString:@" "]) {
        // Remove all unneccessary words
        if ([word isEqualToString:@" "] || [[ZLSearchDatabase stopWords] containsObject:word] || !word.length) {
            continue;
        }
        
        BOOL shouldAddWord = NO;
        // Add all words to the suggestion dictionary that contain our search text, but don't exactly match it.
        // We don't add the ones that exactly match because if they exactly match the user already has typed what he's looking for
        // We don't add words that don't contain the search text because they could outnumber the better results
        
        for (NSString *searchWord in [searchText componentsSeparatedByString:@" "]) {
            if ([word rangeOfString:searchWord].location != NSNotFound) {
                shouldAddWord = YES;
            }
            if ([word isEqualToString:searchWord]) {
                shouldAddWord = NO;
            }
        }
        
        // Either add the word or increment it's existing count.
        int count = 1;
        if (shouldAddWord) {
            NSNumber *rankForExistingSnippet = [suggestionDictionary objectForKey:word];
            if (rankForExistingSnippet) {
                int existingCount = [rankForExistingSnippet intValue];
                count += existingCount;
            }
            [suggestionDictionary setObject:[NSNumber numberWithInt:count] forKey:word];
        }
        
        // Whether or not we add the word to the suggestions, we need to add it here so we can re-construct the
        // snippet, but formatted correctly
        [formattedSnippetWords addObject:word];
    }
    
    // Re-construct the formatted snippet and add it to the suggestion dictionary
    NSString *formattedSnippet = [[formattedSnippetWords allObjects] componentsJoinedByString:@" "];
    NSNumber *rankForPhrase = [suggestionDictionary objectForKey:formattedSnippet];
    int newCount = 1;
    if (rankForPhrase) {
        int existingCount = [rankForPhrase intValue];
        newCount += existingCount;
    }
    [suggestionDictionary setObject:[NSNumber numberWithInt:newCount] forKey:formattedSnippet];
    
    // The above won't work for suggestions with the same words but in a different order
    // So go through each suggestion and if it has the same words, increment it
    // Don't increment it if it only has one word
    for (NSString *suggestion in suggestionDictionary.allKeys) {
        BOOL incrementSuggestion = YES;
        NSArray *suggestionWordArray = [suggestion componentsSeparatedByString:@" "];
        if (suggestionWordArray.count > 1) {
            for (NSString *suggestionWord in suggestionWordArray) {
                if ([formattedSnippet rangeOfString:suggestionWord].location == NSNotFound) {
                    incrementSuggestion = NO;
                }
            }
        } else {
            incrementSuggestion = NO;
        }
        if (incrementSuggestion) {
            NSNumber *rankForExistingSnippet = [suggestionDictionary objectForKey:suggestion];
            int existingCount = [rankForExistingSnippet intValue];
            existingCount++;
            [suggestionDictionary setObject:[NSNumber numberWithInt:existingCount] forKey:suggestion];
        }
    }
    
    return suggestionDictionary;
}

- (BOOL)resetDatabase
{
    __block BOOL success = YES;
    [self.queue inDatabase:^(FMDatabase *db) {
        [db open];
        NSString *deleteCommand = [NSString stringWithFormat:@"DROP TABLE IF EXISTS %@;"
                                   "DROP TABLE IF EXISTS %@;", kZLSearchDBIndexTableName, kZLSearchDBMetadataTableName];
        
        success = [db executeStatements:deleteCommand];
        
        if (!success) {
            NSLog(@"Error resetting database %@", [db lastError]);
        }
        
        [db close];
    }];
    self.queue = nil;
    [self setupDatabaseQueueWithName:self.databaseName];
    
    return success;
}

+ (NSString *)searchableStringFromString:(NSString *)oldString
{
    __block NSString *newString = @"";
    __block NSSet *stopWords = [self stopWords];
    
    // This is a super temporary hack. The tagger doesn't stem the word if there is only one, so adding a word we know will be removed later makes sure that the words we're using are stemmed.
    oldString = [NSString stringWithFormat:@"and %@", oldString];
    oldString = [oldString lowercaseString];
    
    NSLinguisticTagger *tagger = [[NSLinguisticTagger alloc] initWithTagSchemes:@[NSLinguisticTagSchemeLemma] options:(NSLinguisticTaggerOmitPunctuation | NSLinguisticTaggerOmitOther)];
    tagger.string = oldString;
    
    [tagger enumerateTagsInRange:NSMakeRange(0, [oldString length]) scheme:NSLinguisticTagSchemeLemma options:(NSLinguisticTaggerOmitPunctuation | NSLinguisticTaggerOmitOther) usingBlock:^(NSString *tag, NSRange tokenRange, NSRange sentenceRange, BOOL *stop) {
        // The original word
        NSString *token = [oldString substringWithRange:tokenRange];
        
        // If there is a lemma for the word, then use that. If not, use the original word
        NSString *replacement;
        if (tag) {
            replacement = tag;
        } else {
            replacement = token;
        }
        
        // If the word is not just an empty space, then remove everything but letter/numbers
        // We want to keep empty spaces so that words stay separated.
        if (![replacement isEqualToString:@" "]) {
            replacement = [replacement stringByTrimmingCharactersInSet:[[NSCharacterSet alphanumericCharacterSet] invertedSet]];
        }
        
        // Remove all stop words
        if (![stopWords containsObject:replacement]) {
            newString = [newString stringByAppendingString:replacement];
        }
    }];
    
    newString = [newString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    return newString;
}

+ (NSString *)plainTextFromHTML:(NSString *)html
{
    NSScanner *myScanner;
    NSString *text = nil;
    myScanner = [NSScanner scannerWithString:html];
    
    while ([myScanner isAtEnd] == NO) {
        [myScanner scanUpToString:@"<" intoString:NULL] ;
        [myScanner scanUpToString:@">" intoString:&text] ;
        html = [html stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@"%@>", text] withString:@""];
    }
    html = [html stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    return html;
}

#pragma mark - Private Methods
#pragma mark Create Database

+ (void)createTablesForDatabase:(FMDatabase *)database
{
    /**
     NOTE: If you change any of the columns in the searchIndex table you MUST UPDATE the kZLWeight.. column number constants accordingly. (At the top of the file)
     They are used for calculating the rank and have to be accurate.
     */
    NSString *indexTableCreateCommand = [NSString stringWithFormat:@"CREATE VIRTUAL TABLE IF NOT EXISTS %@ USING FTS4 ("
                                         " %@ TEXT NOT NULL,"
                                         " %@ TEXT NOT NULL, "
                                         " %@ TEXT NOT NULL,"
                                         " %@ FLOAT NOT NULL,"
                                         " %@ TEXT,"
                                         " %@ TEXT,"
                                         " %@ TEXT,"
                                         " %@ TEXT,"
                                         " %@ TEXT, PRIMARY KEY (%@, %@));",kZLSearchDBIndexTableName, kZLSearchDBModuleIdKey, kZLSearchDBEntityIdKey, kZLSearchDBLanguageKey, kZLSearchDBBoostKey, kZLSearchDBWeight0Key, kZLSearchDBWeight1Key, kZLSearchDBWeight2Key, kZLSearchDBWeight3Key, kZLSearchDBWeight4Key, kZLSearchDBModuleIdKey, kZLSearchDBEntityIdKey];
    
    NSString *metadataTableCreateCommand = [NSString stringWithFormat:@"CREATE TABLE IF NOT EXISTS %@ ("
                                            "%@ TEXT NOT NULL,"
                                            "%@ TEXT NOT NULL,"
                                            "%@ TEXT,"
                                            "%@ TEXT,"
                                            "%@ TEXT,"
                                            "%@ TEXT,"
                                            "%@ TEXT, PRIMARY KEY (%@,%@));", kZLSearchDBMetadataTableName, kZLSearchDBModuleIdKey, kZLSearchDBEntityIdKey, kZLSearchDBTitleKey, kZLSearchDBSubtitleKey, kZLSearchDBUriKey, kZLSearchDBTypeKey, kZLSearchDBImageUriKey, kZLSearchDBModuleIdKey, kZLSearchDBEntityIdKey];
    
    NSString *combinedCommand = [NSString stringWithFormat:@"%@ %@", indexTableCreateCommand, metadataTableCreateCommand];
    
    BOOL createSuccess = [database executeStatements:combinedCommand];
    if (!createSuccess) {
        NSLog(@"Error creating database %@", [database lastError]);
    }
    
}

+ (void)issueAutomergeCommandForDatabase:(FMDatabase *)database
{
    NSString *command = [NSString stringWithFormat:kFTSCommandAutoMerge, 2];
    BOOL autoMergeSuccess = [database issueCommand:command forTable:kZLSearchDBIndexTableName];
    if (!autoMergeSuccess) {
        NSLog(@"Error issuing automerge command %@", [database lastError]);
    }
}

+ (void)registerRankingFunctionForDatabase:(FMDatabase *)database
{
    [database makeFunctionNamed:@"rank" maximumArguments:2 withBlock:^(sqlite3_context *context, int argc, sqlite3_value **argv) {
        assert( sizeof(int)==4 );
        if(argc!=(2)) goto wrong_number_args;
        
        // rank method parameters
        unsigned int *aMatchinfo = (unsigned int *)sqlite3_value_blob(argv[0]);
        double boost = sqlite3_value_double(argv[1]);
        double weights[5] = {1,2,10,20,50};
        
        double score = rank(aMatchinfo, boost, weights);
        
        sqlite3_result_double(context, score);
        return;
        
        /* Jump here if the wrong number of arguments are passed to this function */
    wrong_number_args:
        sqlite3_result_error(context, "wrong number of arguments to function rank()", -1);
    }];
}

#pragma mark - Helpers

+ (NSString *)insertStringForIndexWithSearchableStrings:(NSDictionary *)searchableStrings
{
    NSString *insertString = [NSString stringWithFormat:@"INSERT INTO %@ (%@, %@, %@, %@", kZLSearchDBIndexTableName, kZLSearchDBModuleIdKey, kZLSearchDBEntityIdKey, kZLSearchDBLanguageKey, kZLSearchDBBoostKey];
    NSString *valuesString = [NSString stringWithFormat:@"VALUES(:%@, :%@, :%@, :%@", kZLSearchDBModuleIdKey, kZLSearchDBEntityIdKey, kZLSearchDBLanguageKey, kZLSearchDBBoostKey];
    
    for (NSString *key in searchableStrings.allKeys) {
        if ([key isEqualToString:kZLSearchableStringWeight0]) {
            insertString = [insertString stringByAppendingFormat:@", %@", kZLSearchDBWeight0Key];
            valuesString = [valuesString stringByAppendingFormat:@", :%@", kZLSearchDBWeight0Key];
        } else if ([key isEqualToString:kZLSearchableStringWeight1]) {
            insertString = [insertString stringByAppendingFormat:@", %@", kZLSearchDBWeight1Key];
            valuesString = [valuesString stringByAppendingFormat:@", :%@", kZLSearchDBWeight1Key];
        } else if ([key isEqualToString:kZLSearchableStringWeight2]) {
            insertString = [insertString stringByAppendingFormat:@", %@", kZLSearchDBWeight2Key];
            valuesString = [valuesString stringByAppendingFormat:@", :%@", kZLSearchDBWeight2Key];
        } else if ([key isEqualToString:kZLSearchableStringWeight3]) {
            insertString = [insertString stringByAppendingFormat:@", %@", kZLSearchDBWeight3Key];
            valuesString = [valuesString stringByAppendingFormat:@", :%@", kZLSearchDBWeight3Key];
        } else if ([key isEqualToString:kZLSearchableStringWeight4]) {
            insertString = [insertString stringByAppendingFormat:@", %@", kZLSearchDBWeight4Key];
            valuesString = [valuesString stringByAppendingFormat:@", :%@", kZLSearchDBWeight4Key];
        }
    }
    insertString = [insertString stringByAppendingFormat:@") %@);", valuesString];
    
    return insertString;
}

+ (NSString *)insertStringForMetadataWithFileMetadata:(NSDictionary *)fileMetadata
{
    NSString *insertString = [NSString stringWithFormat:@"INSERT INTO %@ (%@, %@", kZLSearchDBMetadataTableName, kZLSearchDBModuleIdKey, kZLSearchDBEntityIdKey];
    NSString *valuesString = [NSString stringWithFormat:@"VALUES(:%@, :%@", kZLSearchDBModuleIdKey, kZLSearchDBEntityIdKey];
    
    for (NSString *key in fileMetadata.allKeys) {
        if ([key isEqualToString:kZLFileMetadataTitle]) {
            insertString = [insertString stringByAppendingFormat:@", %@", kZLSearchDBTitleKey];
            valuesString = [valuesString stringByAppendingFormat:@", :%@", kZLSearchDBTitleKey];
        } else if ([key isEqualToString:kZLFileMetadataSubtitle]) {
            insertString = [insertString stringByAppendingFormat:@", %@", kZLSearchDBSubtitleKey];
            valuesString = [valuesString stringByAppendingFormat:@", :%@", kZLSearchDBSubtitleKey];
        } else if ([key isEqualToString:kZLFileMetadataFileType]) {
            insertString = [insertString stringByAppendingFormat:@", %@", kZLSearchDBTypeKey];
            valuesString = [valuesString stringByAppendingFormat:@", :%@", kZLSearchDBTypeKey];
        } else if ([key isEqualToString:kZLFileMetadataURI]) {
            insertString = [insertString stringByAppendingFormat:@", %@", kZLSearchDBUriKey];
            valuesString = [valuesString stringByAppendingFormat:@", :%@", kZLSearchDBUriKey];
        } else if ([key isEqualToString:kZLFileMetadataImageURI]) {
            insertString = [insertString stringByAppendingFormat:@", %@", kZLSearchDBImageUriKey];
            valuesString = [valuesString stringByAppendingFormat:@", :%@", kZLSearchDBImageUriKey];
        }
    }
    
    insertString = [insertString stringByAppendingFormat:@") %@);", valuesString];
    
    return insertString;
}

+ (NSDictionary *)insertDictionaryForIndexWithModuleID:(NSString *)moduleId entityId:(NSString *)entityId language:(NSString *)language boost:(double)boost searchableStrings:(NSDictionary *)searchableStrings
{
    NSMutableDictionary *insertDictionary = [@{kZLSearchDBModuleIdKey:moduleId, kZLSearchDBEntityIdKey:entityId, kZLSearchDBLanguageKey:language, kZLSearchDBBoostKey:[NSNumber numberWithDouble:boost]} mutableCopy];
    
    for (NSString *key in searchableStrings.allKeys) {
        NSString *newKey;
        if ([key isEqualToString:kZLSearchableStringWeight0]) {
            newKey = kZLSearchDBWeight0Key;
        } else if ([key isEqualToString:kZLSearchableStringWeight1]) {
            newKey = kZLSearchDBWeight1Key;
        } else if ([key isEqualToString:kZLSearchableStringWeight2]) {
            newKey = kZLSearchDBWeight2Key;
        } else if ([key isEqualToString:kZLSearchableStringWeight3]) {
            newKey = kZLSearchDBWeight3Key;
        } else if ([key isEqualToString:kZLSearchableStringWeight4]) {
            newKey = kZLSearchDBWeight4Key;
        }
        if (newKey) {
            [insertDictionary setObject:searchableStrings[key] forKey:newKey];
        }
    }
    return [insertDictionary copy];
}

+ (NSDictionary *)insertDictionaryForMetadataWithModuleId:(NSString *)moduleId entityId:(NSString *)entityId metadata:(NSDictionary *)metadata
{
    NSMutableDictionary *insertDictionary = [@{kZLSearchDBModuleIdKey:moduleId, kZLSearchDBEntityIdKey:entityId} mutableCopy];
    
    for (NSString *key in metadata.allKeys) {
        NSString *newKey;
        if ([key isEqualToString:kZLFileMetadataTitle]) {
            newKey = kZLSearchDBTitleKey;
        } else if ([key isEqualToString:kZLFileMetadataSubtitle]) {
            newKey = kZLSearchDBSubtitleKey;
        } else if ([key isEqualToString:kZLFileMetadataFileType]) {
            newKey = kZLSearchDBTypeKey;
        } else if ([key isEqualToString:kZLFileMetadataURI]) {
            newKey = kZLSearchDBUriKey;
        } else if ([key isEqualToString:kZLFileMetadataImageURI]) {
            newKey = kZLSearchDBImageUriKey;
        }
        
        if (newKey) {
            [insertDictionary setObject:metadata[key] forKey:newKey];
        }
    }
    return [insertDictionary copy];
}

+ (NSString *)stringWithLastWordHavingPrefixOperatorFromString:(NSString *)oldString
{
    NSString *newString = @"";
    newString = [oldString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    newString = [newString stringByAppendingString:@"*"];
    
    return newString;
}

- (BOOL)doesFileExistWithModuleId:(NSString *)moduleId entityId:(NSString *)entityId
{
    __block BOOL doesExist = NO;
    
    [self.queue inDatabase:^(FMDatabase *db) {
        [db open];
        
        NSString *indexQuery = [NSString stringWithFormat:@"SELECT * FROM %@ WHERE %@ = ? AND %@ = ?", kZLSearchDBIndexTableName, kZLSearchDBModuleIdKey, kZLSearchDBEntityIdKey];
        FMResultSet *indexResultSet = [db executeQuery:indexQuery, moduleId, entityId];
        if ([indexResultSet next]) {
            doesExist = YES;
        }
        
        NSString *metaQuery = [NSString stringWithFormat:@"SELECT * FROM %@ WHERE %@ = ? AND %@ = ?", kZLSearchDBMetadataTableName, kZLSearchDBModuleIdKey, kZLSearchDBEntityIdKey];
        FMResultSet *metaResultSet = [db executeQuery:metaQuery, moduleId, entityId];
        if ([metaResultSet next]) {
            doesExist = YES;
        }
        
        [db closeOpenResultSets];
    }];
    
    return doesExist;
}

@end
