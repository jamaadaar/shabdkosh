//
//  SKDictionaryEntry.m
//  शब्दकोश कंपाइलर
//
//  Created by जमादार on 22-3-14.
//  Copyright (c) 2014 Apple. All rights reserved.
//

#import "SKDictionaryEntry.h"

#import "NSCharacterSet+SKAdditions.h"
#import "NSString+SKAdditions.h"

static NSDictionary *GetAbbreviationsToExpansionsDictionary()
{
    static NSDictionary *__abbrToExpansions = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        __abbrToExpansions = [NSDictionary dictionaryWithObjectsAndKeys:
                              @"adjective", @"a",
                              @"adverb", @"adv",
                              @"figurative", @"fig",
                              @"indeclinable", @"ind",
                              @"interjection", @"int",
                              @"literal", @"lit",
                              @"noun feminine", @"nf",
                              @"noun masculine", @"nm",
                              @"noun masculine and feminine", @"nm, nf",
                              @"postposition", @"post",
                              @"pronoun", @"pro",
                              @"verb", @"v",
                              @"feminine", @"f",
                              @"masculine", @"m",
                              @"plural", @"pl",
                              @"singular", @"sing",
                              @"archaic", @"arch",
                              nil];
    });
    return __abbrToExpansions;
}

@implementation SKDictionaryEntry

@synthesize uniqueID = _uniqueID;
@synthesize rawHeadword = _word;
@synthesize rawPronunciation = _pronunciation;
@synthesize headword = _headword;
@synthesize entryText = _entryText;
@synthesize indexEntries = _indexEntries;

+ (SKDictionaryEntry *)entry
{
    return [[SKDictionaryEntry alloc] init];
}

- (NSString *)XMLRepresentationForEntryText
{
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"\\(([^()]+)\\)" options:0 error:NULL]; // match anything that looks like '(...)' for tags
    NSMutableString *result = [self.entryText mutableCopy];
    
    /* Expand Tags from Abbreviations into their Full Forms */
    
    // TODO: support generic comma-separate tags such as "(a,nm)", etc.
    NSSet *validTags = [NSSet setWithArray:[GetAbbreviationsToExpansionsDictionary() allKeys]];
    
    NSMutableArray *tags = [NSMutableArray array];
    [regex enumerateMatchesInString:self.entryText
                            options:0
                              range:NSMakeRange(0, [self.entryText length])
                         usingBlock:^(NSTextCheckingResult *match, NSMatchingFlags flags, BOOL *stop) {
                             if ([validTags member:[self.entryText substringWithRange:[match rangeAtIndex:1]]]) {
                                 [tags addObject:[self.entryText substringWithRange:[match range]]];
                             }
                         }];
    
    NSRange searchRange = NSMakeRange(0, [result length]);
    for (NSString *tag in [tags reverseObjectEnumerator]) {
        NSRange r = [result rangeOfString:tag options:NSBackwardsSearch range:searchRange];
        NSString *tagCore = [result substringWithRange:r];
        tagCore = [tagCore stringByReplacingOccurrencesOfString:@"(" withString:@""];
        tagCore = [tagCore stringByReplacingOccurrencesOfString:@")" withString:@""];
        NSString *expansion = [GetAbbreviationsToExpansionsDictionary() objectForKey:tagCore];
        if (expansion != nil) {
            [result replaceCharactersInRange:r withString:[NSString stringWithFormat:@"<span class=\"label\">%@</span>", expansion]];
        }
        searchRange = NSMakeRange(0, r.location);
        if (NSMaxRange(searchRange) == 0) {
            break;
        }
    }
    
    return result;
}

static NSOrderedSet *GetDevanagariSequencesByExplodingSlashes(NSArray *devanagariSequences)
{
    // Slash Handling:
    // (1) if after the slash, there is a character from the set { ~ - — • }, then that becomes an independent sequence e.g. ~पूर्ण/~मय
    // (2) if after the slash, there is only a single word and none of the control chars, then it becomes an alternate for the previous word e.g. —का पैमाना/प्याला भर जाना
    
    NSCharacterSet *nonDevaSet = [[NSCharacterSet devanagariCharacterSet] invertedSet];
    
    // Case (1): split off all the unrelated strings unto themselves.
    
    NSMutableArray *sequencesAfterStage1 = [NSMutableArray array];
    
    for (NSUInteger i = 0; i < [devanagariSequences count]; i++) {
        NSString *sequence = [devanagariSequences objectAtIndex:i];
        
        NSArray * (^splitStringWithString)(NSString *str, NSArray *separators) = ^(NSString *str, NSArray *separators) {
            NSMutableSet *results = [NSMutableSet setWithCapacity:[separators count]];
            for (NSString *separator in separators) {
                NSString *left;
                NSString *right;
                NSRange r = [str rangeOfString:separator];
                if (r.location != NSNotFound) {
                    left = [str substringToIndex:r.location];
                    right = [str substringFromIndex:r.location];
                }
                else {
                    left = str;
                    right = @"";
                }
                [results addObject:[NSArray arrayWithObjects:left, right, nil]];
            }
            
            NSArray *resultWithShortestLeft = [results anyObject];
            for (NSArray *result in results) {
                if ([[result objectAtIndex:0] length] < [[resultWithShortestLeft objectAtIndex:0] length]) {
                    resultWithShortestLeft = result;
                }
            }
            
            return resultWithShortestLeft;
        };
        
        NSMutableString *remainingString = [sequence mutableCopy];
        NSArray *separators = [NSArray arrayWithObjects:@"/~", @"/-", @"/—", @"/•", nil];
        
        while (1) {
            NSArray *split = splitStringWithString(remainingString, separators);
            NSString *left = [[split objectAtIndex:0] copy];
            NSString *right = [[split objectAtIndex:1] copy];
            [sequencesAfterStage1 addObject:left];
            if ([right length] > 0) {
                [remainingString deleteCharactersInRange:NSMakeRange(0, [left length] + 1)]; // extra 1 to get rid of the separator "/"
            }
            else {
                [remainingString deleteCharactersInRange:NSMakeRange(0, [left length])];
                break;
            }
        }
    }
    
    // Case (2): explode entries wherever slashes cause string to branch
    
    NSMutableArray *sequencesRemainingToExplode = [sequencesAfterStage1 mutableCopy];
    NSMutableOrderedSet *sequencesAfterStage2 = [NSMutableOrderedSet orderedSet];
    
    while ([sequencesRemainingToExplode count] > 0) {
        NSString *sequence = [sequencesRemainingToExplode objectAtIndex:0];
        [sequencesRemainingToExplode removeObjectAtIndex:0];
        
        if (![sequence hasSubstring:@"/"]) {
            [sequencesAfterStage2 addObject:sequence];
        }
        else {
            NSRange r;
            if ((r = [sequence rangeOfString:@"/"]).location != NSNotFound) {
                NSRange rPreNonDeva = [sequence rangeOfCharacterFromSet:nonDevaSet
                                                                options:NSBackwardsSearch
                                                                  range:NSMakeRange(0, r.location)];
                NSRange rPostNonDeva = [sequence rangeOfCharacterFromSet:nonDevaSet
                                                                 options:0
                                                                   range:NSMakeRange(r.location + 1, [sequence length] - (r.location + 1))];
                
                NSString *pre;
                if (rPreNonDeva.location == NSNotFound) {
                    pre = [sequence substringToIndex:r.location];
                } else {
                    pre = [sequence substringWithRange:NSMakeRange(rPreNonDeva.location + 1, r.location - (rPreNonDeva.location + 1))];
                }
                
                NSString *post;
                if (rPostNonDeva.location == NSNotFound) {
                    post = [sequence substringFromIndex:(r.location + 1)];
                } else {
                    post = [sequence substringWithRange:NSMakeRange(r.location + 1, rPostNonDeva.location - (r.location + 1))];
                }
                
                NSString *replacement = [NSString stringWithFormat:@"%@/%@", pre, post];
                NSRange replacementRange = NSMakeRange(r.location - [pre length], [pre length] + 1 + [post length]);
                {
                    NSString *explodedPre = [sequence stringByReplacingOccurrencesOfString:replacement withString:pre options:0 range:replacementRange];
                    if ([explodedPre hasSubstring:@"/"]) {
                        [sequencesRemainingToExplode addObject:explodedPre];
                    } else if ([explodedPre length] > 0) {
                        [sequencesAfterStage2 addObject:explodedPre];
                    }
                }
                {
                    NSString *explodedPost = [sequence stringByReplacingOccurrencesOfString:replacement withString:post options:0 range:replacementRange];
                    if ([explodedPost hasSubstring:@"/"]) {
                        [sequencesRemainingToExplode addObject:explodedPost];
                    } else if ([explodedPost length] > 0) {
                        [sequencesAfterStage2 addObject:explodedPost];
                    }
                }
            }
        }
    }
    
    return sequencesAfterStage2;
}

- (void)generateIndexEntriesAndHeadword
{
    /* Devanagari Sequences that start/end with: (1) ~ connect with the headword (before the slash, if any) to form a compound word, (2) - or — connect with the (full) headword to form a phrase, (3) • connect with the previous subentry (which can be the headword) to form a phrase */
    
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"\\(([^()]+)\\)" options:0 error:NULL]; // match anything that looks like '(...)' for tags
    
    NSMutableOrderedSet *indexWords = [NSMutableOrderedSet orderedSet];
    
    NSArray *headwords;
    
    if ([self.rawHeadword rangeOfString:@","].location != NSNotFound || [self.rawHeadword rangeOfString:@"("].location != NSNotFound || [self.rawHeadword rangeOfString:@"~"].location != NSNotFound) {
        NSArray *words;
        if ([self.rawHeadword rangeOfString:@","].location != NSNotFound) {
            NSArray *components = [self.rawHeadword componentsSeparatedByString:@","];
            NSMutableArray *mutableComponents = [components mutableCopy];
            [components enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                NSString *s = obj;
                s = [s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                [mutableComponents replaceObjectAtIndex:idx withObject:s];
            }];
            words = mutableComponents;
        }
        else {
            words = [NSArray arrayWithObject:[self.rawHeadword stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]];
        }
        
        if ([words count] > 0) {
            NSMutableOrderedSet *expandedWords = [NSMutableOrderedSet orderedSet];
            
            NSCharacterSet *devanagariSet = [NSCharacterSet devanagariCharacterSet];
            NSMutableOrderedSet *preslashHeadwords = [NSMutableOrderedSet orderedSet];
            for (NSString *word in words) {
                if ([devanagariSet characterIsMember:[word characterAtIndex:0]]) { // does not start with a ~ or anything
                    NSRange slashRange = [word rangeOfString:@"/"];
                    if (slashRange.location != NSNotFound) {
                        [preslashHeadwords addObject:[word substringToIndex:slashRange.location]];
                    } else {
                        [preslashHeadwords addObject:word];
                    }
                }
            }
            
            for (NSString *word in words) {
                for (NSString *preslashHeadword in preslashHeadwords) {
                    NSString *expandedWord = word;
                    BOOL hasTilde = [word hasPrefix:@"~"];
                    if (hasTilde) { // the ones with tildes are not part of the headword
                        expandedWord = [NSString stringWithFormat:@"%@%@", preslashHeadword, [word substringFromIndex:1]];
                    }
                    
                    // for words which have multiple optional segments (none as of this writing), this will produce one fully expanded version with all the parens taken out but the contents of the parens left in (all the optional parts left in), and one fully collapsed version with all the parens and their contents taken out (all the optional parts taken out).
                    if ([expandedWord rangeOfString:@"("].location != NSNotFound) {
                        NSString *fullyExpandedWord = [regex stringByReplacingMatchesInString:expandedWord
                                                                                      options:0
                                                                                        range:NSMakeRange(0, [expandedWord length])
                                                                                 withTemplate:@"$1"];
                        [indexWords addObject:[fullyExpandedWord stringByReplacingOccurrencesOfString:@"/" withString:@""]];
                        if (!hasTilde) {
                            [expandedWords addObject:fullyExpandedWord];
                        }
                        
                        NSString *fullyCollapsedWord = [regex stringByReplacingMatchesInString:expandedWord
                                                                                       options:0
                                                                                         range:NSMakeRange(0, [expandedWord length])
                                                                                  withTemplate:@""];
                        [indexWords addObject:[fullyCollapsedWord stringByReplacingOccurrencesOfString:@"/" withString:@""]];
                        if (!hasTilde) {
                            [expandedWords addObject:fullyCollapsedWord];
                        }
                    }
                    else {
                        [indexWords addObject:[expandedWord stringByReplacingOccurrencesOfString:@"/" withString:@""]];
                        if (!hasTilde) {
                            [expandedWords addObject:expandedWord];
                        }
                    }
                }
            }
            
            words = [expandedWords array];
        }
        
        headwords = words;
    }
    else {
        headwords = [NSArray arrayWithObject:self.rawHeadword];
        [indexWords addObject:[self.rawHeadword stringByReplacingOccurrencesOfString:@"/" withString:@""]];
    }
    
    NSMutableOrderedSet *devanagariSequences = [NSMutableOrderedSet orderedSet];
    {
        NSCharacterSet *devanagariCharacterSet = [NSCharacterSet devanagariCharacterSet];
        
        NSMutableCharacterSet *controlSet = [NSMutableCharacterSet characterSetWithCharactersInString:@"~-—•"];
        [controlSet formUnionWithCharacterSet:devanagariCharacterSet];
        
        NSMutableCharacterSet *nonDevanagariCharacterSet = [NSMutableCharacterSet characterSetWithCharactersInString:@"/~-—• "];
        [nonDevanagariCharacterSet formUnionWithCharacterSet:devanagariCharacterSet];
        [nonDevanagariCharacterSet invert];
        
        for (NSUInteger i = 0; i < [self.entryText length]; i++) {
            unichar c = [self.entryText characterAtIndex:i];
            if ([controlSet characterIsMember:c]) {
                NSRange searchRange = NSMakeRange(i, [self.entryText length] - i);
                NSRange nonDevaRange = [self.entryText rangeOfCharacterFromSet:nonDevanagariCharacterSet options:0 range:searchRange];
                NSRange devaRange;
                if (nonDevaRange.location == NSNotFound) {
                    devaRange = searchRange;
                } else {
                    NSParameterAssert(nonDevaRange.location >= i);
                    devaRange = NSMakeRange(i, nonDevaRange.location - i);
                }
                NSString *devaSeq = [[self.entryText substringWithRange:devaRange] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                if (devaSeq > 0) {
                    // Control set contains non-Devanagari characters as well. If this word does not have any Devanagari characters, skip it.
                    if ([devaSeq rangeOfCharacterFromSet:devanagariCharacterSet].location != NSNotFound) {
                        [devanagariSequences addObject:devaSeq];
                    }
                }
                i = NSMaxRange(devaRange);
            }
        }
    }
    
    devanagariSequences = [GetDevanagariSequencesByExplodingSlashes([devanagariSequences array]) mutableCopy];
    
    for (NSString *headword in headwords) {
        NSString *preslashHeadword;
        NSRange slashRange = [headword rangeOfString:@"/"];
        if (slashRange.location != NSNotFound) {
            preslashHeadword = [headword substringToIndex:slashRange.location];
        } else {
            preslashHeadword = headword;
        }
        
        NSString *previousWord = [headword stringByReplacingOccurrencesOfString:@"/" withString:@""];
        
        for (NSString *devaSeq in devanagariSequences) {
            NSString *word;
            
            if ([devaSeq hasPrefix:@"~"]) {
                word = [NSString stringWithFormat:@"%@%@", preslashHeadword, [devaSeq substringFromIndex:1]];
                previousWord = word;
            }
            else if ([devaSeq hasSuffix:@"~"]) {
                word = [NSString stringWithFormat:@"%@%@", [devaSeq substringToIndex:([devaSeq length] - 1)], preslashHeadword];
                previousWord = word;
            }
            else if ([devaSeq hasPrefix:@"-"] || [devaSeq hasPrefix:@"—"]) {
                word = [NSString stringWithFormat:@"%@ %@", preslashHeadword, [devaSeq substringFromIndex:1]];
                previousWord = word;
            }
            else if ([devaSeq hasSuffix:@"-"] || [devaSeq hasSuffix:@"—"]) {
                word = [NSString stringWithFormat:@"%@ %@", [devaSeq substringToIndex:([devaSeq length] - 1)], preslashHeadword];
                previousWord = word;
            }
            else if ([devaSeq hasPrefix:@"•"]) {
                word = [NSString stringWithFormat:@"%@ %@", previousWord, [devaSeq substringFromIndex:1]];
            }
            else if ([devaSeq hasSuffix:@"•"]) {
                word = [NSString stringWithFormat:@"%@ %@", [devaSeq substringToIndex:([devaSeq length] - 1)], previousWord];
            }
            
            if ([word length] > 0) {
                [indexWords addObject:word];
            }
        }
    }
    
    self.indexEntries = [indexWords array];
    self.headword = [self.indexEntries objectAtIndex:0];
}

- (NSString *)XMLRepresentation
{
    NSMutableString *result = [NSMutableString string];
    
    NSArray *indexEntries = self.indexEntries;
    NSString *headword = self.headword;
    NSString *pronunciation = [self.rawPronunciation stringByReplacingOccurrencesOfString:@"/" withString:@""];
    
    [result appendFormat:@"<d:entry id=\"%@\" d:title=\"%@\">\n", [self.uniqueID escapedStringForXMLName], headword];
    for (NSString *entry in indexEntries) {
        [result appendFormat:@"    <d:index d:value=\"%@\"/>\n", entry];
    }
    [result appendFormat:@"    <div><span class=\"headword\">%@</span> <span class=\"pr\">| %@ |</span> </div>\n", headword, pronunciation];
    [result appendFormat:@"    <div><p>%@</p></div>\n", [self XMLRepresentationForEntryText]];
    [result appendFormat:@"</d:entry>"];
    
    return result;
}

@end
