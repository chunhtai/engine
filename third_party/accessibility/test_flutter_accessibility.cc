// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "test_flutter_accessibility.h"

namespace ax {

FlutterAccessibility* FlutterAccessibility::Create() {
  return new TestFlutterAccessibility();
}

void TestFlutterAccessibility::OnAccessibilityEvent(
    AXEventGenerator::TargetedEvent targeted_event) {
  accessibilitiy_events.push_back(targeted_event);
}

void TestFlutterAccessibility::DispatchAccessibilityAction(
    uint16_t target,
    FlutterSemanticsAction action,
    uint8_t* data,
    size_t data_size) {
  performed_actions.push_back(action);
}

}  // namespace ax
