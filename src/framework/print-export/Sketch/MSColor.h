//
//  MSColor.h
//  print-export
//
//  Created by Mark Horgan on 21/03/2019.
//  Copyright © 2019 Sketch. All rights reserved.
//

#import "MSModelObject.h"
#import "MSColor-Protocol.h"

@interface MSColor : MSModelObject <MSColor>

@property (readonly, nonatomic) double red;
@property (readonly, nonatomic) double green;
@property (readonly, nonatomic) double blue;
@property (readonly, nonatomic) double alpha;

@end

