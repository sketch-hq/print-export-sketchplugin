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

extern CGFloat PEMMToUnit(CGFloat millimeter);
extern CGRect PEMMRectToUnitRect(CGFloat x, CGFloat y, CGFloat width, CGFloat height);

@interface PEUtils : NSObject

+ (CGPDFPageRef)PDFPageOfArtboard:(MSImmutableArtboardGroup *)artboard documentData:(MSImmutableDocumentData *)documentData;
+ (CGSize)fitSize:(CGSize)sourceSize inSize:(CGSize)targetSize;

@end
