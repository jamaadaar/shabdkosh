//
//  NSString+SKAdditions.h
//  शब्दकोश कंपाइलर
//
//  Created by जमादार on 22-3-14.
//  Copyright (c) 2014 Apple. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (SKAdditions)

- (NSString *)escapedStringForXML;
- (NSString *)escapedStringForXMLName;
- (NSString *)stringByTrimmingWhitespace;
- (BOOL)hasSubstring:(NSString *)substring;

@end

