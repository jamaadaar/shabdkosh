//
//  NSString+SKAdditions.m
//  शब्दकोश कंपाइलर
//
//  Created by जमादार on 22-3-14.
//  Copyright (c) 2014 Apple. All rights reserved.
//

#import "NSString+SKAdditions.h"

@implementation NSString (SKAdditions)

- (NSString *)escapedStringForXML
{
    static NSCharacterSet *__charactersToEscape = nil;
    static NSDictionary *__charactersToEscapedCharacters = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        __charactersToEscape = [NSCharacterSet characterSetWithCharactersInString:@"&:\\/\"'<>"];
        __charactersToEscapedCharacters = [NSDictionary dictionaryWithObjectsAndKeys:
                                           @"&amp;", @"&",
                                           @"&#58;", @":",
                                           @"&#92;", @"\\",
                                           @"&#47;", @"/",
                                           @"&quot;", @"\"",
                                           @"&#x27;", @"'",
                                           @"&lt;", @"<",
                                           @"&gt;", @">",
                                           nil];
        
    });
    
    NSMutableString *result = [self mutableCopy];
    NSRange r = NSMakeRange(0, 0);
    while ((r = [result rangeOfCharacterFromSet:__charactersToEscape
                                        options:NSLiteralSearch
                                          range:NSMakeRange(NSMaxRange(r), [result length] - NSMaxRange(r))]).location != NSNotFound)
    {
        NSString *substring = [result substringWithRange:r];
        NSString *replacement = [__charactersToEscapedCharacters objectForKey:substring];
        [result replaceCharactersInRange:r withString:replacement];
        r.location = NSMaxRange(r);
        r.length = [replacement length];
    }
    return result;
}

- (NSString *)escapedStringForXMLName
{
    static NSCharacterSet *__charactersToEscape = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        __charactersToEscape = [NSCharacterSet characterSetWithCharactersInString:@"&:\\/\"'<>()-"];
        
    });
    
    NSMutableString *result = [self mutableCopy];
    NSRange r = NSMakeRange(0, 0);
    while ((r = [result rangeOfCharacterFromSet:__charactersToEscape options:NSLiteralSearch range:NSMakeRange(r.location + r.length, [result length] - (r.location + r.length))]).location != NSNotFound) {
        NSString *replacement = @"_";
        [result replaceCharactersInRange:r withString:replacement];
        r.length = [replacement length];
    }
    return result;
}

- (NSString *)stringByTrimmingWhitespace
{
    return [self stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
}

- (BOOL)hasSubstring:(NSString *)substring
{
    return [self rangeOfString:substring].location != NSNotFound;
}

@end
