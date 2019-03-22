//
//  MSPage.h
//  print-export
//
//  Created by Mark Horgan on 21/03/2019.
//  Copyright © 2019 Sketch. All rights reserved.
//

#import "MSModelObject.h"
#import "MSArtboardGroup.h"

@interface MSPage : MSModelObject

@property (readonly, nonatomic) NSArray<MSArtboardGroup*> *artboards;

@end
