// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "flutter/shell/platform/darwin/macos/framework/Source/FlutterTextInputSemanticsObject.h"

#import "flutter/shell/platform/darwin/macos/framework/Source/FlutterTextInputPlugin.h"
#import "flutter/shell/platform/darwin/macos/framework/Source/FlutterEngine_Internal.h"
#import "flutter/shell/platform/darwin/macos/framework/Source/FlutterViewController_Internal.h"

#include "flutter/third_party/accessibility/ax/ax_action_data.h"
#include "flutter/third_party/accessibility/gfx/mac/coordinate_conversion.h"
#include "flutter/third_party/accessibility/gfx/geometry/rect_conversions.h"

@interface FlutterFieldEditor : NSTextView
@end

@implementation FlutterFieldEditor {
  FlutterViewController* _controller;
}

-(instancetype)initWithViewController:(FlutterViewController*)controller {
  self = [super initWithFrame:NSMakeRect(1,1,1,1)];
  if(self){
    _controller = controller;
  }
  return self;
}

- (void)keyDown:(NSEvent *)event {
  [_controller keyDown:event];
  return;
}

- (void)keyUp:(NSEvent *)event {
  [_controller keyUp:event];
  return;
}

@end

@implementation FlutterTextField {
  flutter::FlutterTextPlatformNode* _node;
}

- (instancetype)initWithPlatformNode:(flutter::FlutterTextPlatformNode*)node
                          controller:(FlutterViewController*)controller {
  self = [super initWithFrame:NSZeroRect];
  if (self) {
    _node = node;
    _fieldEditor = [[FlutterFieldEditor alloc] initWithViewController:controller];
  }
  return self;
}

- (NSRect)frame {
  return _node->GetFrame();
}

- (void)updateTextAndSelection {
  NSString* textValue = @(_node->GetStringAttribute(ax::mojom::StringAttribute::kValue).data());
  if (![[self stringValue] isEqualToString:textValue]) {
    [self setStringValue:textValue];
  }

  int start = _node->GetIntAttribute(ax::mojom::IntAttribute::kTextSelStart);
  int end = _node->GetIntAttribute(ax::mojom::IntAttribute::kTextSelEnd);
  _fieldEditor.string = textValue;
  if (start > 0 && end > 0) {
    _fieldEditor.selectedRange = NSMakeRange(start, end - start);
  } else {
    _fieldEditor.selectedRange = NSMakeRange([self stringValue].length, 0);
  }
  NSLog(@"after update text=%@, selection=%@", [self stringValue], NSStringFromRange(_fieldEditor.selectedRange));
}

- (void)setAccessibilityFocused:(BOOL)isFocused {
  [super setAccessibilityFocused:isFocused];
  ui::AXActionData data;
  data.action = isFocused ? ax::mojom::Action::kFocus : ax::mojom::Action::kBlur;
  _node->GetDelegate()->AccessibilityPerformAction(data);
}

- (BOOL)becomeFirstResponder {
  BOOL result = [super becomeFirstResponder];
  // The default implementation of becomeFirstResponder will select the entire text.
  // We need to set it back manually.
  [self updateTextAndSelection];
  return result;
}


@end

namespace flutter {

FlutterTextPlatformNode::FlutterTextPlatformNode(FlutterPlatformNodeDelegate* delegate, FlutterEngine* engine) {
  Init(delegate);
  engine_ = engine;
  native_text_field_ = [[FlutterTextField alloc] initWithPlatformNode:this controller:engine.viewController];
  native_text_field_.bezeled         = NO;
  native_text_field_.drawsBackground = NO;
  native_text_field_.bordered = NO;
  native_text_field_.focusRingType = NSFocusRingTypeNone;
  [native_text_field_ updateTextAndSelection];
  [engine.viewController.view addSubview:native_text_field_ positioned:NSWindowBelow relativeTo:engine.viewController.flutterView];
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

}
