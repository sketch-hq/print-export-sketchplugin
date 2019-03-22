//
//  MSLayerGroup.h
//  print-export
//
//  Created by Mark Horgan on 21/03/2019.
//  Copyright © 2019 Sketch. All rights reserved.
//

#import "MSStyledLayer.h"
#import "MSLayer.h"

@interface MSLayerGroup: MSStyledLayer

@property (readonly, nonatomic) NSArray<MSLayer*> *layers;

@end

