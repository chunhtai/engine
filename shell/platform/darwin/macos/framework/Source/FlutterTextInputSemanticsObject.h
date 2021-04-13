// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import <Cocoa/Cocoa.h>

#import "flutter/shell/platform/darwin/macos/framework/Source/FlutterTextInputPlugin.h"
#import "flutter/shell/platform/darwin/macos/framework/Source/FlutterPlatformNodeDelegateMac.h"

#include "flutter/third_party/accessibility/ax/platform/ax_platform_node_base.h"


@interface FlutterTextField : NSTextField

@property(nonatomic, strong) NSTextView* fieldEditor;

- (void)updateTextAndSelection;

@end

namespace flutter {

class FlutterTextPlatformNode : public ui::AXPlatformNodeBase {
 public:
  FlutterTextPlatformNode(FlutterPlatformNodeDelegate* delegate, FlutterEngine* engine);
  ~FlutterTextPlatformNode() override;
  // AXPlatformNodeMac.
  gfx::NativeViewAccessible GetNativeViewAccessible() override;
  NSRect GetFrame();
 private:
  FlutterEngine* engine_;
  FlutterTextField* native_text_field_;
};

} // namespace flutter
