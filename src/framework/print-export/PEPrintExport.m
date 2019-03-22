//
//  PEPrintExport.m
//  print-export
//
//  Created by Mark Horgan on 19/03/2019.
//  Copyright © 2019 Sketch. All rights reserved.
//

#import "PEPrintExport.h"
#import <dlfcn.h>
#import <Foundation/Foundation.h>
#import "PEOptions.h"
#import "PEUtils.h"
#import "MSDocument.h"
#import "MSImmutableDocumentData.h"

// millimeters
static const CGFloat kCropMarkLength = 5;
static const CGFloat kPageMargin = 20;
static NSString *const kFontName = @"Helvetica Neue";

@interface PEPrintExport()

@property (readonly, nonatomic) NSString *symbolsPageID;
@property (readonly, nonatomic) NSURL *fileURL;
@property (readonly, nonatomic) PEOptions *options;
@property (readonly, nonatomic) MSImmutableDocumentData *documentData;
@property (readonly, nonatomic) CFDictionaryRef auxiliaryInfo;
@property (readonly, nonatomic) CGRect mediaBox;
@property (readonly, nonatomic) CGRect bleedBox;
@property (readonly, nonatomic) CGRect trimBox;
@property (readonly, nonatomic) CGFloat slugBleed;
@property (readonly, nonatomic) CGFloat cropMarkLength;
@property (readonly, nonatomic) CGFloat pageMargin;
@property (readonly, nonatomic) CGSize maxPageSize;

@end

@implementation PEPrintExport

+ (void)onShutdown:(NSDictionary *)context {
    NSString *scriptPath = context[@"scriptPath"];
    NSString *frameworkBasePath = [scriptPath.stringByDeletingLastPathComponent.stringByDeletingLastPathComponent stringByAppendingPathComponent:@"Resources"];
    NSString *frameworkPath = [[frameworkBasePath stringByAppendingPathComponent:@"print_export.framework"] stringByAppendingPathComponent:@"print_export"];
    void *frameworkHandle = dlopen([frameworkPath UTF8String], RTLD_LAZY);
    if (frameworkHandle != nil) {
        int result;
        do {
            result = dlclose(frameworkHandle);
        } while (result != -1);
    } else {
        NSLog(@"Couldn't load framework: %@", frameworkPath);
    }
}

+ (void)generatePDFWithDocument:(MSDocument *)document filePath:(NSString *)filePath options:(NSDictionary*)options {
    PEOptions *typedOptions = [[PEOptions alloc] initWithOptions:options];
    NSURL *fileURL = [NSURL fileURLWithPath:filePath];
    PEPrintExport *printExport = [[PEPrintExport alloc] initWithDocument:document fileURL:fileURL options:typedOptions];
    switch (typedOptions.exportType) {
        case PEExportTypeArtboardPerPage:
            [printExport generateArtboardPerPage];
            break;
            
        case PEExportTypeSketchPagePerPage:
            [printExport generateSketchPagePerPage];
            break;
    }
}

- (instancetype)initWithDocument:(MSDocument*)document fileURL:(NSURL *)fileURL options:(PEOptions*)options {
    if (self = [super init]) {
        _documentData = document.documentData.immutableModelObject;
        _fileURL = fileURL;
        _options = options;
        _symbolsPageID = [document.documentData symbolsPage].objectID;
        _auxiliaryInfo = [self createAuxiliaryInfoWithOptions:self.options];
        _pageMargin = PEMMToUnit(kPageMargin);
        _slugBleed = self.options.slug + self.options.bleed;
        _maxPageSize = CGSizeMake(self.options.pageSize.width - (self.pageMargin * 2), self.options.pageSize.height - (self.pageMargin * 2));
    }
    return self;
}

- (void)dealloc {
    CFRelease(self.auxiliaryInfo);
}

- (void)generateArtboardPerPage {
    CGRect mediaBox = self.mediaBox;
    CGContextRef ctx = CGPDFContextCreateWithURL((__bridge CFURLRef)self.fileURL, &mediaBox, self.auxiliaryInfo);
    if (!ctx) {
        NSLog(@"Couldn't create PDF context");
        return;
    }
    switch (self.options.scope) {
        case PEScopeAllPages:
            for (MSImmutablePage *page in self.documentData.pages) {
                if (![page.objectID isEqualToString:self.symbolsPageID]) {
                    [self generateArtboardsWithPage:page context:ctx];
                }
            }
            break;
            
        case PEScopeCurrentPage:
            [self generateArtboardsWithPage:self.documentData.currentPage context:ctx];
            break;
    }
    CGContextRelease(ctx);
}

- (void)generateSketchPagePerPage {
    CGRect mediaBox = self.mediaBox;
    CGContextRef ctx = CGPDFContextCreateWithURL((__bridge CFURLRef)self.fileURL, &mediaBox, self.auxiliaryInfo);
    if (!ctx) {
        NSLog(@"Couldn't create PDF context");
        return;
    }
    switch (self.options.scope) {
        case PEScopeAllPages:
            for (MSImmutablePage *page in self.documentData.pages) {
                if (![page.objectID isEqualToString:self.symbolsPageID]) {
                    [self generateSketchPageWithPage:page context:ctx];
                }
            }
            break;
            
        case PEScopeCurrentPage:
            [self generateSketchPageWithPage:self.documentData.currentPage context:ctx];
            break;
    }
    CGContextRelease(ctx);
}

# pragma mark - Private

- (CGFloat)cropMarkLength {
    if (kCropMarkLength <= self.options.slug) {
        return PEMMToUnit(kCropMarkLength);
    } else {
        return self.options.slug;
    }
}

- (void)generateArtboardsWithPage:(MSImmutablePage*)page context:(CGContextRef)ctx {
    NSArray<MSImmutableArtboardGroup*> *sortedArtboards = [page.artboards sortedArrayUsingComparator:^(MSImmutableArtboardGroup *artboard1, MSImmutableArtboardGroup *artboard2) {
        if (artboard1.rect.origin.y < artboard2.rect.origin.y) {
            return NSOrderedAscending;
        } else if (artboard1.rect.origin.y > artboard2.rect.origin.y) {
            return NSOrderedDescending;
        } else {
            if (artboard1.rect.origin.x < artboard2.rect.origin.x) {
                return NSOrderedAscending;
            } else if (artboard1.rect.origin.x > artboard2.rect.origin.x) {
                return NSOrderedDescending;
            }
        }
        return NSOrderedSame;
    }];
    for (MSImmutableArtboardGroup *artboard in sortedArtboards) {
        CGContextBeginPage(ctx, NULL);
        CGContextSaveGState(ctx);
        if (self.options.hasCropMarks) {
            [self drawCropMarksWithContext:ctx];
        }
        CGPDFDocumentRef artboardPDF = [PEUtils createPDFPageOfArtboard:artboard documentData:self.documentData];
        CGPDFPageRef artboardPDFPage = CGPDFDocumentGetPage(artboardPDF, 1);
        CGSize targetSize = [PEUtils fitSize:artboard.rect.size inSize:self.maxPageSize];
        CGRect artboardPDFRect = CGPDFPageGetBoxRect(artboardPDFPage, kCGPDFCropBox);
        CGContextSaveGState(ctx);
        CGRect targetRect = CGRectMake((self.mediaBox.size.width - targetSize.width) / 2.0, (self.mediaBox.size.height - targetSize.height) / 2.0, targetSize.width, targetSize.height);
        CGContextTranslateCTM(ctx, targetRect.origin.x, targetRect.origin.y);
        CGContextScaleCTM(ctx, targetSize.width / artboardPDFRect.size.width, targetSize.height / artboardPDFRect.size.height);
        CGContextDrawPDFPage(ctx, artboardPDFPage);
        CFRelease(artboardPDF);
        CGContextRestoreGState(ctx);
        if (self.options.showArboardBorder) {
            [self drawArtboardBorderWithArtboard:artboard rect:targetRect context:ctx];
        }
        if (self.options.showArboardName) {
            [self drawLabel:artboard.name position:CGPointMake(targetRect.origin.x + targetRect.size.width / 2.0, targetRect.origin.y - 30) size:12 context:ctx];
        }
        CGContextRestoreGState(ctx);
        CGContextEndPage(ctx);
    }
}

- (void)generateSketchPageWithPage:(MSImmutablePage*)page context:(CGContextRef)ctx {
    CGContextBeginPage(ctx, NULL);
    CGContextSaveGState(ctx);
    if (self.options.hasCropMarks) {
        [self drawCropMarksWithContext:ctx];
    }
    CGRect artboardsRect = [self boundsOfArtboardsInPage:page];
    CGSize targetSize = [PEUtils fitSize:artboardsRect.size inSize:self.maxPageSize];
    CGFloat scale = targetSize.width / artboardsRect.size.width;
    CGPoint origin = CGPointMake((self.mediaBox.size.width - targetSize.width) / 2.0, (self.mediaBox.size.height - targetSize.height) / 2.0);
    CGContextTranslateCTM(ctx, origin.x, origin.y);
    for (MSImmutableArtboardGroup *artboard in page.artboards) {
        CGPDFDocumentRef artboardPDF = [PEUtils createPDFPageOfArtboard:artboard documentData:self.documentData];
        CGPDFPageRef artboardPDFPage = CGPDFDocumentGetPage(artboardPDF, 1);
        CGRect artboardPDFRect = CGPDFPageGetBoxRect(artboardPDFPage, kCGPDFCropBox);
        CGContextSaveGState(ctx);
        CGContextScaleCTM(ctx, (artboard.rect.size.width * scale) / artboardPDFRect.size.width, (artboard.rect.size.height * scale) / artboardPDFRect.size.height);
        CGContextTranslateCTM(ctx, artboard.rect.origin.x - artboardsRect.origin.x, artboardsRect.size.height - (artboard.rect.origin.y - artboardsRect.origin.y + artboard.rect.size.height));
        CGContextDrawPDFPage(ctx, artboardPDFPage);
        CFRelease(artboardPDF);
        if (self.options.showArboardBorder) {
            [self drawArtboardBorderWithArtboard:artboard rect:CGRectMake(0, 0, artboard.rect.size.width, artboard.rect.size.height) context:ctx];
        }
        if (self.options.showArboardName) {
            [self drawLabel:artboard.name position:CGPointMake(artboard.rect.size.width / 2.0, -40) size:18 context:ctx];
        }
        CGContextRestoreGState(ctx);
    }
    CGContextRestoreGState(ctx);
    CGContextEndPage(ctx);
}

- (void)drawCropMarksWithContext:(CGContextRef)ctx {
    CGContextSaveGState(ctx);
    CGFloat x0 = self.options.slug;
    CGFloat x1 = self.options.slug + self.options.bleed;
    CGFloat x2 = x1 + self.options.pageSize.width;
    CGFloat x3 = x2 + self.options.bleed;
    CGFloat y0 = x0;
    CGFloat y1 = x1;
    CGFloat y2 = y1 + self.options.pageSize.height;
    CGFloat y3 = y2 + self.options.bleed;
    CGPoint points[] = {
        x1, y0,
        x1, y0 - self.cropMarkLength,
        
        x2, y0,
        x2, y0 - self.cropMarkLength,
        
        x0, y1,
        x0 - self.cropMarkLength, y1,
        
        x3, y1,
        x3 + self.cropMarkLength, y1,
        
        x0, y2,
        x0 - self.cropMarkLength, y2,
        
        x3, y2,
        x3 + self.cropMarkLength, y2,
        
        x1, y3,
        x1, y3 + self.cropMarkLength,
        
        x2, y3,
        x2, y3 + self.cropMarkLength
    };
    CGContextSetLineWidth(ctx, 0.5);
    CGContextSetCMYKStrokeColor(ctx, 0, 0, 0, 1, 1);
    CGContextStrokeLineSegments(ctx, points, 16);
}

- (void)drawArtboardBorderWithArtboard:(MSImmutableArtboardGroup*)artboard rect:(CGRect)artboardRect context:(CGContextRef)ctx {
    CGContextSetLineWidth(ctx, 0.5);
    CGContextSetCMYKStrokeColor(ctx, 0, 0, 0, 0.5, 1);
    CGContextStrokeRect(ctx, artboardRect);
}

- (void)drawLabel:(NSString*)label position:(CGPoint)position size:(CGFloat)size context:(CGContextRef)ctx {
    CTFontRef font = CTFontCreateWithName((__bridge CFStringRef)kFontName, size, NULL);
    CFStringRef keys[] = {kCTFontAttributeName};
    CFTypeRef values[] = {font};
    CFDictionaryRef attributes = CFDictionaryCreate(kCFAllocatorDefault, (const void**)&keys, (const void**)&values, sizeof(keys) / sizeof(keys[0]),
                                                    &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    CFAttributedStringRef attrString = CFAttributedStringCreate(kCFAllocatorDefault, (__bridge CFStringRef)label, attributes);
    CFRelease(attributes);
    CTLineRef line = CTLineCreateWithAttributedString(attrString);
    CFRelease(attrString);
    CGRect lineBounds = CTLineGetImageBounds(line, ctx);
    CGContextSetTextPosition(ctx, position.x - lineBounds.size.width / 2.0, position.y);
    CTLineDraw(line, ctx);
    CFRelease(line);
    CFRelease(font);
}

- (void)flipContextVertically:(CGContextRef)ctx {
    CGContextConcatCTM(ctx, CGAffineTransformMake(1, 0, 0, -1, 0, self.mediaBox.size.height));
}

- (CFDictionaryRef)createAuxiliaryInfoWithOptions:(PEOptions *)options {
    _mediaBox = CGRectMake(0, 0, self.options.pageSize.width + ((self.options.slug + self.options.bleed) * 2), self.options.pageSize.height + ((self.options.slug + self.options.bleed) * 2));
    _bleedBox = CGRectMake(self.options.slug, self.options.slug, self.options.pageSize.width + (self.options.bleed * 2), self.options.pageSize.height + (self.options.bleed * 2));
    _trimBox = CGRectMake(self.options.slug + self.options.bleed, self.options.slug + self.options.bleed, self.options.pageSize.width, self.options.pageSize.height);
    
    CFMutableDictionaryRef info = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    
    CGRect mediaBox = self.mediaBox;
    CFDataRef mediaBoxData = CFDataCreate(kCFAllocatorDefault, (UInt8 *)&mediaBox, sizeof(mediaBox));
    CFDictionarySetValue(info, kCGPDFContextMediaBox, mediaBoxData);
    CFRelease(mediaBoxData);
    
    CGRect bleedBox = self.bleedBox;
    CFDataRef bleedBoxData = CFDataCreate(kCFAllocatorDefault, (UInt8 *)&bleedBox, sizeof(bleedBox));
    CFDictionarySetValue(info, kCGPDFContextMediaBox, bleedBoxData);
    CFRelease(bleedBoxData);
    
    CGRect trimBox = self.trimBox;
    CFDataRef trimBoxData = CFDataCreate(kCFAllocatorDefault, (UInt8 *)&trimBox, sizeof(trimBox));
    CFDictionarySetValue(info, kCGPDFContextTrimBox, trimBoxData);
    CFRelease(trimBoxData);
    
    return info;
}

- (CGRect)boundsOfArtboardsInPage:(MSImmutablePage *)page {
    NSNumber *minX, *minY, *maxX, *maxY;
    for (MSImmutableArtboardGroup *artboard in page.artboards) {
        if (minX == nil || artboard.rect.origin.x < minX.doubleValue) {
            minX = [NSNumber numberWithDouble:artboard.rect.origin.x];
        }
        if (minY == nil || artboard.rect.origin.y < minY.doubleValue) {
            minY = [NSNumber numberWithDouble:artboard.rect.origin.y];
        }
        if (maxX == nil || artboard.rect.origin.x + artboard.rect.size.width > maxX.doubleValue) {
            maxX = [NSNumber numberWithDouble:artboard.rect.origin.x + artboard.rect.size.width];
        }
        if (maxY == nil || artboard.rect.origin.y + artboard.rect.size.height > maxY.doubleValue) {
            maxY = [NSNumber numberWithDouble:artboard.rect.origin.y + artboard.rect.size.height];
        }
    }
    return CGRectMake(minX.doubleValue, minY.doubleValue, maxX.doubleValue - minX.doubleValue, maxY.doubleValue - minY.doubleValue);
}

@end
