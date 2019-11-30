//
//  CALayerRenderer.m
//  DrawUI
//
//  Created by Adam Wulf on 11/12/19.
//  Copyright © 2019 Milestone Made. All rights reserved.
//

#import "CALayerRenderer.h"
#import "MMAbstractBezierPathElement.h"

@interface CAEraserLayer : CALayer

@end

@implementation CAEraserLayer

@end

@interface CAEraserShapeLayer : CAShapeLayer

@end

@implementation CAEraserShapeLayer

@end

@interface CALayerRenderer () <CALayerDelegate>

@end

@implementation CALayerRenderer {
    NSMutableDictionary<NSString *, CALayer *> *_strokeLayers;
    NSUInteger _lastRenderedVersion;
    CALayer *_canvasLayer;
}

@synthesize dynamicWidth;

- (instancetype)init
{
    if (self = [super init]) {
        _strokeLayers = [NSMutableDictionary dictionary];
        _lastRenderedVersion = 0;
        _canvasLayer = [CALayer layer];
        [_canvasLayer setDelegate:self];
    }
    return self;
}

#pragma mark - Render

- (__kindof CALayer *)layerForStroke:(NSString *)strokeId isEraser:(BOOL)eraser
{
    CALayer *layer = [_strokeLayers objectForKey:strokeId];

    if (!layer) {
        if ([self dynamicWidth]) {
            if (eraser) {
                layer = [CAEraserLayer layer];
            } else {
                layer = [CALayer layer];
            }
        } else {
            if (eraser) {
                layer = [CAEraserShapeLayer layer];
            } else {
                layer = [CAShapeLayer layer];
            }
        }

        layer.delegate = self;

        [_strokeLayers setObject:layer forKey:strokeId];
    }

    return layer;
}

- (void)renderStroke:(MMDrawnStroke *)stroke inView:(MMDrawView *)drawView
{
    if ([self dynamicWidth]) {
        CALayer *layer = [self layerForStroke:[stroke identifier] isEraser:[[stroke tool] color] == nil];

        for (NSInteger i = 0; i < [[stroke segments] count]; i++) {
            MMAbstractBezierPathElement *element = [[stroke segments] objectAtIndex:i];
            CAShapeLayer *segmentLayer = i < [[layer sublayers] count] ? [[layer sublayers] objectAtIndex:i] : [CAShapeLayer layer];

            segmentLayer.delegate = self;
            segmentLayer.path = [[element borderPath] CGPath];
            segmentLayer.fillColor = [[[stroke tool] color] CGColor] ?: [[UIColor whiteColor] CGColor];
            segmentLayer.lineWidth = 0;

            if (![segmentLayer superlayer]) {
                [layer addSublayer:segmentLayer];
            }
        }

        if (!layer.superlayer) {
            [_canvasLayer addSublayer:layer];
        }
    } else if ([stroke path]) {
        CAShapeLayer *layer = [self layerForStroke:[stroke identifier] isEraser:[[stroke tool] color] == nil];

        layer.path = [[stroke path] CGPath];
        layer.strokeColor = [[[stroke tool] color] CGColor] ?: [[UIColor whiteColor] CGColor];
        layer.fillColor = [[UIColor clearColor] CGColor];
        layer.lineWidth = 10;

        if (!layer.superlayer) {
            [_canvasLayer addSublayer:layer];
        }
    }
}

- (void)renderModel:(MMDrawModel *)drawModel inView:(MMDrawView *)drawView
{
    NSUInteger maxSoFar = _lastRenderedVersion;

    for (MMDrawnStroke *stroke in [drawModel strokes]) {
        if ([stroke version] > _lastRenderedVersion) {
            [self renderStroke:stroke inView:drawView];

            maxSoFar = MAX([stroke version], maxSoFar);
        }
    }

    if ([drawModel stroke]) {
        if ([[drawModel stroke] version] > _lastRenderedVersion) {
            [self renderStroke:[drawModel stroke] inView:drawView];

            maxSoFar = MAX([[drawModel stroke] version], maxSoFar);
        }
    }

    _lastRenderedVersion = maxSoFar;
}

#pragma mark - CAShapeLayerDelegate

- (void)drawLayer:(CALayer *)layer inContext:(CGContextRef)context
{
    if ([layer isKindOfClass:[CAEraserLayer class]] ||
        [layer isKindOfClass:[CAEraserShapeLayer class]]) {
        CGContextSetBlendMode(context, kCGBlendModeClear);
    }

    [layer renderInContext:context];

    CGContextSetBlendMode(context, kCGBlendModeNormal);
}

#pragma mark - MMDrawViewRenderer

- (void)drawView:(MMDrawView *)drawView willUpdateModel:(MMDrawModel *)oldModel to:(MMDrawModel *)newModel
{
    if (![_canvasLayer superlayer]) {
        [[drawView layer] addSublayer:_canvasLayer];
        [[drawView layer] setActions:@{ @"sublayers": [NSNull null] }];
    }

    if (CGRectEqualToRect([_canvasLayer frame], [[drawView layer] bounds])) {
        [_canvasLayer setFrame:[[drawView layer] bounds]];
    }
}

- (void)drawView:(MMDrawView *)drawView didUpdateModel:(MMDrawModel *)drawModel
{
    [self renderModel:drawModel inView:drawView];
}

#pragma mark - CALayerDelegate

- (nullable id<CAAction>)actionForLayer:(CALayer *)layer forKey:(NSString *)event
{
    return [NSNull null];
}


@end
