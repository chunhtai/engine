// Copyright (c) 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "accessibility_features.h"

#include "base/feature_list.h"
#include "ax_build/build_config.h"

namespace features {

// Allow use of ARIA roles from https://github.com/w3c/annotation-aria draft.
const base::Feature kEnableAccessibilityExposeARIAAnnotations{
    "AccessibilityExposeARIAAnnotations", base::FEATURE_DISABLED_BY_DEFAULT};

bool IsAccessibilityExposeARIAAnnotationsEnabled() {
  // return base::FeatureList::IsEnabled(
  //     ::features::kEnableAccessibilityExposeARIAAnnotations);
  return false;
}

// Enable exposing "display: none" nodes to the browser process AXTree
const base::Feature kEnableAccessibilityExposeDisplayNone{
    "AccessibilityExposeDisplayNone", base::FEATURE_DISABLED_BY_DEFAULT};

bool IsAccessibilityExposeDisplayNoneEnabled() {
  // return base::FeatureList::IsEnabled(
  //     ::features::kEnableAccessibilityExposeDisplayNone);
  return false;
}

// Enable exposing the <html> element to the browser process AXTree
// (as an ignored node).
const base::Feature kEnableAccessibilityExposeHTMLElement{
    "AccessibilityExposeHTMLElement", base::FEATURE_DISABLED_BY_DEFAULT};

bool IsAccessibilityExposeHTMLElementEnabled() {
  // return base::FeatureList::IsEnabled(
  //     ::features::kEnableAccessibilityExposeHTMLElement);
  return false;
}

// Enable language detection to determine language used in page text, exposed
// on the browser process AXTree.
const base::Feature kEnableAccessibilityLanguageDetection{
    "AccessibilityLanguageDetection", base::FEATURE_DISABLED_BY_DEFAULT};

bool IsAccessibilityLanguageDetectionEnabled() {
  // return base::FeatureList::IsEnabled(
  //     ::features::kEnableAccessibilityLanguageDetection);
  return false;
}

// Serializes accessibility information from the Views tree and deserializes it
// into an AXTree in the browser process.
const base::Feature kEnableAccessibilityTreeForViews{
    "AccessibilityTreeForViews", base::FEATURE_DISABLED_BY_DEFAULT};

bool IsAccessibilityTreeForViewsEnabled() {
  // return base::FeatureList::IsEnabled(
  //     ::features::kEnableAccessibilityTreeForViews);
  return false;
}

const base::Feature kAccessibilityFocusHighlight{
    "AccessibilityFocusHighlight", base::FEATURE_ENABLED_BY_DEFAULT};

bool IsAccessibilityFocusHighlightEnabled() {
//   return base::FeatureList::IsEnabled(::features::kAccessibilityFocusHighlight);
  return false;
}

#if defined(OS_WIN)
const base::Feature kIChromeAccessible{"IChromeAccessible",
                                       base::FEATURE_DISABLED_BY_DEFAULT};

bool IsIChromeAccessibleEnabled() {
  // return base::FeatureList::IsEnabled(::features::kIChromeAccessible);
  return false;
}
#endif  // defined(OS_WIN)

#if defined(OS_CHROMEOS)
const base::Feature kAccessibilityCursorColor{"AccessibilityCursorColor",
                                              base::FEATURE_ENABLED_BY_DEFAULT};

bool IsAccessibilityCursorColorEnabled() {
  // return base::FeatureList::IsEnabled(::features::kAccessibilityCursorColor);
  return false;
}
#endif  // defined(OS_CHROMEOS)

const base::Feature kAugmentExistingImageLabels{
    "AugmentExistingImageLabels", base::FEATURE_DISABLED_BY_DEFAULT};

bool IsAugmentExistingImageLabelsEnabled() {
  // return base::FeatureList::IsEnabled(::features::kAugmentExistingImageLabels);
  return false;
}

}  // namespace features