#include "gtest/gtest.h"
#include "flutter/shell/platform/windows/win32_flutter_window.h"
#include "flutter/shell/platform/windows/testing/win32_flutter_window_test.h"

namespace flutter {
namespace testing {

  TEST(Win32FlutterWindowTester, CreateDestroy) {
    Win32FlutterWindow w(800, 600);
  }

  TEST(Win32FlutterWindowTest, CanFontChange) {
    Win32FlutterWindowTest w(800, 600);
    HWND hwnd = w.GetWindowHandle();
    LRESULT result = SendMessage(hwnd, WM_FONTCHANGE, NULL, NULL);
    ASSERT_EQ(result, 0);
    ASSERT_TRUE(w.onFontChangeCalled);
  }

}
}