//
//  SKCatuvediParser.m
//  शब्दकोश कंपाइलर
//
//  Created by जमादार on 22-3-14.
//  Copyright (c) 2014 Apple. All rights reserved.
//

#import "SKCatuvediParser.h"

#import "NSCharacterSet+SKAdditions.h"
#import "SKDictionaryEntry.h"
#import "SKParser_Internal.h"

@implementation SKCatuvediParser

+ (NSArray *)entriesFromParsingLinesInString:(NSString *)lines
{
    NSCharacterSet *matchPunctuationCharacterSet = [NSCharacterSet characterSetWithCharactersInString:@"-()~, "]; // forward slashes don't need to be matched between Devanagari and Latin
    NSCharacterSet *validPunctuationCharacterSet = [NSCharacterSet characterSetWithCharactersInString:@"-()/~, "];
    
    NSCharacterSet *devanagariCharacterSet = [NSCharacterSet devanagariCharacterSet];
    NSMutableCharacterSet *validDevanagariCharacterSet = [devanagariCharacterSet mutableCopy];
    [validDevanagariCharacterSet formUnionWithCharacterSet:validPunctuationCharacterSet];
    
    NSCharacterSet *latinCharacterSet = [NSCharacterSet latinCharacterSet];
    NSMutableCharacterSet *validLatinCharacterSet = [latinCharacterSet mutableCopy];
    [validLatinCharacterSet formUnionWithCharacterSet:validPunctuationCharacterSet];
    
    NSMutableArray *dictionaryEntries = [NSMutableArray array];
    NSMutableDictionary *headwordToDictionaryEntries = [NSMutableDictionary dictionary];
    [lines enumerateLinesUsingBlock:^(NSString *line, BOOL *stop) {
        if ([line length] == 0) {
            return;
        }
        
        NSScanner *scanner = [NSScanner scannerWithString:line];
        scanner.charactersToBeSkipped = nil;
        
        BOOL success = YES;
        
        NSString *word;
        success = success && [scanner scanCharactersFromSet:validDevanagariCharacterSet intoString:&word];
        if (!success) {
            NSLog(@"%@", line);
            return;
        }
        
        // Parse Latin according to Devanagari pattern
        NSUInteger previousPunctIndex = NSNotFound;
        NSMutableArray *punctuationPattern = [NSMutableArray array];
        for (NSUInteger i = 0; i < [word length]; i++) {
            unichar currentChar = [word characterAtIndex:i];
            if ([matchPunctuationCharacterSet characterIsMember:currentChar]) {
                NSString *punct = [word substringWithRange:NSMakeRange(i, 1)];
                if (previousPunctIndex != NSNotFound && previousPunctIndex + 1 == i) {
                    NSMutableString *previousPunct = [[punctuationPattern lastObject] mutableCopy];
                    [previousPunct appendString:punct];
                    [punctuationPattern replaceObjectAtIndex:([punctuationPattern count] - 1) withObject:previousPunct];
                }
                else {
                    [punctuationPattern addObject:punct];
                }
                previousPunctIndex = i;
            }
        }
        
        NSMutableString *mutablePronunciation = [NSMutableString string];
        while ([punctuationPattern count] > 0) {
            NSString *punctuation = [punctuationPattern objectAtIndex:0];
            [punctuationPattern removeObjectAtIndex:0];
            
            if ([scanner isAtEnd]) {
                NSLog(@"%@", line);
                return;
            }
            
            NSString *segment;
            
            success = success && [scanner scanUpToString:punctuation intoString:&segment];
            if (!success) {
                NSLog(@"%@", line);
                return;
            }
            [mutablePronunciation appendString:segment];
            
            success = success && [scanner scanString:punctuation intoString:&segment];
            if (!success) {
                NSLog(@"%@", line);
                return;
            }
            [mutablePronunciation appendString:segment];
        }
        
        word = [word stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        NSString *pronunciation = [mutablePronunciation stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        
        /* Ad-hoc checks to ensure that entries are well-formed. */
        
        // "—" should only occur in definitions, not in the pronunciation portion, so if it is found in the pronunciation, then something is malformed
        success = success && [pronunciation rangeOfString:@"—"].location == NSNotFound;
        if (!success) {
            NSLog(@"%@ %@", word, pronunciation);
            return;
        }
        
        NSString *entryText = [line substringWithRange:NSMakeRange([scanner scanLocation], [line length] - [scanner scanLocation])];
        
        SKDictionaryEntry *entry = [SKDictionaryEntry entry];
        entry.rawHeadword = word;
        entry.rawPronunciation = pronunciation;
        entry.entryText = entryText;
        [entry generateIndexEntriesAndHeadword];
        
        [dictionaryEntries addObject:entry];
        
        NSMutableArray *entriesForHeadword = [headwordToDictionaryEntries objectForKey:entry.headword];
        if (entriesForHeadword == nil) {
            entriesForHeadword = [NSMutableArray array];
            [headwordToDictionaryEntries setObject:entriesForHeadword forKey:entry.headword];
        }
        [entriesForHeadword addObject:entry];
    }];
    
    // Set Unique IDs
    for (NSString *headword in headwordToDictionaryEntries) {
        NSArray *entries = [headwordToDictionaryEntries objectForKey:headword];
        NSUInteger entryID = 0;
        for (SKDictionaryEntry *entry in entries) {
            entry.uniqueID = [NSString stringWithFormat:@"%@_%lu", entry.headword, entryID];
            entryID++;
        }
    }
    
    NSLog(@"Scanned %lu entries", [dictionaryEntries count]);
    
    return dictionaryEntries;
}

@end
