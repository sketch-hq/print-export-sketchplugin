//
//  PEUtils.h
//  print-export
//
//  Created by Mark Horgan on 21/03/2019.
//  Copyright © 2019 Sketch. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MSArtboardGroup.h"

extern CGFloat PEMMToUnit(CGFloat millimeter);
extern CGRect PEMMRectToUnitRect(CGFloat x, CGFloat y, CGFloat width, CGFloat height);

@interface PEUtils : NSObject

+ (CGPDFDocumentRef)PDFOfArtboard:(MSArtboardGroup*)artboard;
+ (CGSize)fitSize:(CGSize)sourceSize inSize:(CGSize)targetSize;
+ (BOOL)colorIsWhite:(id<MSColor>)color;

@end
