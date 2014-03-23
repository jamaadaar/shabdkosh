//
//  SKDictionaryEntry.h
//  शब्दकोश कंपाइलर
//
//  Created by जमादार on 22-3-14.
//  Copyright (c) 2014 Apple. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SKDictionaryEntry : NSObject

+ (SKDictionaryEntry *)entry;

@property (copy) NSString *uniqueID;
@property (copy) NSString *rawHeadword;
@property (copy) NSString *rawPronunciation;
@property (copy) NSString *headword;
@property (copy) NSString *entryText;
@property (retain) NSArray *indexEntries;

- (void)generateIndexEntriesAndHeadword;

@end
