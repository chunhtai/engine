// Copyright (c) 2012 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "browser_accessibility_cocoa.h"

#include <execinfo.h>
#include <stddef.h>
#include <stdint.h>
#include <string.h>

#include <algorithm>
#include <iterator>
#include <map>
#include <memory>
#include <utility>

// #include "base/mac/foundation_util.h"
// #include "base/mac/scoped_cftyperef.h"
// #include "base/optional.h"
// #include "base/strings/string_split.h"
// #include "base/strings/string_util.h"
// #include "base/strings/sys_string_conversions.h"
// #include "base/strings/utf_string_conversions.h"
// #include "base/trace_event/trace_event.h"
// #include "content/browser/accessibility/browser_accessibility_mac.h"
// #include "content/browser/accessibility/browser_accessibility_manager.h"
// #include "content/browser/accessibility/browser_accessibility_manager_mac.h"
// #include "content/browser/accessibility/browser_accessibility_position.h"
// #include "content/browser/accessibility/one_shot_accessibility_tree_search.h"
// #include "content/public/common/content_client.h"
// #include "content/public/common/use_zoom_for_dsf_policy.h"
// #include "third_party/blink/public/strings/grit/blink_strings.h"
#include "third_party/skia/include/core/SkColor.h"
#include "../ax_enum_util.h"
#include "../ax_range.h"
#include "../ax_role_properties.h"
#include "ax_platform_node.h"
#include "../../gfx/mac/coordinate_conversion.h"

#import "ax_platform_node_mac.h"

using BrowserAccessibilityPositionInstance =
    ax::AXNodePosition::AXPositionInstance;
using SerializedPosition =
    ax::AXNodePosition::SerializedPosition;
using AXPlatformRange =
    ax::AXRange<BrowserAccessibilityPositionInstance::element_type>;
using AXTextMarkerRangeRef = CFTypeRef;
using AXTextMarkerRef = CFTypeRef;
using StringAttribute = ax::StringAttribute;
using ax::AXNodeData;
using ax::AXTreeIDRegistry;

static_assert(
    std::is_trivially_copyable<SerializedPosition>::value,
    "SerializedPosition must be POD because it's used to back an AXTextMarker");

namespace {

// Private WebKit accessibility attributes.
NSString* const NSAccessibilityARIAAtomicAttribute = @"AXARIAAtomic";
NSString* const NSAccessibilityARIABusyAttribute = @"AXARIABusy";
NSString* const NSAccessibilityARIAColumnCountAttribute = @"AXARIAColumnCount";
NSString* const NSAccessibilityARIAColumnIndexAttribute = @"AXARIAColumnIndex";
NSString* const NSAccessibilityARIALiveAttribute = @"AXARIALive";
NSString* const NSAccessibilityARIAPosInSetAttribute = @"AXARIAPosInSet";
NSString* const NSAccessibilityARIARelevantAttribute = @"AXARIARelevant";
NSString* const NSAccessibilityARIARowCountAttribute = @"AXARIARowCount";
NSString* const NSAccessibilityARIARowIndexAttribute = @"AXARIARowIndex";
NSString* const NSAccessibilityARIASetSizeAttribute = @"AXARIASetSize";
NSString* const NSAccessibilityAccessKeyAttribute = @"AXAccessKey";
NSString* const NSAccessibilityAutocompleteValueAttribute =
    @"AXAutocompleteValue";
NSString* const NSAccessibilityBlockQuoteLevelAttribute = @"AXBlockQuoteLevel";
NSString* const NSAccessibilityDOMClassList = @"AXDOMClassList";
NSString* const NSAccessibilityDOMIdentifierAttribute = @"AXDOMIdentifier";
NSString* const NSAccessibilityDropEffectsAttribute = @"AXDropEffects";
NSString* const NSAccessibilityEditableAncestorAttribute =
    @"AXEditableAncestor";
NSString* const NSAccessibilityElementBusyAttribute = @"AXElementBusy";
NSString* const NSAccessibilityFocusableAncestorAttribute =
    @"AXFocusableAncestor";
NSString* const NSAccessibilityGrabbedAttribute = @"AXGrabbed";
NSString* const NSAccessibilityHasPopupAttribute = @"AXHasPopup";
NSString* const NSAccessibilityHasPopupValueAttribute = @"AXHasPopupValue";
NSString* const NSAccessibilityHighestEditableAncestorAttribute =
    @"AXHighestEditableAncestor";
NSString* const NSAccessibilityInvalidAttribute = @"AXInvalid";
NSString* const NSAccessibilityIsMultiSelectableAttribute =
    @"AXIsMultiSelectable";
NSString* const NSAccessibilityLoadingProgressAttribute = @"AXLoadingProgress";
NSString* const NSAccessibilityOwnsAttribute = @"AXOwns";
NSString* const
    NSAccessibilityUIElementCountForSearchPredicateParameterizedAttribute =
        @"AXUIElementCountForSearchPredicate";
NSString* const
    NSAccessibilityUIElementsForSearchPredicateParameterizedAttribute =
        @"AXUIElementsForSearchPredicate";
NSString* const NSAccessibilityVisitedAttribute = @"AXVisited";

// Private attributes for text markers.
NSString* const NSAccessibilityStartTextMarkerAttribute = @"AXStartTextMarker";
NSString* const NSAccessibilityEndTextMarkerAttribute = @"AXEndTextMarker";
NSString* const NSAccessibilitySelectedTextMarkerRangeAttribute =
    @"AXSelectedTextMarkerRange";
NSString* const NSAccessibilityTextMarkerIsValidParameterizedAttribute =
    @"AXTextMarkerIsValid";
NSString* const NSAccessibilityIndexForTextMarkerParameterizedAttribute =
    @"AXIndexForTextMarker";
NSString* const NSAccessibilityTextMarkerForIndexParameterizedAttribute =
    @"AXTextMarkerForIndex";
NSString* const NSAccessibilityEndTextMarkerForBoundsParameterizedAttribute =
    @"AXEndTextMarkerForBounds";
NSString* const NSAccessibilityStartTextMarkerForBoundsParameterizedAttribute =
    @"AXStartTextMarkerForBounds";
NSString* const
    NSAccessibilityLineTextMarkerRangeForTextMarkerParameterizedAttribute =
        @"AXLineTextMarkerRangeForTextMarker";
// TODO(nektar): Implement programmatic text operations.
//
// NSString* const NSAccessibilityTextOperationMarkerRanges =
//    @"AXTextOperationMarkerRanges";
NSString* const NSAccessibilityUIElementForTextMarkerParameterizedAttribute =
    @"AXUIElementForTextMarker";
NSString* const
    NSAccessibilityTextMarkerRangeForUIElementParameterizedAttribute =
        @"AXTextMarkerRangeForUIElement";
NSString* const NSAccessibilityLineForTextMarkerParameterizedAttribute =
    @"AXLineForTextMarker";
NSString* const NSAccessibilityTextMarkerRangeForLineParameterizedAttribute =
    @"AXTextMarkerRangeForLine";
NSString* const NSAccessibilityStringForTextMarkerRangeParameterizedAttribute =
    @"AXStringForTextMarkerRange";
NSString* const NSAccessibilityTextMarkerForPositionParameterizedAttribute =
    @"AXTextMarkerForPosition";
NSString* const NSAccessibilityBoundsForTextMarkerRangeParameterizedAttribute =
    @"AXBoundsForTextMarkerRange";
NSString* const
    NSAccessibilityAttributedStringForTextMarkerRangeParameterizedAttribute =
        @"AXAttributedStringForTextMarkerRange";
NSString* const
    NSAccessibilityAttributedStringForTextMarkerRangeWithOptionsParameterizedAttribute =
        @"AXAttributedStringForTextMarkerRangeWithOptions";
NSString* const
    NSAccessibilityTextMarkerRangeForUnorderedTextMarkersParameterizedAttribute =
        @"AXTextMarkerRangeForUnorderedTextMarkers";
NSString* const
    NSAccessibilityNextTextMarkerForTextMarkerParameterizedAttribute =
        @"AXNextTextMarkerForTextMarker";
NSString* const
    NSAccessibilityPreviousTextMarkerForTextMarkerParameterizedAttribute =
        @"AXPreviousTextMarkerForTextMarker";
NSString* const
    NSAccessibilityLeftWordTextMarkerRangeForTextMarkerParameterizedAttribute =
        @"AXLeftWordTextMarkerRangeForTextMarker";
NSString* const
    NSAccessibilityRightWordTextMarkerRangeForTextMarkerParameterizedAttribute =
        @"AXRightWordTextMarkerRangeForTextMarker";
NSString* const
    NSAccessibilityLeftLineTextMarkerRangeForTextMarkerParameterizedAttribute =
        @"AXLeftLineTextMarkerRangeForTextMarker";
NSString* const
    NSAccessibilityRightLineTextMarkerRangeForTextMarkerParameterizedAttribute =
        @"AXRightLineTextMarkerRangeForTextMarker";
NSString* const
    NSAccessibilitySentenceTextMarkerRangeForTextMarkerParameterizedAttribute =
        @"AXSentenceTextMarkerRangeForTextMarker";
NSString* const
    NSAccessibilityParagraphTextMarkerRangeForTextMarkerParameterizedAttribute =
        @"AXParagraphTextMarkerRangeForTextMarker";
NSString* const
    NSAccessibilityNextWordEndTextMarkerForTextMarkerParameterizedAttribute =
        @"AXNextWordEndTextMarkerForTextMarker";
NSString* const
    NSAccessibilityPreviousWordStartTextMarkerForTextMarkerParameterizedAttribute =
        @"AXPreviousWordStartTextMarkerForTextMarker";
NSString* const
    NSAccessibilityNextLineEndTextMarkerForTextMarkerParameterizedAttribute =
        @"AXNextLineEndTextMarkerForTextMarker";
NSString* const
    NSAccessibilityPreviousLineStartTextMarkerForTextMarkerParameterizedAttribute =
        @"AXPreviousLineStartTextMarkerForTextMarker";
NSString* const
    NSAccessibilityNextSentenceEndTextMarkerForTextMarkerParameterizedAttribute =
        @"AXNextSentenceEndTextMarkerForTextMarker";
NSString* const
    NSAccessibilityPreviousSentenceStartTextMarkerForTextMarkerParameterizedAttribute =
        @"AXPreviousSentenceStartTextMarkerForTextMarker";
NSString* const
    NSAccessibilityNextParagraphEndTextMarkerForTextMarkerParameterizedAttribute =
        @"AXNextParagraphEndTextMarkerForTextMarker";
NSString* const
    NSAccessibilityPreviousParagraphStartTextMarkerForTextMarkerParameterizedAttribute =
        @"AXPreviousParagraphStartTextMarkerForTextMarker";
NSString* const
    NSAccessibilityStyleTextMarkerRangeForTextMarkerParameterizedAttribute =
        @"AXStyleTextMarkerRangeForTextMarker";
NSString* const NSAccessibilityLengthForTextMarkerRangeParameterizedAttribute =
    @"AXLengthForTextMarkerRange";

// Private attributes that can be used for testing text markers, e.g. in dump
// tree tests.
NSString* const
    NSAccessibilityTextMarkerDebugDescriptionParameterizedAttribute =
        @"AXTextMarkerDebugDescription";
NSString* const
    NSAccessibilityTextMarkerRangeDebugDescriptionParameterizedAttribute =
        @"AXTextMarkerRangeDebugDescription";
NSString* const
    NSAccessibilityTextMarkerNodeDebugDescriptionParameterizedAttribute =
        @"AXTextMarkerNodeDebugDescription";

// Other private attributes.
NSString* const NSAccessibilitySelectTextWithCriteriaParameterizedAttribute =
    @"AXSelectTextWithCriteria";
NSString* const NSAccessibilityIndexForChildUIElementParameterizedAttribute =
    @"AXIndexForChildUIElement";
NSString* const NSAccessibilityValueAutofillAvailableAttribute =
    @"AXValueAutofillAvailable";
// Not currently supported by Chrome -- information not stored:
// NSString* const NSAccessibilityValueAutofilledAttribute =
// @"AXValueAutofilled"; Not currently supported by Chrome -- mismatch of types
// supported: NSString* const NSAccessibilityValueAutofillTypeAttribute =
// @"AXValueAutofillType";

// Actions.
NSString* const NSAccessibilityScrollToVisibleAction = @"AXScrollToVisible";

// A mapping from an accessibility attribute to its method name.
NSDictionary* attributeToMethodNameMap = nil;

// VoiceOver uses -1 to mean "no limit" for AXResultsLimit.
const int kAXResultsLimitNoLimit = -1;

extern "C" {

// // The following are private accessibility APIs required for cursor navigation
// // and text selection. VoiceOver started relying on them in Mac OS X 10.11.
// #if !defined(MAC_OS_X_VERSION_10_11) || \
//     MAC_OS_X_VERSION_MIN_REQUIRED < MAC_OS_X_VERSION_10_11

CFTypeID AXTextMarkerGetTypeID();

AXTextMarkerRef AXTextMarkerCreate(CFAllocatorRef allocator,
                                   const UInt8* bytes,
                                   CFIndex length);

const UInt8* AXTextMarkerGetBytePtr(AXTextMarkerRef text_marker);

size_t AXTextMarkerGetLength(AXTextMarkerRef text_marker);

CFTypeID AXTextMarkerRangeGetTypeID();

AXTextMarkerRangeRef AXTextMarkerRangeCreate(CFAllocatorRef allocator,
                                             AXTextMarkerRef start_marker,
                                             AXTextMarkerRef end_marker);

AXTextMarkerRef AXTextMarkerRangeCopyStartMarker(
    AXTextMarkerRangeRef text_marker_range);

AXTextMarkerRef AXTextMarkerRangeCopyEndMarker(
    AXTextMarkerRangeRef text_marker_range);

// #endif  // MAC_OS_X_VERSION_10_11

}  // extern "C"

NSString* SysUTF8ToNSString(std::string str) {
  return @(str.data());
}

NSString* SysUTF16ToNSString(std::u16string str) {
  std::wstring_convert<std::codecvt_utf8_utf16<char16_t>,char16_t> convert;
  return @(convert.to_bytes(str).data());
}

// AXTextMarkerCreate is a system function that makes a copy of the data buffer
// given to it.
id CreateTextMarker(BrowserAccessibilityPositionInstance position) {
  SerializedPosition serialized = position->Serialize();
  AXTextMarkerRef cf_text_marker = AXTextMarkerCreate(
      kCFAllocatorDefault, reinterpret_cast<const UInt8*>(&serialized),
      sizeof(SerializedPosition));
  return [static_cast<id>(cf_text_marker) autorelease];
}

id CreateTextMarkerRange(const AXPlatformRange range) {
  SerializedPosition serialized_anchor = range.anchor()->Serialize();
  SerializedPosition serialized_focus = range.focus()->Serialize();
  AXTextMarkerRef start_marker=AXTextMarkerCreate(
      kCFAllocatorDefault, reinterpret_cast<const UInt8*>(&serialized_anchor),
      sizeof(SerializedPosition));
  AXTextMarkerRef end_marker=AXTextMarkerCreate(
      kCFAllocatorDefault, reinterpret_cast<const UInt8*>(&serialized_focus),
      sizeof(SerializedPosition));
  AXTextMarkerRangeRef cf_marker_range =
      AXTextMarkerRangeCreate(kCFAllocatorDefault, start_marker, end_marker);
  return [static_cast<id>(cf_marker_range) autorelease];
}

BrowserAccessibilityPositionInstance CreatePositionFromTextMarker(
    id text_marker) {
  if (!ax::IsAXTextMarker(text_marker))
    return ax::AXNodePosition::CreateNullPosition();

  AXTextMarkerRef cf_text_marker = static_cast<AXTextMarkerRef>(text_marker);
  if (AXTextMarkerGetLength(cf_text_marker) != sizeof(SerializedPosition))
    return ax::AXNodePosition::CreateNullPosition();

  const UInt8* source_buffer = AXTextMarkerGetBytePtr(cf_text_marker);
  if (!source_buffer)
    return ax::AXNodePosition::CreateNullPosition();

  return ax::AXNodePosition::Unserialize(
      *reinterpret_cast<const SerializedPosition*>(source_buffer));
}

AXPlatformRange CreateRangeFromTextMarkerRange(id marker_range) {
  if (!ax::IsAXTextMarkerRange(marker_range)) {
    return AXPlatformRange();
  }

  AXTextMarkerRangeRef cf_marker_range =
      static_cast<AXTextMarkerRangeRef>(marker_range);

  AXTextMarkerRef start_marker=
      AXTextMarkerRangeCopyStartMarker(cf_marker_range);
  AXTextMarkerRef end_marker=
      AXTextMarkerRangeCopyEndMarker(cf_marker_range);
  if (!start_marker || !end_marker)
    return AXPlatformRange();

  BrowserAccessibilityPositionInstance anchor =
      CreatePositionFromTextMarker(static_cast<id>(start_marker));
  BrowserAccessibilityPositionInstance focus =
      CreatePositionFromTextMarker(static_cast<id>(end_marker));
  // |AXPlatformRange| takes ownership of its anchor and focus.
  return AXPlatformRange(std::move(anchor), std::move(focus));
}

BrowserAccessibilityPositionInstance CreateTreePosition(
    const ax::AXPlatformNodeMac& object,
    int offset) {
  return ax::AXNodePosition::CreateTreePosition(
      {}, object.GetData().id, offset);
}

BrowserAccessibilityPositionInstance CreateTextPosition(
    const ax::AXPlatformNodeMac& object,
    int offset,
    ax::TextAffinity affinity) {
  return ax::AXNodePosition::CreateTextPosition(
      {}, object.GetData().id, offset, affinity);
}

AXPlatformRange CreateAXPlatformRange(const ax::AXPlatformNodeMac& start_object,
                                      int start_offset,
                                      ax::TextAffinity start_affinity,
                                      const ax::AXPlatformNodeMac& end_object,
                                      int end_offset,
                                      ax::TextAffinity end_affinity) {
  BrowserAccessibilityPositionInstance anchor = CreateTextPosition(start_object, start_offset, start_affinity);
  BrowserAccessibilityPositionInstance focus =CreateTextPosition(end_object, end_offset, end_affinity);
  // |AXPlatformRange| takes ownership of its anchor and focus.
  return AXPlatformRange(std::move(anchor), std::move(focus));
}

AXPlatformRange GetSelectedRange(ax::AXPlatformNodeMac& owner) {
  // const BrowserAccessibilityManager* manager = owner.manager();
  // if (!manager)
  //   return {};

  // const ax::AXTree::Selection unignored_selection =
  //     manager->ax_tree()->GetUnignoredSelection();
  // int32_t anchor_id = unignored_selection.anchor_object_id;
  // const ax::AXPlatformNodeMac* anchor_object = manager->GetFromID(anchor_id);
  // if (!anchor_object)
  //   return {};

  // int32_t focus_id = unignored_selection.focus_object_id;
  // const ax::AXPlatformNodeMac* focus_object = manager->GetFromID(focus_id);
  // if (!focus_object)
  //   return {};

  // |anchor_offset| and / or |focus_offset| refer to a character offset if
  // |anchor_object| / |focus_object| are text-only objects or native text
  // fields. Otherwise, they should be treated as child indices.
  int anchor_offset = owner.GetData().GetIntAttribute(ax::IntAttribute::kTextSelStart);
  int focus_offset = owner.GetData().GetIntAttribute(ax::IntAttribute::kTextSelEnd);
  if (anchor_offset == -1 || focus_offset == -1)
    return {};

  return CreateAXPlatformRange(owner, anchor_offset, ax::TextAffinity::kDownstream,
                               owner, focus_offset, ax::TextAffinity::kDownstream);
}

void AddMisspelledTextAttributes(const AXPlatformRange& ax_range,
                                 NSMutableAttributedString* attributed_string) {
  int anchor_start_offset = 0;
  [attributed_string beginEditing];
  for (const AXPlatformRange& leaf_text_range : ax_range) {
    FML_DCHECK(!leaf_text_range.IsNull());
    FML_DCHECK(leaf_text_range.anchor()->GetAnchor() ==
              leaf_text_range.focus()->GetAnchor())
        << "An anchor range should only span a single object.";
    const ax::AXNode* anchor = leaf_text_range.focus()->GetAnchor();
    const std::vector<int32_t>& marker_types =
        anchor->data().GetIntListAttribute(ax::IntListAttribute::kMarkerTypes);
    const std::vector<int>& marker_starts =
        anchor->data().GetIntListAttribute(ax::IntListAttribute::kMarkerStarts);
    const std::vector<int>& marker_ends =
        anchor->data().GetIntListAttribute(ax::IntListAttribute::kMarkerEnds);
    for (size_t i = 0; i < marker_types.size(); ++i) {
      if (!(marker_types[i] &
            static_cast<int32_t>(ax::MarkerType::kSpelling))) {
        continue;
      }

      int misspelling_start = anchor_start_offset + marker_starts[i];
      int misspelling_end = anchor_start_offset + marker_ends[i];
      int misspelling_length = misspelling_end - misspelling_start;
      FML_DCHECK(static_cast<unsigned long>(misspelling_end) <=
                [attributed_string length]);
      FML_DCHECK(misspelling_length > 0);
      [attributed_string
          addAttribute:NSAccessibilityMarkedMisspelledTextAttribute
                 value:@YES
                 range:NSMakeRange(misspelling_start, misspelling_length)];
    }

    anchor_start_offset += leaf_text_range.GetText().length();
  }
  [attributed_string endEditing];
}

NSString* GetTextForTextMarkerRange(id marker_range) {
  AXPlatformRange range = CreateRangeFromTextMarkerRange(marker_range);
  if (range.IsNull())
    return nil;
  std::wstring_convert<std::codecvt_utf8_utf16<char16_t>,char16_t> convert;
  return @(convert.to_bytes(range.GetText()).data());
}

NSAttributedString* GetAttributedTextForTextMarkerRange(id marker_range) {
  AXPlatformRange ax_range = CreateRangeFromTextMarkerRange(marker_range);
  if (ax_range.IsNull())
    return nil;
  std::wstring_convert<std::codecvt_utf8_utf16<char16_t>,char16_t> convert;
  NSString* text = @(convert.to_bytes(ax_range.GetText()).data());;
  if ([text length] == 0)
    return nil;

  NSMutableAttributedString* attributed_text =
      [[[NSMutableAttributedString alloc] initWithString:text] autorelease];
  // Currently, we only decorate the attributed string with misspelling
  // information.
  AddMisspelledTextAttributes(ax_range, attributed_text);
  return attributed_text;
}

// Returns an autoreleased copy of the AXNodeData's attribute.
NSString* NSStringForStringAttribute(ax::AXPlatformNodeMac* delegate,
                                     StringAttribute attribute) {
  return @(delegate->GetData().GetStringAttribute(attribute).data());
}

// GetState checks the bitmask used in AXNodeData to check
// if the given state was set on the accessibility object.
bool GetState(ax::AXPlatformNodeMac* delegate, ax::State state) {
  return delegate->GetData().HasState(state);
}

// Given a search key provided to AXUIElementCountForSearchPredicate or
// AXUIElementsForSearchPredicate, return a predicate that can be added
// to OneShotAccessibilityTreeSearch.
// AccessibilityMatchPredicate PredicateForSearchKey(NSString* searchKey) {
//   if ([searchKey isEqualToString:@"AXAnyTypeSearchKey"]) {
//     return [](ax::AXPlatformNodeMac* start, ax::AXPlatformNodeMac* current) {
//       return true;
//     };
//   } else if ([searchKey isEqualToString:@"AXBlockquoteSameLevelSearchKey"]) {
//     // TODO(dmazzoni): implement the "same level" part.
//     return ax::AccessibilityBlockquotePredicate;
//   } else if ([searchKey isEqualToString:@"AXBlockquoteSearchKey"]) {
//     return ax::AccessibilityBlockquotePredicate;
//   } else if ([searchKey isEqualToString:@"AXBoldFontSearchKey"]) {
//     return ax::AccessibilityTextStyleBoldPredicate;
//   } else if ([searchKey isEqualToString:@"AXButtonSearchKey"]) {
//     return ax::AccessibilityButtonPredicate;
//   } else if ([searchKey isEqualToString:@"AXCheckBoxSearchKey"]) {
//     return ax::AccessibilityCheckboxPredicate;
//   } else if ([searchKey isEqualToString:@"AXControlSearchKey"]) {
//     return ax::AccessibilityControlPredicate;
//   } else if ([searchKey isEqualToString:@"AXDifferentTypeSearchKey"]) {
//     return [](ax::AXPlatformNodeMac* start, ax::AXPlatformNodeMac* current) {
//       return current->GetRole() != start->GetRole();
//     };
//   } else if ([searchKey isEqualToString:@"AXFontChangeSearchKey"]) {
//     // TODO(dmazzoni): implement this.
//     return nullptr;
//   } else if ([searchKey isEqualToString:@"AXFontColorChangeSearchKey"]) {
//     // TODO(dmazzoni): implement this.
//     return nullptr;
//   } else if ([searchKey isEqualToString:@"AXFrameSearchKey"]) {
//     return ax::AccessibilityFramePredicate;
//   } else if ([searchKey isEqualToString:@"AXGraphicSearchKey"]) {
//     return ax::AccessibilityGraphicPredicate;
//   } else if ([searchKey isEqualToString:@"AXHeadingLevel1SearchKey"]) {
//     return ax::AccessibilityH1Predicate;
//   } else if ([searchKey isEqualToString:@"AXHeadingLevel2SearchKey"]) {
//     return ax::AccessibilityH2Predicate;
//   } else if ([searchKey isEqualToString:@"AXHeadingLevel3SearchKey"]) {
//     return ax::AccessibilityH3Predicate;
//   } else if ([searchKey isEqualToString:@"AXHeadingLevel4SearchKey"]) {
//     return ax::AccessibilityH4Predicate;
//   } else if ([searchKey isEqualToString:@"AXHeadingLevel5SearchKey"]) {
//     return ax::AccessibilityH5Predicate;
//   } else if ([searchKey isEqualToString:@"AXHeadingLevel6SearchKey"]) {
//     return ax::AccessibilityH6Predicate;
//   } else if ([searchKey isEqualToString:@"AXHeadingSameLevelSearchKey"]) {
//     return ax::AccessibilityHeadingSameLevelPredicate;
//   } else if ([searchKey isEqualToString:@"AXHeadingSearchKey"]) {
//     return ax::AccessibilityHeadingPredicate;
//   } else if ([searchKey isEqualToString:@"AXHighlightedSearchKey"]) {
//     // TODO(dmazzoni): implement this.
//     return nullptr;
//   } else if ([searchKey isEqualToString:@"AXItalicFontSearchKey"]) {
//     return ax::AccessibilityTextStyleItalicPredicate;
//   } else if ([searchKey isEqualToString:@"AXLandmarkSearchKey"]) {
//     return ax::AccessibilityLandmarkPredicate;
//   } else if ([searchKey isEqualToString:@"AXLinkSearchKey"]) {
//     return ax::AccessibilityLinkPredicate;
//   } else if ([searchKey isEqualToString:@"AXListSearchKey"]) {
//     return ax::AccessibilityListPredicate;
//   } else if ([searchKey isEqualToString:@"AXLiveRegionSearchKey"]) {
//     return ax::AccessibilityLiveRegionPredicate;
//   } else if ([searchKey isEqualToString:@"AXMisspelledWordSearchKey"]) {
//     // TODO(dmazzoni): implement this.
//     return nullptr;
//   } else if ([searchKey isEqualToString:@"AXOutlineSearchKey"]) {
//     return ax::AccessibilityTreePredicate;
//   } else if ([searchKey isEqualToString:@"AXPlainTextSearchKey"]) {
//     // TODO(dmazzoni): implement this.
//     return nullptr;
//   } else if ([searchKey isEqualToString:@"AXRadioGroupSearchKey"]) {
//     return ax::AccessibilityRadioGroupPredicate;
//   } else if ([searchKey isEqualToString:@"AXSameTypeSearchKey"]) {
//     return [](ax::AXPlatformNodeMac* start, ax::AXPlatformNodeMac* current) {
//       return current->GetRole() == start->GetRole();
//     };
//   } else if ([searchKey isEqualToString:@"AXStaticTextSearchKey"]) {
//     return [](ax::AXPlatformNodeMac* start, ax::AXPlatformNodeMac* current) {
//       return current->IsText();
//     };
//   } else if ([searchKey isEqualToString:@"AXStyleChangeSearchKey"]) {
//     // TODO(dmazzoni): implement this.
//     return nullptr;
//   } else if ([searchKey isEqualToString:@"AXTableSameLevelSearchKey"]) {
//     // TODO(dmazzoni): implement the "same level" part.
//     return ax::AccessibilityTablePredicate;
//   } else if ([searchKey isEqualToString:@"AXTableSearchKey"]) {
//     return ax::AccessibilityTablePredicate;
//   } else if ([searchKey isEqualToString:@"AXTextFieldSearchKey"]) {
//     return ax::AccessibilityTextfieldPredicate;
//   } else if ([searchKey isEqualToString:@"AXUnderlineSearchKey"]) {
//     return ax::AccessibilityTextStyleUnderlinePredicate;
//   } else if ([searchKey isEqualToString:@"AXUnvisitedLinkSearchKey"]) {
//     return ax::AccessibilityUnvisitedLinkPredicate;
//   } else if ([searchKey isEqualToString:@"AXVisitedLinkSearchKey"]) {
//     return ax::AccessibilityVisitedLinkPredicate;
//   }

//   return nullptr;
// }

// Initialize a OneShotAccessibilityTreeSearch object given the parameters
// passed to AXUIElementCountForSearchPredicate or
// AXUIElementsForSearchPredicate. Return true on success.
// bool InitializeAccessibilityTreeSearch(OneShotAccessibilityTreeSearch* search,
//                                        id parameter) {
//   if (![parameter isKindOfClass:[NSDictionary class]])
//     return false;
//   NSDictionary* dictionary = parameter;

//   id startElementParameter = [dictionary objectForKey:@"AXStartElement"];
//   if ([startElementParameter isKindOfClass:[BrowserAccessibilityCocoa class]]) {
//     BrowserAccessibilityCocoa* startNodeCocoa =
//         (BrowserAccessibilityCocoa*)startElementParameter;
//     search->SetStartNode([startNodeCocoa owner]);
//   }

//   bool immediateDescendantsOnly = false;
//   NSNumber* immediateDescendantsOnlyParameter =
//       [dictionary objectForKey:@"AXImmediateDescendantsOnly"];
//   if ([immediateDescendantsOnlyParameter isKindOfClass:[NSNumber class]])
//     immediateDescendantsOnly = [immediateDescendantsOnlyParameter boolValue];

//   bool onscreenOnly = false;
//   // AXVisibleOnly actually means onscreen objects only -- nothing scrolled off.
//   NSNumber* onscreenOnlyParameter = [dictionary objectForKey:@"AXVisibleOnly"];
//   if ([onscreenOnlyParameter isKindOfClass:[NSNumber class]])
//     onscreenOnly = [onscreenOnlyParameter boolValue];

//   ax::OneShotAccessibilityTreeSearch::Direction direction =
//       ax::OneShotAccessibilityTreeSearch::FORWARDS;
//   NSString* directionParameter = [dictionary objectForKey:@"AXDirection"];
//   if ([directionParameter isKindOfClass:[NSString class]]) {
//     if ([directionParameter isEqualToString:@"AXDirectionNext"])
//       direction = ax::OneShotAccessibilityTreeSearch::FORWARDS;
//     else if ([directionParameter isEqualToString:@"AXDirectionPrevious"])
//       direction = ax::OneShotAccessibilityTreeSearch::BACKWARDS;
//   }

//   int resultsLimit = kAXResultsLimitNoLimit;
//   NSNumber* resultsLimitParameter = [dictionary objectForKey:@"AXResultsLimit"];
//   if ([resultsLimitParameter isKindOfClass:[NSNumber class]])
//     resultsLimit = [resultsLimitParameter intValue];

//   std::string searchText;
//   NSString* searchTextParameter = [dictionary objectForKey:@"AXSearchText"];
//   if ([searchTextParameter isKindOfClass:[NSString class]])
//     searchText = [searchTextParameter UTF8String];

//   search->SetDirection(direction);
//   search->SetImmediateDescendantsOnly(immediateDescendantsOnly);
//   search->SetOnscreenOnly(onscreenOnly);
//   search->SetSearchText(searchText);

//   // Mac uses resultsLimit == -1 for unlimited, that that's
//   // the default for OneShotAccessibilityTreeSearch already.
//   // Only set the results limit if it's nonnegative.
//   if (resultsLimit >= 0)
//     search->SetResultLimit(resultsLimit);

//   id searchKey = [dictionary objectForKey:@"AXSearchKey"];
//   if ([searchKey isKindOfClass:[NSString class]]) {
//     AccessibilityMatchPredicate predicate =
//         PredicateForSearchKey((NSString*)searchKey);
//     if (predicate)
//       search->AddPredicate(predicate);
//   } else if ([searchKey isKindOfClass:[NSArray class]]) {
//     size_t searchKeyCount = static_cast<size_t>([searchKey count]);
//     for (size_t i = 0; i < searchKeyCount; ++i) {
//       id key = [searchKey objectAtIndex:i];
//       if ([key isKindOfClass:[NSString class]]) {
//         AccessibilityMatchPredicate predicate =
//             PredicateForSearchKey((NSString*)key);
//         if (predicate)
//           search->AddPredicate(predicate);
//       }
//     }
//   }

//   return true;
// }

void AppendTextToString(const std::string& extra_text, std::string* string) {
  if (extra_text.empty())
    return;

  if (string->empty()) {
    *string = extra_text;
    return;
  }

  *string += std::string(". ") + extra_text;
}

// bool IsSelectedStateRelevant(ax::AXPlatformNodeMac* item) {
//   if (!item->HasBoolAttribute(ax::BoolAttribute::kSelected))
//     return false;  // Does not have selected state -> not relevant.

//   ax::AXPlatformNodeMac* container = item->PlatformGetSelectionContainer();
//   if (!container)
//     return false;  // No container -> not relevant.

//   if (container->HasState(ax::State::kMultiselectable))
//     return true;  // In a multiselectable -> is relevant.

//   // Single selection AND not selected - > is relevant.
//   // Single selection containers can explicitly set the focused item as not
//   // selected, for example via aria-selectable="false". It's useful for the user
//   // to know that it's not selected in this case.
//   // Only do this for the focused item -- that is the only item where explicitly
//   // setting the item to unselected is relevant, as the focused item is the only
//   // item that could have been selected annyway.
//   // Therefore, if the user navigates to other items by detaching accessibility
//   // focus from the input focus via VO+Shift+F3, those items will not be
//   // redundantly reported as not selected.
//   return item->manager()->GetFocus() == item &&
//          !item->GetBoolAttribute(ax::BoolAttribute::kSelected);
// }

}  // namespace

namespace ax {

AXTextEdit::AXTextEdit() = default;
AXTextEdit::AXTextEdit(std::u16string inserted_text,
                       std::u16string deleted_text,
                       id edit_text_marker)
    : inserted_text(inserted_text),
      deleted_text(deleted_text),
      edit_text_marker(edit_text_marker) {}
AXTextEdit::AXTextEdit(const AXTextEdit& other) = default;
AXTextEdit::~AXTextEdit() = default;

}  // namespace ax

#if defined(MAC_OS_X_VERSION_10_12) && \
    (MAC_OS_X_VERSION_MIN_REQUIRED >= MAC_OS_X_VERSION_10_12)
#warning NSAccessibilityRequiredAttributeChrome \
  should be removed since the deployment target is >= 10.12
#endif

// The following private WebKit accessibility attribute became public in 10.12,
// but it can't be used on all OS because it has availability of 10.12. Instead,
// define a similarly named constant with the "Chrome" suffix, and the same
// string. This is used as the key to a dictionary, so string-comparison will
// work.
extern "C" {
NSString* const NSAccessibilityRequiredAttributeChrome = @"AXRequired";
}

// Not defined in current versions of library, but may be in the future:
#ifndef NSAccessibilityLanguageAttribute
#define NSAccessibilityLanguageAttribute @"AXLanguage"
#endif

bool ax::IsAXTextMarker(id object) {
  if (object == nil)
    return false;

  AXTextMarkerRef cf_text_marker = static_cast<AXTextMarkerRef>(object);
  FML_DCHECK(cf_text_marker);
  return CFGetTypeID(cf_text_marker) == AXTextMarkerGetTypeID();
}

bool ax::IsAXTextMarkerRange(id object) {
  if (object == nil)
    return false;

  AXTextMarkerRangeRef cf_marker_range =
      static_cast<AXTextMarkerRangeRef>(object);
  FML_DCHECK(cf_marker_range);
  return CFGetTypeID(cf_marker_range) == AXTextMarkerRangeGetTypeID();
}

ax::AXNodePosition::AXPositionInstance
ax::AXTextMarkerToPosition(id text_marker) {
  return CreatePositionFromTextMarker(text_marker);
}

ax::AXNodePosition::AXRangeType
ax::AXTextMarkerRangeToRange(id text_marker_range) {
  return CreateRangeFromTextMarkerRange(text_marker_range);
}

id AXTextMarkerFrom(const BrowserAccessibilityCocoa* anchor,
                             int offset,
                             ax::TextAffinity affinity) {
  ax::AXPlatformNodeMac* anchor_node = [anchor owner];
  BrowserAccessibilityPositionInstance position =
      CreateTextPosition(*anchor_node, offset, affinity);
  return CreateTextMarker(std::move(position));
}

id ax::AXTextMarkerRangeFrom(id anchor_textmarker, id focus_textmarker) {
  AXTextMarkerRangeRef cf_marker_range = AXTextMarkerRangeCreate(
      kCFAllocatorDefault, anchor_textmarker, focus_textmarker);
  return [static_cast<id>(cf_marker_range) autorelease];
}

@implementation BrowserAccessibilityCocoa

+ (void)initialize {
  const struct {
    NSString* attribute;
    NSString* methodName;
  } attributeToMethodNameContainer[] = {
      {NSAccessibilityARIAAtomicAttribute, @"ariaAtomic"},
      {NSAccessibilityARIABusyAttribute, @"ariaBusy"},
      {NSAccessibilityARIAColumnCountAttribute, @"ariaColumnCount"},
      {NSAccessibilityARIAColumnIndexAttribute, @"ariaColumnIndex"},
      {NSAccessibilityARIALiveAttribute, @"ariaLive"},
      {NSAccessibilityARIAPosInSetAttribute, @"ariaPosInSet"},
      {NSAccessibilityARIARelevantAttribute, @"ariaRelevant"},
      {NSAccessibilityARIARowCountAttribute, @"ariaRowCount"},
      {NSAccessibilityARIARowIndexAttribute, @"ariaRowIndex"},
      {NSAccessibilityARIASetSizeAttribute, @"ariaSetSize"},
      {NSAccessibilityAccessKeyAttribute, @"accessKey"},
      {NSAccessibilityAutocompleteValueAttribute, @"autocompleteValue"},
      {NSAccessibilityBlockQuoteLevelAttribute, @"blockQuoteLevel"},
      {NSAccessibilityChildrenAttribute, @"children"},
      {NSAccessibilityColumnsAttribute, @"columns"},
      {NSAccessibilityColumnHeaderUIElementsAttribute, @"columnHeaders"},
      {NSAccessibilityColumnIndexRangeAttribute, @"columnIndexRange"},
      {NSAccessibilityContentsAttribute, @"contents"},
      {NSAccessibilityDescriptionAttribute, @"descriptionForAccessibility"},
      {NSAccessibilityDisclosingAttribute, @"disclosing"},
      {NSAccessibilityDisclosedByRowAttribute, @"disclosedByRow"},
      {NSAccessibilityDisclosureLevelAttribute, @"disclosureLevel"},
      {NSAccessibilityDisclosedRowsAttribute, @"disclosedRows"},
      {NSAccessibilityDropEffectsAttribute, @"dropEffects"},
      {NSAccessibilityDOMClassList, @"domClassList"},
      {NSAccessibilityDOMIdentifierAttribute, @"domIdentifier"},
      {NSAccessibilityEditableAncestorAttribute, @"editableAncestor"},
      {NSAccessibilityElementBusyAttribute, @"elementBusy"},
      {NSAccessibilityEnabledAttribute, @"enabled"},
      {NSAccessibilityEndTextMarkerAttribute, @"endTextMarker"},
      {NSAccessibilityExpandedAttribute, @"expanded"},
      {NSAccessibilityFocusableAncestorAttribute, @"focusableAncestor"},
      {NSAccessibilityFocusedAttribute, @"focused"},
      {NSAccessibilityGrabbedAttribute, @"grabbed"},
      {NSAccessibilityHeaderAttribute, @"header"},
      {NSAccessibilityHasPopupAttribute, @"hasPopup"},
      {NSAccessibilityHasPopupValueAttribute, @"hasPopupValue"},
      {NSAccessibilityHelpAttribute, @"help"},
      {NSAccessibilityHighestEditableAncestorAttribute,
       @"highestEditableAncestor"},
      {NSAccessibilityIndexAttribute, @"index"},
      {NSAccessibilityInsertionPointLineNumberAttribute,
       @"insertionPointLineNumber"},
      {NSAccessibilityInvalidAttribute, @"invalid"},
      {NSAccessibilityIsMultiSelectableAttribute, @"isMultiSelectable"},
      {NSAccessibilityLanguageAttribute, @"language"},
      {NSAccessibilityLinkedUIElementsAttribute, @"linkedUIElements"},
      {NSAccessibilityLoadingProgressAttribute, @"loadingProgress"},
      {NSAccessibilityMaxValueAttribute, @"maxValue"},
      {NSAccessibilityMinValueAttribute, @"minValue"},
      {NSAccessibilityNumberOfCharactersAttribute, @"numberOfCharacters"},
      {NSAccessibilityOrientationAttribute, @"orientation"},
      {NSAccessibilityOwnsAttribute, @"owns"},
      {NSAccessibilityParentAttribute, @"parent"},
      {NSAccessibilityPlaceholderValueAttribute, @"placeholderValue"},
      {NSAccessibilityPositionAttribute, @"position"},
      {NSAccessibilityRequiredAttributeChrome, @"required"},
      {NSAccessibilityRoleAttribute, @"role"},
      {NSAccessibilityRoleDescriptionAttribute, @"roleDescription"},
      {NSAccessibilityRowHeaderUIElementsAttribute, @"rowHeaders"},
      {NSAccessibilityRowIndexRangeAttribute, @"rowIndexRange"},
      {NSAccessibilityRowsAttribute, @"rows"},
      // TODO(aboxhall): expose
      // NSAccessibilityServesAsTitleForUIElementsAttribute
      {NSAccessibilityStartTextMarkerAttribute, @"startTextMarker"},
      {NSAccessibilitySelectedAttribute, @"selected"},
      {NSAccessibilitySelectedChildrenAttribute, @"selectedChildren"},
      {NSAccessibilitySelectedTextAttribute, @"selectedText"},
      {NSAccessibilitySelectedTextRangeAttribute, @"selectedTextRange"},
      {NSAccessibilitySelectedTextMarkerRangeAttribute,
       @"selectedTextMarkerRange"},
      {NSAccessibilitySizeAttribute, @"size"},
      {NSAccessibilitySortDirectionAttribute, @"sortDirection"},
      {NSAccessibilitySubroleAttribute, @"subrole"},
      {NSAccessibilityTabsAttribute, @"tabs"},
      {NSAccessibilityTitleAttribute, @"title"},
      {NSAccessibilityTitleUIElementAttribute, @"titleUIElement"},
      {NSAccessibilityTopLevelUIElementAttribute, @"window"},
      {NSAccessibilityURLAttribute, @"url"},
      {NSAccessibilityValueAttribute, @"value"},
      {NSAccessibilityValueAutofillAvailableAttribute,
       @"valueAutofillAvailable"},
      // Not currently supported by Chrome -- information not stored:
      // {NSAccessibilityValueAutofilledAttribute, @"valueAutofilled"},
      // Not currently supported by Chrome -- mismatch of types supported:
      // {NSAccessibilityValueAutofillTypeAttribute, @"valueAutofillType"},
      {NSAccessibilityValueDescriptionAttribute, @"valueDescription"},
      {NSAccessibilityVisibleCharacterRangeAttribute, @"visibleCharacterRange"},
      {NSAccessibilityVisibleCellsAttribute, @"visibleCells"},
      {NSAccessibilityVisibleChildrenAttribute, @"visibleChildren"},
      {NSAccessibilityVisibleColumnsAttribute, @"visibleColumns"},
      {NSAccessibilityVisibleRowsAttribute, @"visibleRows"},
      {NSAccessibilityVisitedAttribute, @"visited"},
      {NSAccessibilityWindowAttribute, @"window"},
      {@"AXLoaded", @"loaded"},
  };

  NSMutableDictionary* dict = [[NSMutableDictionary alloc] init];
  const size_t numAttributes = sizeof(attributeToMethodNameContainer) /
                               sizeof(attributeToMethodNameContainer[0]);
  for (size_t i = 0; i < numAttributes; ++i) {
    [dict setObject:attributeToMethodNameContainer[i].methodName
             forKey:attributeToMethodNameContainer[i].attribute];
  }
  attributeToMethodNameMap = dict;
  dict = nil;
}

- (instancetype)initWithObject:(ax::AXPlatformNodeMac*)accessibility {
  if ((self = [super init]))
    _owner = accessibility;
  return self;
}

- (void)detach {
  if (!_owner)
    return;
  NSAccessibilityPostNotification(
      self, NSAccessibilityUIElementDestroyedNotification);
  _owner = nullptr;
}

- (NSString*)accessKey {
  if (![self instanceActive])
    return nil;
  return NSStringForStringAttribute(_owner,
                                    ax::StringAttribute::kAccessKey);
}

- (NSNumber*)ariaAtomic {
  if (![self instanceActive])
    return nil;
  bool boolValue =
      _owner->GetData().GetBoolAttribute(ax::BoolAttribute::kLiveAtomic);
  return [NSNumber numberWithBool:boolValue];
}

- (NSNumber*)ariaBusy {
  if (![self instanceActive])
    return nil;
  return [NSNumber
      numberWithBool:_owner->GetData().GetBoolAttribute(ax::BoolAttribute::kBusy)];
}

- (NSNumber*)ariaColumnCount {
  // if (![self instanceActive])
  //   return nil;
  // std::optional<int> aria_col_count = _owner->node()->GetTableAriaColCount();
  // if (!aria_col_count)
  //   return nil;
  // return [NSNumber numberWithInt:*aria_col_count];
  return nil;
}

- (NSNumber*)ariaColumnIndex {
  // if (![self instanceActive])
  //   return nil;
  // std::optional<int> ariaColIndex = _owner->node()->GetTableCellAriaColIndex();
  // if (!ariaColIndex)
  //   return nil;
  // return [NSNumber numberWithInt:*ariaColIndex];
  return nil;
}

- (NSString*)ariaLive {
  if (![self instanceActive])
    return nil;
  return NSStringForStringAttribute(_owner,
                                    ax::StringAttribute::kLiveStatus);
}

- (NSNumber*)ariaPosInSet {
  // if (![self instanceActive])
  //   return nil;
  // std::optional<int> posInSet = _owner->node()->GetPosInSet();
  // if (!posInSet)
  //   return nil;
  // return [NSNumber numberWithInt:*posInSet];
  return nil;
}

- (NSString*)ariaRelevant {
  if (![self instanceActive])
    return nil;
  return NSStringForStringAttribute(_owner,
                                    ax::StringAttribute::kLiveRelevant);
}

- (NSNumber*)ariaRowCount {
  // if (![self instanceActive])
  //   return nil;
  // std::optional<int> ariaRowCount = _owner->node()->GetTableAriaRowCount();
  // if (!ariaRowCount)
  //   return nil;
  // return [NSNumber numberWithInt:*ariaRowCount];
  return nil;
}

- (NSNumber*)ariaRowIndex {
  // if (![self instanceActive])
  //   return nil;
  // std::optional<int> ariaRowIndex = _owner->node()->GetTableCellAriaRowIndex();
  // if (!ariaRowIndex)
  //   return nil;
  // return [NSNumber numberWithInt:*ariaRowIndex];
  return nil;
}

- (NSNumber*)ariaSetSize {
  // if (![self instanceActive])
  //   return nil;
  // std::optional<int> setSize = _owner->node()->GetSetSize();
  // if (!setSize)
  //   return nil;
  // return [NSNumber numberWithInt:*setSize];
  return nil;
}

- (NSString*)autocompleteValue {
  if (![self instanceActive])
    return nil;
  return NSStringForStringAttribute(_owner,
                                    ax::StringAttribute::kAutoComplete);
}

- (id)blockQuoteLevel {
  // if (![self instanceActive])
  //   return nil;
  // // TODO(accessibility) This is for the number of ancestors that are a
  // // <blockquote>, including self, useful for tracking replies to replies etc.
  // // in an email.
  // int level = 0;
  // ax::AXPlatformNodeMac* ancestor = _owner;
  // while (ancestor) {
  //   if (ancestor->GetRole() == ax::Role::kBlockquote)
  //     ++level;
  //   ancestor = ancestor->PlatformGetParent();
  // }
  // return [NSNumber numberWithInt:level];
  return nil;
}

// Returns an array of BrowserAccessibilityCocoa objects, representing the
// accessibility children of this object.
- (NSArray*)children {
  if (![self instanceActive])
    return nil;
  if (!_children) {
    uint32_t childCount = _owner->PlatformChildCount();
    _children.reset([[NSMutableArray alloc] initWithCapacity:childCount]);
    for (auto it = _owner->PlatformChildrenBegin();
         it != _owner->PlatformChildrenEnd(); ++it) {
      BrowserAccessibilityCocoa* child = ToBrowserAccessibilityCocoa(it.get());
      if ([child isIgnored])
        [_children addObjectsFromArray:[child children]];
      else
        [_children addObject:child];
    }

    // Also, add indirect children (if any).
    const std::vector<int32_t>& indirectChildIds = _owner->GetIntListAttribute(
        ax::IntListAttribute::kIndirectChildIds);
    for (uint32_t i = 0; i < indirectChildIds.size(); ++i) {
      int32_t child_id = indirectChildIds[i];
      ax::AXPlatformNodeMac* child = _owner->manager()->GetFromID(child_id);

      // This only became necessary as a result of crbug.com/93095. It should be
      // a DCHECK in the future.
      if (child) {
        BrowserAccessibilityCocoa* child_cocoa =
            ToBrowserAccessibilityCocoa(child);
        [_children addObject:child_cocoa];
      }
    }
  }
  return _children;
}

- (void)childrenChanged {
  if (![self instanceActive])
    return;
  if (![self isIgnored]) {
    _children.reset();
  } else {
    auto* parent = _owner->PlatformGetParent();
    if (parent)
      [ToBrowserAccessibilityCocoa(parent) childrenChanged];
  }
}

- (NSArray*)columnHeaders {
  if (![self instanceActive])
    return nil;

  bool is_cell_or_table_header = ax::IsCellOrTableHeader(_owner->GetRole());
  bool is_table_like = ax::IsTableLike(_owner->GetRole());
  if (!is_table_like && !is_cell_or_table_header)
    return nil;
  ax::AXPlatformNodeMac* table = [self containingTable];
  if (!table)
    return nil;

  NSMutableArray* ret = [[[NSMutableArray alloc] init] autorelease];
  if (is_table_like) {
    // If this is a table, return all column headers.
    for (int32_t id : table->GetColHeaderNodeIds()) {
      ax::AXPlatformNodeMac* cell = _owner->manager()->GetFromID(id);
      if (cell)
        [ret addObject:ToBrowserAccessibilityCocoa(cell)];
    }
  } else {
    // Otherwise this is a cell, return the column headers for this cell.
    std::optional<int> column = _owner->GetTableCellColIndex();
    if (!column)
      return nil;

    std::vector<int32_t> colHeaderIds = table->GetColHeaderNodeIds(*column);
    for (int32_t id : colHeaderIds) {
      ax::AXPlatformNodeMac* cell = _owner->manager()->GetFromID(id);
      if (cell)
        [ret addObject:ToBrowserAccessibilityCocoa(cell)];
    }
  }

  return [ret count] ? ret : nil;
}

- (NSValue*)columnIndexRange {
  if (![self instanceActive])
    return nil;

  std::optional<int> column = _owner->node()->GetTableCellColIndex();
  std::optional<int> colspan = _owner->node()->GetTableCellColSpan();
  if (column && colspan)
    return [NSValue valueWithRange:NSMakeRange(*column, *colspan)];
  return nil;
}

- (NSArray*)columns {
  if (![self instanceActive])
    return nil;
  NSMutableArray* ret = [[[NSMutableArray alloc] init] autorelease];
  for (BrowserAccessibilityCocoa* child in [self children]) {
    if ([[child role] isEqualToString:NSAccessibilityColumnRole])
      [ret addObject:child];
  }
  return ret;
}

- (ax::AXPlatformNodeMac*)containingTable {
  ax::AXPlatformNodeMac* table = _owner;
  while (table && !ax::IsTableLike(table->GetRole())) {
    table = table->PlatformGetParent();
  }
  return table;
}

- (NSString*)descriptionForAccessibility {
  if (![self instanceActive])
    return nil;

  // Mac OS X wants static text exposed in AXValue.
  if (ax::IsNameExposedInAXValueForRole([self internalRole]))
    return @"";

  // If we're exposing the title in TitleUIElement, don't also redundantly
  // expose it in AXDescription.
  if ([self shouldExposeTitleUIElement])
    return @"";

  ax::NameFrom nameFrom = static_cast<ax::NameFrom>(
      _owner->GetIntAttribute(ax::IntAttribute::kNameFrom));
  std::string name = _owner->GetName();

  auto status = _owner->GetData().GetImageAnnotationStatus();
  switch (status) {
    case ax::ImageAnnotationStatus::kEligibleForAnnotation:
    case ax::ImageAnnotationStatus::kAnnotationPending:
    case ax::ImageAnnotationStatus::kAnnotationEmpty:
    case ax::ImageAnnotationStatus::kAnnotationAdult:
    case ax::ImageAnnotationStatus::kAnnotationProcessFailed: {
      std::u16string status_string =
          _owner->GetLocalizedStringForImageAnnotationStatus(status);
      std::wstring_convert<std::codecvt_utf8_utf16<char16_t>,char16_t> convert;
      AppendTextToString(convert.to_bytes(status_string), &name);
      break;
    }

    case ax::ImageAnnotationStatus::kAnnotationSucceeded:
      AppendTextToString(_owner->GetStringAttribute(
                             ax::StringAttribute::kImageAnnotation),
                         &name);
      break;

    case ax::ImageAnnotationStatus::kNone:
    case ax::ImageAnnotationStatus::kWillNotAnnotateDueToScheme:
    case ax::ImageAnnotationStatus::kIneligibleForAnnotation:
    case ax::ImageAnnotationStatus::kSilentlyEligibleForAnnotation:
      break;
  }

  if (!name.empty()) {
    // On Mac OS X, the accessible name of an object is exposed as its
    // title if it comes from visible text, and as its description
    // otherwise, but never both.

    // Group, radiogroup etc.
    if ([self shouldExposeNameInDescription]) {
      return @(name.data());
    } else if (nameFrom == ax::NameFrom::kCaption ||
               nameFrom == ax::NameFrom::kContents ||
               nameFrom == ax::NameFrom::kRelatedElement ||
               nameFrom == ax::NameFrom::kValue) {
      return @"";
    } else {
      return @(name.data());
    }
  }

  // Given an image where there's no other title, return the base part
  // of the filename as the description.
  if ([[self role] isEqualToString:NSAccessibilityImageRole]) {
    if ([self titleUIElement])
      return @"";

    std::string url;
    if (_owner->GetStringAttribute(ax::StringAttribute::kUrl, &url)) {
      // Given a url like http://foo.com/bar/baz.png, just return the
      // base name, e.g., "baz.png".
      size_t leftIndex = url.rfind('/');
      std::string basename =
          leftIndex != std::string::npos ? url.substr(leftIndex) : url;
      return @(basename.data());
    }
  }

  // If it's focusable but didn't have any other name or value, compute a name
  // from its descendants. Note that this is a workaround because VoiceOver
  // does not always present focus changes if the new focus lacks a name.
  std::u16string value = _owner->GetValue();
  if (_owner->HasState(ax::State::kFocusable) &&
      !ax::IsControl(_owner->GetRole()) && value.empty() &&
      [self internalRole] != ax::Role::kDateTime &&
      [self internalRole] != ax::Role::kWebArea &&
      [self internalRole] != ax::Role::kRootWebArea) {
    return @(
        _owner->ComputeAccessibleNameFromDescendants().data());
  }

  return @"";
}

- (NSNumber*)disclosing {
  if (![self instanceActive])
    return nil;
  if ([self internalRole] == ax::Role::kTreeItem) {
    return
        [NSNumber numberWithBool:GetState(_owner, ax::State::kExpanded)];
  } else {
    return nil;
  }
}

- (id)disclosedByRow {
  if (![self instanceActive])
    return nil;

  // The row that contains this row.
  // It should be the same as the first parent that is a treeitem.
  return nil;
}

- (NSNumber*)disclosureLevel {
  if (![self instanceActive])
    return nil;
  ax::Role role = [self internalRole];
  if (role == ax::Role::kRow || role == ax::Role::kTreeItem) {
    int level =
        _owner->GetIntAttribute(ax::IntAttribute::kHierarchicalLevel);
    // Mac disclosureLevel is 0-based, but web levels are 1-based.
    if (level > 0)
      level--;
    return [NSNumber numberWithInt:level];
  } else {
    return nil;
  }
}

- (id)disclosedRows {
  if (![self instanceActive])
    return nil;

  // The rows that are considered inside this row.
  return nil;
}

- (NSString*)dropEffects {
  if (![self instanceActive])
    return nil;

  std::string dropEffects;
  if (_owner->GetHtmlAttribute("aria-dropeffect", &dropEffects))
    return @(dropEffects.data());

  return nil;
}

- (NSArray*)domClassList {
  return nil
}

- (NSString*)domIdentifier {
  if (![self instanceActive])
    return nil;

  std::string id;
  if (_owner->GetHtmlAttribute("id", &id))
    return @(id.data());

  return @"";
}

- (id)editableAncestor {
  if (![self instanceActive])
    return nil;

  BrowserAccessibilityCocoa* editableRoot = self;
  while (![editableRoot owner]->GetBoolAttribute(
      ax::BoolAttribute::kEditableRoot)) {
    BrowserAccessibilityCocoa* parent = [editableRoot parent];
    if (!parent || ![parent isKindOfClass:[self class]] ||
        ![parent instanceActive]) {
      return nil;
    }
    editableRoot = parent;
  }
  return editableRoot;
}

- (NSNumber*)elementBusy {
  if (![self instanceActive])
    return nil;
  return [NSNumber numberWithBool:_owner->GetData().GetBoolAttribute(
                                      ax::BoolAttribute::kBusy)];
}

- (NSNumber*)enabled {
  if (![self instanceActive])
    return nil;
  return [NSNumber numberWithBool:_owner->GetData().GetRestriction() !=
                                  ax::Restriction::kDisabled];
}

// Returns a text marker that points to the last character in the document that
// can be selected with VoiceOver.
- (id)endTextMarker {
  const ax::AXPlatformNodeMac* root = _owner->manager()->GetRoot();
  if (!root)
    return nil;

  BrowserAccessibilityPositionInstance position = root->CreatePositionAt(0);
  return CreateTextMarker(position->CreatePositionAtEndOfAnchor());
}

- (NSNumber*)expanded {
  if (![self instanceActive])
    return nil;
  return
      [NSNumber numberWithBool:GetState(_owner, ax::State::kExpanded)];
}

- (id)focusableAncestor {
  if (![self instanceActive])
    return nil;

  BrowserAccessibilityCocoa* focusableRoot = self;
  while (![focusableRoot owner]->HasState(ax::State::kFocusable)) {
    BrowserAccessibilityCocoa* parent = [focusableRoot parent];
    if (!parent || ![parent isKindOfClass:[self class]] ||
        ![parent instanceActive]) {
      return nil;
    }
    focusableRoot = parent;
  }
  return focusableRoot;
}

- (NSNumber*)focused {
  if (![self instanceActive])
    return nil;
  BrowserAccessibilityManager* manager = _owner->manager();
  NSNumber* ret = [NSNumber numberWithBool:manager->GetFocus() == _owner];
  return ret;
}

- (NSNumber*)grabbed {
  if (![self instanceActive])
    return nil;
  std::string grabbed;
  if (_owner->GetHtmlAttribute("aria-grabbed", &grabbed) && grabbed == "true")
    return [NSNumber numberWithBool:YES];

  return [NSNumber numberWithBool:NO];
}

- (NSNumber*)hasPopup {
  if (![self instanceActive])
    return nil;
  return @(_owner->HasIntAttribute(ax::IntAttribute::kHasPopup));
}

- (NSString*)hasPopupValue {
  if (![self instanceActive])
    return nil;
  int hasPopup = _owner->GetIntAttribute(ax::IntAttribute::kHasPopup);
  switch (static_cast<ax::HasPopup>(hasPopup)) {
    case ax::HasPopup::kFalse:
      return @"false";
    case ax::HasPopup::kTrue:
      return @"true";
    case ax::HasPopup::kMenu:
      return @"menu";
    case ax::HasPopup::kListbox:
      return @"listbox";
    case ax::HasPopup::kTree:
      return @"tree";
    case ax::HasPopup::kGrid:
      return @"grid";
    case ax::HasPopup::kDialog:
      return @"dialog";
  }
}

- (id)header {
  if (![self instanceActive])
    return nil;
  int headerElementId = -1;
  if (ax::IsTableLike(_owner->GetRole())) {
    // The table header container is always the last child of the table,
    // if it exists. The table header container is a special node in the
    // accessibility tree only used on macOS. It has all of the table
    // headers as its children, even though those cells are also children
    // of rows in the table. Internally this is implemented using
    // AXTableInfo and indirect_child_ids.
    uint32_t childCount = _owner->PlatformChildCount();
    if (childCount > 0) {
      ax::AXPlatformNodeMac* tableHeader = _owner->PlatformGetLastChild();
      if (tableHeader->GetRole() == ax::Role::kTableHeaderContainer)
        return ToBrowserAccessibilityCocoa(tableHeader);
    }
  } else if ([self internalRole] == ax::Role::kColumn) {
    _owner->GetIntAttribute(ax::IntAttribute::kTableColumnHeaderId,
                            &headerElementId);
  } else if ([self internalRole] == ax::Role::kRow) {
    _owner->GetIntAttribute(ax::IntAttribute::kTableRowHeaderId,
                            &headerElementId);
  }

  if (headerElementId > 0) {
    ax::AXPlatformNodeMac* headerObject =
        _owner->manager()->GetFromID(headerElementId);
    if (headerObject)
      return ToBrowserAccessibilityCocoa(headerObject);
  }
  return nil;
}

- (NSString*)help {
  if (![self instanceActive])
    return nil;
  return NSStringForStringAttribute(_owner,
                                    ax::StringAttribute::kDescription);
}

- (id)highestEditableAncestor {
  if (![self instanceActive])
    return nil;

  BrowserAccessibilityCocoa* highestEditableAncestor = [self editableAncestor];
  while (highestEditableAncestor) {
    BrowserAccessibilityCocoa* ancestorParent =
        [highestEditableAncestor parent];
    if (!ancestorParent || ![ancestorParent isKindOfClass:[self class]]) {
      break;
    }
    BrowserAccessibilityCocoa* higherAncestor =
        [ancestorParent editableAncestor];
    if (!higherAncestor)
      break;
    highestEditableAncestor = higherAncestor;
  }
  return highestEditableAncestor;
}

- (NSNumber*)index {
  if (![self instanceActive])
    return nil;
  if ([self internalRole] == ax::Role::kColumn) {
    FML_DCHECK(_owner->node());
    std::optional<int> col_index = *_owner->node()->GetTableColColIndex();
    if (col_index)
      return @(*col_index);
  } else if ([self internalRole] == ax::Role::kRow) {
    FML_DCHECK(_owner->node());
    std::optional<int> row_index = _owner->node()->GetTableRowRowIndex();
    if (row_index)
      return @(*row_index);
  }

  return nil;
}

- (NSNumber*)insertionPointLineNumber {
  if (![self instanceActive])
    return nil;
  if (!_owner->HasVisibleCaretOrSelection())
    return nil;

  const AXPlatformRange range = GetSelectedRange(*_owner);
  // If the selection is not collapsed, then there is no visible caret.
  if (!range.IsCollapsed())
    return nil;

  const BrowserAccessibilityPositionInstance caretPosition =
      range.focus()->LowestCommonAncestor(*_owner->CreatePositionAt(0));
  FML_DCHECK(!caretPosition->IsNullPosition())
      << "Calling HasVisibleCaretOrSelection() should have ensured that there "
         "is a valid selection focus inside the current object.";
  const std::vector<int> lineBreaks = _owner->GetLineStartOffsets();
  auto iterator =
      std::upper_bound(lineBreaks.begin(), lineBreaks.end(),
                       caretPosition->AsTextPosition()->text_offset());
  return @(std::distance(lineBreaks.begin(), iterator));
}

// Returns whether or not this node should be ignored in the
// accessibility tree.
- (BOOL)isIgnored {
  if (![self instanceActive])
    return YES;
  return [[self role] isEqualToString:NSAccessibilityUnknownRole] ||
         _owner->HasState(ax::State::kInvisible);
}

- (NSString*)invalid {
  if (![self instanceActive])
    return nil;
  int invalidState;
  if (!_owner->GetIntAttribute(ax::IntAttribute::kInvalidState,
                               &invalidState))
    return @"false";

  switch (static_cast<ax::InvalidState>(invalidState)) {
    case ax::InvalidState::kFalse:
      return @"false";
    case ax::InvalidState::kTrue:
      return @"true";
    case ax::InvalidState::kOther: {
      std::string ariaInvalidValue;
      if (_owner->GetStringAttribute(
              ax::StringAttribute::kAriaInvalidValue, &ariaInvalidValue))
        return @(ariaInvalidValue.data());
      // Return @"true" since we cannot be more specific about the value.
      return @"true";
    }
    default:
      FML_DCHECK(false);
  }

  return @"false";
}

- (NSNumber*)isMultiSelectable {
  if (![self instanceActive])
    return nil;
  return [NSNumber
      numberWithBool:GetState(_owner, ax::State::kMultiselectable)];
}

- (NSString*)placeholderValue {
  if (![self instanceActive])
    return nil;
  ax::NameFrom nameFrom = static_cast<ax::NameFrom>(
      _owner->GetIntAttribute(ax::IntAttribute::kNameFrom));
  if (nameFrom == ax::NameFrom::kPlaceholder) {
    return @(_owner->GetName().data());
  }

  return NSStringForStringAttribute(_owner,
                                    ax::StringAttribute::kPlaceholder);
}

- (NSString*)language {
  if (![self instanceActive])
    return nil;
  ax::AXNode* node = _owner->node();
  FML_DCHECK(node);
  return @(node->GetLanguage().data());
}

// private
- (void)addLinkedUIElementsFromAttribute:(ax::IntListAttribute)attribute
                                   addTo:(NSMutableArray*)outArray {
  const std::vector<int32_t>& attributeValues =
      _owner->GetIntListAttribute(attribute);
  for (size_t i = 0; i < attributeValues.size(); ++i) {
    ax::AXPlatformNodeMac* element =
        _owner->manager()->GetFromID(attributeValues[i]);
    if (element)
      [outArray addObject:ToBrowserAccessibilityCocoa(element)];
  }
}

// private
- (NSArray*)linkedUIElements {
  NSMutableArray* ret = [[[NSMutableArray alloc] init] autorelease];
  [self
      addLinkedUIElementsFromAttribute:ax::IntListAttribute::kControlsIds
                                 addTo:ret];
  [self addLinkedUIElementsFromAttribute:ax::IntListAttribute::kFlowtoIds
                                   addTo:ret];

  int target_id;
  if (_owner->GetIntAttribute(ax::IntAttribute::kInPageLinkTargetId,
                              &target_id)) {
    ax::AXPlatformNodeMac* target =
        _owner->manager()->GetFromID(static_cast<int32_t>(target_id));
    if (target)
      [ret addObject:ToBrowserAccessibilityCocoa(target)];
  }

  [self addLinkedUIElementsFromAttribute:ax::IntListAttribute::
                                             kRadioGroupIds
                                   addTo:ret];
  return ret;
}

- (NSNumber*)loaded {
  if (![self instanceActive])
    return nil;
  return [NSNumber numberWithBool:YES];
}

- (NSNumber*)loadingProgress {
  if (![self instanceActive])
    return nil;
  BrowserAccessibilityManager* manager = _owner->manager();
  float floatValue = manager->GetTreeData().loading_progress;
  return [NSNumber numberWithFloat:floatValue];
}

- (NSNumber*)maxValue {
  if (![self instanceActive])
    return nil;
  float floatValue =
      _owner->GetFloatAttribute(ax::FloatAttribute::kMaxValueForRange);
  return [NSNumber numberWithFloat:floatValue];
}

- (NSNumber*)minValue {
  if (![self instanceActive])
    return nil;
  float floatValue =
      _owner->GetFloatAttribute(ax::FloatAttribute::kMinValueForRange);
  return [NSNumber numberWithFloat:floatValue];
}

- (NSString*)orientation {
  if (![self instanceActive])
    return nil;
  if (GetState(_owner, ax::State::kVertical))
    return NSAccessibilityVerticalOrientationValue;
  else if (GetState(_owner, ax::State::kHorizontal))
    return NSAccessibilityHorizontalOrientationValue;

  return @"";
}

- (id)owns {
  if (![self instanceActive])
    return nil;

  //
  // If the active descendant points to an element in a container with
  // selectable children, add the "owns" relationship to point to that
  // container. That's the only way activeDescendant is actually
  // supported with VoiceOver.
  //

  int activeDescendantId;
  if (!_owner->GetIntAttribute(ax::IntAttribute::kActivedescendantId,
                               &activeDescendantId))
    return nil;

  BrowserAccessibilityManager* manager = _owner->manager();
  ax::AXPlatformNodeMac* activeDescendant =
      manager->GetFromID(activeDescendantId);
  if (!activeDescendant)
    return nil;

  ax::AXPlatformNodeMac* container = activeDescendant->PlatformGetParent();
  while (container &&
         !ax::IsContainerWithSelectableChildren(container->GetRole()))
    container = container->PlatformGetParent();
  if (!container)
    return nil;

  NSMutableArray* ret = [[[NSMutableArray alloc] init] autorelease];
  [ret addObject:ToBrowserAccessibilityCocoa(container)];
  return ret;
}

- (NSNumber*)numberOfCharacters {
  if (![self instanceActive])
    return nil;
  std::u16string value = _owner->GetValue();
  return [NSNumber numberWithUnsignedInt:value.size()];
}

// The origin of this accessibility object in the page's document.
// This is relative to webkit's top-left origin, not Cocoa's
// bottom-left origin.
- (NSPoint)origin {
  if (![self instanceActive])
    return NSMakePoint(0, 0);
  gfx::Rect bounds = _owner->GetClippedRootFrameBoundsRect();
  return NSMakePoint(bounds.x(), bounds.y());
}

- (id)parent {
  if (![self instanceActive])
    return nil;
  // A nil parent means we're the root.
  if (_owner->PlatformGetParent()) {
    return NSAccessibilityUnignoredAncestor(
        ToBrowserAccessibilityCocoa(_owner->PlatformGetParent()));
  } else {
    // Hook back up to RenderWidgetHostViewCocoa.
    BrowserAccessibilityManagerMac* manager =
        _owner->manager()->GetRootManager()->ToBrowserAccessibilityManagerMac();
    if (manager)
      return manager->GetParentView();
    return nil;
  }
}

- (NSValue*)position {
  if (![self instanceActive])
    return nil;
  NSPoint origin = [self origin];
  NSSize size = [[self size] sizeValue];
  NSPoint pointInScreen =
      [self rectInScreen:SkRect::MakeXYWH(origin.x, origin.y, size.width, size.height)].origin;
  return [NSValue valueWithPoint:pointInScreen];
}

- (NSNumber*)required {
  if (![self instanceActive])
    return nil;
  return
      [NSNumber numberWithBool:GetState(_owner, ax::State::kRequired)];
}

// Returns an enum indicating the role from owner_.
// internal
- (ax::Role)internalRole {
  if ([self instanceActive])
    return static_cast<ax::Role>(_owner->GetRole());
  return ax::Role::kNone;
}

- (BOOL)shouldExposeNameInDescription {
  // Image annotations are not visible text, so they should be exposed
  // as a description and not a title.
  switch (_owner->GetData().GetImageAnnotationStatus()) {
    case ax::ImageAnnotationStatus::kEligibleForAnnotation:
    case ax::ImageAnnotationStatus::kAnnotationPending:
    case ax::ImageAnnotationStatus::kAnnotationEmpty:
    case ax::ImageAnnotationStatus::kAnnotationAdult:
    case ax::ImageAnnotationStatus::kAnnotationProcessFailed:
    case ax::ImageAnnotationStatus::kAnnotationSucceeded:
      return true;

    case ax::ImageAnnotationStatus::kNone:
    case ax::ImageAnnotationStatus::kWillNotAnnotateDueToScheme:
    case ax::ImageAnnotationStatus::kIneligibleForAnnotation:
    case ax::ImageAnnotationStatus::kSilentlyEligibleForAnnotation:
      break;
  }

  // VoiceOver computes the wrong description for a link.
  if (ax::IsLink(_owner->GetRole()))
    return true;

  // VoiceOver will not read the label of these roles unless it is
  // exposed in the description instead of the title.
  switch (_owner->GetRole()) {
    case ax::Role::kGenericContainer:
    case ax::Role::kGroup:
    case ax::Role::kRadioGroup:
      return true;
    default:
      return false;
  }
}

// Returns true if this object should expose its accessible name using
// AXTitleUIElement rather than AXTitle or AXDescription. We only do
// this if it's a control, if there's a single label, and the label has
// nonempty text.
// internal
- (BOOL)shouldExposeTitleUIElement {
  // VoiceOver ignores TitleUIElement if the element isn't a control.
  if (!ax::IsControl(_owner->GetRole()))
    return false;

  ax::NameFrom nameFrom = static_cast<ax::NameFrom>(
      _owner->GetIntAttribute(ax::IntAttribute::kNameFrom));
  if (nameFrom != ax::NameFrom::kCaption &&
      nameFrom != ax::NameFrom::kRelatedElement)
    return false;

  std::vector<int32_t> labelledby_ids =
      _owner->GetIntListAttribute(ax::IntListAttribute::kLabelledbyIds);
  if (labelledby_ids.size() != 1)
    return false;

  ax::AXPlatformNodeMac* label = _owner->manager()->GetFromID(labelledby_ids[0]);
  if (!label)
    return false;

  std::string labelName = label->GetName();
  return !labelName.empty();
}

// internal
// - (ax::BrowserAccessibilityDelegate*)delegate {
//   return [self instanceActive] ? _owner->manager()->delegate() : nil;
// }

- (ax::AXPlatformNodeMac*)owner {
  return _owner;
}

// Assumes that there is at most one insertion, deletion or replacement at once.
// TODO(nektar): Merge this method with
// |BrowserAccessibilityAndroid::CommonEndLengths|.
- (ax::AXTextEdit)computeTextEdit {
  // Starting from macOS 10.11, if the user has edited some text we need to
  // dispatch the actual text that changed on the value changed notification.
  // We run this code on all macOS versions to get the highest test coverage.
  std::u16string oldValue = _oldValue;
  std::u16string newValue = _owner->GetValue();
  _oldValue = newValue;
  if (oldValue.empty() && newValue.empty())
    return ax::AXTextEdit();

  size_t i;
  size_t j;
  // Sometimes Blink doesn't use the same UTF16 characters to represent
  // whitespace.
  for (i = 0;
       i < oldValue.length() && i < newValue.length() &&
       (oldValue[i] == newValue[i] || (iswspace(oldValue[i]) &&
                                       iswspace(newValue[i])));
       ++i) {
  }
  for (j = 0;
       (i + j) < oldValue.length() && (i + j) < newValue.length() &&
       (oldValue[oldValue.length() - j - 1] ==
            newValue[newValue.length() - j - 1] ||
        (iswspace(oldValue[oldValue.length() - j - 1]) &&
         iswspace(newValue[newValue.length() - j - 1])));
       ++j) {
  }
  FML_DCHECK(i + j <= oldValue.length());
  FML_DCHECK(i + j <= newValue.length());

  std::u16string deletedText = oldValue.substr(i, oldValue.length() - i - j);
  std::u16string insertedText = newValue.substr(i, newValue.length() - i - j);

  // Heuristic for editable combobox. If more than 1 character is inserted or
  // deleted, and the caret is at the end of the field, assume the entire text
  // field changed.
  // TODO(nektar) Remove this once editing intents are implemented,
  // and the actual inserted and deleted text is passed over from Blink.
  if ([self internalRole] == ax::Role::kTextFieldWithComboBox &&
      (deletedText.length() > 1 || insertedText.length() > 1)) {
    int sel_start, sel_end;
    _owner->GetIntAttribute(ax::IntAttribute::kTextSelStart, &sel_start);
    _owner->GetIntAttribute(ax::IntAttribute::kTextSelEnd, &sel_end);
    if (size_t{sel_start} == newValue.length() &&
        size_t{sel_end} == newValue.length()) {
      // Don't include oldValue as it would be announced -- very confusing.
      return ax::AXTextEdit(newValue, std::u16string(), nil);
    }
  }
  return ax::AXTextEdit(insertedText, deletedText,
                             CreateTextMarker(_owner->CreatePositionAt(i)));
}

- (BOOL)instanceActive {
  return _owner != nullptr;
}

// internal
- (NSRect)rectInScreen:(SkRect)rect {
  if (![self instanceActive])
    return NSZeroRect;

  SkRect view_bounds = _owner->GetBoundsRect(
      ax::AXCoordinateSystem::kScreenDIPs, ax::AXClippingBehavior::kClipped);
  rect.offsetTo(rect.x() + view_bounds.x(), rect.y() + view_bounds.y());
  return gfx::ScreenRectToNSRect(rect);
}

// Returns a string indicating the NSAccessibility role of this object.
- (NSString*)role {
  if (![self instanceActive]) {
    TRACE_EVENT0("accessibility", "BrowserAccessibilityCocoa::role nil");
    return nil;
  }

  NSString* cocoa_role = nil;
  ax::Role role = [self internalRole];
  if (role == ax::Role::kCanvas &&
      _owner->GetBoolAttribute(ax::BoolAttribute::kCanvasHasFallback)) {
    cocoa_role = NSAccessibilityGroupRole;
  } else if ((_owner->IsPlainTextField() &&
              _owner->HasState(ax::State::kMultiline)) ||
             _owner->IsRichTextField()) {
    cocoa_role = NSAccessibilityTextAreaRole;
  } else if (role == ax::Role::kImage &&
             _owner->HasExplicitlyEmptyName()) {
    cocoa_role = NSAccessibilityUnknownRole;
  } else if (_owner->IsWebAreaForPresentationalIframe()) {
    cocoa_role = NSAccessibilityGroupRole;
  } else {
    cocoa_role = [AXPlatformNodeCocoa nativeRoleFromAXRole:role];
  }
  return cocoa_role;
}

// Returns a string indicating the role description of this object.
- (NSString*)roleDescription {
  if (![self instanceActive])
    return nil;

  if (_owner->GetData().GetImageAnnotationStatus() ==
          ax::ImageAnnotationStatus::kEligibleForAnnotation ||
      _owner->GetData().GetImageAnnotationStatus() ==
          ax::ImageAnnotationStatus::kSilentlyEligibleForAnnotation) {
    std::wstring_convert<std::codecvt_utf8_utf16<char16_t>,char16_t> convert;
    return @(convert.to_bytes(_owner->GetLocalizedRoleDescriptionForUnlabeledImage()).data());
  }

  if (_owner->HasStringAttribute(
          ax::StringAttribute::kRoleDescription)) {
    return NSStringForStringAttribute(
        _owner, ax::StringAttribute::kRoleDescription);
  }

  NSString* role = [self role];
  ContentClient* content_client = ax::GetContentClient();

  // The following descriptions are specific to webkit.
  if ([role isEqualToString:@"AXWebArea"]) {
    std::wstring_convert<std::codecvt_utf8_utf16<char16_t>,char16_t> convert;
    return @(convert.to_bytes(content_client->GetLocalizedString(IDS_AX_ROLE_WEB_AREA)).data()); 
  }

  if ([role isEqualToString:@"NSAccessibilityLinkRole"]) {
    std::wstring_convert<std::codecvt_utf8_utf16<char16_t>,char16_t> convert;
    return @(convert.to_bytes(content_client->GetLocalizedString(IDS_AX_ROLE_LINK)).data()); 
  }

  if ([role isEqualToString:@"AXHeading"]) {
    std::wstring_convert<std::codecvt_utf8_utf16<char16_t>,char16_t> convert;
    return @(convert.to_bytes(content_client->GetLocalizedString(IDS_AX_ROLE_HEADING)).data()); 
  }

  if (([role isEqualToString:NSAccessibilityGroupRole] ||
       [role isEqualToString:NSAccessibilityRadioButtonRole]) &&
      !_owner->IsWebAreaForPresentationalIframe()) {
    std::string role_attribute;
    if (_owner->GetHtmlAttribute("role", &role_attribute)) {
      ax::Role internalRole = [self internalRole];
      if ((internalRole != ax::Role::kBlockquote &&
           internalRole != ax::Role::kCaption &&
           internalRole != ax::Role::kGroup &&
           internalRole != ax::Role::kListItem &&
           internalRole != ax::Role::kMark &&
           internalRole != ax::Role::kParagraph) ||
          internalRole == ax::Role::kTab) {
        // TODO(dtseng): This is not localized; see crbug/84814.
        return @(role_attribute.data());
      }
    }
  }
  std::wstring_convert<std::codecvt_utf8_utf16<char16_t>,char16_t> convert;
  switch ([self internalRole]) {
    case ax::Role::kArticle:
      return @(convert.to_bytes(content_client->GetLocalizedString(IDS_AX_ROLE_ARTICLE)).data());
    case ax::Role::kBanner:
      return @(convert.to_bytes(content_client->GetLocalizedString(IDS_AX_ROLE_BANNER)).data());
    case ax::Role::kCheckBox:
      return @(convert.to_bytes(content_client->GetLocalizedString(IDS_AX_ROLE_CHECK_BOX)).data());
    case ax::Role::kComment:
      return @(convert.to_bytes(content_client->GetLocalizedString(IDS_AX_ROLE_COMMENT)).data());
    case ax::Role::kComplementary:
      return @(convert.to_bytes(content_client->GetLocalizedString(IDS_AX_ROLE_COMPLEMENTARY)).data());
    case ax::Role::kContentInfo:
      return @(convert.to_bytes(content_client->GetLocalizedString(IDS_AX_ROLE_CONTENT_INFO)).data());
    case ax::Role::kDescriptionList:
      return @(convert.to_bytes(content_client->GetLocalizedString(IDS_AX_ROLE_DESCRIPTION_LIST)).data());
    case ax::Role::kDescriptionListDetail:
      return @(convert.to_bytes(content_client->GetLocalizedString(IDS_AX_ROLE_DEFINITION)).data());
    case ax::Role::kDescriptionListTerm:
      return @(convert.to_bytes(content_client->GetLocalizedString(IDS_AX_ROLE_DESCRIPTION_TERM)).data());
    case ax::Role::kDisclosureTriangle:
      return @(convert.to_bytes(content_client->GetLocalizedString(IDS_AX_ROLE_DISCLOSURE_TRIANGLE)).data());
    case ax::Role::kFigure:
      return @(convert.to_bytes(content_client->GetLocalizedString(IDS_AX_ROLE_FIGURE)).data());
    case ax::Role::kFooter:
      return @(convert.to_bytes(content_client->GetLocalizedString(IDS_AX_ROLE_FOOTER)).data());
    case ax::Role::kForm:
      return @(convert.to_bytes(content_client->GetLocalizedString(IDS_AX_ROLE_FORM)).data());
    case ax::Role::kHeader:
      return @(convert.to_bytes(content_client->GetLocalizedString(IDS_AX_ROLE_BANNER)).data());
    case ax::Role::kMain:
      return @(convert.to_bytes(content_client->GetLocalizedString(IDS_AX_ROLE_MAIN_CONTENT)).data());
    case ax::Role::kMark:
      return @(convert.to_bytes(content_client->GetLocalizedString(IDS_AX_ROLE_MARK)).data());
    case ax::Role::kMath:
      return @(convert.to_bytes(content_client->GetLocalizedString(IDS_AX_ROLE_MATH)).data());
    case ax::Role::kNavigation:
      return @(convert.to_bytes(content_client->GetLocalizedString(IDS_AX_ROLE_NAVIGATIONAL_LINK)).data());
    case ax::Role::kRegion:
      return @(convert.to_bytes(content_client->GetLocalizedString(IDS_AX_ROLE_REGION)).data());
    case ax::Role::kSection:
      // A <section> element uses the 'region' ARIA role mapping.
      return @(convert.to_bytes(content_client->GetLocalizedString(IDS_AX_ROLE_REGION)).data());
    case ax::Role::kSpinButton:
      // This control is similar to what VoiceOver calls a "stepper".
      return @(convert.to_bytes(content_client->GetLocalizedString(IDS_AX_ROLE_STEPPER)).data());
    case ax::Role::kStatus:
      return @(convert.to_bytes(content_client->GetLocalizedString(IDS_AX_ROLE_STATUS)).data());
    case ax::Role::kSearchBox:
      return @(convert.to_bytes(content_client->GetLocalizedString(IDS_AX_ROLE_SEARCH_BOX)).data());
    case ax::Role::kSuggestion:
      return @(convert.to_bytes(content_client->GetLocalizedString(IDS_AX_ROLE_SUGGESTION)).data());
    case ax::Role::kSwitch:
      return @(convert.to_bytes(content_client->GetLocalizedString(IDS_AX_ROLE_SWITCH)).data());
    case ax::Role::kTerm:
      return @(convert.to_bytes(content_client->GetLocalizedString(IDS_AX_ROLE_DESCRIPTION_TERM)).data());
    case ax::Role::kToggleButton:
      return @(convert.to_bytes(content_client->GetLocalizedString(IDS_AX_ROLE_TOGGLE_BUTTON)).data());
    default:
      break;
  }

  return NSAccessibilityRoleDescription(role, nil);
}

- (NSArray*)rowHeaders {
  if (![self instanceActive])
    return nil;

  bool is_cell_or_table_header = ax::IsCellOrTableHeader(_owner->GetRole());
  bool is_table_like = ax::IsTableLike(_owner->GetRole());
  if (!is_table_like && !is_cell_or_table_header)
    return nil;
  ax::AXPlatformNodeMac* table = [self containingTable];
  if (!table)
    return nil;

  NSMutableArray* ret = [[[NSMutableArray alloc] init] autorelease];

  if (is_table_like) {
    // If this is a table, return all row headers.
    std::set<int32_t> headerIds;
    for (int i = 0; i < *table->GetTableRowCount(); i++) {
      std::vector<int32_t> rowHeaderIds = table->GetRowHeaderNodeIds(i);
      for (int32_t id : rowHeaderIds)
        headerIds.insert(id);
    }
    for (int32_t id : headerIds) {
      ax::AXPlatformNodeMac* cell = _owner->manager()->GetFromID(id);
      if (cell)
        [ret addObject:ToBrowserAccessibilityCocoa(cell)];
    }
  } else {
    // Otherwise this is a cell, return the row headers for this cell.
    for (int32_t id : _owner->node()->GetTableCellRowHeaderNodeIds()) {
      ax::AXPlatformNodeMac* cell = _owner->manager()->GetFromID(id);
      if (cell)
        [ret addObject:ToBrowserAccessibilityCocoa(cell)];
    }
  }

  return [ret count] ? ret : nil;
}

- (NSValue*)rowIndexRange {
  if (![self instanceActive])
    return nil;

  std::optional<int> row = _owner->node()->GetTableCellRowIndex();
  std::optional<int> rowspan = _owner->node()->GetTableCellRowSpan();
  if (row && rowspan)
    return [NSValue valueWithRange:NSMakeRange(*row, *rowspan)];
  return nil;
}

- (NSArray*)rows {
  if (![self instanceActive])
    return nil;
  NSMutableArray* ret = [[[NSMutableArray alloc] init] autorelease];

  std::vector<int32_t> node_id_list;
  if (_owner->GetRole() == ax::Role::kTree)
    [self getTreeItemDescendantNodeIds:&node_id_list];
  else if (ax::IsTableLike(_owner->GetRole()))
    node_id_list = _owner->node()->GetTableRowNodeIds();
  // Rows attribute for a column is the list of all the elements in that column
  // at each row.
  else if ([self internalRole] == ax::Role::kColumn)
    node_id_list = _owner->GetIntListAttribute(
        ax::IntListAttribute::kIndirectChildIds);

  for (int32_t node_id : node_id_list) {
    ax::AXPlatformNodeMac* rowElement = _owner->manager()->GetFromID(node_id);
    if (rowElement)
      [ret addObject:ToBrowserAccessibilityCocoa(rowElement)];
  }

  return ret;
}

- (NSNumber*)selected {
  if (![self instanceActive])
    return nil;
  return [NSNumber numberWithBool:_owner->GetBoolAttribute(
                                      ax::BoolAttribute::kSelected)];
}

- (NSArray*)selectedChildren {
  if (![self instanceActive])
    return nil;
  NSMutableArray* ret = [[[NSMutableArray alloc] init] autorelease];
  BrowserAccessibilityManager* manager = _owner->manager();
  ax::AXPlatformNodeMac* focusedChild = manager->GetFocus();
  if (focusedChild == _owner)
    focusedChild = manager->GetActiveDescendant(focusedChild);

  if (focusedChild &&
      (focusedChild == _owner || !focusedChild->IsDescendantOf(_owner)))
    focusedChild = nullptr;

  // If it's not multiselectable, try to skip iterating over the
  // children.
  if (!GetState(_owner, ax::State::kMultiselectable)) {
    // First try the focused child.
    if (focusedChild) {
      [ret addObject:ToBrowserAccessibilityCocoa(focusedChild)];
      return ret;
    }
  }

  // Put the focused one first, if it's focused, as this helps VO draw the
  // focus box around the active item.
  if (focusedChild &&
      focusedChild->GetBoolAttribute(ax::BoolAttribute::kSelected))
    [ret addObject:ToBrowserAccessibilityCocoa(focusedChild)];

  // If it's multiselectable or if the previous attempts failed,
  // return any children with the "selected" state, which may
  // come from aria-selected.
  for (auto it = _owner->PlatformChildrenBegin();
       it != _owner->PlatformChildrenEnd(); ++it) {
    ax::AXPlatformNodeMac* child = it.get();
    if (child->GetBoolAttribute(ax::BoolAttribute::kSelected)) {
      if (child == focusedChild)
        continue;  // Already added as first item.
      else
        [ret addObject:ToBrowserAccessibilityCocoa(child)];
    }
  }

  return ret;
}

- (NSString*)selectedText {
  if (![self instanceActive])
    return nil;
  if (!_owner->HasVisibleCaretOrSelection())
    return nil;

  const AXPlatformRange range = GetSelectedRange(*_owner);
  if (range.IsNull())
    return nil;
  std::wstring_convert<std::codecvt_utf8_utf16<char16_t>,char16_t> convert;
  return @(convert.to_bytes(range.GetText()).data());
}

// Returns range of text under the current object that is selected.
//
// Example, caret at offset 5:
// NSRange:  “pos=5 len=0”
- (NSValue*)selectedTextRange {
  if (![self instanceActive])
    return nil;
  if (!_owner->HasVisibleCaretOrSelection())
    return nil;

  const AXPlatformRange range = GetSelectedRange(*_owner).AsForwardRange();
  if (range.IsNull())
    return nil;

  const BrowserAccessibilityPositionInstance startPosition =
      range.anchor()->LowestCommonAncestor(*_owner->CreatePositionAt(0));
  FML_DCHECK(!startPosition->IsNullPosition())
      << "Calling HasVisibleCaretOrSelection() should have ensured that there "
         "is a valid selection anchor inside the current object.";
  int selStart = startPosition->AsTextPosition()->text_offset();
  FML_DCHECK(selStart >= 0);
  int selLength = range.GetText().length();
  return [NSValue valueWithRange:NSMakeRange(selStart, selLength)];
}

- (id)selectedTextMarkerRange {
  if (![self instanceActive])
    return nil;
  // Voiceover expects this range to be backwards in order to read the selected
  // words correctly.
  return CreateTextMarkerRange(GetSelectedRange(*_owner).AsBackwardRange());
}

- (NSValue*)size {
  if (![self instanceActive])
    return nil;
  gfx::Rect bounds = _owner->GetClippedRootFrameBoundsRect();
  return [NSValue valueWithSize:NSMakeSize(bounds.width(), bounds.height())];
}

- (NSString*)sortDirection {
  if (![self instanceActive])
    return nil;
  int sortDirection;
  if (!_owner->GetIntAttribute(ax::IntAttribute::kSortDirection,
                               &sortDirection))
    return nil;

  switch (static_cast<ax::SortDirection>(sortDirection)) {
    case ax::SortDirection::kUnsorted:
      return nil;
    case ax::SortDirection::kAscending:
      return NSAccessibilityAscendingSortDirectionValue;
    case ax::SortDirection::kDescending:
      return NSAccessibilityDescendingSortDirectionValue;
    case ax::SortDirection::kOther:
      return NSAccessibilityUnknownSortDirectionValue;
    default:
      NOTREACHED();
  }

  return nil;
}

// Returns a text marker that points to the first character in the document that
// can be selected with VoiceOver.
- (id)startTextMarker {
  const ax::AXPlatformNodeMac* root = _owner->manager()->GetRoot();
  if (!root)
    return nil;

  BrowserAccessibilityPositionInstance position = root->CreatePositionAt(0);
  return CreateTextMarker(position->CreatePositionAtStartOfAnchor());
}

// Returns a subrole based upon the role.
- (NSString*)subrole {
  if (![self instanceActive])
    return nil;

  if (_owner->IsPlainTextField() &&
      GetState(_owner, ax::State::kProtected)) {
    return NSAccessibilitySecureTextFieldSubrole;
  }

  if ([self internalRole] == ax::Role::kDescriptionList)
    return NSAccessibilityDefinitionListSubrole;

  if ([self internalRole] == ax::Role::kList)
    return NSAccessibilityContentListSubrole;

  return [AXPlatformNodeCocoa nativeSubroleFromAXRole:[self internalRole]];
}

// Returns all tabs in this subtree.
- (NSArray*)tabs {
  if (![self instanceActive])
    return nil;
  NSMutableArray* tabSubtree = [[[NSMutableArray alloc] init] autorelease];

  if ([self internalRole] == ax::Role::kTab)
    [tabSubtree addObject:self];

  for (uint i = 0; i < [[self children] count]; ++i) {
    NSArray* tabChildren = [[[self children] objectAtIndex:i] tabs];
    if ([tabChildren count] > 0)
      [tabSubtree addObjectsFromArray:tabChildren];
  }

  return tabSubtree;
}

- (NSString*)title {
  if (![self instanceActive])
    return nil;
  // Mac OS X wants static text exposed in AXValue.
  if (ax::IsNameExposedInAXValueForRole([self internalRole]))
    return @"";

  if ([self shouldExposeNameInDescription])
    return @"";

  // If we're exposing the title in TitleUIElement, don't also redundantly
  // expose it in AXDescription.
  if ([self shouldExposeTitleUIElement])
    return @"";

  ax::NameFrom nameFrom = static_cast<ax::NameFrom>(
      _owner->GetIntAttribute(ax::IntAttribute::kNameFrom));

  // On Mac OS X, cell titles are "" if it it came from content.
  NSString* role = [self role];
  if ([role isEqualToString:NSAccessibilityCellRole] &&
      nameFrom == ax::NameFrom::kContents)
    return @"";

  // On Mac OS X, the accessible name of an object is exposed as its
  // title if it comes from visible text, and as its description
  // otherwise, but never both.
  if (nameFrom == ax::NameFrom::kCaption ||
      nameFrom == ax::NameFrom::kContents ||
      nameFrom == ax::NameFrom::kRelatedElement ||
      nameFrom == ax::NameFrom::kValue) {
    return NSStringForStringAttribute(_owner,
                                      ax::StringAttribute::kName);
  }

  return @"";
}

- (id)titleUIElement {
  if (![self instanceActive])
    return nil;
  if (![self shouldExposeTitleUIElement])
    return nil;

  std::vector<int32_t> labelledby_ids =
      _owner->GetIntListAttribute(ax::IntListAttribute::kLabelledbyIds);
  ax::NameFrom nameFrom = static_cast<ax::NameFrom>(
      _owner->GetIntAttribute(ax::IntAttribute::kNameFrom));
  if ((nameFrom == ax::NameFrom::kCaption ||
       nameFrom == ax::NameFrom::kRelatedElement) &&
      labelledby_ids.size() == 1) {
    ax::AXPlatformNodeMac* titleElement =
        _owner->manager()->GetFromID(labelledby_ids[0]);
    if (titleElement)
      return ToBrowserAccessibilityCocoa(titleElement);
  }

  return nil;
}

- (NSURL*)url {
  if (![self instanceActive])
    return nil;
  std::string url;
  if ([[self role] isEqualToString:@"AXWebArea"])
    url = _owner->manager()->GetTreeData().url;
  else
    url = _owner->GetStringAttribute(ax::StringAttribute::kUrl);

  if (url.empty())
    return nil;

  return [NSURL URLWithString:(SysUTF8ToNSString(url))];
}

- (id)value {
  if (![self instanceActive])
    return nil;

  // if (ax::IsNameExposedInAXValueForRole([self internalRole])) {
  //   if (!IsSelectedStateRelevant(_owner)) {
  //     return NSStringForStringAttribute(_owner,
  //                                       ax::StringAttribute::kName);
  //   }

  //   // Append the selection state as a string, because VoiceOver will not
  //   // automatically report selection state when an individual item is focused.
  //   std::u16string name =
  //       _owner->GetString16Attribute(ax::StringAttribute::kName);
  //   bool is_selected =
  //       _owner->GetBoolAttribute(ax::BoolAttribute::kSelected);
  //   int msg_id =
  //       is_selected ? IDS_AX_OBJECT_SELECTED : IDS_AX_OBJECT_NOT_SELECTED;
  //   ContentClient* content_client = ax::GetContentClient();
  //   std::u16string name_with_selection = base::ReplaceStringPlaceholders(
  //       content_client->GetLocalizedString(msg_id), {name}, nullptr);

  //   return SysUTF16ToNSString(name_with_selection);
  // }

  NSString* role = [self role];
  if ([role isEqualToString:@"AXHeading"]) {
    int level = 0;
    if (_owner->GetIntAttribute(ax::IntAttribute::kHierarchicalLevel,
                                &level)) {
      return [NSNumber numberWithInt:level];
    }
  } else if ([role isEqualToString:NSAccessibilityButtonRole]) {
    // AXValue does not make sense for pure buttons.
    return @"";
  } else if ([self isCheckable]) {
    int value;
    const auto checkedState = _owner->GetData().GetCheckedState();
    switch (checkedState) {
      case ax::CheckedState::kTrue:
        value = 1;
        break;
      case ax::CheckedState::kMixed:
        value = 2;
        break;
      default:
        value = _owner->GetBoolAttribute(ax::BoolAttribute::kSelected)
                    ? 1
                    : 0;
        break;
    }
    return [NSNumber numberWithInt:value];
  } else if (_owner->GetData().IsRangeValueSupported()) {
    float floatValue;
    if (_owner->GetFloatAttribute(ax::FloatAttribute::kValueForRange,
                                  &floatValue)) {
      return [NSNumber numberWithFloat:floatValue];
    }
  } else if ([role isEqualToString:NSAccessibilityColorWellRole]) {
    unsigned int color = static_cast<unsigned int>(
        _owner->GetIntAttribute(ax::IntAttribute::kColorValue));
    unsigned int red = SkColorGetR(color);
    unsigned int green = SkColorGetG(color);
    unsigned int blue = SkColorGetB(color);
    // This string matches the one returned by a native Mac color well.
    return [NSString stringWithFormat:@"rgb %7.5f %7.5f %7.5f 1", red / 255.,
                                      green / 255., blue / 255.];
  }

  return SysUTF16ToNSString(_owner->GetValue());
}

- (NSNumber*)valueAutofillAvailable {
  if (![self instanceActive])
    return nil;
  return _owner->HasState(ax::State::kAutofillAvailable) ? @YES : @NO;
}

// Not currently supported, as Chrome does not store whether an autofill
// occurred. We could have autofill fire an event, however, and set an
// "is_autofilled" flag until the next edit. - (NSNumber*)valueAutofilled {
//  return @NO;
// }

// Not currently supported, as Chrome's autofill types aren't like Safari's.
// - (NSString*)valueAutofillType {
//  return @"none";
//}

- (NSString*)valueDescription {
  if (![self instanceActive])
    return nil;
  if (_owner)
    return SysUTF16ToNSString(_owner->GetValue());
  return nil;
}

- (NSValue*)visibleCharacterRange {
  if (![self instanceActive])
    return nil;
  std::u16string value = _owner->GetValue();
  return [NSValue valueWithRange:NSMakeRange(0, value.size())];
}

- (NSArray*)visibleCells {
  if (![self instanceActive])
    return nil;

  NSMutableArray* ret = [[[NSMutableArray alloc] init] autorelease];
  for (int32_t id : _owner->node()->GetTableUniqueCellIds()) {
    ax::AXPlatformNodeMac* cell = _owner->manager()->GetFromID(id);
    if (cell)
      [ret addObject:ToBrowserAccessibilityCocoa(cell)];
  }
  return ret;
}

- (NSArray*)visibleChildren {
  if (![self instanceActive])
    return nil;
  return [self children];
}

- (NSArray*)visibleColumns {
  if (![self instanceActive])
    return nil;
  return [self columns];
}

- (NSArray*)visibleRows {
  if (![self instanceActive])
    return nil;
  return [self rows];
}

- (NSNumber*)visited {
  if (![self instanceActive])
    return nil;
  return [NSNumber numberWithBool:GetState(_owner, ax::State::kVisited)];
}

- (id)window {
  if (![self instanceActive])
    return nil;

  BrowserAccessibilityManagerMac* manager =
      _owner->manager()->GetRootManager()->ToBrowserAccessibilityManagerMac();
  if (!manager || !manager->GetParentView())
    return nil;

  return manager->GetWindow();
}

- (void)getTreeItemDescendantNodeIds:(std::vector<int32_t>*)tree_item_ids {
  for (auto it = _owner->PlatformChildrenBegin();
       it != _owner->PlatformChildrenEnd(); ++it) {
    const BrowserAccessibilityCocoa* child =
        ToBrowserAccessibilityCocoa(it.get());

    if ([child internalRole] == ax::Role::kTreeItem) {
      tree_item_ids->push_back([child hash]);
    }
    [child getTreeItemDescendantNodeIds:tree_item_ids];
  }
}

- (NSString*)methodNameForAttribute:(NSString*)attribute {
  return [attributeToMethodNameMap objectForKey:attribute];
}

- (void)swapChildren:(fml::scoped_nsobject<NSMutableArray>*)other {
  _children.swap(*other);
}

- (NSString*)valueForRange:(NSRange)range {
  if (![self instanceActive])
    return nil;

  std::u16string innerText = _owner->GetValue();
  if (innerText.empty())
    innerText = _owner->GetInnerText();
  if (NSMaxRange(range) > innerText.length())
    return nil;

  return SysUTF16ToNSString(
      innerText.substr(range.location, range.length));
}

// Retrieves the text inside this object and decorates it with attributes
// indicating specific ranges of interest within the text, e.g. the location of
// misspellings.
- (NSAttributedString*)attributedValueForRange:(NSRange)range {
  if (![self instanceActive])
    return nil;

  std::u16string innerText = _owner->GetValue();
  if (innerText.empty())
    innerText = _owner->GetInnerText();
  if (NSMaxRange(range) > innerText.length())
    return nil;

  // We potentially need to add text attributes to the whole inner text because
  // a spelling mistake might start or end outside the given range.
  NSMutableAttributedString* attributedInnerText =
      [[[NSMutableAttributedString alloc]
          initWithString:SysUTF16ToNSString(innerText)] autorelease];
  if (!_owner->IsText()) {
    AXPlatformRange ax_range(_owner->CreatePositionAt(0),
                             _owner->CreatePositionAt(int{innerText.length()}));
    AddMisspelledTextAttributes(ax_range, attributedInnerText);
  }

  return [attributedInnerText attributedSubstringFromRange:range];
}

// Returns the accessibility value for the given attribute.  If the value isn't
// supported this will return nil.
- (id)accessibilityAttributeValue:(NSString*)attribute {
  TRACE_EVENT2("accessibility",
               "BrowserAccessibilityCocoa::accessibilityAttributeValue",
               "role=", ax::ToString([self internalRole]),
               "attribute=", [attribute UTF8String]);
  if (![self instanceActive])
    return nil;

  SEL selector = NSSelectorFromString([self methodNameForAttribute:attribute]);
  if (selector)
    return [self performSelector:selector];

  return nil;
}

// Returns the accessibility value for the given attribute and parameter. If the
// value isn't supported this will return nil.
- (id)accessibilityAttributeValue:(NSString*)attribute
                     forParameter:(id)parameter {
  if (parameter && [parameter isKindOfClass:[NSNumber self]]) {
    TRACE_EVENT2(
        "accessibility",
        "BrowserAccessibilityCocoa::accessibilityAttributeValue:forParameter",
        "role=", ax::ToString([self internalRole]), "attribute=",
        [attribute UTF8String] +
            " parameter=" + [[parameter stringValue] UTF8String]);
  } else {
    TRACE_EVENT2(
        "accessibility",
        "BrowserAccessibilityCocoa::accessibilityAttributeValue:forParameter",
        "role=", ax::ToString([self internalRole]),
        "attribute=", [attribute UTF8String]);
  }

  if (![self instanceActive])
    return nil;

  if ([attribute isEqualToString:
                     NSAccessibilityStringForRangeParameterizedAttribute]) {
    return [self valueForRange:[(NSValue*)parameter rangeValue]];
  }

  if ([attribute
          isEqualToString:
              NSAccessibilityAttributedStringForRangeParameterizedAttribute]) {
    return [self attributedValueForRange:[(NSValue*)parameter rangeValue]];
  }

  if ([attribute
          isEqualToString:NSAccessibilityLineForIndexParameterizedAttribute]) {
    int lineIndex = [(NSNumber*)parameter intValue];
    const std::vector<int> lineBreaks = _owner->GetLineStartOffsets();
    auto iterator =
        std::upper_bound(lineBreaks.begin(), lineBreaks.end(), lineIndex);
    return @(std::distance(lineBreaks.begin(), iterator));
  }

  if ([attribute
          isEqualToString:NSAccessibilityRangeForLineParameterizedAttribute]) {
    int lineIndex = [(NSNumber*)parameter intValue];
    const std::vector<int> lineBreaks = _owner->GetLineStartOffsets();
    std::u16string value = _owner->GetValue();
    if (value.empty())
      value = _owner->GetInnerText();
    int valueLength = static_cast<int>(value.size());

    int lineCount = static_cast<int>(lineBreaks.size()) + 1;
    if (lineIndex < 0 || lineIndex >= lineCount)
      return nil;
    int start = (lineIndex > 0) ? lineBreaks[lineIndex - 1] : 0;
    int end =
        (lineIndex < (lineCount - 1)) ? lineBreaks[lineIndex] : valueLength;
    return [NSValue valueWithRange:NSMakeRange(start, end - start)];
  }

  if ([attribute
          isEqualToString:
              NSAccessibilityCellForColumnAndRowParameterizedAttribute]) {
    if (!ax::IsTableLike([self internalRole]))
      return nil;
    if (![parameter isKindOfClass:[NSArray class]])
      return nil;
    if (2 != [parameter count])
      return nil;
    NSArray* array = parameter;
    int column = [[array objectAtIndex:0] intValue];
    int row = [[array objectAtIndex:1] intValue];

    ax::AXNode* cellNode = _owner->node()->GetTableCellFromCoords(row, column);
    if (!cellNode)
      return nil;

    ax::AXPlatformNodeMac* cell = _owner->manager()->GetFromID(cellNode->id());
    if (cell)
      return ToBrowserAccessibilityCocoa(cell);
  }

  if ([attribute
          isEqualToString:
              NSAccessibilityUIElementForTextMarkerParameterizedAttribute]) {
    BrowserAccessibilityPositionInstance position =
        CreatePositionFromTextMarker(parameter);
    if (!position->IsNullPosition())
      return ToBrowserAccessibilityCocoa(position->GetAnchor());

    return nil;
  }

  if ([attribute
          isEqualToString:
              NSAccessibilityTextMarkerRangeForUIElementParameterizedAttribute]) {
    BrowserAccessibilityPositionInstance startPosition =
        _owner->CreatePositionAt(0);
    BrowserAccessibilityPositionInstance endPosition =
        startPosition->CreatePositionAtEndOfAnchor();
    AXPlatformRange range =
        AXPlatformRange(std::move(startPosition), std::move(endPosition));
    return CreateTextMarkerRange(std::move(range));
  }

  if ([attribute
          isEqualToString:
              NSAccessibilityStringForTextMarkerRangeParameterizedAttribute])
    return GetTextForTextMarkerRange(parameter);

  if ([attribute
          isEqualToString:
              NSAccessibilityAttributedStringForTextMarkerRangeParameterizedAttribute])
    return GetAttributedTextForTextMarkerRange(parameter);

  if ([attribute
          isEqualToString:
              NSAccessibilityNextTextMarkerForTextMarkerParameterizedAttribute]) {
    BrowserAccessibilityPositionInstance position =
        CreatePositionFromTextMarker(parameter);
    if (position->IsNullPosition())
      return nil;
    return CreateTextMarker(position->CreateNextCharacterPosition(
        ax::AXBoundaryBehavior::CrossBoundary));
  }

  if ([attribute
          isEqualToString:
              NSAccessibilityPreviousTextMarkerForTextMarkerParameterizedAttribute]) {
    BrowserAccessibilityPositionInstance position =
        CreatePositionFromTextMarker(parameter);
    if (position->IsNullPosition())
      return nil;
    return CreateTextMarker(position->CreatePreviousCharacterPosition(
        ax::AXBoundaryBehavior::CrossBoundary));
  }

  if ([attribute
          isEqualToString:
              NSAccessibilityLeftWordTextMarkerRangeForTextMarkerParameterizedAttribute]) {
    BrowserAccessibilityPositionInstance endPosition =
        CreatePositionFromTextMarker(parameter);
    if (endPosition->IsNullPosition())
      return nil;

    BrowserAccessibilityPositionInstance startWordPosition =
        endPosition->CreatePreviousWordStartPosition(
            ax::AXBoundaryBehavior::StopAtAnchorBoundary);
    BrowserAccessibilityPositionInstance endWordPosition =
        endPosition->CreatePreviousWordEndPosition(
            ax::AXBoundaryBehavior::StopAtAnchorBoundary);
    BrowserAccessibilityPositionInstance startPosition =
        *startWordPosition <= *endWordPosition ? std::move(endWordPosition)
                                               : std::move(startWordPosition);
    AXPlatformRange range(std::move(startPosition), std::move(endPosition));
    return CreateTextMarkerRange(std::move(range));
  }

  if ([attribute
          isEqualToString:
              NSAccessibilityRightWordTextMarkerRangeForTextMarkerParameterizedAttribute]) {
    BrowserAccessibilityPositionInstance startPosition =
        CreatePositionFromTextMarker(parameter);
    if (startPosition->IsNullPosition())
      return nil;

    BrowserAccessibilityPositionInstance endWordPosition =
        startPosition->CreateNextWordEndPosition(
            ax::AXBoundaryBehavior::StopAtAnchorBoundary);
    BrowserAccessibilityPositionInstance startWordPosition =
        startPosition->CreateNextWordStartPosition(
            ax::AXBoundaryBehavior::StopAtAnchorBoundary);
    BrowserAccessibilityPositionInstance endPosition =
        *startWordPosition <= *endWordPosition ? std::move(startWordPosition)
                                               : std::move(endWordPosition);
    AXPlatformRange range(std::move(startPosition), std::move(endPosition));
    return CreateTextMarkerRange(std::move(range));
  }

  if ([attribute
          isEqualToString:
              NSAccessibilityNextWordEndTextMarkerForTextMarkerParameterizedAttribute]) {
    BrowserAccessibilityPositionInstance position =
        CreatePositionFromTextMarker(parameter);
    if (position->IsNullPosition())
      return nil;
    return CreateTextMarker(position->CreateNextWordEndPosition(
        ax::AXBoundaryBehavior::CrossBoundary));
  }

  if ([attribute
          isEqualToString:
              NSAccessibilityPreviousWordStartTextMarkerForTextMarkerParameterizedAttribute]) {
    BrowserAccessibilityPositionInstance position =
        CreatePositionFromTextMarker(parameter);
    if (position->IsNullPosition())
      return nil;
    return CreateTextMarker(position->CreatePreviousWordStartPosition(
        ax::AXBoundaryBehavior::CrossBoundary));
  }

  if ([attribute isEqualToString:
                     NSAccessibilityLineForTextMarkerParameterizedAttribute]) {
    BrowserAccessibilityPositionInstance position =
        CreatePositionFromTextMarker(parameter);
    if (position->IsNullPosition())
      return nil;

    int textOffset = position->AsTextPosition()->text_offset();
    const std::vector<int> lineBreaks = _owner->GetLineStartOffsets();
    const auto iterator =
        std::upper_bound(lineBreaks.begin(), lineBreaks.end(), textOffset);
    return @(std::distance(lineBreaks.begin(), iterator));
  }

  if ([attribute
          isEqualToString:
              NSAccessibilityTextMarkerRangeForLineParameterizedAttribute]) {
    int lineIndex = [(NSNumber*)parameter intValue];
    const std::vector<int> lineBreaks = _owner->GetLineStartOffsets();
    int lineCount = static_cast<int>(lineBreaks.size()) + 1;
    if (lineIndex < 0 || lineIndex >= lineCount)
      return nil;

    int lineStartOffset = (lineIndex > 0) ? lineBreaks[lineIndex - 1] : 0;
    BrowserAccessibilityPositionInstance lineStartPosition = CreateTextPosition(
        *_owner, lineStartOffset, ax::TextAffinity::kDownstream);
    if (lineStartPosition->IsNullPosition())
      return nil;

    // Make sure that the line start position is really at the start of the
    // current line.
    lineStartPosition = lineStartPosition->CreatePreviousLineStartPosition(
        ax::AXBoundaryBehavior::StopIfAlreadyAtBoundary);
    BrowserAccessibilityPositionInstance lineEndPosition =
        lineStartPosition->CreateNextLineEndPosition(
            ax::AXBoundaryBehavior::StopAtAnchorBoundary);
    AXPlatformRange range(std::move(lineStartPosition),
                          std::move(lineEndPosition));
    return CreateTextMarkerRange(std::move(range));
  }

  if ([attribute
          isEqualToString:
              NSAccessibilityLeftLineTextMarkerRangeForTextMarkerParameterizedAttribute]) {
    BrowserAccessibilityPositionInstance endPosition =
        CreatePositionFromTextMarker(parameter);
    if (endPosition->IsNullPosition())
      return nil;

    BrowserAccessibilityPositionInstance startLinePosition =
        endPosition->CreatePreviousLineStartPosition(
            ax::AXBoundaryBehavior::StopAtLastAnchorBoundary);
    BrowserAccessibilityPositionInstance endLinePosition =
        endPosition->CreatePreviousLineEndPosition(
            ax::AXBoundaryBehavior::StopAtLastAnchorBoundary);
    BrowserAccessibilityPositionInstance startPosition =
        *startLinePosition <= *endLinePosition ? std::move(endLinePosition)
                                               : std::move(startLinePosition);
    AXPlatformRange range(std::move(startPosition), std::move(endPosition));
    return CreateTextMarkerRange(std::move(range));
  }

  if ([attribute
          isEqualToString:
              NSAccessibilityRightLineTextMarkerRangeForTextMarkerParameterizedAttribute]) {
    BrowserAccessibilityPositionInstance startPosition =
        CreatePositionFromTextMarker(parameter);
    if (startPosition->IsNullPosition())
      return nil;

    BrowserAccessibilityPositionInstance startLinePosition =
        startPosition->CreateNextLineStartPosition(
            ax::AXBoundaryBehavior::StopAtLastAnchorBoundary);
    BrowserAccessibilityPositionInstance endLinePosition =
        startPosition->CreateNextLineEndPosition(
            ax::AXBoundaryBehavior::StopAtLastAnchorBoundary);
    BrowserAccessibilityPositionInstance endPosition =
        *startLinePosition <= *endLinePosition ? std::move(startLinePosition)
                                               : std::move(endLinePosition);
    AXPlatformRange range(std::move(startPosition), std::move(endPosition));
    return CreateTextMarkerRange(std::move(range));
  }

  if ([attribute
          isEqualToString:
              NSAccessibilityNextLineEndTextMarkerForTextMarkerParameterizedAttribute]) {
    BrowserAccessibilityPositionInstance position =
        CreatePositionFromTextMarker(parameter);
    if (position->IsNullPosition())
      return nil;
    return CreateTextMarker(position->CreateNextLineEndPosition(
        ax::AXBoundaryBehavior::CrossBoundary));
  }

  if ([attribute
          isEqualToString:
              NSAccessibilityPreviousLineStartTextMarkerForTextMarkerParameterizedAttribute]) {
    BrowserAccessibilityPositionInstance position =
        CreatePositionFromTextMarker(parameter);
    if (position->IsNullPosition())
      return nil;
    return CreateTextMarker(position->CreatePreviousLineStartPosition(
        ax::AXBoundaryBehavior::CrossBoundary));
  }

  if ([attribute
          isEqualToString:
              NSAccessibilityParagraphTextMarkerRangeForTextMarkerParameterizedAttribute]) {
    BrowserAccessibilityPositionInstance position =
        CreatePositionFromTextMarker(parameter);
    if (position->IsNullPosition())
      return nil;

    BrowserAccessibilityPositionInstance startPosition =
        position->CreatePreviousParagraphStartPosition(
            ax::AXBoundaryBehavior::StopIfAlreadyAtBoundary);
    BrowserAccessibilityPositionInstance endPosition =
        position->CreateNextParagraphEndPosition(
            ax::AXBoundaryBehavior::StopIfAlreadyAtBoundary);
    AXPlatformRange range(std::move(startPosition), std::move(endPosition));
    return CreateTextMarkerRange(std::move(range));
  }

  if ([attribute
          isEqualToString:
              NSAccessibilityNextParagraphEndTextMarkerForTextMarkerParameterizedAttribute]) {
    BrowserAccessibilityPositionInstance position =
        CreatePositionFromTextMarker(parameter);
    if (position->IsNullPosition())
      return nil;
    return CreateTextMarker(position->CreateNextParagraphEndPosition(
        ax::AXBoundaryBehavior::CrossBoundary));
  }

  if ([attribute
          isEqualToString:
              NSAccessibilityPreviousParagraphStartTextMarkerForTextMarkerParameterizedAttribute]) {
    BrowserAccessibilityPositionInstance position =
        CreatePositionFromTextMarker(parameter);
    if (position->IsNullPosition())
      return nil;
    return CreateTextMarker(position->CreatePreviousParagraphStartPosition(
        ax::AXBoundaryBehavior::CrossBoundary));
  }

  if ([attribute
          isEqualToString:
              NSAccessibilityStyleTextMarkerRangeForTextMarkerParameterizedAttribute]) {
    BrowserAccessibilityPositionInstance position =
        CreatePositionFromTextMarker(parameter);
    if (position->IsNullPosition())
      return nil;

    BrowserAccessibilityPositionInstance startPosition =
        position->CreatePreviousFormatStartPosition(
            ax::AXBoundaryBehavior::StopIfAlreadyAtBoundary);
    BrowserAccessibilityPositionInstance endPosition =
        position->CreateNextFormatEndPosition(
            ax::AXBoundaryBehavior::StopIfAlreadyAtBoundary);
    AXPlatformRange range(std::move(startPosition), std::move(endPosition));
    return CreateTextMarkerRange(std::move(range));
  }

  if ([attribute
          isEqualToString:
              NSAccessibilityLengthForTextMarkerRangeParameterizedAttribute]) {
    NSString* text = GetTextForTextMarkerRange(parameter);
    return @([text length]);
  }

  if ([attribute isEqualToString:
                     NSAccessibilityTextMarkerIsValidParameterizedAttribute]) {
    return @(CreatePositionFromTextMarker(parameter)->IsNullPosition());
  }

  if ([attribute isEqualToString:
                     NSAccessibilityIndexForTextMarkerParameterizedAttribute]) {
    BrowserAccessibilityPositionInstance position =
        CreatePositionFromTextMarker(parameter);
    if (position->IsNullPosition())
      return nil;
    return @(position->AsTextPosition()->text_offset());
  }

  if ([attribute isEqualToString:
                     NSAccessibilityTextMarkerForIndexParameterizedAttribute]) {
    int index = [static_cast<NSNumber*>(parameter) intValue];
    if (index < 0)
      return nil;

    const ax::AXPlatformNodeMac* root = _owner->manager()->GetRoot();
    if (!root)
      return nil;

    return CreateTextMarker(root->CreatePositionAt(index));
  }

  if ([attribute isEqualToString:
                     NSAccessibilityBoundsForRangeParameterizedAttribute]) {
    // if (!_owner->IsText())
    //   return nil;
    // NSRange range = [(NSValue*)parameter rangeValue];
    // gfx::Rect rect = _owner->GetUnclippedScreenInnerTextRangeBoundsRect(
    //     range.location, range.location + range.length);
    // NSRect nsrect = [self rectInScreen:rect];
    // return [NSValue valueWithRect:nsrect];
    return nil
  }

  if ([attribute isEqualToString:
                   NSAccessibilityUIElementCountForSearchPredicateParameterizedAttribute]) {
    // OneShotAccessibilityTreeSearch search(_owner);
    // if (InitializeAccessibilityTreeSearch(&search, parameter))
    //   return [NSNumber numberWithInt:search.CountMatches()];
    return nil;
  }

  if ([attribute isEqualToString:
                     NSAccessibilityUIElementsForSearchPredicateParameterizedAttribute]) {
    // OneShotAccessibilityTreeSearch search(_owner);
    // if (InitializeAccessibilityTreeSearch(&search, parameter)) {
    //   size_t count = search.CountMatches();
    //   NSMutableArray* result = [NSMutableArray arrayWithCapacity:count];
    //   for (size_t i = 0; i < count; ++i) {
    //     ax::AXPlatformNodeMac* match = search.GetMatchAtIndex(i);
    //     [result addObject:ToBrowserAccessibilityCocoa(match)];
    //   }
    //   return result;
    // }
    return nil;
  }

  if ([attribute
          isEqualToString:
              NSAccessibilityLineTextMarkerRangeForTextMarkerParameterizedAttribute]) {
    BrowserAccessibilityPositionInstance position =
        CreatePositionFromTextMarker(parameter);
    if (position->IsNullPosition())
      return nil;

    // If the initial position is between lines, e.g. if it is on a soft line
    // break or on an ignored position that separates lines, we have to return
    // the previous line. This is what Safari does.
    //
    // Note that hard line breaks are on a line of their own.
    BrowserAccessibilityPositionInstance startPosition =
        position->CreatePreviousLineStartPosition(
            ax::AXBoundaryBehavior::StopIfAlreadyAtBoundary);
    BrowserAccessibilityPositionInstance endPosition =
        startPosition->CreateNextLineStartPosition(
            ax::AXBoundaryBehavior::StopAtLastAnchorBoundary);
    AXPlatformRange range(std::move(startPosition), std::move(endPosition));
    return CreateTextMarkerRange(std::move(range));
  }

  if ([attribute
          isEqualToString:
              NSAccessibilityBoundsForTextMarkerRangeParameterizedAttribute]) {
    // ax::AXPlatformNodeMac* startObject;
    // ax::AXPlatformNodeMac* endObject;
    // int startOffset, endOffset;
    // AXPlatformRange range = CreateRangeFromTextMarkerRange(parameter);
    // if (range.IsNull())
    //   return nil;

    // startObject = range.anchor()->GetAnchor();
    // endObject = range.focus()->GetAnchor();
    // startOffset = range.anchor()->text_offset();
    // endOffset = range.focus()->text_offset();
    // FML_DCHECK(startObject && endObject);
    // FML_DCHECK(startOffset >= 0);
    // FML_DCHECK(endOffset >= 0);

    // gfx::Rect rect =
    //     BrowserAccessibilityManager::GetRootFrameInnerTextRangeBoundsRect(
    //         *startObject, startOffset, *endObject, endOffset);
    // NSRect nsrect = [self rectInScreen:rect];
    // return [NSValue valueWithRect:nsrect];
    return nil
  }

  if ([attribute
          isEqualToString:
              NSAccessibilityTextMarkerRangeForUnorderedTextMarkersParameterizedAttribute]) {
    if (![parameter isKindOfClass:[NSArray class]])
      return nil;

    NSArray* textMarkerArray = parameter;
    if ([textMarkerArray count] != 2)
      return nil;

    BrowserAccessibilityPositionInstance startPosition =
        CreatePositionFromTextMarker([textMarkerArray objectAtIndex:0]);
    BrowserAccessibilityPositionInstance endPosition =
        CreatePositionFromTextMarker([textMarkerArray objectAtIndex:1]);
    if (*startPosition <= *endPosition) {
      return CreateTextMarkerRange(
          AXPlatformRange(std::move(startPosition), std::move(endPosition)));
    } else {
      return CreateTextMarkerRange(
          AXPlatformRange(std::move(endPosition), std::move(startPosition)));
    }
  }

  if ([attribute
          isEqualToString:
              NSAccessibilityTextMarkerDebugDescriptionParameterizedAttribute]) {
    BrowserAccessibilityPositionInstance position =
        CreatePositionFromTextMarker(parameter);
    return SysUTF8ToNSString(position->ToString());
  }

  if ([attribute
          isEqualToString:
              NSAccessibilityTextMarkerRangeDebugDescriptionParameterizedAttribute]) {
    AXPlatformRange range = CreateRangeFromTextMarkerRange(parameter);
    return SysUTF8ToNSString(range.ToString());
  }

  if ([attribute
          isEqualToString:
              NSAccessibilityTextMarkerNodeDebugDescriptionParameterizedAttribute]) {
    BrowserAccessibilityPositionInstance position =
        CreatePositionFromTextMarker(parameter);
    if (position->IsNullPosition())
      return @"nil";
    FML_DCHECK(position->GetAnchor());
    return SysUTF8ToNSString(position->GetAnchor()->ToString());
  }

  if ([attribute
          isEqualToString:
              NSAccessibilityIndexForChildUIElementParameterizedAttribute]) {
    if (![parameter isKindOfClass:[BrowserAccessibilityCocoa class]])
      return nil;

    BrowserAccessibilityCocoa* childCocoaObj =
        (BrowserAccessibilityCocoa*)parameter;
    ax::AXPlatformNodeMac* child = [childCocoaObj owner];
    if (!child)
      return nil;

    if (child->PlatformGetParent() != _owner)
      return nil;

    return @(child->GetIndexInParent());
  }

  return nil;
}

// Returns an array of parameterized attributes names that this object will
// respond to.
- (NSArray*)accessibilityParameterizedAttributeNames {
  TRACE_EVENT1(
      "accessibility",
      "BrowserAccessibilityCocoa::accessibilityParameterizedAttributeNames",
      "role=", ax::ToString([self internalRole]));
  if (![self instanceActive])
    return nil;

  // General attributes.
  NSMutableArray* ret = [NSMutableArray
      arrayWithObjects:
          NSAccessibilityUIElementForTextMarkerParameterizedAttribute,
          NSAccessibilityTextMarkerRangeForUIElementParameterizedAttribute,
          NSAccessibilityLineForTextMarkerParameterizedAttribute,
          NSAccessibilityTextMarkerRangeForLineParameterizedAttribute,
          NSAccessibilityStringForTextMarkerRangeParameterizedAttribute,
          NSAccessibilityTextMarkerForPositionParameterizedAttribute,
          NSAccessibilityBoundsForTextMarkerRangeParameterizedAttribute,
          NSAccessibilityAttributedStringForTextMarkerRangeParameterizedAttribute,
          NSAccessibilityAttributedStringForTextMarkerRangeWithOptionsParameterizedAttribute,
          NSAccessibilityTextMarkerRangeForUnorderedTextMarkersParameterizedAttribute,
          NSAccessibilityNextTextMarkerForTextMarkerParameterizedAttribute,
          NSAccessibilityPreviousTextMarkerForTextMarkerParameterizedAttribute,
          NSAccessibilityLeftWordTextMarkerRangeForTextMarkerParameterizedAttribute,
          NSAccessibilityRightWordTextMarkerRangeForTextMarkerParameterizedAttribute,
          NSAccessibilityLeftLineTextMarkerRangeForTextMarkerParameterizedAttribute,
          NSAccessibilityRightLineTextMarkerRangeForTextMarkerParameterizedAttribute,
          NSAccessibilitySentenceTextMarkerRangeForTextMarkerParameterizedAttribute,
          NSAccessibilityParagraphTextMarkerRangeForTextMarkerParameterizedAttribute,
          NSAccessibilityNextWordEndTextMarkerForTextMarkerParameterizedAttribute,
          NSAccessibilityPreviousWordStartTextMarkerForTextMarkerParameterizedAttribute,
          NSAccessibilityNextLineEndTextMarkerForTextMarkerParameterizedAttribute,
          NSAccessibilityPreviousLineStartTextMarkerForTextMarkerParameterizedAttribute,
          NSAccessibilityNextSentenceEndTextMarkerForTextMarkerParameterizedAttribute,
          NSAccessibilityPreviousSentenceStartTextMarkerForTextMarkerParameterizedAttribute,
          NSAccessibilityNextParagraphEndTextMarkerForTextMarkerParameterizedAttribute,
          NSAccessibilityPreviousParagraphStartTextMarkerForTextMarkerParameterizedAttribute,
          NSAccessibilityStyleTextMarkerRangeForTextMarkerParameterizedAttribute,
          NSAccessibilityLengthForTextMarkerRangeParameterizedAttribute,
          NSAccessibilityEndTextMarkerForBoundsParameterizedAttribute,
          NSAccessibilityStartTextMarkerForBoundsParameterizedAttribute,
          NSAccessibilityLineTextMarkerRangeForTextMarkerParameterizedAttribute,
          NSAccessibilityIndexForChildUIElementParameterizedAttribute,
          NSAccessibilityBoundsForRangeParameterizedAttribute,
          NSAccessibilityStringForRangeParameterizedAttribute,
          NSAccessibilityUIElementCountForSearchPredicateParameterizedAttribute,
          NSAccessibilityUIElementsForSearchPredicateParameterizedAttribute,
          NSAccessibilitySelectTextWithCriteriaParameterizedAttribute, nil];

  if ([[self role] isEqualToString:NSAccessibilityTableRole] ||
      [[self role] isEqualToString:NSAccessibilityGridRole]) {
    [ret addObjectsFromArray:@[
      NSAccessibilityCellForColumnAndRowParameterizedAttribute
    ]];
  }

  if (_owner->HasState(ax::State::kEditable)) {
    [ret addObjectsFromArray:@[
      NSAccessibilityLineForIndexParameterizedAttribute,
      NSAccessibilityRangeForLineParameterizedAttribute,
      NSAccessibilityStringForRangeParameterizedAttribute,
      NSAccessibilityRangeForPositionParameterizedAttribute,
      NSAccessibilityRangeForIndexParameterizedAttribute,
      NSAccessibilityBoundsForRangeParameterizedAttribute,
      NSAccessibilityRTFForRangeParameterizedAttribute,
      NSAccessibilityAttributedStringForRangeParameterizedAttribute,
      NSAccessibilityStyleRangeForIndexParameterizedAttribute
    ]];
  }

  if ([self internalRole] == ax::Role::kStaticText) {
    [ret addObjectsFromArray:@[
      NSAccessibilityBoundsForRangeParameterizedAttribute
    ]];
  }

  if ([self internalRole] == ax::Role::kRootWebArea ||
      [self internalRole] == ax::Role::kWebArea) {
    [ret addObjectsFromArray:@[
      NSAccessibilityTextMarkerIsValidParameterizedAttribute,
      NSAccessibilityIndexForTextMarkerParameterizedAttribute,
      NSAccessibilityTextMarkerForIndexParameterizedAttribute
    ]];
  }

  return ret;
}

// Returns an array of action names that this object will respond to.
- (NSArray*)accessibilityActionNames {
  TRACE_EVENT1("accessibility",
               "BrowserAccessibilityCocoa::accessibilityActionNames",
               "role=", ax::ToString([self internalRole]));
  if (![self instanceActive])
    return nil;

  NSMutableArray* actions = [NSMutableArray
      arrayWithObjects:NSAccessibilityShowMenuAction,
                       NSAccessibilityScrollToVisibleAction, nil];

  // VoiceOver expects the "press" action to be first.
  if (_owner->IsClickable())
    [actions insertObject:NSAccessibilityPressAction atIndex:0];

  if (ax::IsMenuRelated(_owner->GetRole()))
    [actions addObject:NSAccessibilityCancelAction];

  if ([self internalRole] == ax::Role::kSlider ||
      [self internalRole] == ax::Role::kSpinButton) {
    [actions addObjectsFromArray:@[
      NSAccessibilityIncrementAction, NSAccessibilityDecrementAction
    ]];
  }

  return actions;
}

// Returns the list of accessibility attributes that this object supports.
- (NSArray*)accessibilityAttributeNames {
  TRACE_EVENT1("accessibility",
               "BrowserAccessibilityCocoa::accessibilityAttributeNames",
               "role=", ax::ToString([self internalRole]));
  if (![self instanceActive])
    return nil;

  // General attributes.
  NSMutableArray* ret = [NSMutableArray
      arrayWithObjects:NSAccessibilityBlockQuoteLevelAttribute,
                       NSAccessibilityChildrenAttribute,
                       NSAccessibilityDescriptionAttribute,
                       NSAccessibilityDOMClassList,
                       NSAccessibilityDOMIdentifierAttribute,
                       NSAccessibilityElementBusyAttribute,
                       NSAccessibilityEnabledAttribute,
                       NSAccessibilityEndTextMarkerAttribute,
                       NSAccessibilityFocusedAttribute,
                       NSAccessibilityHelpAttribute,
                       NSAccessibilityLinkedUIElementsAttribute,
                       NSAccessibilityParentAttribute,
                       NSAccessibilityPositionAttribute,
                       NSAccessibilityRoleAttribute,
                       NSAccessibilityRoleDescriptionAttribute,
                       NSAccessibilitySelectedAttribute,
                       NSAccessibilitySelectedTextMarkerRangeAttribute,
                       NSAccessibilitySizeAttribute,
                       NSAccessibilityStartTextMarkerAttribute,
                       NSAccessibilitySubroleAttribute,
                       NSAccessibilityTitleAttribute,
                       NSAccessibilityTitleUIElementAttribute,
                       NSAccessibilityTopLevelUIElementAttribute,
                       NSAccessibilityValueAttribute,
                       NSAccessibilityVisitedAttribute,
                       NSAccessibilityWindowAttribute, nil];

  // Specific role attributes.
  NSString* role = [self role];
  NSString* subrole = [self subrole];
  if ([role isEqualToString:NSAccessibilityTableRole] ||
      [role isEqualToString:NSAccessibilityGridRole]) {
    [ret addObjectsFromArray:@[
      NSAccessibilityColumnsAttribute,
      NSAccessibilityVisibleColumnsAttribute,
      NSAccessibilityRowsAttribute,
      NSAccessibilityVisibleRowsAttribute,
      NSAccessibilityVisibleCellsAttribute,
      NSAccessibilityHeaderAttribute,
      NSAccessibilityColumnHeaderUIElementsAttribute,
      NSAccessibilityRowHeaderUIElementsAttribute,
      NSAccessibilityARIAColumnCountAttribute,
      NSAccessibilityARIARowCountAttribute,
    ]];
  } else if ([role isEqualToString:NSAccessibilityColumnRole]) {
    [ret addObjectsFromArray:@[
      NSAccessibilityIndexAttribute, NSAccessibilityHeaderAttribute,
      NSAccessibilityRowsAttribute, NSAccessibilityVisibleRowsAttribute
    ]];
  } else if ([role isEqualToString:NSAccessibilityCellRole]) {
    [ret addObjectsFromArray:@[
      NSAccessibilityColumnIndexRangeAttribute,
      NSAccessibilityRowIndexRangeAttribute,
      NSAccessibilityARIAColumnIndexAttribute,
      NSAccessibilityARIARowIndexAttribute,
      @"AXSortDirection",
    ]];
    if ([self internalRole] != ax::Role::kColumnHeader) {
      [ret addObjectsFromArray:@[
        NSAccessibilityColumnHeaderUIElementsAttribute,
      ]];
    }
    if ([self internalRole] != ax::Role::kRowHeader) {
      [ret addObjectsFromArray:@[
        NSAccessibilityRowHeaderUIElementsAttribute,
      ]];
    }
  } else if ([role isEqualToString:@"AXWebArea"]) {
    [ret addObjectsFromArray:@[
      @"AXLoaded", NSAccessibilityLoadingProgressAttribute
    ]];
  } else if ([role isEqualToString:NSAccessibilityTabGroupRole]) {
    [ret addObject:NSAccessibilityTabsAttribute];
  } else if (_owner->GetData().IsRangeValueSupported()) {
    [ret addObjectsFromArray:@[
      NSAccessibilityMaxValueAttribute, NSAccessibilityMinValueAttribute,
      NSAccessibilityValueDescriptionAttribute
    ]];
  } else if ([role isEqualToString:NSAccessibilityRowRole]) {
    ax::AXPlatformNodeMac* container = _owner->PlatformGetParent();
    if (container && container->GetRole() == ax::Role::kRowGroup)
      container = container->PlatformGetParent();
    if ([subrole isEqualToString:NSAccessibilityOutlineRowSubrole] ||
        (container && container->GetRole() == ax::Role::kTreeGrid)) {
      [ret addObjectsFromArray:@[
        NSAccessibilityDisclosingAttribute,
        NSAccessibilityDisclosedByRowAttribute,
        NSAccessibilityDisclosureLevelAttribute,
        NSAccessibilityDisclosedRowsAttribute
      ]];
    } else {
      [ret addObjectsFromArray:@[ NSAccessibilityIndexAttribute ]];
    }
  } else if ([role isEqualToString:NSAccessibilityListRole]) {
    [ret addObjectsFromArray:@[
      NSAccessibilitySelectedChildrenAttribute,
      NSAccessibilityVisibleChildrenAttribute
    ]];
  } else if ([role isEqualToString:NSAccessibilityOutlineRole]) {
    [ret addObjectsFromArray:@[
      NSAccessibilitySelectedRowsAttribute,
      NSAccessibilityRowsAttribute,
      NSAccessibilityColumnsAttribute,
      NSAccessibilityOrientationAttribute
    ]];
  }

  // Caret navigation and text selection attributes.
  if (_owner->HasState(ax::State::kEditable)) {
    // Add ancestor attributes if not a web area.
    if (![role isEqualToString:@"AXWebArea"]) {
      [ret addObjectsFromArray:@[
        NSAccessibilityEditableAncestorAttribute,
        NSAccessibilityFocusableAncestorAttribute,
        NSAccessibilityHighestEditableAncestorAttribute
      ]];
    }
  }

  if (_owner->GetBoolAttribute(ax::BoolAttribute::kEditableRoot)) {
    [ret addObjectsFromArray:@[
      NSAccessibilityInsertionPointLineNumberAttribute,
      NSAccessibilityNumberOfCharactersAttribute,
      NSAccessibilityPlaceholderValueAttribute,
      NSAccessibilitySelectedTextAttribute,
      NSAccessibilitySelectedTextRangeAttribute,
      NSAccessibilityVisibleCharacterRangeAttribute,
      NSAccessibilityValueAutofillAvailableAttribute,
      // Not currently supported by Chrome:
      // NSAccessibilityValueAutofilledAttribute,
      // Not currently supported by Chrome:
      // NSAccessibilityValueAutofillTypeAttribute
    ]];
  }

  // Add the url attribute only if it has a valid url.
  if ([self url] != nil) {
    [ret addObjectsFromArray:@[ NSAccessibilityURLAttribute ]];
  }

  // Position in set and Set size.
  // Only add these attributes for roles that use posinset and setsize.
  if (ax::IsItemLike(_owner->node()->data().role))
    [ret addObjectsFromArray:@[ NSAccessibilityARIAPosInSetAttribute ]];
  if (ax::IsSetLike(_owner->node()->data().role) ||
      ax::IsItemLike(_owner->node()->data().role))
    [ret addObjectsFromArray:@[ NSAccessibilityARIASetSizeAttribute ]];

  // Live regions.
  if (_owner->HasStringAttribute(ax::StringAttribute::kLiveStatus)) {
    [ret addObjectsFromArray:@[ NSAccessibilityARIALiveAttribute ]];
  }
  if (_owner->HasStringAttribute(ax::StringAttribute::kLiveRelevant)) {
    [ret addObjectsFromArray:@[ NSAccessibilityARIARelevantAttribute ]];
  }
  if (_owner->HasBoolAttribute(ax::BoolAttribute::kLiveAtomic)) {
    [ret addObjectsFromArray:@[ NSAccessibilityARIAAtomicAttribute ]];
  }
  if (_owner->HasBoolAttribute(ax::BoolAttribute::kBusy)) {
    [ret addObjectsFromArray:@[ NSAccessibilityARIABusyAttribute ]];
  }

  std::string dropEffect;
  if (_owner->GetHtmlAttribute("aria-dropeffect", &dropEffect)) {
    [ret addObjectsFromArray:@[ NSAccessibilityDropEffectsAttribute ]];
  }

  std::string grabbed;
  if (_owner->GetHtmlAttribute("aria-grabbed", &grabbed)) {
    [ret addObjectsFromArray:@[ NSAccessibilityGrabbedAttribute ]];
  }

  if (_owner->HasIntAttribute(ax::IntAttribute::kHasPopup)) {
    [ret addObjectsFromArray:@[
      NSAccessibilityHasPopupAttribute, NSAccessibilityHasPopupValueAttribute
    ]];
  }

  if (_owner->HasBoolAttribute(ax::BoolAttribute::kSelected)) {
    [ret addObjectsFromArray:@[ NSAccessibilitySelectedAttribute ]];
  }

  // Add expanded attribute only if it has expanded or collapsed state.
  if (GetState(_owner, ax::State::kExpanded) ||
      GetState(_owner, ax::State::kCollapsed)) {
    [ret addObjectsFromArray:@[ NSAccessibilityExpandedAttribute ]];
  }

  if (GetState(_owner, ax::State::kVertical) ||
      GetState(_owner, ax::State::kHorizontal)) {
    [ret addObjectsFromArray:@[ NSAccessibilityOrientationAttribute ]];
  }

  // Anything focusable or any control:
  if (_owner->HasIntAttribute(ax::IntAttribute::kRestriction) ||
      _owner->HasIntAttribute(ax::IntAttribute::kInvalidState) ||
      _owner->HasState(ax::State::kFocusable)) {
    [ret addObjectsFromArray:@[
      NSAccessibilityAccessKeyAttribute,
      NSAccessibilityInvalidAttribute,
      @"AXRequired",
    ]];
  }

  // TODO(accessibility) What nodes should language be exposed on given new
  // auto detection features?
  //
  // Once lang attribute inheritance becomes stable most nodes will have a
  // language, so it may make more sense to always expose this attribute.
  //
  // For now we expose the language attribute if we have any language set.
  if (_owner->node() && !_owner->node()->GetLanguage().empty()) {
    [ret addObjectsFromArray:@[ NSAccessibilityLanguageAttribute ]];
  }

  if ([self internalRole] == ax::Role::kTextFieldWithComboBox) {
    [ret addObjectsFromArray:@[
      NSAccessibilityOwnsAttribute,
    ]];
  }

  // Title UI Element.
  if (_owner->HasIntListAttribute(
          ax::IntListAttribute::kLabelledbyIds) &&
      _owner->GetIntListAttribute(ax::IntListAttribute::kLabelledbyIds)
              .size() > 0) {
    [ret addObjectsFromArray:@[ NSAccessibilityTitleUIElementAttribute ]];
  }

  if (_owner->HasStringAttribute(ax::StringAttribute::kAutoComplete))
    [ret addObject:NSAccessibilityAutocompleteValueAttribute];

  if ([self shouldExposeTitleUIElement])
    [ret addObject:NSAccessibilityTitleUIElementAttribute];

  // TODO(aboxhall): expose NSAccessibilityServesAsTitleForUIElementsAttribute
  // for elements which are referred to by labelledby or are labels

  return ret;
}

// Returns the index of the child in this objects array of children.
- (NSUInteger)accessibilityGetIndexOf:(id)child {
  TRACE_EVENT1("accessibility",
               "BrowserAccessibilityCocoa::accessibilityGetIndexOf",
               "role=", ax::ToString([self internalRole]));
  if (![self instanceActive])
    return 0;

  NSUInteger index = 0;
  for (BrowserAccessibilityCocoa* childToCheck in [self children]) {
    if ([child isEqual:childToCheck])
      return index;
    ++index;
  }
  return NSNotFound;
}

// Returns whether or not the specified attribute can be set by the
// accessibility API via |accessibilitySetValue:forAttribute:|.
- (BOOL)accessibilityIsAttributeSettable:(NSString*)attribute {
  TRACE_EVENT2("accessibility",
               "BrowserAccessibilityCocoa::accessibilityIsAttributeSettable",
               "role=", ax::ToString([self internalRole]),
               "attribute=", [attribute UTF8String]);
  if (![self instanceActive])
    return NO;

  if ([attribute isEqualToString:NSAccessibilityFocusedAttribute]) {
    if ([self internalRole] == ax::Role::kDateTime)
      return NO;

    return GetState(_owner, ax::State::kFocusable);
  }

  if ([attribute isEqualToString:NSAccessibilityValueAttribute])
    return _owner->HasAction(ax::Action::kSetValue);

  if ([attribute isEqualToString:NSAccessibilitySelectedTextRangeAttribute] &&
      _owner->HasState(ax::State::kEditable)) {
    return YES;
  }

  return NO;
}

// Returns whether or not this object should be ignored in the accessibility
// tree.
- (BOOL)accessibilityIsIgnored {
  TRACE_EVENT1("accessibility",
               "BrowserAccessibilityCocoa::accessibilityIsIgnored",
               "role=", ax::ToString([self internalRole]));
  if (![self instanceActive])
    return YES;

  return [self isIgnored];
}

- (BOOL)isCheckable {
  if (![self instanceActive])
    return NO;

  return _owner->GetData().HasCheckedState() ||
         _owner->GetData().role == ax::Role::kTab;
}

// Performs the given accessibility action on the webkit accessibility object
// that backs this object.
- (void)accessibilityPerformAction:(NSString*)action {
  TRACE_EVENT2("accessibility",
               "BrowserAccessibilityCocoa::accessibilityPerformAction",
               "role=", ax::ToString([self internalRole]),
               "action=", [action UTF8String]);
  if (![self instanceActive])
    return;

  // TODO(dmazzoni): Support more actions.
  BrowserAccessibilityManager* manager = _owner->manager();
  if ([action isEqualToString:NSAccessibilityPressAction]) {
    manager->DoDefaultAction(*_owner);
    if (_owner->GetData().GetRestriction() != ax::Restriction::kNone ||
        ![self isCheckable])
      return;
    // Hack: preemptively set the checked state to what it should become,
    // otherwise VoiceOver will very likely report the old, incorrect state to
    // the user as it requests the value too quickly.
    ax::AXNode* node = _owner->node();
    if (!node)
      return;
    AXNodeData data(node->TakeData());  // Temporarily take data.
    if (data.role == ax::Role::kRadioButton) {
      data.SetCheckedState(ax::CheckedState::kTrue);
    } else if (data.role == ax::Role::kCheckBox ||
               data.role == ax::Role::kSwitch ||
               data.role == ax::Role::kToggleButton) {
      ax::CheckedState checkedState = data.GetCheckedState();
      ax::CheckedState newCheckedState =
          checkedState == ax::CheckedState::kFalse
              ? ax::CheckedState::kTrue
              : ax::CheckedState::kFalse;
      data.SetCheckedState(newCheckedState);
    }
    node->SetData(data);  // Set the data back in the node.
  } else if ([action isEqualToString:NSAccessibilityShowMenuAction]) {
    manager->ShowContextMenu(*_owner);
  } else if ([action isEqualToString:NSAccessibilityScrollToVisibleAction]) {
    manager->ScrollToMakeVisible(*_owner, gfx::Rect());
  } else if ([action isEqualToString:NSAccessibilityIncrementAction]) {
    manager->Increment(*_owner);
  } else if ([action isEqualToString:NSAccessibilityDecrementAction]) {
    manager->Decrement(*_owner);
  }
}

// Returns the description of the given action.
- (NSString*)accessibilityActionDescription:(NSString*)action {
  TRACE_EVENT2("accessibility",
               "BrowserAccessibilityCocoa::accessibilityActionDescription",
               "role=", ax::ToString([self internalRole]),
               "action=", [action UTF8String]);
  if (![self instanceActive])
    return nil;

  return NSAccessibilityActionDescription(action);
}

// Sets an override value for a specific accessibility attribute.
// This class does not support this.
- (BOOL)accessibilitySetOverrideValue:(id)value
                         forAttribute:(NSString*)attribute {
  TRACE_EVENT2(
      "accessibility",
      "BrowserAccessibilityCocoa::accessibilitySetOverrideValue:forAttribute",
      "role=", ax::ToString([self internalRole]),
      "attribute=", [attribute UTF8String]);
  if (![self instanceActive])
    return NO;
  return NO;
}

// Sets the value for an accessibility attribute via the accessibility API.
- (void)accessibilitySetValue:(id)value forAttribute:(NSString*)attribute {
  TRACE_EVENT2("accessibility",
               "BrowserAccessibilityCocoa::accessibilitySetValue:forAttribute",
               "role=", ax::ToString([self internalRole]),
               "attribute=", [attribute UTF8String]);
  if (![self instanceActive])
    return;

  if ([attribute isEqualToString:NSAccessibilityFocusedAttribute]) {
    BrowserAccessibilityManager* manager = _owner->manager();
    NSNumber* focusedNumber = value;
    BOOL focused = [focusedNumber intValue];
    if (focused)
      manager->SetFocus(*_owner);
  }
  if ([attribute isEqualToString:NSAccessibilitySelectedTextRangeAttribute]) {
    NSRange range = [(NSValue*)value rangeValue];
    BrowserAccessibilityManager* manager = _owner->manager();
    manager->SetSelection(
        AXPlatformRange(_owner->CreatePositionAt(range.location),
                        _owner->CreatePositionAt(NSMaxRange(range))));
  }
}

// Returns the deepest accessibility child that should not be ignored.
// It is assumed that the hit test has been narrowed down to this object
// or one of its children, so this will never return nil unless this
// object is invalid.
- (id)accessibilityHitTest:(NSPoint)point {
  TRACE_EVENT2("accessibility",
               "BrowserAccessibilityCocoa::accessibilityHitTest",
               "role=", ax::ToString([self internalRole]),
               "point=", [NSStringFromPoint(point) UTF8String]);
  if (![self instanceActive])
    return nil;

  // The point we receive is in frame coordinates.
  // Convert to screen coordinates and then to physical pixel coordinates.
  BrowserAccessibilityManager* manager = _owner->manager();
  gfx::Point screen_point(point.x, point.y);
  screen_point +=
      manager->GetViewBoundsInScreenCoordinates().OffsetFromOrigin();

  gfx::Point physical_pixel_point =
      IsUseZoomForDSFEnabled()
          ? screen_point
          : ScaleToRoundedPoint(screen_point, manager->device_scale_factor());

  ax::AXPlatformNodeMac* hit =
      manager->CachingAsyncHitTest(physical_pixel_point);
  if (!hit)
    return nil;

  return NSAccessibilityUnignoredAncestor(ToBrowserAccessibilityCocoa(hit));
}

- (BOOL)isEqual:(id)object {
  if (![object isKindOfClass:[BrowserAccessibilityCocoa class]])
    return NO;
  return ([self hash] == [object hash]);
}

- (NSUInteger)hash {
  // Potentially called during dealloc.
  if (![self instanceActive])
    return [super hash];
  return _owner->GetId();
}

- (BOOL)accessibilityNotifiesWhenDestroyed {
  TRACE_EVENT0("accessibility",
               "BrowserAccessibilityCocoa::accessibilityNotifiesWhenDestroyed");
  // Indicate that BrowserAccessibilityCocoa will post a notification when it's
  // destroyed (see -detach). This allows VoiceOver to do some internal things
  // more efficiently.
  return YES;
}

@end
