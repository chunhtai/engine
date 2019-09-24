#include "flutter/shell/platform/windows/testing/win32_flutter_window_test.h"
#include <iostream>

namespace flutter {
namespace testing {
  void Win32FlutterWindowTest::OnFontChange() {
    onFontChangeCalled = true;
  }
}
}  // namespace flutter
