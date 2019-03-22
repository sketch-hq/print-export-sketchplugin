//
//  MSImmutableDocumentData.h
//  print-export
//
//  Created by Mark Horgan on 21/03/2019.
//  Copyright © 2019 Sketch. All rights reserved.
//

#import "MSImmutablePage.h"

@interface MSImmutableDocumentData : MSImmutableModelObject

@property (readonly, nonatomic) NSArray<MSImmutablePage*> *pages;
@property (readonly, nonatomic) MSImmutablePage *currentPage;

@end
