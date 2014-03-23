//
//  SKAppDelegate.h
//  Caturvedi
//
//  Created by जमादारा on Sun 9/11/11.
//  Copyright (c) 2011 Apple. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "SKParser.h"

@interface SKAppDelegate : NSObject <NSApplicationDelegate>

@property (nonatomic, assign) SKDictionaryFormat selectedFormatIndex;
@property (nonatomic, readonly) NSString *sourceFileLabelText;
@property (nonatomic, readonly) NSString *destinationFileLabelText;
@property (nonatomic, readonly) BOOL startButtonEnabled;
@property (nonatomic, assign) BOOL parsing;
@property (nonatomic, copy) NSString *statusText;

@property (nonatomic, assign) IBOutlet NSWindow *window;

- (IBAction)selectSourceFileAction:(id)sender;
- (IBAction)selectOutputDirectoryAction:(id)sender;
- (IBAction)start:(id)sender;

@end
