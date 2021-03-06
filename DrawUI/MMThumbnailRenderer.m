//
//  MMThumbnailRenderer.m
//  DrawUI
//
//  Created by Adam Wulf on 12/17/19.
//  Copyright © 2019 Milestone Made. All rights reserved.
//

#import "MMThumbnailRenderer.h"
#import "CGContextRenderer.h"


@interface MMThumbnailRenderer ()

@property(nonatomic, strong) CGContextRenderer *ctxRenderer;
@property(nonatomic, assign) CGContextRef imageContext;
@property(nonatomic, assign) CGColorSpaceRef colorSpace;
@property(nonatomic, assign) CGRect frame;
@end


@implementation MMThumbnailRenderer

@synthesize dynamicWidth = _dynamicWidth;

- (instancetype)initWithFrame:(CGRect)frame
{
    if (self = [super init]) {
        _ctxRenderer = [[CGContextRenderer alloc] init];
        [_ctxRenderer setDrawByDiff:YES];
        _frame = frame;

        // gradient is always black-white and the mask must be in the gray colorspace
        _colorSpace = CGColorSpaceCreateDeviceRGB();

        // create the bitmap context

        _imageContext = CGBitmapContextCreate(NULL, CGRectGetWidth(_frame), CGRectGetHeight(_frame), 8, 0, _colorSpace, kCGBitmapByteOrderDefault | kCGImageAlphaPremultipliedLast);

        CGAffineTransform flipTransform = CGAffineTransformMake(1, 0, 0, -1, 0, CGRectGetHeight(_frame));
        CGContextConcatCTM(_imageContext, flipTransform);
        CGContextTranslateCTM(_imageContext, -_frame.origin.x, -_frame.origin.y);
    }
    return self;
}

- (void)setDynamicWidth:(BOOL)dynamicWidth
{
    _dynamicWidth = dynamicWidth;

    [_ctxRenderer setDynamicWidth:dynamicWidth];
}

- (void)setDrawModel:(MMDrawModel *)drawModel
{
    _drawModel = drawModel;

    [_ctxRenderer setModel:drawModel];
}

#pragma mark - MMDrawViewRenderer

- (void)invalidate
{
    CGContextRelease(_imageContext);
    CGColorSpaceRelease(_colorSpace);
    _imageContext = nil;
    _drawModel = nil;
}

- (void)drawModelDidUpdate:(MMDrawModel *)drawModel withBounds:(CGRect)bounds
{
    @autoreleasepool {
        if ([[drawModel strokes] count] && ![drawModel activeStroke]) {
            CGRect bounds = CGRectMake(0, 0, _frame.size.width, _frame.size.height);
            [_ctxRenderer drawRect:bounds inContext:_imageContext];

            CGImageRef theCGImage = CGBitmapContextCreateImage(_imageContext);

            UIImage *img = [[UIImage alloc] initWithCGImage:theCGImage];

            [UIImagePNGRepresentation(img) writeToFile:[NSString stringWithFormat:@"/Users/adamwulf/Downloads/%@.png", @(random())] atomically:YES];

            CGImageRelease(theCGImage);
        }
    }
}

@end
