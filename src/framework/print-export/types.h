//
//  types.h
//  print-export
//
//  Created by Mark Horgan on 20/03/2019.
//  Copyright © 2019 Sketch. All rights reserved.
//

typedef NS_ENUM(NSUInteger, PEExportType) {
    PEExportTypeArtboardPerPage,
    PEExportTypeSketchPagePerPage
};

typedef NS_ENUM(NSUInteger, PEScope) {
    PEScopeCurrentPage,
    PEScopeAllPages
};

typedef NS_ENUM(NSUInteger, PEOrientation) {
    PEOrientationPortrait,
    PEOrrientationLandscape
};

typedef NS_ENUM(NSUInteger, PEUnitType) {
    PEUnitTypeMM,
    PEUnitTypeInch
};
