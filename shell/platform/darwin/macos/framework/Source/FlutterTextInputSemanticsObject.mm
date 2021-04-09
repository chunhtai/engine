// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "flutter/shell/platform/darwin/macos/framework/Source/FlutterTextInputSemanticsObject.h"

#import "flutter/shell/platform/darwin/macos/framework/Source/FlutterTextInputPlugin.h"
#import "flutter/shell/platform/darwin/macos/framework/Source/FlutterEngine_Internal.h"
#import "flutter/shell/platform/darwin/macos/framework/Source/FlutterViewController_Internal.h"

#include "flutter/third_party/accessibility/gfx/mac/coordinate_conversion.h"
#include "flutter/third_party/accessibility/gfx/geometry/rect_conversions.h"

@interface FlutterTextField : NSTextField
@end

@implementation FlutterTextField

- (NSView *)hitTest:(NSPoint)point {
  return nil;
}

- (void)setAccessibilityFocused:(BOOL)isFocused {
  [super setAccessibilityFocused:isFocused];
  NSLog(@"setAccessibilityFocused %d", isFocused);
}


@end

namespace flutter {

FlutterTextPlatformNode::FlutterTextPlatformNode(FlutterPlatformNodeDelegate* delegate, FlutterEngine* engine) {
  // native_node_ = [[FlutterTextPlatformNodeCocoa alloc] initWithNode:this
  //                                                            plugin:plugin];

  Init(delegate);

  NSRect rect = NSMakeRect(0, 281, 800, 48);
  NSLog(@"rect is %@", NSStringFromRect(rect));
  plugin_ = [[FlutterTextField alloc] initWithFrame:rect];
  plugin_.bezeled         = NO;
  plugin_.drawsBackground = NO;
  plugin_.bordered = NO;
  plugin_.focusRingType = NSFocusRingTypeNone;
  [engine.viewController.view addSubview:plugin_ positioned:NSWindowBelow relativeTo:engine.viewController.flutterView];
}

FlutterTextPlatformNode::~FlutterTextPlatformNode() {}

gfx::NativeViewAccessible FlutterTextPlatformNode::GetNativeViewAccessible() {
  return plugin_;
}

}

@implementation FlutterTextPlatformNodeCocoa {
  ui::AXPlatformNodeBase* _node;
  NSTextField* _plugin;
}

- (instancetype)initWithNode:(ui::AXPlatformNodeBase*)node
                      plugin:(NSTextField*)plugin {
  if ((self = [super init])) {
    _node = node;
    _plugin = plugin;
  }
  return self;
}

// The methods below implement the NSAccessibility protocol. These methods
// appear to be the minimum needed to avoid AppKit refusing to handle the
// element or crashing internally. Most of the remaining old API methods (the
// ones from NSObject) are implemented in terms of the new NSAccessibility
// methods.
- (BOOL)isAccessibilityElement {
  if (!_node)
    return NO;
  return YES;
}
- (BOOL)isAccessibilityEnabled {
  return [_plugin isAccessibilityEnabled];
}
- (NSRect)accessibilityFrame {
  if (!_node || !_node->GetDelegate())
    return NSZeroRect;
  return gfx::ScreenRectToNSRect(_node->GetDelegate()->GetBoundsRect(
      ui::AXCoordinateSystem::kScreenDIPs, ui::AXClippingBehavior::kClipped));
}

- (NSString*)accessibilityLabel {
  // accessibilityLabel is "a short description of the accessibility element",
  // and accessibilityTitle is "the title of the accessibility element"; at
  // least in Chromium, the title usually is a short description of the element,
  // so it also functions as a label.
  return [_plugin accessibilityLabel];
}

- (NSString*)accessibilityTitle {
  return [_plugin accessibilityTitle];
}

- (id)accessibilityValue {
  return [_plugin accessibilityValue];
}

- (NSAccessibilityRole)accessibilityRole {
  return [_plugin accessibilityRole];
}

- (NSString*)accessibilityRoleDescription {
  return [_plugin accessibilityRoleDescription];
}

- (NSAccessibilitySubrole)accessibilitySubrole {
  return [_plugin accessibilitySubrole];
}

- (NSString*)accessibilityHelp {
  return [_plugin accessibilityHelp];
}

- (id)accessibilityParent {
  if (!_node)
    return nil;
  return NSAccessibilityUnignoredAncestor(_node->GetParent());
}

- (id)accessibilityWindow {
  return _node->GetDelegate()->GetNSWindow();
}

- (id)accessibilityTopLevelUIElement {
  return _node->GetDelegate()->GetNSWindow();
}

#pragma mark NSTextInputClient

// - (BOOL)hasMarkedText {
//   return [_plugin hasMarkedText];
// }

// - (NSRange)markedRange {
//   return [_plugin markedRange];
// }

// - (NSRange)selectedRange {
//   return [_plugin selectedRange];
// }

// - (void)setMarkedText:(id)string
//         selectedRange:(NSRange)selectedRange
//      replacementRange:(NSRange)replacementRange {
//   [_plugin setMarkedText:string
//            selectedRange:selectedRange
//         replacementRange:replacementRange];
// }

// - (void)unmarkText {
//   [_plugin unmarkText];
// }

// - (NSArray<NSString*>*)validAttributesForMarkedText {
//   return [_plugin validAttributesForMarkedText];
// }

// - (NSAttributedString*)attributedSubstringForProposedRange:(NSRange)range
//                                                actualRange:(NSRangePointer)actualRange {
//   return [_plugin attributedSubstringForProposedRange:range
//                                           actualRange:actualRange];
// }

// - (void)insertText:(id)string replacementRange:(NSRange)range {
//   [_plugin insertText:string replacementRange:range];
// }

// - (NSUInteger)characterIndexForPoint:(NSPoint)point {
//   return [_plugin characterIndexForPoint:point];
// }

// - (NSRect)firstRectForCharacterRange:(NSRange)range actualRange:(NSRangePointer)actualRange {
//   // TODO: Implement.
//   // Note: This function can't easily be implemented under the system-message architecture.
//   return [_plugin firstRectForCharacterRange:range actualRange:actualRange];
// }

// - (void)doCommandBySelector:(SEL)selector {
//   return [_plugin doCommandBySelector:selector];
// }

@end
