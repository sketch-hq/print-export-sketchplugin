//
//  MSExportRequest.h
//  print-export
//
//  Created by Mark Horgan on 21/03/2019.
//  Copyright © 2019 Sketch. All rights reserved.
//

@interface MSExportRequest : NSObject

@property(nonatomic) BOOL includeArtboardBackground;
@property(nonatomic) BOOL progressive;
@property(nonatomic) double compression;
@property(nonatomic) BOOL saveForWeb;
@property(copy, nonatomic) NSString *format;
@property(nonatomic) BOOL shouldTrim;
@property(nonatomic) double scale;
@property(copy, nonatomic) NSSet *includedLayerIDs;
@property(nonatomic) unsigned long long options;
@property(copy, nonatomic) NSString *name;
@property(nonatomic) struct CGRect rect;

@end
