//
//  inspect.m
//  Dnamer
//
//  Created by Lia huang on 2/25/26.
//

#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>
#import <Cocoa/Cocoa.h>

__attribute__((constructor))
static void onLoad() {
    NSLog(@"✅ INJECTED");

    Class ecTextLayer = NSClassFromString(@"ECTextLayer");
    if (!ecTextLayer) {
        NSLog(@"❌ ECTextLayer class not found!");
        NSLog(@"🔍 Searching for similar classes...");
        
        unsigned int classCount;
        Class *classes = objc_copyClassList(&classCount);
        for (unsigned int i = 0; i < classCount; i++) {
            const char *className = class_getName(classes[i]);
            if (strstr(className, "Text") || strstr(className, "Label") || strstr(className, "EC")) {
                NSLog(@"   Found: %s", className);
            }
        }
        free(classes);
        return;
    }
    
    NSLog(@"✅ Found ECTextLayer class");

    SEL sel = NSSelectorFromString(@"setString:");
    Method original = class_getInstanceMethod(ecTextLayer, sel);
    if (!original) {
        NSLog(@"❌ setString: method not found on ECTextLayer");
        
        NSLog(@"🔍 Available methods:");
        unsigned int methodCount;
        Method *methods = class_copyMethodList(ecTextLayer, &methodCount);
        for (unsigned int i = 0; i < methodCount; i++) {
            SEL methodSel = method_getName(methods[i]);
            NSLog(@"   %@", NSStringFromSelector(methodSel));
        }
        free(methods);
        return;
    }
    
    NSLog(@"✅ Found setString: method, hooking...");
    IMP origIMP = method_getImplementation(original);

    method_setImplementation(original, imp_implementationWithBlock(^(CATextLayer *self, id string) {
        NSString *originalString = [string isKindOfClass:[NSAttributedString class]] 
            ? [(NSAttributedString *)string string] 
            : (string ? [string description] : @"(null)");
        
        // Check if this is a desktop name or app name we want to customize
        NSString *customName = nil;
        
        if ([originalString isEqualToString:@"Desktop 1"]) {
            customName = @"🏠 Home";
        } else if ([originalString isEqualToString:@"Desktop 2"] && [originalString isEqualToString:@"Xcode"]) {
            // This will never match - keeping for reference
            customName = @"💻 Work";
        } else if ([originalString isEqualToString:@"Desktop 3"]) {
            customName = @"🎮 Play";
        } else if ([originalString isEqualToString:@"Xcode"]) {
            customName = @"💻 Work";
        } else if ([originalString isEqualToString:@"Google Chrome"]) {
            customName = @"🌐 Browse";
        }
        
        if (customName) {
            NSLog(@"🎯 Text detected: '%@' → renamed to: '%@'", originalString, customName);
            // Replace the string with our custom name!
            string = customName;
        }
        
        // Call the original implementation with potentially modified string
        ((void(*)(id,SEL,id))origIMP)(self, sel, string);
    }));
    
    NSLog(@"✅ Hook installed successfully");
}
