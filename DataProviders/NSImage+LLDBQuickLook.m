//
//  NSImage+LLDBQuickLook.m
//
//  Created by Michail Pishchagin on 1/7/14.
//
//  The MIT License (MIT)
//
//  Copyright (c) 2014 Michail Pishchagin
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy of
//  this software and associated documentation files (the "Software"), to deal in
//  the Software without restriction, including without limitation the rights to
//  use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
//  the Software, and to permit persons to whom the Software is furnished to do so,
//  subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
//  FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
//  COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
//  IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
//  CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

#import "NSObject+LLDBQuickLook.h"
#import "NSImage+LLDBQuickLook.h"

static NSBitmapImageRep* CreateBitmapImageRep(NSInteger width,
                                              NSInteger height,
                                              CGFloat scale) {
    return [[NSBitmapImageRep alloc]
        initWithBitmapDataPlanes:NULL
                      pixelsWide:width * scale
                      pixelsHigh:height * scale
                   bitsPerSample:8
                 samplesPerPixel:4
                        hasAlpha:YES
                        isPlanar:NO
                  colorSpaceName:NSDeviceRGBColorSpace
                    bitmapFormat:NSAlphaFirstBitmapFormat
                     bytesPerRow:0
                    bitsPerPixel:0];
}

static NSBitmapImageRep* CreateImageRep(NSInteger width,
                                        NSInteger height,
                                        CGFloat scale,
                                        void (^drawingBlock)(NSRect rect)) {
    // code copied from "Create and Render Bitmaps to Accommodate High Resolution"
    // in "High Resolution Guidelines for OS X"
    NSBitmapImageRep* _rep = CreateBitmapImageRep(width, height, scale);
    // There isn't a colorspace name constant for sRGB so retag
    // using the sRGBColorSpace method
    NSBitmapImageRep* bmpImageRep =
        [_rep bitmapImageRepByRetaggingWithColorSpace:
                  [NSColorSpace deviceRGBColorSpace]];
    [_rep release];

    // Setting the user size communicates the dpi
    [bmpImageRep setSize:NSMakeSize(width, height)];
    {
        [NSGraphicsContext saveGraphicsState];
        [NSGraphicsContext
            setCurrentContext:
                [NSGraphicsContext
                    graphicsContextWithBitmapImageRep:bmpImageRep]];
        drawingBlock(NSMakeRect(0, 0, width, height));
        [NSGraphicsContext restoreGraphicsState];
    }

    return bmpImageRep;
}

static NSImage* CreateImage(NSInteger width,
                            NSInteger height,
                            CGFloat scale,
                            void (^drawingBlock)(NSRect rect)) {
    NSBitmapImageRep* bmpImageRep =
        CreateImageRep(width, height, scale, drawingBlock);

    NSImage* image = [[NSImage alloc] init];
    [image addRepresentation:bmpImageRep];
    return image;
}

NSData* LLDBQuickLookPNGRepresentationOfImage(NSImage* image) {
    // Copied from https://gist.github.com/mtabini/1178403
    [image lockFocus];
    NSBitmapImageRep* bitmapRep =
        [[[NSBitmapImageRep alloc]
             initWithFocusedViewRect:
                 NSMakeRect(
                     0, 0, image.size.width, image.size.height)] autorelease];
    [image unlockFocus];

    return [bitmapRep representationUsingType:NSPNGFileType properties:Nil];

#if 0
  // image can possibly contain PDF image rep, we need to rasterize it
  NSImage* rasterImage =
  [CreateImage(
               [image size].width, [image size].height, 1.0f, ^(NSRect rect) {
                 [image drawInRect:rect
                          fromRect:rect
                         operation:NSCompositeSourceOver
                          fraction:1.0];
               }) autorelease];

  NSBitmapImageRep* rep = [[rasterImage representations] objectAtIndex:0];
  return [rep representationUsingType:NSPNGFileType properties:nil];
#endif  // if 0
}

NSData* LLDBQuickLookPNGRepresentationOfView(NSView* view) {
  [view lockFocus];
  NSBitmapImageRep* bitmapRep =
      [[[NSBitmapImageRep alloc]
           initWithFocusedViewRect:NSMakeRect(
                                       0,
                                       0,
                                       view.bounds.size.width,
                                       view.bounds.size.height)] autorelease];
  [view unlockFocus];

  return [bitmapRep representationUsingType:NSPNGFileType properties:Nil];
}

NSData* LLDBQuickLookPNGRepresentationOfLayer(CALayer* layer) {
  NSImage* image = [CreateImage(layer.bounds.size.width,
                                layer.bounds.size.height,
                                layer.contentsScale,
                                ^(NSRect rect) {
                      CGContextRef context = (CGContextRef)
                          [[NSGraphicsContext currentContext] graphicsPort];
                      [layer renderInContext:context];
                    }) autorelease];

  return LLDBQuickLookPNGRepresentationOfImage(image);
}

@implementation NSImage (LLDBQuickLook)

- (NSData *)quickLookDebugData
{
    return LLDBQuickLookPNGRepresentationOfImage(self);
}

- (NSString *)quickLookDebugFilename
{
    return [[super quickLookDebugFilename] stringByAppendingPathExtension:@"png"];
}

@end
