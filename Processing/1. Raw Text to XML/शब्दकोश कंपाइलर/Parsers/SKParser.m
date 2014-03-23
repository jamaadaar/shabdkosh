//
//  SKParser.m
//  शब्दकोश कंपाइलर
//
//  Created by जमादार on 22-3-14.
//  Copyright (c) 2014 Apple. All rights reserved.
//

#import "SKParser_Internal.h"

#import "SKCatuvediParser.h"

@implementation SKParser

+ (NSArray *)entriesFromParsingLinesInString:(NSString *)lines format:(SKDictionaryFormat)format
{
    Class parserClass = Nil;
    switch (format) {
        case SKDictionaryFormatCaturvedi:
            parserClass = [SKCatuvediParser class];
    };
    
    if (parserClass != Nil) {
        return [parserClass entriesFromParsingLinesInString:lines];
    }
    
    return nil;
}

+ (NSArray *)entriesFromParsingLinesInString:(NSString *)lines
{
    NSAssert(NO, @"required subclass override");
    return nil;
}

@end
