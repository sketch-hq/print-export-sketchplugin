//
//  PEUtils.h
//  print-export
//
//  Created by Mark Horgan on 21/03/2019.
//  Copyright © 2019 Sketch. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MSImmutableArtboardGroup.h"
#import "MSImmutableDocumentData.h"
#import "MSColor-Protocol.h"
#import "types.h"
#import "MSDocumentData.h"

extern CGFloat PEMMToUnit(CGFloat millimeter);
extern CGRect PEMMRectToUnitRect(CGFloat x, CGFloat y, CGFloat width, CGFloat height);

@interface PEUtils : NSObject

+ (CGPDFDocumentRef)createPDFPageOfArtboard:(MSImmutableArtboardGroup *)artboard documentData:(MSImmutableDocumentData *)documentData;
+ (MSImmutableLayer*)immutableLayerWithID:(NSString *)layerID documentData:(MSDocumentData *)documentData;
+ (CGSize)fitSize:(CGSize)sourceSize inSize:(CGSize)targetSize;
+ (PEConnectingLine)connectingLineWithRect:(CGRect)rect1 withRect:(CGRect)rect2;
+ (CGRect)makeRectWithMidpoint:(CGPoint)midpoint size:(CGFloat)size;
+ (CGRect)centerSize:(CGSize)size inRect:(CGRect)rect2;
+ (CGFloat)distanceBetweenPoint:(CGPoint)point1 andPoint:(CGPoint)point2;
+ (CGPoint)PDFPointWithAbsPoint:(CGPoint)absPoint artboardsRect:(CGRect)artboardsRect scale:(CGFloat)scale;
+ (PEConnectedPoint)PDFConnectedPointWithAbsConnectedPoint:(PEConnectedPoint)absConnectedPoint artboardsRect:(CGRect)artboardsRect scale:(CGFloat)scale;
+ (CGRect)PDFRectWithAbsRect:(CGRect)absRect artboardsRect:(CGRect)artboardsRect scale:(CGFloat)scale;
+ (CGPoint)offsetPDFPoint:(CGPoint)point side:(PESide)side offset:(CGFloat)offset;

@end
