//
//  PESketchMethods.h
//  print-export
//
//  Created by Mark Horgan on 27/03/2019.
//  Copyright © 2019 Sketch. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MSImmutableLayer.h"
#import "MSDocument.h"
#import "MSImmutableDocumentData.h"
#import "MSImmutableSymbolInstance.h"

@interface PESketchMethods : NSObject

+ (NSData *)imageDataOfLayer:(MSImmutableLayer *)layer scale:(double)scale documentData:(MSImmutableDocumentData *)documentData;
+ (MSImmutableLayer *)immutableLayerWithID:(NSString *)layerID documentData:(MSDocumentData *)documentData;
+ (void)displayFlashMessage:(NSString *)message document:(MSDocument *)document;
+ (MSImmutableLayerGroup *)detachedLayerGroupRecursively:(BOOL)recursively withDocument:(MSImmutableDocumentData *)documentData symbolInstance:(MSImmutableSymbolInstance *)symbolInstance;

@end
