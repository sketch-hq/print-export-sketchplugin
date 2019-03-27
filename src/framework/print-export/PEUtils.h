//
//  PEUtils.h
//  print-export
//
//  Created by Mark Horgan on 21/03/2019.
//  Copyright © 2019 Sketch. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MSImmutableArtboardGroup.h"
#import "MSImmutableDocumentData.h"
#import "MSColor-Protocol.h"
#import "types.h"
#import "MSDocumentData.h"
#import "MSDocument.h"

extern CGFloat PEMMToUnit(CGFloat millimeter);
extern CGRect PEMMRectToUnitRect(CGFloat x, CGFloat y, CGFloat width, CGFloat height);

@interface PEUtils : NSObject

+ (CGImageRef)imageOfArtboard:(MSImmutableArtboardGroup *)artboard scale:(double)scale targetColorSpace:(NSColorSpace *)targetColorSpace
                    documentData:(MSImmutableDocumentData *)documentData;
+ (CGSize)fitSize:(CGSize)sourceSize inSize:(CGSize)targetSize;
+ (PEConnectingLine)connectingLineWithRect:(CGRect)rect1 withRect:(CGRect)rect2;
+ (CGRect)makeRectWithMidpoint:(CGPoint)midpoint size:(CGFloat)size;
+ (CGRect)centerSize:(CGSize)size inRect:(CGRect)rect2;
+ (CGFloat)distanceBetweenPoint:(CGPoint)point1 andPoint:(CGPoint)point2;
+ (CGPoint)PDFPointWithAbsPoint:(CGPoint)absPoint absBoundsRect:(CGRect)absBoundsRect scale:(CGFloat)scale;
+ (PEConnectedPoint)PDFConnectedPointWithAbsConnectedPoint:(PEConnectedPoint)absConnectedPoint absBoundsRect:(CGRect)absBoundsRect scale:(CGFloat)scale;
+ (CGRect)PDFRectWithAbsRect:(CGRect)absRect absBoundsRect:(CGRect)absBoundsRect scale:(CGFloat)scale;
+ (CGPoint)offsetPDFPoint:(CGPoint)point side:(PESide)side offset:(CGFloat)offset;

@end
