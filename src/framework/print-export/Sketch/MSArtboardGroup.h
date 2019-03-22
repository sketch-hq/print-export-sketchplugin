//
//  MSArtboardGroup.h
//  print-export
//
//  Created by Mark Horgan on 21/03/2019.
//  Copyright © 2019 Sketch. All rights reserved.
//

#import "MSLayerGroup.h"
#import "MSColor.h"

@interface MSArtboardGroup: MSLayerGroup

@property (readonly, nonatomic) BOOL hasBackgroundColor;
@property (readonly, nonatomic) MSColor *backgroundColor;
@property (readonly, nonatomic) BOOL includeBackgroundColorInExport;

@end

