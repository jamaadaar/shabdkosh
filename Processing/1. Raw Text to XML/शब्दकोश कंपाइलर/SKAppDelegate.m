//
//  SKAppDelegate.m
//  Caturvedi
//
//  Created by जमादारा on Sun 9/11/11.
//  Copyright (c) 2011 Apple. All rights reserved.
//

#import "SKAppDelegate.h"

#import "NSCharacterSet+SKAdditions.h"
#import "NSString+SKAdditions.h"
#import "SKDictionaryEntry.h"

// TODO: Instead of showing ~ and –, the derived words and phrases should show the full word or phrase.
// TODO: Multiple labels within the same entry need to be handled better.
// TODO: Add English index - find those English words that are unique to a particular entry and then find entries for all the discarded stop words.
// TODO: Take word inflections into accountfor building index (the gender of the word should be useful)

@interface SKAppDelegate ()

@property (nonatomic, copy) NSURL *sourceFileURL;
@property (nonatomic, copy) NSURL *outputFileURL;

@end


@implementation SKAppDelegate

static NSString * const kHeader =   @"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
                                    @"<d:dictionary xmlns=\"http://www.w3.org/1999/xhtml\" xmlns:d=\"http://www.apple.com/DTDs/DictionaryService-1.0.rng\">\n"
                                    @"<d:entry id=\"dictionary_application\" d:title=\"Caturvedi\">\n"
                                    @"<d:index d:value=\"Caturvedi\"/>"
                                        @"<h1>चतुर्वेदी</h1>"
                                        @"<p>चतुर्वेदी का हिन्दी-अंग्रेज़ी शब्दकोश<br/></p>"
                                    @"</d:entry>";

static NSString * const kFooter =   @"</d:dictionary>";

- (void)parseSourceFile
{
    NSAssert(self.sourceFileURL != nil, @"self.sourceFileURL is nil");
    NSAssert(self.outputFileURL != nil, @"self.outputFileURL is nil");
 
    self.parsing = YES;
    self.statusText = NSLocalizedString(@"PROCESSING_IN_PROGRESS", nil);

    // perform the file reading, processing and writing in the background so that the ui remains responsive
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *sourceFileContents = [NSString stringWithContentsOfURL:self.sourceFileURL usedEncoding:NULL error:NULL];
        NSArray *entries = [SKParser entriesFromParsingLinesInString:sourceFileContents format:self.selectedFormatIndex];
        
        NSMutableDictionary *entriesDictionary = [NSMutableDictionary dictionaryWithCapacity:[entries count]];
        for (SKDictionaryEntry *entry in entries) {
            [entriesDictionary setObject:entry forKey:entry.rawHeadword];
        }
        entries = [[entriesDictionary allValues] sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
            SKDictionaryEntry *entry1 = obj1;
            SKDictionaryEntry *entry2 = obj2;
            return [entry1.rawHeadword localizedStandardCompare:entry2.rawHeadword];
        }];
        
        // List of Masculine and Feminine Nouns (which are headwords)
        //    {
        //        NSMutableArray *nounsMasculine = [NSMutableArray array];
        //        NSMutableArray *nounsFeminine = [NSMutableArray array];
        //        for (SKDictionaryEntry *entry in entries) {
        //            if ([entry.entryText hasPrefix:@"(nm)"]) {
        //                [nounsMasculine addObject:entry.headword];
        //            }
        //            else if ([entry.entryText hasPrefix:@"(nf)"]) {
        //                [nounsFeminine addObject:entry.headword];
        //            }
        //        }
        //        [nounsMasculine writeToFile:[@"~/Desktop/nouns-masc.plist" stringByExpandingTildeInPath] atomically:YES];
        //        [nounsFeminine writeToFile:[@"~/Desktop/nouns-fem.plist" stringByExpandingTildeInPath] atomically:YES];
        //    }
        
        if (NO) {
            // Output as Property List
            NSMutableArray *plistReps = [NSMutableArray arrayWithCapacity:[entries count]];
            for (SKDictionaryEntry *entry in entries) {
                NSDictionary *plist = [NSDictionary dictionaryWithObjectsAndKeys:
                                       entry.headword, @"headword",
                                       entry.entryText, @"text", nil];
                [plistReps addObject:plist];
            }
            [plistReps writeToFile:[@"~/Desktop/Caturvedi.plist" stringByExpandingTildeInPath] atomically:YES];
        }
        else {
            // Output as XML
            NSArray *XMLRepresentations = [entries valueForKey:@"XMLRepresentation"];
            NSString *XMLOutput = [XMLRepresentations componentsJoinedByString:@"\n"];
            XMLOutput = [NSString stringWithFormat:@"%@\n%@\n%@", kHeader, XMLOutput, kFooter];
            [XMLOutput writeToURL:self.outputFileURL atomically:YES encoding:NSUTF8StringEncoding error:NULL];
        }

        // update the ui to become enabled again on the main thread
        dispatch_async(dispatch_get_main_queue(), ^{
            self.parsing = NO;
            self.statusText = NSLocalizedString(@"PROCESSING_FINISHED", nil);
        });
    });
}

- (IBAction)selectSourceFileAction:(id)sender
{
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    openPanel.canChooseFiles = YES;
    openPanel.allowsMultipleSelection = NO;
    openPanel.canChooseDirectories = NO;
    [openPanel beginWithCompletionHandler:^(NSInteger result) {
        if (result == NSFileHandlingPanelOKButton) {
            self.sourceFileURL = openPanel.URLs.firstObject;
            if (self.sourceFileURL != nil) {
                self.outputFileURL = [[self.sourceFileURL URLByDeletingPathExtension] URLByAppendingPathExtension:@"xml"];
            }
        }
    }];
}

- (IBAction)selectOutputDirectoryAction:(id)sender
{
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    openPanel.canChooseFiles = NO;
    openPanel.allowsMultipleSelection = NO;
    openPanel.canChooseDirectories = YES;
    [openPanel beginWithCompletionHandler:^(NSInteger result) {
        if (result == NSFileHandlingPanelOKButton) {
            NSURL *URL = openPanel.URLs.firstObject;
            if (URL != nil) {
                NSString *outputFileName = [[self.sourceFileURL URLByDeletingPathExtension] URLByAppendingPathExtension:@"xml"].lastPathComponent;
                URL = [URL URLByAppendingPathComponent:outputFileName];
                self.outputFileURL = URL;
            }
        }
    }];
}

- (IBAction)start:(id)sender
{
    NSAssert(self.sourceFileURL != nil, @"self.sourceFileURL is nil");
    NSAssert(self.outputFileURL != nil, @"self.outputFileURL is nil");
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:self.outputFileURL.path]) {
        NSAlert *fileExistsAlert = [NSAlert alertWithMessageText:NSLocalizedString(@"DESTINATION_FILE_EXISTS_ERROR", nil)
                                                   defaultButton:NSLocalizedString(@"DESTINATION_FILE_EXISTS_CANCEL", nil)
                                                 alternateButton:NSLocalizedString(@"DESTINATION_FILE_EXISTS_PROCEED", nil)
                                                     otherButton:nil
                                       informativeTextWithFormat:NSLocalizedString(@"DESTINATION_FILE_EXISTS_ERROR_DESCRIPTION", nil)];
        [fileExistsAlert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
            if (returnCode == 0) {
                [self parseSourceFile];
            }
        }];
    }
    else {
        [self parseSourceFile];
    }
}

+ (NSSet *)keyPathsForValuesAffectingValueForKey:(NSString *)key
{
    if ([key isEqualToString:@"sourceFileLabelText"]) {
        return [NSSet setWithObjects:@"sourceFileURL", nil];
    }
    
    if ([key isEqualToString:@"destinationFileLabelText"]) {
        return [NSSet setWithObjects:@"outputFileURL", nil];
    }
        
    if ([key isEqualToString:@"startButtonEnabled"]) {
        return [NSSet setWithObjects:@"parsing", @"sourceFileURL", @"outputFileURL", nil];
    }
    
    return [super keyPathsForValuesAffectingValueForKey:key];
}

- (NSString *)sourceFileLabelText
{
    if (self.sourceFileURL != nil) {
        return self.sourceFileURL.path;
    } else {
        return NSLocalizedString(@"CHOOSE_SOURCE_FILE_PLACEHOLDER", nil);
    }
}

- (NSString *)destinationFileLabelText
{
    if (self.outputFileURL != nil) {
        return self.outputFileURL.path;
    } else {
        return NSLocalizedString(@"CHOOSE_DESTINATION_FILE_PLACEHOLDER", nil);
    }
}

- (BOOL)startButtonEnabled
{
    if (!self.parsing && self.sourceFileURL != nil && self.outputFileURL != nil) {
        return YES;
    }
    return NO;
}

@end
