//
//  desktop_renamer.m
//  Dnamer
//
//  Created by Lia huang on 2/26/26.
//

#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>
#import <CoreText/CoreText.h>
#import <Cocoa/Cocoa.h>
#import "ZKSwizzle.h"

static char OVERRIDDEN_STRING;
static char OVERRIDDEN_WIDTH;
static char OFFSET;
static char NEW_X;

// Desktop names loaded from plist
static NSMutableDictionary *desktopNamesDict = nil;
static const int MAX_DESKTOPS = 6;

// Helper: Load desktop names from plist
static void loadDesktopNames(void) {
    NSString *plistPath = [@"~/Library/Preferences/com.dnamer.desktopnames.plist" stringByExpandingTildeInPath];
    desktopNamesDict = [[NSMutableDictionary alloc] initWithContentsOfFile:plistPath];
    
    if (desktopNamesDict) {
        NSLog(@"✅ Loaded desktop names from plist: %@", desktopNamesDict);
    } else {
        NSLog(@"⚠️  No desktop names plist found, using defaults");
        desktopNamesDict = [@{} mutableCopy];
    }
}

// Helper: Get desktop name by number
static NSString *getDesktopName(int desktopNumber) {
    if (!desktopNamesDict) {
        loadDesktopNames();
    }
    
    NSString *key = [NSString stringWithFormat:@"Desktop %d", desktopNumber];
    NSString *name = desktopNamesDict[key];
    
    // Return custom name if exists, otherwise return default
    return name ?: [NSString stringWithFormat:@"Desktop %d", desktopNumber];
}

// Forward declarations
@interface ECMaterialLayer : CALayer
@end

@interface ECTextLayer : CATextLayer
@end

// Helper: Find ECTextLayer in view hierarchy
static CATextLayer *getTextLayer(CALayer *view) {
    if ([NSStringFromClass(view.class) isEqualToString:@"ECTextLayer"]) {
        return (CATextLayer *)view;
    }
    for (CALayer *sublayer in view.sublayers) {
        CATextLayer *found = getTextLayer(sublayer);
        if (found) return found;
    }
    return nil;
}

// Helper: Calculate text width using CoreText
static double getTextSize(CATextLayer *textLayer, NSString *string) {
    if (!textLayer || !string) return -1;
    
    // Add ".." and subtract "." to handle whitespace-only strings
    NSString *testString = [string stringByAppendingString:@".."];
    
    CFRange textRange = CFRangeMake(0, testString.length);
    CFMutableAttributedStringRef attrString = CFAttributedStringCreateMutable(kCFAllocatorDefault, testString.length);
    CFAttributedStringReplaceString(attrString, CFRangeMake(0, 0), (__bridge CFStringRef)testString);
    CFAttributedStringSetAttribute(attrString, textRange, kCTFontAttributeName, textLayer.font);
    
    CTFramesetterRef framesetter = CTFramesetterCreateWithAttributedString(attrString);
    CFRange fitRange;
    CGSize frameSize = CTFramesetterSuggestFrameSizeWithConstraints(framesetter, textRange, NULL, CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX), &fitRange);
    
    CFRelease(framesetter);
    CFRelease(attrString);
    
    // Subtract the ".." width
    CFRange dotRange = CFRangeMake(0, 1);
    CFMutableAttributedStringRef dotString = CFAttributedStringCreateMutable(kCFAllocatorDefault, 1);
    CFAttributedStringReplaceString(dotString, CFRangeMake(0, 0), CFSTR("."));
    CFAttributedStringSetAttribute(dotString, dotRange, kCTFontAttributeName, textLayer.font);
    CTFramesetterRef dotFramesetter = CTFramesetterCreateWithAttributedString(dotString);
    CGSize dotSize = CTFramesetterSuggestFrameSizeWithConstraints(dotFramesetter, dotRange, NULL, CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX), &fitRange);
    
    CFRelease(dotFramesetter);
    CFRelease(dotString);
    
    return frameSize.width - dotSize.width;
}

// Helper: Override text layer string and width
static void overrideTextLayer(CALayer *view, NSString *newString, double width) {
    CATextLayer *textLayer = getTextLayer(view);
    if (!textLayer) return;
    
    textLayer.string = newString;
    CALayer *parent = textLayer.superlayer;
    
    // Store in associated objects on both text layer and parent
    objc_setAssociatedObject(textLayer, &OVERRIDDEN_STRING, newString, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(parent, &OVERRIDDEN_STRING, newString, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    if (width > 0) {
        objc_setAssociatedObject(textLayer, &OVERRIDDEN_WIDTH, @(width), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(parent, &OVERRIDDEN_WIDTH, @(width + 20), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    
    // Store on siblings too
    for (CALayer *sibling in parent.sublayers) {
        objc_setAssociatedObject(sibling, &OVERRIDDEN_STRING, newString, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        if (width > 0) {
            objc_setAssociatedObject(sibling, &OVERRIDDEN_WIDTH, @(width), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    }
    
    NSLog(@"🎨 Overriding text: '%@' with width: %.2f", newString, width);
}

// Helper: Set offset for centering
static void setOffset(CALayer *view, double offset, BOOL modify) {
    CATextLayer *textLayer = getTextLayer(view);
    if (!textLayer) return;
    
    CALayer *parent = textLayer.superlayer;
    if (modify) {
        NSNumber *existingOffset = objc_getAssociatedObject(parent, &OFFSET);
        if (existingOffset) {
            offset += [existingOffset doubleValue];
        }
    }
    
    objc_setAssociatedObject(parent, &OFFSET, @(offset), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    for (CALayer *sibling in parent.sublayers) {
        objc_setAssociatedObject(sibling, &OFFSET, @(offset), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

// Recursive frame refresh
static void refreshFrames(CALayer *layer) {
    for (CALayer *sublayer in layer.sublayers) {
        [sublayer setFrame:sublayer.frame];
        refreshFrames(sublayer);
    }
}

// ============================================================================
// MARK: - ZKSwizzle Hooks
// ============================================================================

// Hook ECMaterialLayer.setFrame: to detect Mission Control and apply custom names
ZKSwizzleInterface(_DN_ECMaterialLayer, ECMaterialLayer, CALayer)
@implementation _DN_ECMaterialLayer

- (void)setFrame:(CGRect)frame {
    // Debug logging
    NSLog(@"🔍 ECMaterialLayer.setFrame: frame={%.1f, %.1f, %.1f, %.1f}, superlayer=%@", 
          frame.origin.x, frame.origin.y, frame.size.width, frame.size.height,
          NSStringFromClass([self.superlayer class]));
    
    // Check if this is the desktop switcher (Mission Control)
    if (frame.origin.x == 0 && [self.superlayer.class isEqual:[CALayer class]]) {
        NSLog(@"🎯 ECMaterialLayer.setFrame: detected Mission Control UI");
        
        // Navigate to desktop views
        CALayer *root = self.superlayer;
        if (root.sublayers.count > 0) {
            CALayer *container = root.sublayers.lastObject;
            if (container.sublayers.count >= 2) {
                NSArray *unexpandedViews = container.sublayers[0].sublayers;
                NSArray *expandedViews = container.sublayers[1].sublayers;
                
                NSLog(@"📊 Found %lu desktop views (unexpanded), %lu expanded", 
                      (unsigned long)unexpandedViews.count, (unsigned long)expandedViews.count);
                
                // Apply custom names
                double unexpandedOffset = 0;
                
                for (int i = 0; i < MIN(unexpandedViews.count, MAX_DESKTOPS); i++) {
                    NSString *name = getDesktopName(i + 1);  // Desktop numbers start at 1
                    
                    // Unexpanded view
                    if (i < unexpandedViews.count) {
                        CALayer *desktop = unexpandedViews[i];
                        CATextLayer *textLayer = getTextLayer(desktop);
                        if (textLayer) {
                            double originalWidth = textLayer.bounds.size.width;
                            double newWidth = getTextSize(textLayer, name);
                            overrideTextLayer(desktop, name, newWidth);
                            setOffset(desktop, unexpandedOffset, NO);
                            unexpandedOffset += (newWidth - originalWidth);
                        }
                    }
                    
                    // Expanded view
                    if (i < expandedViews.count) {
                        CALayer *desktop = expandedViews[i];
                        CATextLayer *textLayer = getTextLayer(desktop);
                        if (textLayer) {
                            double newWidth = getTextSize(textLayer, name);
                            // Limit to parent width
                            newWidth = MIN(newWidth, desktop.frame.size.width);
                            overrideTextLayer(desktop, name, newWidth);
                        }
                    }
                }
                
                // Center the unexpanded desktops
                for (int i = 0; i < MIN(unexpandedViews.count, MAX_DESKTOPS); i++) {
                    setOffset(unexpandedViews[i], -unexpandedOffset / 2, YES);
                }
                
                // Refresh frames
                refreshFrames(root);
            }
        }
    }
    
    // Call original implementation
    ZKOrig(void, frame);
}

@end

// Hook CALayer.setFrame: to adjust positioning based on associated objects
ZKSwizzleInterface(_DN_CALayer, CALayer, CALayer)
@implementation _DN_CALayer

- (void)setFrame:(CGRect)frame {
    CGRect orig = frame;
    
    // Check for overridden width
    NSNumber *width = objc_getAssociatedObject(self, &OVERRIDDEN_WIDTH);
    if (width && [self.class isEqual:[CALayer class]]) {
        frame.size.width = [width doubleValue] + 20;
    }
    
    // Check if this has a text layer child
    int textIndex = -1;
    NSArray *sublayers = self.sublayers;
    if (sublayers.count > 0 && 
        [NSStringFromClass([sublayers.lastObject class]) isEqualToString:@"ECTextLayer"]) {
        textIndex = (int)sublayers.count - 1;
    }
    
    if (textIndex != -1) {
        CALayer *textLayer = sublayers[textIndex];
        NSNumber *textWidth = objc_getAssociatedObject(textLayer, &OVERRIDDEN_WIDTH);
        if (textWidth) {
            frame.size.width = [textWidth doubleValue];
        }
        
        // Apply offset for horizontal positioning
        NSNumber *offset = objc_getAssociatedObject(textLayer, &OFFSET);
        NSNumber *newX = objc_getAssociatedObject(self, &NEW_X);
        if (offset && (!newX || [newX doubleValue] != frame.origin.x)) {
            frame.origin.x += [offset doubleValue];
            objc_setAssociatedObject(self, &NEW_X, @(frame.origin.x), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    }
    
    // Prevent zero-width frames
    if (frame.size.width == 0.0 && orig.size.width != 0.0) {
        frame = orig;
    }
    
    // Call original implementation
    ZKOrig(void, frame);
}

@end

// Hook ECTextLayer.setFrame: to maintain custom width
ZKSwizzleInterface(_DN_ECTextLayer, ECTextLayer, CATextLayer)
@implementation _DN_ECTextLayer

- (void)setFrame:(CGRect)frame {
    NSNumber *width = objc_getAssociatedObject(self, &OVERRIDDEN_WIDTH);
    if (width) {
        frame.size.width = [width doubleValue];
        NSLog(@"📏 ECTextLayer adjusting width to: %.2f", width.doubleValue);
    }
    
    // Call original implementation
    ZKOrig(void, frame);
}

- (void)setString:(id)string {
    // Extract the actual string value
    NSString *stringValue = [string isKindOfClass:[NSAttributedString class]] 
        ? [(NSAttributedString *)string string] 
        : (string ? [string description] : @"(null)");
    
    NSLog(@"🔍 ECTextLayer.setString: '%@'", stringValue);
    
    // Check if this is a desktop name we want to rename
    // Extract desktop number from "Desktop X" format
    if ([stringValue hasPrefix:@"Desktop "]) {
        NSString *numberPart = [stringValue substringFromIndex:8]; // Skip "Desktop "
        int desktopNumber = [numberPart intValue];
        
        if (desktopNumber >= 1 && desktopNumber <= MAX_DESKTOPS) {
            NSString *customName = getDesktopName(desktopNumber);
            if (customName && ![customName isEqualToString:stringValue]) {
                string = customName;
                NSLog(@"✅ Renamed %@ → %@", stringValue, customName);
            }
        }
    }
    
    // Call original implementation with potentially modified string
    ZKOrig(void, string);
}

@end

__attribute__((constructor))
static void initialize() {
    NSLog(@"🚀 Desktop Renamer Loading with ZKSwizzle");
    
    // Load desktop names from plist
    loadDesktopNames();
    
    // Listen for reload notifications
    [[NSDistributedNotificationCenter defaultCenter] addObserverForName:@"com.dnamer.reloadDesktopNames"
                                                                  object:nil
                                                                   queue:[NSOperationQueue mainQueue]
                                                              usingBlock:^(NSNotification *note) {
        NSLog(@"🔄 Reloading desktop names from plist");
        loadDesktopNames();
    }];
    
    // Check if required classes exist before attempting to swizzle
    Class ecMaterialLayer = NSClassFromString(@"ECMaterialLayer");
    Class ecTextLayer = NSClassFromString(@"ECTextLayer");
    Class caLayer = NSClassFromString(@"CALayer");
    
    if (!ecMaterialLayer) {
        NSLog(@"⚠️  ECMaterialLayer class not found - swizzle will be skipped");
    }
    
    if (!ecTextLayer) {
        NSLog(@"⚠️  ECTextLayer class not found - swizzle will be skipped");
    }
    
    if (!caLayer) {
        NSLog(@"⚠️  CALayer class not found - swizzle will be skipped");
    }
    
    if (ecMaterialLayer && ecTextLayer && caLayer) {
        NSLog(@"✅ All required classes found, hooks can be installed");
        NSLog(@"✅ ECMaterialLayer, CALayer, and ECTextLayer hooks installed");
    } else {
        NSLog(@"❌ Some required classes missing - desktop renaming may not work");
        
        // List all available classes for debugging
        NSLog(@"🔍 Searching for similar classes...");
        unsigned int classCount;
        Class *classes = objc_copyClassList(&classCount);
        for (unsigned int i = 0; i < classCount; i++) {
            const char *className = class_getName(classes[i]);
            if (strstr(className, "EC") || strstr(className, "Desktop")) {
                NSLog(@"   Found: %s", className);
            }
        }
        free(classes);
    }
    
    NSLog(@"✅ Desktop Renamer Loaded Successfully");
}
