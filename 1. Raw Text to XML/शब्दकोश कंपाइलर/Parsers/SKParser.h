//
//  SKParser.h
//  शब्दकोश कंपाइलर
//
//  Created by जमादार on 22-3-14.
//  Copyright (c) 2014 Apple. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum SKDictionaryFormat : NSUInteger {
    SKDictionaryFormatCaturvedi,
} SKDictionaryFormat;

@interface SKParser : NSObject

+ (NSArray *)entriesFromParsingLinesInString:(NSString *)lines format:(SKDictionaryFormat)format;

@end
