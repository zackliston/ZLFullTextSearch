//
//  ADTestSearchRank.m
//  AgileSDK
//
//  Created by Zack Liston on 1/26/15.
//  Copyright (c) 2015 AgileMD. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>
#include "ZLSearchRank.h"

@interface ADTestSearchRank : XCTestCase

@end

double inverseDocumentFrequency(int totalNumberOfDocuments, int numberOfDocumentsContainingSearchPhrase);
double normalizedTermFrequencyForField(int numberOfMatches, int lengthOfFieldInWords, int averageLengthOfFieldInWords, double bConstant);
double normalizedTermFrequencyForDocument(double fieldWeights[], double fieldNormalizedTermFrequencies[], int numberOfFields);
double BM25F(double normalizedWeightedTermFrequencies[], double inverseDocumentFrequencies[], double saturationConstant, int numberOfTerms);


@implementation ADTestSearchRank

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

#pragma mark - Test Inverse Document Frequency

- (void)testInverseDocumentFrequency
{
    int totalNumberOfDocuments = abs(arc4random())+1;
    int numberOfDocumentsContainingSearchPhrase = arc4random_uniform(totalNumberOfDocuments)+1;
    
    double numerator = totalNumberOfDocuments-numberOfDocumentsContainingSearchPhrase+0.5;
    double denominator = numberOfDocumentsContainingSearchPhrase+0.5;
    double fraction = numerator/denominator;
    
    double expectedResult = log(fraction);
    
    double result = inverseDocumentFrequency(totalNumberOfDocuments, numberOfDocumentsContainingSearchPhrase);
    
    XCTAssertEqualWithAccuracy(expectedResult, result, 0.0001);
}

- (void)testInverseDocumentFrequencyZeroDocuments
{
    int totalNumberOfDocuments = 0;
    int numberOfDocumentsContainingSearchPhrase = abs(arc4random())+1;

    
    double expectedResult = 0.0;
    
    double result = inverseDocumentFrequency(totalNumberOfDocuments, numberOfDocumentsContainingSearchPhrase);
    
    XCTAssertEqualWithAccuracy(expectedResult, result, 0.0001);
}

#pragma mark - Test Normalized Term Frequency For Field

- (void)testNormalizedTermFrequencyForField
{
    int lengthOfFieldInWords = abs(arc4random())+1;
    int numberOfMatches = arc4random_uniform(lengthOfFieldInWords);
    int averageLengthOfFieldInWords = abs(arc4random())+1;
    double bConstant = 0.4;
    
    double numerator = numberOfMatches;
    double denominator = 1+bConstant*(((double)lengthOfFieldInWords/(double)averageLengthOfFieldInWords)-1);
    
    double expectedResult = numerator/denominator;
    
    double result = normalizedTermFrequencyForField(numberOfMatches, lengthOfFieldInWords, averageLengthOfFieldInWords, bConstant);
    
    XCTAssertEqualWithAccuracy(expectedResult, result, 0.0001);
}

- (void)testNormalizedTermFrequencyForFieldNoMatches
{
    int lengthOfFieldInWords = abs(arc4random())+1;
    int numberOfMatches = 0;
    int averageLengthOfFieldInWords = abs(arc4random())+1;
    double bConstant = 0.4;
    
    double expectedResult = 0.0;
    
    double result = normalizedTermFrequencyForField(numberOfMatches, lengthOfFieldInWords, averageLengthOfFieldInWords, bConstant);
    
    XCTAssertEqualWithAccuracy(expectedResult, result, 0.0001);
}

- (void)testNormalizedTermFrequencyForFieldEmptyField
{
    int lengthOfFieldInWords = 0;
    int numberOfMatches = arc4random_uniform(100)+1;
    int averageLengthOfFieldInWords = abs(arc4random())+1;
    double bConstant = 0.4;
    
    double expectedResult = 0.0;
    
    double result = normalizedTermFrequencyForField(numberOfMatches, lengthOfFieldInWords, averageLengthOfFieldInWords, bConstant);
    
    XCTAssertEqualWithAccuracy(expectedResult, result, 0.0001);
}


- (void)testNormalizedTermFrequencyForFieldZeroAverage
{
    int lengthOfFieldInWords = abs(arc4random())+1;
    int numberOfMatches = arc4random_uniform(lengthOfFieldInWords);
    int averageLengthOfFieldInWords = 0;
    double bConstant = 0.4;
    
    double numerator = numberOfMatches;
    double denominator = 1+bConstant*(((double)lengthOfFieldInWords/(double)1)-1);
    
    double expectedResult = numerator/denominator;

    
    double result = normalizedTermFrequencyForField(numberOfMatches, lengthOfFieldInWords, averageLengthOfFieldInWords, bConstant);
    
    XCTAssertEqualWithAccuracy(expectedResult, result, 0.0001);
}

#pragma mark - Test NormalizedTermFrequencyForDocument

- (void)testNormalizedTermFrequencyForDocument
{
    int numberOfFields = 4;// arc4random_uniform(50)+1;
    
    double fieldWeights[numberOfFields];
    double fieldNormalizedTermFrequencies[numberOfFields];
    
    double expectedResult = 0.0;
    
    for (int i=0;i<numberOfFields;i++) {
        double weight = drand48();
        double NTF = drand48();
        
        fieldWeights[i] = weight;
        fieldNormalizedTermFrequencies[i] = NTF;
        
        expectedResult += (weight*NTF);
    }
    
    double result = normalizedTermFrequencyForDocument(fieldWeights, fieldNormalizedTermFrequencies, numberOfFields);
    
    XCTAssertEqualWithAccuracy(expectedResult, result, 0.0001);
}

#pragma mark - Test BM25

- (void)testBM25
{
    int numberOfTerms = arc4random_uniform(50)+1;
    
    double termFrequencies[numberOfTerms];
    double termIDFs[numberOfTerms];
    double saturationConstant = drand48();
    
    double expectedRank = 0.0;
    for (int i=0;i<numberOfTerms; i++) {
        double NTF = drand48();
        double IDF = drand48();
        
        termFrequencies[i] = NTF;
        termIDFs[i] = IDF;
        
        expectedRank += (NTF/(saturationConstant+NTF)) * IDF;
    }
    
    double result = BM25F(termFrequencies, termIDFs, saturationConstant, numberOfTerms);
    
    XCTAssertEqualWithAccuracy(expectedRank, result, 0.0001);
}


@end
