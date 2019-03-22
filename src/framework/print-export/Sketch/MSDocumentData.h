//
//  MSDocumentData.h
//  print-export
//
//  Created by Mark Horgan on 21/03/2019.
//  Copyright © 2019 Sketch. All rights reserved.
//

#import "MSModelObject.h"
#import "MSPage.h"

@interface MSDocumentData: MSModelObject

@property (readonly, nonatomic) NSArray<MSPage*> *pages;
@property (readonly, nonatomic) MSPage *currentPage;

- (MSPage*)symbolsPage;

@end

