//
//  MSLayerGroup.h
//  ProtoWire
//
//  Created by Mark Horgan on 28/05/2017.
//  Copyright © 2017 Mark Horgan. All rights reserved.
//

#import "MSImmutableStyledLayer.h"
#import "MSImmutableLayer.h"

@interface MSImmutableLayerGroup: MSImmutableStyledLayer

@property (readonly, nonatomic) NSArray<MSImmutableLayer*> *layers;

@end
