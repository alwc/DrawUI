//
//  SmartDrawRectRenderer.m
//  DrawUI
//
//  Created by Adam Wulf on 11/13/19.
//  Copyright © 2019 Milestone Made. All rights reserved.
//

#import "SmartDrawRectRenderer.h"
#import "MMAbstractBezierPathElement.h"
#import "CGContextRenderer.h"
#import "Constants.h"


@interface SmartDrawRectRenderer ()

@property(nonatomic, strong) CGContextRenderer *ctxRenderer;
@property(nonatomic, assign) CGRect lastBounds;

@end


@implementation SmartDrawRectRenderer

@synthesize dynamicWidth = _dynamicWidth;
@synthesize drawModel = _drawModel;

- (instancetype)initWithView:(UIView *)canvasView
{
    if (self = [super init]) {
        [self setOpaque:NO];

        _ctxRenderer = [[CGContextRenderer alloc] init];
        _lastBounds = [canvasView bounds];

        [canvasView addSubview:self];
        [[[self leadingAnchor] constraintEqualToAnchor:[canvasView leadingAnchor]] setActive:YES];
        [[[self trailingAnchor] constraintEqualToAnchor:[canvasView trailingAnchor]] setActive:YES];
        [[[self topAnchor] constraintEqualToAnchor:[canvasView topAnchor]] setActive:YES];
        [[[self bottomAnchor] constraintEqualToAnchor:[canvasView bottomAnchor]] setActive:YES];

        [self setTranslatesAutoresizingMaskIntoConstraints:NO];
    }
    return self;
}

- (void)setDrawModel:(MMDrawModel *)drawModel
{
    _drawModel = drawModel;

    [[self ctxRenderer] setModel:[self drawModel]];
    [self setNeedsDisplay];
}

- (BOOL)dynamicWidth
{
    return [[self ctxRenderer] dynamicWidth];
}

- (void)setDynamicWidth:(BOOL)dynamicWidth
{
    [[self ctxRenderer] setDynamicWidth:dynamicWidth];
}

#pragma mark - MMDrawViewRenderer

- (void)invalidate
{
    _drawModel = nil;

    [[self ctxRenderer] setModel:nil];
    [self removeFromSuperview];
}

- (void)drawModelDidUpdateBounds:(CGRect)bounds
{
    [self setNeedsDisplay];
}

- (void)drawModelDidUpdate:(MMDrawModel *)drawModel withBounds:(CGRect)bounds
{
    MMDrawnStroke *stroke = [drawModel activeStroke] ?: [[drawModel strokes] lastObject];

    if (stroke) {
        CGRect pathBounds = [[stroke path] bounds];

        pathBounds = CGRectInset(pathBounds, -[[stroke tool] maxSize], -[[stroke tool] maxSize]);
        pathBounds = CGRectInset(pathBounds, -kStrokeWidth, -kStrokeWidth);

        [self setNeedsDisplayInRect:pathBounds];
    }

    if (!CGRectEqualToRect(_lastBounds, bounds)) {
        _lastBounds = bounds;

        [self setNeedsDisplay];
    }
}

#pragma mark - Rendering

- (void)drawRect:(CGRect)rect
{
    [[self ctxRenderer] drawRect:rect inContext:UIGraphicsGetCurrentContext()];
}

@end
