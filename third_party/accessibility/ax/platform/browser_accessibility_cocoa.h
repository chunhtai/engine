// Copyright (c) 2012 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef CONTENT_BROWSER_ACCESSIBILITY_BROWSER_ACCESSIBILITY_COCOA_H_
#define CONTENT_BROWSER_ACCESSIBILITY_BROWSER_ACCESSIBILITY_COCOA_H_

#import <Cocoa/Cocoa.h>
#include <vector>
#include <string>

#include "flutter/fml/platform/darwin/scoped_nsobject.h"
#include "third_party/skia/include/core/SkRect.h"

#include "../ax_export.h"
#include "../ax_node_position.h"
#include "ax_platform_node_mac.h"
// #import "base/mac/scoped_nsobject.h"
// #include "base/strings/string16.h"
// #include "content/browser/accessibility/browser_accessibility.h"
// #include "content/browser/accessibility/browser_accessibility_manager.h"
// #include "content/common/AX_EXPORT.h"

namespace ax {

class AXPlatformNodeMac;

// Used to store changes in edit fields, required by VoiceOver in order to
// support character echo and other announcements during editing.
struct AX_EXPORT AXTextEdit {
  AXTextEdit();
  AXTextEdit(std::u16string inserted_text,
             std::u16string deleted_text,
             id edit_text_marker);
  AXTextEdit(const AXTextEdit& other);
  ~AXTextEdit();

  bool IsEmpty() const { return inserted_text.empty() && deleted_text.empty(); }

  std::u16string inserted_text;
  std::u16string deleted_text;
  id edit_text_marker;
};

// Returns true if the given object is AXTextMarker object.
bool IsAXTextMarker(id);

// Returns true if the given object is AXTextMarkerRange object.
bool IsAXTextMarkerRange(id);

// Returns browser accessibility position for the given AXTextMarker.
AX_EXPORT ax::AXNodePosition::AXPositionInstance AXTextMarkerToPosition(id);

// Returns browser accessibility range for the given AXTextMarkerRange.
ax::AXNodePosition::AXRangeType AXTextMarkerRangeToRange(id);

// Returns AXTextMarkerRange for the given browser accessibility positions.
id AXTextMarkerRangeFrom(id anchor_textmarker, id focus_textmarker);

}  // namespace content

// BrowserAccessibilityCocoa is a cocoa wrapper around the BrowserAccessibility
// object. The renderer converts webkit's accessibility tree into a
// WebAccessibility tree and passes it to the browser process over IPC.
// This class converts it into a format Cocoa can query.
@interface BrowserAccessibilityCocoa : NSAccessibilityElement {
 @private
  ax::AXPlatformNodeMac* _owner;
  fml::scoped_nsobject<NSMutableArray> _children;
  // Stores the previous value of an edit field.
  std::u16string _oldValue;
}

// This creates a cocoa browser accessibility object around
// the cross platform BrowserAccessibility object, which can't be nullptr.
- (instancetype)initWithObject:(ax::AXPlatformNodeMac*)accessibility;

// Clear this object's pointer to the wrapped BrowserAccessibility object
// because the wrapped object has been deleted, but this object may
// persist if the system still has references to it.
- (void)detach;

// Invalidate children for a non-ignored ancestor (including self).
- (void)childrenChanged;

// Convenience method to get the internal, cross-platform role
// from browserAccessibility_.
- (ax::Role)internalRole;

// Convenience method to get the BrowserAccessibilityDelegate from
// the manager.
// - (content::BrowserAccessibilityDelegate*)delegate;

// Get the BrowserAccessibility that this object wraps.
- (ax::AXPlatformNodeMac*)owner;

// Computes the text that was added or deleted in a text field after an edit.
- (ax::AXTextEdit)computeTextEdit;

// Determines if this object is alive, i.e. it hasn't been detached.
- (BOOL)instanceActive;

// Convert from the view's local coordinate system (with the origin in the upper
// left) to the primary NSScreen coordinate system (with the origin in the lower
// left).
- (NSRect)rectInScreen:(SkRect)rect;

- (void)getTreeItemDescendantNodeIds:(std::vector<int32_t>*)tree_item_ids;

// Return the method name for the given attribute. For testing only.
- (NSString*)methodNameForAttribute:(NSString*)attribute;

// Swap the children array with the given scoped_nsobject.
- (void)swapChildren:(fml::scoped_nsobject<NSMutableArray>*)other;

- (NSString*)valueForRange:(NSRange)range;
- (NSAttributedString*)attributedValueForRange:(NSRange)range;

// Internally-used property.
@property(nonatomic, readonly) NSPoint origin;

@property(nonatomic, readonly) NSString* accessKey;
@property(nonatomic, readonly) NSNumber* ariaAtomic;
@property(nonatomic, readonly) NSNumber* ariaBusy;
@property(nonatomic, readonly) NSString* ariaLive;
@property(nonatomic, readonly) NSNumber* ariaPosInSet;
@property(nonatomic, readonly) NSString* ariaRelevant;
@property(nonatomic, readonly) NSNumber* ariaSetSize;
@property(nonatomic, readonly) NSArray* children;
@property(nonatomic, readonly) NSArray* columns;
@property(nonatomic, readonly) NSArray* columnHeaders;
@property(nonatomic, readonly) NSValue* columnIndexRange;
@property(nonatomic, readonly) NSString* descriptionForAccessibility;
@property(nonatomic, readonly) NSNumber* disclosing;
@property(nonatomic, readonly) id disclosedByRow;
@property(nonatomic, readonly) NSNumber* disclosureLevel;
@property(nonatomic, readonly) id disclosedRows;
@property(nonatomic, readonly) NSString* dropEffects;
// Returns the object at the root of the current edit field, if any.
@property(nonatomic, readonly) id editableAncestor;
@property(nonatomic, readonly) NSNumber* enabled;
// Returns a text marker that points to the last character in the document that
// can be selected with Voiceover.
@property(nonatomic, readonly) id endTextMarker;
@property(nonatomic, readonly) NSNumber* expanded;
@property(nonatomic, readonly) NSNumber* focused;
@property(nonatomic, readonly) NSNumber* grabbed;
@property(nonatomic, readonly) id header;
@property(nonatomic, readonly) NSString* help;
// isIgnored returns whether or not the accessibility object
// should be ignored by the accessibility hierarchy.
@property(nonatomic, readonly, getter=isIgnored) BOOL ignored;
// Index of a row, column, or tree item.
@property(nonatomic, readonly) NSNumber* index;
@property(nonatomic, readonly) NSNumber* insertionPointLineNumber;
@property(nonatomic, readonly) NSString* invalid;
@property(nonatomic, readonly) NSNumber* isMultiSelectable;
@property(nonatomic, readonly) NSString* placeholderValue;
@property(nonatomic, readonly) NSNumber* loaded;
@property(nonatomic, readonly) NSNumber* loadingProgress;
@property(nonatomic, readonly) NSNumber* maxValue;
@property(nonatomic, readonly) NSNumber* minValue;
@property(nonatomic, readonly) NSNumber* numberOfCharacters;
@property(nonatomic, readonly) NSString* orientation;
@property(nonatomic, readonly) id parent;
@property(nonatomic, readonly) NSValue* position;
@property(nonatomic, readonly) NSNumber* required;
// A string indicating the role of this object as far as accessibility
// is concerned.
@property(nonatomic, readonly) NSString* role;
@property(nonatomic, readonly) NSString* roleDescription;
@property(nonatomic, readonly) NSArray* rowHeaders;
@property(nonatomic, readonly) NSValue* rowIndexRange;
@property(nonatomic, readonly) NSArray* rows;
// The object is selected as a whole.
@property(nonatomic, readonly) NSNumber* selected;
@property(nonatomic, readonly) NSArray* selectedChildren;
@property(nonatomic, readonly) NSString* selectedText;
@property(nonatomic, readonly) NSValue* selectedTextRange;
@property(nonatomic, readonly) id selectedTextMarkerRange;
@property(nonatomic, readonly) NSValue* size;
@property(nonatomic, readonly) NSString* sortDirection;
// Returns a text marker that points to the first character in the document that
// can be selected with Voiceover.
@property(nonatomic, readonly) id startTextMarker;
// A string indicating the subrole of this object as far as accessibility
// is concerned.
@property(nonatomic, readonly) NSString* subrole;
// The tabs owned by a tablist.
@property(nonatomic, readonly) NSArray* tabs;
@property(nonatomic, readonly) NSString* title;
@property(nonatomic, readonly) id titleUIElement;
@property(nonatomic, readonly) NSURL* url;
@property(nonatomic, readonly) NSString* value;
@property(nonatomic, readonly) NSString* valueDescription;
@property(nonatomic, readonly) NSValue* visibleCharacterRange;
@property(nonatomic, readonly) NSArray* visibleCells;
@property(nonatomic, readonly) NSArray* visibleChildren;
@property(nonatomic, readonly) NSArray* visibleColumns;
@property(nonatomic, readonly) NSArray* visibleRows;
@property(nonatomic, readonly) NSNumber* visited;
@property(nonatomic, readonly) id window;
@end

// Returns AXTextMarker for the given browser accessibility position.
id AXTextMarkerFrom(const BrowserAccessibilityCocoa* anchor,
                    int offset,
                    ax::TextAffinity affinity);

#endif  // CONTENT_BROWSER_ACCESSIBILITY_BROWSER_ACCESSIBILITY_COCOA_H_
