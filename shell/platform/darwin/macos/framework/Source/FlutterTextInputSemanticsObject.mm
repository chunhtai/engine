// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "flutter/shell/platform/darwin/macos/framework/Source/FlutterTextInputSemanticsObject.h"

#import "flutter/shell/platform/darwin/macos/framework/Source/FlutterTextInputPlugin.h"
#import "flutter/shell/platform/darwin/macos/framework/Source/FlutterEngine_Internal.h"
#import "flutter/shell/platform/darwin/macos/framework/Source/FlutterViewController_Internal.h"

#include "flutter/third_party/accessibility/gfx/mac/coordinate_conversion.h"
#include "flutter/third_party/accessibility/gfx/geometry/rect_conversions.h"

NSString* const NSFieldEditorKey = @"NSFieldEditor";

// @interface FlutterTextViewDelegate : NSObject<NSTextViewDelegate>
// @end

// @implementation FlutterTextViewDelegate {
//   flutter::FlutterTextPlatformNode* _node;
// }

// - (instancetype)initWithPlatformNode:(flutter::FlutterTextPlatformNode*)node {
//   self = [super init];
//   if (self) {
//     _node = node;
//   }
//   return self;
// }

// - (void)controlTextDidBeginEditing::(NSNotification *)obj {
//   NSLog(@"controlTextDidBeginEditing %@", obj);
// }

// - (void)controlTextDidChange:(NSNotification *)obj {
//   NSLog(@"text has changed %@", obj);
// }



// @end

@interface FlutterTextFieldDelegate : NSObject<NSTextFieldDelegate>

// @property(nonatomic, strong, nonnull) FlutterTextFieldDelegate* textFieldDelegate;

@end

@implementation FlutterTextFieldDelegate {
  flutter::FlutterTextPlatformNode* _node;
}

- (instancetype)initWithPlatformNode:(flutter::FlutterTextPlatformNode*)node {
  self = [super init];
  if (self) {
    _node = node;
  }
  return self;
}

- (void)controlTextDidBeginEditing:(NSNotification*)obj {
  NSLog(@"controlTextDidBeginEditing %@", obj);
}

- (void)controlTextDidChange:(NSNotification*)notification {
  if (notification) {
    _node->updateEditingState(notification.userInfo[NSFieldEditorKey]);
  }
}

- (BOOL)control:(NSControl *)control 
       textView:(NSTextView *)textView 
doCommandBySelector:(SEL)commandSelector {
  NSLog(@"control textView, doCommandBySelector");
  return NO;
}


@end

// @interface FlutterTextField : NSTextField

// @property(nonatomic, strong, nonnull) FlutterTextFieldDelegate* textFieldDelegate;

// @end

@implementation FlutterTextField {
  flutter::FlutterTextPlatformNode* _node;
}

- (instancetype)initWithPlatformNode:(flutter::FlutterTextPlatformNode*)node {
  self = [super initWithFrame:NSZeroRect];
  if (self) {
    _node = node;
    // _textFieldDelegate = [[FlutterTextFieldDelegate alloc] initWithPlatformNode:node];
    // self.delegate = _textFieldDelegate;
  }
  return self;
}

- (NSRect)frame {
  return _node->GetFrame();
}

- (NSView *)hitTest:(NSPoint)point {
  return nil;
}

// - (BOOL)acceptsFirstResponder {
//   BOOL result = [super acceptsFirstResponder];
//   NSLog(@"accept first responder called %d", result);
//   return NO;
// }

- (void)keyDown:(NSEvent *)event {
  NSLog(@"key down");
  return;
}

- (void)keyUp:(NSEvent *)event {
  NSLog(@"key up");
  return;
}

- (void)interpretKeyEvents:(NSArray<NSEvent *> *)eventArray {
  NSLog(@"interpretKeyEvents");
  return;
}

- (BOOL)performKeyEquivalent:(NSEvent *)theEvent{
    NSLog(@"performKeyEquivalent");
    return YES;
}

- (void)setAccessibilityFocused:(BOOL)isFocused {
  [super setAccessibilityFocused:isFocused];
}


@end

namespace flutter {

FlutterTextPlatformNode::FlutterTextPlatformNode(FlutterPlatformNodeDelegate* delegate, FlutterEngine* engine) {
  // native_node_ = [[FlutterTextPlatformNodeCocoa alloc] initWithNode:this
  //                                                            plugin:plugin];

  Init(delegate);
  engine_ = engine;
  native_text_field_ = [[FlutterTextField alloc] initWithPlatformNode:this];
  native_text_field_.bezeled         = NO;
  native_text_field_.drawsBackground = NO;
  native_text_field_.bordered = NO;
  native_text_field_.focusRingType = NSFocusRingTypeNone;
  [engine.viewController.view addSubview:native_text_field_];// positioned:NSWindowBelow relativeTo:engine.viewController.flutterView];
}

FlutterTextPlatformNode::~FlutterTextPlatformNode() {
  if ([native_text_field_ isDescendantOf:engine_.viewController.view]) {
    [native_text_field_ removeFromSuperview];
  }
  native_text_field_ = nil;
  engine_ = nil;
}

gfx::NativeViewAccessible FlutterTextPlatformNode::GetNativeViewAccessible() {
  return native_text_field_;
}

NSRect FlutterTextPlatformNode::GetFrame() {
  FlutterPlatformNodeDelegate* delegate = (FlutterPlatformNodeDelegate*)GetDelegate();
  bool offscreen;
  auto bridge_ptr = delegate->GetOwnerBridge().lock();
  gfx::RectF bounds = bridge_ptr->RelativeToGlobalBounds(delegate->GetAXNode(), offscreen, true);


  // Converts to NSRect to use NSView rect conversion.
  NSRect ns_local_bounds =
      NSMakeRect(bounds.x(), bounds.y(), bounds.width(), bounds.height());
  // The macOS XY coordinates start at bottom-left and increase toward top-right,
  // which is different from the Flutter's XY coordinates that start at top-left
  // increasing to bottom-right. Therefore, We need to flip the y coordinate when
  // we convert from flutter coordinates to macOS coordinates.
  ns_local_bounds.origin.y = -ns_local_bounds.origin.y - ns_local_bounds.size.height;
  NSRect ns_view_bounds =
      [engine_.viewController.flutterView convertRectFromBacking:ns_local_bounds];
  return [engine_.viewController.flutterView convertRect:ns_view_bounds
                                                                    toView:nil];
}

void FlutterTextPlatformNode::updateEditingState(NSTextView* fieldEditor) {
  NSLog(@"updateEditingState string %@, selection %@", fieldEditor.string, NSStringFromRange(fieldEditor.selectedRange));
}

}
