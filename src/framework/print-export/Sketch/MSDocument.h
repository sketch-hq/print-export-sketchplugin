//
//  MSDocument.h
//  print-export
//
//  Created by Mark Horgan on 21/03/2019.
//  Copyright © 2019 Sketch. All rights reserved.
//

#import <AppKit/AppKit.h>
#import "MSDocumentData.h"
#import "MSContentDrawViewController.h"

@interface MSDocument: NSDocument

@property (readonly, nonatomic) MSDocumentData *documentData;
@property (readonly, nonatomic) MSContentDrawViewController *currentContentViewController;

@end
