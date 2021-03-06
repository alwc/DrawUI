//
//  MMDrawViewRenderer.h
//  DrawUI
//
//  Created by Adam Wulf on 12/17/19.
//  Copyright © 2019 Milestone Made. All rights reserved.
//

#ifndef MMDrawViewRenderer_h
#define MMDrawViewRenderer_h

#import <UIKit/UIKit.h>

@class MMDrawModel, MMPen;

@protocol MMDrawViewRenderer <NSObject>

/// YES if the renderer should adjust the width throughout the stroke
/// NO for strokes to have uniform width
@property(nonatomic, assign) BOOL dynamicWidth;

/// the MMDrawModel to use for rendering
@property(nonatomic, strong) MMDrawModel *drawModel;

- (void)drawModelDidUpdate:(MMDrawModel *)drawModel withBounds:(CGRect)bounds;

@optional

- (void)invalidate;

@end

#endif /* MMDrawViewRenderer_h */
