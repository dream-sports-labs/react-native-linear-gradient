#import "RNLinearGradientLayer.h"

#include <math.h>
#import <UIKit/UIKit.h>

@implementation RNLinearGradientLayer

- (instancetype)init
{
    self = [super init];

    if (self)
    {
        self.needsDisplayOnBoundsChange = YES;
        self.masksToBounds = YES;
        _startPoint = CGPointMake(0.5, 0.0);
        _endPoint = CGPointMake(0.5, 1.0);
        _angleCenter = CGPointMake(0.5, 0.5);
        _angle = 45.0;
    }

    return self;
}

- (void)setColors:(NSArray<id> *)colors
{
    _colors = colors;
    [self setNeedsDisplay];
}

- (void)setLocations:(NSArray<NSNumber *> *)locations
{
    _locations = locations;
    [self setNeedsDisplay];
}

- (void)setStartPoint:(CGPoint)startPoint
{
    _startPoint = startPoint;
    [self setNeedsDisplay];
}

- (void)setEndPoint:(CGPoint)endPoint
{
    _endPoint = endPoint;
    [self setNeedsDisplay];
}

- (void)display {
    [super display];

    if (self.bounds.size.height == 0 || self.bounds.size.width == 0) {
      return;
    }

    BOOL hasAlpha = NO;

    for (NSInteger i = 0; i < self.colors.count; i++) {
        hasAlpha = hasAlpha || CGColorGetAlpha(self.colors[i].CGColor) < 1.0;
    }

    if (@available(iOS 10.0, *)) {
        UIGraphicsImageRendererFormat *format;
        if (@available(iOS 11.0, *)) {
            format = [UIGraphicsImageRendererFormat preferredFormat];
        } else {
            format = [UIGraphicsImageRendererFormat defaultFormat];
        }
        format.opaque = !hasAlpha;
        UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:self.bounds.size format:format];
        UIImage *image = [renderer imageWithActions:^(UIGraphicsImageRendererContext * _Nonnull ref) {
            [self drawInContext:ref.CGContext];
        }];

        self.contents = (__bridge id _Nullable)(image.CGImage);
        self.contentsScale = image.scale;
    } else {
        UIGraphicsBeginImageContextWithOptions(self.bounds.size, !hasAlpha, 0.0);
        CGContextRef ref = UIGraphicsGetCurrentContext();
        [self drawInContext:ref];

        UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
        self.contents = (__bridge id _Nullable)(image.CGImage);
        self.contentsScale = image.scale;

        UIGraphicsEndImageContext();
    }
}

- (void)setUseAngle:(BOOL)useAngle
{
    _useAngle = useAngle;
    [self setNeedsDisplay];
}

- (void)setAngleCenter:(CGPoint)angleCenter
{
    _angleCenter = angleCenter;
    [self setNeedsDisplay];
}

- (void)setAngle:(CGFloat)angle
{
    _angle = angle;
    [self setNeedsDisplay];
}

+ (CGPoint) getStartCornerToIntersectFromAngle:(CGFloat)angle AndSize:(CGSize)size
{
    float halfHeight = size.height / 2.0;
    float halfWidth = size.width / 2.0;
    if (angle < 90)
        return CGPointMake(-halfWidth, -halfHeight);
    else if (angle < 180)
        return CGPointMake(halfWidth, -halfHeight);
    else if (angle < 270)
        return CGPointMake(halfWidth, halfHeight);
    else
        return CGPointMake(-halfWidth, halfHeight);
}

+ (CGPoint) getHorizontalOrVerticalStartPointFromAngle:(CGFloat)angle AndSize:(CGSize)size
{
    float halfWidth = size.width / 2;
    float halfHeight = size.height / 2;
    if (angle == 0) {
        return CGPointMake(-halfWidth, 0);
    } else if (angle == 90) {
        return CGPointMake(0, -halfHeight);
    } else if (angle == 180) {
        return CGPointMake(halfWidth, 0);
    } else {
        return CGPointMake(0, halfHeight);
    }
}

+ (CGPoint) getGradientStartPointFromAngle:(CGFloat)angle AndSize:(CGSize)size
{
    angle = fmodf(angle, 360);
    if (angle < 0)
        angle += 360;

    if (fmodf(angle, 90) == 0)
        return [RNLinearGradientLayer getHorizontalOrVerticalStartPointFromAngle:angle AndSize:size];

    float slope = tan(angle * M_PI / 180.0);
    float perpendicularSlope = -1 / slope;
    CGPoint startCorner = [RNLinearGradientLayer getStartCornerToIntersectFromAngle:angle AndSize:size];
    float b = startCorner.y - perpendicularSlope * startCorner.x;
    float startX = b / (slope - perpendicularSlope);
    float startY = slope * startX;
    return CGPointMake(startX, startY);
}

- (void)drawInContext:(CGContextRef)ctx
{
    [super drawInContext:ctx];
    CGContextSaveGState(ctx);

    CGSize size = self.bounds.size;
    if (!self.colors || self.colors.count == 0 || size.width == 0.0 || size.height == 0.0)
        return;

    // FIX: small padding inset to prevent cropping
    CGFloat scale = [UIScreen mainScreen].scale;
    CGFloat inset = 1.0 / scale; 
    CGRect drawingRect = CGRectInset(self.bounds, inset, inset);

    CGFloat *locations = malloc(sizeof(CGFloat) * self.colors.count);

    for (NSInteger i = 0; i < self.colors.count; i++)
    {
        if (self.locations.count > i)
            locations[i] = self.locations[i].floatValue;
        else
            locations[i] = (1.0 / (self.colors.count - 1)) * i;
    }
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    NSMutableArray *colors = [[NSMutableArray alloc] initWithCapacity:self.colors.count];
    for (UIColor *color in self.colors) {
        [colors addObject:(id)color.CGColor];
    }

    CGGradientRef gradient = CGGradientCreateWithColors(colorSpace, (CFArrayRef)colors, locations);
    free(locations);

    CGPoint start, end;
    CGSize adjustedSize = drawingRect.size;

    if (_useAngle)
    {
        float angle = (90 - _angle);
        CGPoint relativeStartPoint = [RNLinearGradientLayer getGradientStartPointFromAngle:angle AndSize:adjustedSize];
        CGPoint angleCenter = CGPointMake(
           _angleCenter.x * adjustedSize.width + drawingRect.origin.x,
           _angleCenter.y * adjustedSize.height + drawingRect.origin.y
        );
        start = CGPointMake(
            angleCenter.x + relativeStartPoint.x,
            angleCenter.y - relativeStartPoint.y
        );
        end = CGPointMake(
            angleCenter.x - relativeStartPoint.x,
            angleCenter.y + relativeStartPoint.y
        );
    }
    else
    {
        start = CGPointMake(self.startPoint.x * adjustedSize.width + drawingRect.origin.x,
                            self.startPoint.y * adjustedSize.height + drawingRect.origin.y);
        end = CGPointMake(self.endPoint.x * adjustedSize.width + drawingRect.origin.x,
                          self.endPoint.y * adjustedSize.height + drawingRect.origin.y);
    }

    CGContextClipToRect(ctx, drawingRect);
    CGContextDrawLinearGradient(ctx, gradient, start, end,
                                kCGGradientDrawsBeforeStartLocation | kCGGradientDrawsAfterEndLocation);
    CGGradientRelease(gradient);
    CGColorSpaceRelease(colorSpace);
    CGContextRestoreGState(ctx);
}

@end
