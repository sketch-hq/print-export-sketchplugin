//
//  MSPage.h
//  ProtoWire
//
//  Created by Mark Horgan on 28/05/2017.
//  Copyright © 2017 Mark Horgan. All rights reserved.
//

#import "MSImmutableLayerGroup.h"
#import "MSImmutableArtboardGroup.h"

@interface MSImmutablePage: MSImmutableLayerGroup

@property (readonly, nonatomic) NSArray<MSImmutableArtboardGroup*> *artboards;

@end
