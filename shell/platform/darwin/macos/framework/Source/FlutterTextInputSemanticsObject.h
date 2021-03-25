// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import <Cocoa/Cocoa.h>

#import "flutter/shell/platform/darwin/macos/framework/Source/FlutterTextInputPlugin.h"

#include "flutter/third_party/accessibility/ax/platform/ax_platform_node_base.h"

@class FlutterTextPlatformNodeCocoa;

namespace flutter {

class FlutterTextPlatformNode : public ui::AXPlatformNodeBase {
 public:
  FlutterTextPlatformNode(ui::AXPlatformNodeDelegate* delegate, FlutterTextInputPlugin* plugin);
  ~FlutterTextPlatformNode() override;
  // AXPlatformNodeMac.
  gfx::NativeViewAccessible GetNativeViewAccessible() override;
 private:
  FlutterTextPlatformNodeCocoa* native_node_;
};

} // namespace flutter

@interface FlutterTextPlatformNodeCocoa : NSAccessibilityElement <NSAccessibility, NSTextInputClient>

- (instancetype)initWithNode:(ui::AXPlatformNodeBase*)node
                      plugin:(FlutterTextInputPlugin*)plugin;

@end

