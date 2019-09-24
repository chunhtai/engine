// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include <windowsx.h>

#include "flutter/shell/platform/windows/win32_flutter_window.h"

namespace flutter {
namespace testing {

class Win32FlutterWindowTest : public Win32FlutterWindow {
  public:
    Win32FlutterWindowTest(int width, int height) : Win32FlutterWindow(width, height) { };

    void OnFontChange() override;

    bool onFontChangeCalled = false;
 private:
};

}  // namespace testing
}  // namespace flutterS
