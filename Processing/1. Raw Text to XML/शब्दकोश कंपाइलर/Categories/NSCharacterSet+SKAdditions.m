//
//  NSCharacterSet+SKAdditions.m
//  शब्दकोश कंपाइलर
//
//  Created by जमादार on 22-3-14.
//  Copyright (c) 2014 Apple. All rights reserved.
//

#import "NSCharacterSet+SKAdditions.h"

@implementation NSCharacterSet (SKAdditions)

+ (NSCharacterSet *)devanagariCharacterSet
{
    static NSCharacterSet *__devanagariCharacterSet = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSMutableCharacterSet *devanagariCharacterSet = [[NSMutableCharacterSet alloc] init];
        [devanagariCharacterSet addCharactersInRange:NSMakeRange(0x0900, 0x097F - 0x0900)];
        [devanagariCharacterSet addCharactersInRange:NSMakeRange(0xA8E0, 0xA8FF - 0xA8E0)];
        __devanagariCharacterSet = devanagariCharacterSet;
    });
    return __devanagariCharacterSet;
}

+ (NSCharacterSet *)latinCharacterSet
{
    static NSCharacterSet *__latinCharacterSet = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSMutableCharacterSet *latinCharacterSet = [[NSMutableCharacterSet alloc] init];
        [latinCharacterSet addCharactersInRange:NSMakeRange(0x0041, 0x005A - 0x0041)]; // Basic Latin
        [latinCharacterSet addCharactersInRange:NSMakeRange(0x0061, 0x007A - 0x0061)]; // Basic Latin
        [latinCharacterSet addCharactersInRange:NSMakeRange(0x00C0, 0x017E - 0x00C0)]; // Latin-1 Supplement, Latin Extended-A
        __latinCharacterSet = latinCharacterSet;
    });
    return __latinCharacterSet;
}

@end
