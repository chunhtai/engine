// Copyright 2014 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "base/bind.h"
#include "base/compiler_specific.h"
#include "base/macros.h"
#include "base/path_service.h"
#include "base/test/launcher/unit_test_launcher.h"
#include "base/test/test_discardable_memory_allocator.h"
#include "base/test/test_suite.h"
#include "ax_build/build_config.h"
#include "testing/gtest/include/gtest/gtest.h"
#include "ui/base/resource/resource_bundle.h"
#include "ui/base/ui_base_paths.h"
#include "ui/gfx/font_util.h"

#if defined(OS_MAC)
#include "base/test/mock_chrome_application_mac.h"
#endif

#if !defined(OS_IOS)
#include "mojo/core/embedder/embedder.h"  // nogncheck
#endif

#if defined(OS_FUCHSIA)
#include "skia/ext/test_fonts.h"  // nogncheck
#endif

namespace {

class GfxTestSuite : public base::TestSuite {
 public:
  GfxTestSuite(int argc, char** argv) : base::TestSuite(argc, argv) {
  }

 protected:
  void Initialize() override {
    base::TestSuite::Initialize();

#if defined(OS_MAC)
    mock_cr_app::RegisterMockCrApp();
#endif

    ax::RegisterPathProvider();

    base::FilePath ui_test_pak_path;
    ASSERT_TRUE(base::PathService::Get(ax::UI_TEST_PAK, &ui_test_pak_path));
    ax::ResourceBundle::InitSharedInstanceWithPakPath(ui_test_pak_path);

#if defined(OS_ANDROID)
    // Android needs a discardable memory allocator when loading fallback fonts.
    base::DiscardableMemoryAllocator::SetInstance(
        &discardable_memory_allocator);
#endif

#if defined(OS_FUCHSIA)
    skia::ConfigureTestFont();
#endif

    gfx::InitializeFonts();
  }

  void Shutdown() override {
    ax::ResourceBundle::CleanupSharedInstance();
    base::TestSuite::Shutdown();
  }

 private:
  base::TestDiscardableMemoryAllocator discardable_memory_allocator;

  DISALLOW_COPY_AND_ASSIGN(GfxTestSuite);
};

}  // namespace

int main(int argc, char** argv) {
  GfxTestSuite test_suite(argc, argv);

#if !defined(OS_IOS)
  mojo::core::Init();
#endif

  return base::LaunchUnitTests(
      argc, argv,
      base::BindOnce(&GfxTestSuite::Run, base::Unretained(&test_suite)));
}
