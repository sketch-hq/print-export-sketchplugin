//
//  MSImmutableColor.h
//  print-export
//
//  Created by Mark Horgan on 22/03/2019.
//  Copyright © 2019 Sketch. All rights reserved.
//

#import "MSImmutableModelObject.h"
#import "MSColor-Protocol.h"

@interface MSImmutableColor: MSImmutableModelObject <MSColor>

@property (readonly, nonatomic) double red;
@property (readonly, nonatomic) double green;
@property (readonly, nonatomic) double blue;
@property (readonly, nonatomic) double alpha;

@end
