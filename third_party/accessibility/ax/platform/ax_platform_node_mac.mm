// Copyright 2014 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ax_platform_node_mac.h"

#import <Cocoa/Cocoa.h>
#include <stddef.h>

#include "ax/ax_action_data.h"
#include "ax/ax_node_data.h"
#include "ax/ax_role_properties.h"
#include "base/no_destructor.h"
#import "gfx/mac/coordinate_conversion.h"

#include "ax_platform_node.h"
#include "ax_platform_node_delegate.h"

namespace {

NSString* const NSAccessibilityScrollToVisibleAction = @"AXScrollToVisible";

// Same length as web content/WebKit.
static int kLiveRegionDebounceMillis = 20;

using RoleMap = std::map<ax::Role, NSString*>;
using EventMap = std::map<ax::Event, NSString*>;
using ActionList = std::vector<std::pair<ax::Action, NSString*>>;

struct AnnouncementSpec {
  fml::scoped_nsobject<NSString> announcement;
  fml::scoped_nsobject<NSWindow> window;
  bool is_polite;
};

RoleMap BuildRoleMap() {
  const RoleMap::value_type roles[] = {
      {ax::Role::kAbbr, NSAccessibilityGroupRole},
      {ax::Role::kAlert, NSAccessibilityGroupRole},
      {ax::Role::kAlertDialog, NSAccessibilityGroupRole},
      {ax::Role::kAnchor, NSAccessibilityGroupRole},
      {ax::Role::kApplication, NSAccessibilityGroupRole},
      {ax::Role::kArticle, NSAccessibilityGroupRole},
      {ax::Role::kAudio, NSAccessibilityGroupRole},
      {ax::Role::kBanner, NSAccessibilityGroupRole},
      {ax::Role::kBlockquote, NSAccessibilityGroupRole},
      {ax::Role::kButton, NSAccessibilityButtonRole},
      {ax::Role::kCanvas, NSAccessibilityImageRole},
      {ax::Role::kCaption, NSAccessibilityGroupRole},
      {ax::Role::kCell, @"AXCell"},
      {ax::Role::kCheckBox, NSAccessibilityCheckBoxRole},
      {ax::Role::kCode, NSAccessibilityGroupRole},
      {ax::Role::kColorWell, NSAccessibilityColorWellRole},
      {ax::Role::kColumn, NSAccessibilityColumnRole},
      {ax::Role::kColumnHeader, @"AXCell"},
      {ax::Role::kComboBoxGrouping, NSAccessibilityGroupRole},
      {ax::Role::kComboBoxMenuButton, NSAccessibilityPopUpButtonRole},
      {ax::Role::kComment, NSAccessibilityGroupRole},
      {ax::Role::kComplementary, NSAccessibilityGroupRole},
      {ax::Role::kContentDeletion, NSAccessibilityGroupRole},
      {ax::Role::kContentInsertion, NSAccessibilityGroupRole},
      {ax::Role::kContentInfo, NSAccessibilityGroupRole},
      {ax::Role::kDate, @"AXDateField"},
      {ax::Role::kDateTime, @"AXDateField"},
      {ax::Role::kDefinition, NSAccessibilityGroupRole},
      {ax::Role::kDescriptionListDetail, NSAccessibilityGroupRole},
      {ax::Role::kDescriptionList, NSAccessibilityListRole},
      {ax::Role::kDescriptionListTerm, NSAccessibilityGroupRole},
      {ax::Role::kDialog, NSAccessibilityGroupRole},
      {ax::Role::kDetails, NSAccessibilityGroupRole},
      {ax::Role::kDirectory, NSAccessibilityListRole},
      // If Mac supports AXExpandedChanged event with
      // NSAccessibilityDisclosureTriangleRole, We should update
      // ax::Role::kDisclosureTriangle mapping to
      // NSAccessibilityDisclosureTriangleRole. http://crbug.com/558324
      {ax::Role::kDisclosureTriangle, NSAccessibilityButtonRole},
      {ax::Role::kDocAbstract, NSAccessibilityGroupRole},
      {ax::Role::kDocAcknowledgments, NSAccessibilityGroupRole},
      {ax::Role::kDocAfterword, NSAccessibilityGroupRole},
      {ax::Role::kDocAppendix, NSAccessibilityGroupRole},
      {ax::Role::kDocBackLink, NSAccessibilityLinkRole},
      {ax::Role::kDocBiblioEntry, NSAccessibilityGroupRole},
      {ax::Role::kDocBibliography, NSAccessibilityGroupRole},
      {ax::Role::kDocBiblioRef, NSAccessibilityLinkRole},
      {ax::Role::kDocChapter, NSAccessibilityGroupRole},
      {ax::Role::kDocColophon, NSAccessibilityGroupRole},
      {ax::Role::kDocConclusion, NSAccessibilityGroupRole},
      {ax::Role::kDocCover, NSAccessibilityImageRole},
      {ax::Role::kDocCredit, NSAccessibilityGroupRole},
      {ax::Role::kDocCredits, NSAccessibilityGroupRole},
      {ax::Role::kDocDedication, NSAccessibilityGroupRole},
      {ax::Role::kDocEndnote, NSAccessibilityGroupRole},
      {ax::Role::kDocEndnotes, NSAccessibilityGroupRole},
      {ax::Role::kDocEpigraph, NSAccessibilityGroupRole},
      {ax::Role::kDocEpilogue, NSAccessibilityGroupRole},
      {ax::Role::kDocErrata, NSAccessibilityGroupRole},
      {ax::Role::kDocExample, NSAccessibilityGroupRole},
      {ax::Role::kDocFootnote, NSAccessibilityGroupRole},
      {ax::Role::kDocForeword, NSAccessibilityGroupRole},
      {ax::Role::kDocGlossary, NSAccessibilityGroupRole},
      {ax::Role::kDocGlossRef, NSAccessibilityLinkRole},
      {ax::Role::kDocIndex, NSAccessibilityGroupRole},
      {ax::Role::kDocIntroduction, NSAccessibilityGroupRole},
      {ax::Role::kDocNoteRef, NSAccessibilityLinkRole},
      {ax::Role::kDocNotice, NSAccessibilityGroupRole},
      {ax::Role::kDocPageBreak, NSAccessibilitySplitterRole},
      {ax::Role::kDocPageList, NSAccessibilityGroupRole},
      {ax::Role::kDocPart, NSAccessibilityGroupRole},
      {ax::Role::kDocPreface, NSAccessibilityGroupRole},
      {ax::Role::kDocPrologue, NSAccessibilityGroupRole},
      {ax::Role::kDocPullquote, NSAccessibilityGroupRole},
      {ax::Role::kDocQna, NSAccessibilityGroupRole},
      {ax::Role::kDocSubtitle, @"AXHeading"},
      {ax::Role::kDocTip, NSAccessibilityGroupRole},
      {ax::Role::kDocToc, NSAccessibilityGroupRole},
      {ax::Role::kDocument, NSAccessibilityGroupRole},
      {ax::Role::kEmbeddedObject, NSAccessibilityGroupRole},
      {ax::Role::kEmphasis, NSAccessibilityGroupRole},
      {ax::Role::kFigcaption, NSAccessibilityGroupRole},
      {ax::Role::kFigure, NSAccessibilityGroupRole},
      {ax::Role::kFooter, NSAccessibilityGroupRole},
      {ax::Role::kFooterAsNonLandmark, NSAccessibilityGroupRole},
      {ax::Role::kForm, NSAccessibilityGroupRole},
      {ax::Role::kGenericContainer, NSAccessibilityGroupRole},
      {ax::Role::kGraphicsDocument, NSAccessibilityGroupRole},
      {ax::Role::kGraphicsObject, NSAccessibilityGroupRole},
      {ax::Role::kGraphicsSymbol, NSAccessibilityImageRole},
      // Should be NSAccessibilityGridRole but VoiceOver treating it like
      // a list as of 10.12.6, so following WebKit and using table role:
      {ax::Role::kGrid, NSAccessibilityTableRole},  // crbug.com/753925
      {ax::Role::kGroup, NSAccessibilityGroupRole},
      {ax::Role::kHeader, NSAccessibilityGroupRole},
      {ax::Role::kHeaderAsNonLandmark, NSAccessibilityGroupRole},
      {ax::Role::kHeading, @"AXHeading"},
      {ax::Role::kIframe, NSAccessibilityGroupRole},
      {ax::Role::kIframePresentational, NSAccessibilityGroupRole},
      {ax::Role::kIgnored, NSAccessibilityUnknownRole},
      {ax::Role::kImage, NSAccessibilityImageRole},
      {ax::Role::kImageMap, NSAccessibilityGroupRole},
      {ax::Role::kInputTime, @"AXTimeField"},
      {ax::Role::kLabelText, NSAccessibilityGroupRole},
      {ax::Role::kLayoutTable, NSAccessibilityGroupRole},
      {ax::Role::kLayoutTableCell, NSAccessibilityGroupRole},
      {ax::Role::kLayoutTableRow, NSAccessibilityGroupRole},
      {ax::Role::kLegend, NSAccessibilityGroupRole},
      {ax::Role::kLineBreak, NSAccessibilityGroupRole},
      {ax::Role::kLink, NSAccessibilityLinkRole},
      {ax::Role::kList, NSAccessibilityListRole},
      {ax::Role::kListBox, NSAccessibilityListRole},
      {ax::Role::kListBoxOption, NSAccessibilityStaticTextRole},
      {ax::Role::kListItem, NSAccessibilityGroupRole},
      {ax::Role::kListMarker, @"AXListMarker"},
      {ax::Role::kLog, NSAccessibilityGroupRole},
      {ax::Role::kMain, NSAccessibilityGroupRole},
      {ax::Role::kMark, NSAccessibilityGroupRole},
      {ax::Role::kMarquee, NSAccessibilityGroupRole},
      {ax::Role::kMath, NSAccessibilityGroupRole},
      {ax::Role::kMenu, NSAccessibilityMenuRole},
      {ax::Role::kMenuBar, NSAccessibilityMenuBarRole},
      {ax::Role::kMenuItem, NSAccessibilityMenuItemRole},
      {ax::Role::kMenuItemCheckBox, NSAccessibilityMenuItemRole},
      {ax::Role::kMenuItemRadio, NSAccessibilityMenuItemRole},
      {ax::Role::kMenuListOption, NSAccessibilityMenuItemRole},
      {ax::Role::kMenuListPopup, NSAccessibilityMenuRole},
      {ax::Role::kMeter, NSAccessibilityLevelIndicatorRole},
      {ax::Role::kNavigation, NSAccessibilityGroupRole},
      {ax::Role::kNone, NSAccessibilityGroupRole},
      {ax::Role::kNote, NSAccessibilityGroupRole},
      {ax::Role::kParagraph, NSAccessibilityGroupRole},
      {ax::Role::kPdfActionableHighlight, NSAccessibilityButtonRole},
      {ax::Role::kPluginObject, NSAccessibilityGroupRole},
      {ax::Role::kPopUpButton, NSAccessibilityPopUpButtonRole},
      {ax::Role::kPortal, NSAccessibilityButtonRole},
      {ax::Role::kPre, NSAccessibilityGroupRole},
      {ax::Role::kPresentational, NSAccessibilityGroupRole},
      {ax::Role::kProgressIndicator, NSAccessibilityProgressIndicatorRole},
      {ax::Role::kRadioButton, NSAccessibilityRadioButtonRole},
      {ax::Role::kRadioGroup, NSAccessibilityRadioGroupRole},
      {ax::Role::kRegion, NSAccessibilityGroupRole},
      {ax::Role::kRootWebArea, @"AXWebArea"},
      {ax::Role::kRow, NSAccessibilityRowRole},
      {ax::Role::kRowGroup, NSAccessibilityGroupRole},
      {ax::Role::kRowHeader, @"AXCell"},
      // TODO(accessibility) What should kRuby be? It's not listed? Any others
      // missing? Maybe use switch statement so that compiler doesn't allow us
      // to miss any.
      {ax::Role::kRubyAnnotation, NSAccessibilityUnknownRole},
      {ax::Role::kScrollBar, NSAccessibilityScrollBarRole},
      {ax::Role::kSearch, NSAccessibilityGroupRole},
      {ax::Role::kSearchBox, NSAccessibilityTextFieldRole},
      {ax::Role::kSection, NSAccessibilityGroupRole},
      {ax::Role::kSlider, NSAccessibilitySliderRole},
      {ax::Role::kSliderThumb, NSAccessibilityValueIndicatorRole},
      {ax::Role::kSpinButton, NSAccessibilityIncrementorRole},
      {ax::Role::kSplitter, NSAccessibilitySplitterRole},
      {ax::Role::kStaticText, NSAccessibilityStaticTextRole},
      {ax::Role::kStatus, NSAccessibilityGroupRole},
      {ax::Role::kSuggestion, NSAccessibilityGroupRole},
      {ax::Role::kSvgRoot, NSAccessibilityGroupRole},
      {ax::Role::kSwitch, NSAccessibilityCheckBoxRole},
      {ax::Role::kStrong, NSAccessibilityGroupRole},
      {ax::Role::kTab, NSAccessibilityRadioButtonRole},
      {ax::Role::kTable, NSAccessibilityTableRole},
      {ax::Role::kTableHeaderContainer, NSAccessibilityGroupRole},
      {ax::Role::kTabList, NSAccessibilityTabGroupRole},
      {ax::Role::kTabPanel, NSAccessibilityGroupRole},
      {ax::Role::kTerm, NSAccessibilityGroupRole},
      {ax::Role::kTextField, NSAccessibilityTextFieldRole},
      {ax::Role::kTextFieldWithComboBox, NSAccessibilityComboBoxRole},
      {ax::Role::kTime, NSAccessibilityGroupRole},
      {ax::Role::kTimer, NSAccessibilityGroupRole},
      {ax::Role::kTitleBar, NSAccessibilityStaticTextRole},
      {ax::Role::kToggleButton, NSAccessibilityCheckBoxRole},
      {ax::Role::kToolbar, NSAccessibilityToolbarRole},
      {ax::Role::kTooltip, NSAccessibilityGroupRole},
      {ax::Role::kTree, NSAccessibilityOutlineRole},
      {ax::Role::kTreeGrid, NSAccessibilityTableRole},
      {ax::Role::kTreeItem, NSAccessibilityRowRole},
      {ax::Role::kVideo, NSAccessibilityGroupRole},
      {ax::Role::kWebArea, @"AXWebArea"},
      // Use the group role as the BrowserNativeWidgetWindow already provides
      // a kWindow role, and having extra window roles, which are treated
      // specially by screen readers, can break their ability to find the
      // content window. See http://crbug.com/875843 for more information.
      {ax::Role::kWindow, NSAccessibilityGroupRole},
  };

  return RoleMap(begin(roles), end(roles));
}

RoleMap BuildSubroleMap() {
  const RoleMap::value_type subroles[] = {
      {ax::Role::kAlert, @"AXApplicationAlert"},
      {ax::Role::kAlertDialog, @"AXApplicationAlertDialog"},
      {ax::Role::kApplication, @"AXLandmarkApplication"},
      {ax::Role::kArticle, @"AXDocumentArticle"},
      {ax::Role::kBanner, @"AXLandmarkBanner"},
      {ax::Role::kCode, @"AXCodeStyleGroup"},
      {ax::Role::kComplementary, @"AXLandmarkComplementary"},
      {ax::Role::kContentDeletion, @"AXDeleteStyleGroup"},
      {ax::Role::kContentInsertion, @"AXInsertStyleGroup"},
      {ax::Role::kContentInfo, @"AXLandmarkContentInfo"},
      {ax::Role::kDefinition, @"AXDefinition"},
      {ax::Role::kDescriptionListDetail, @"AXDefinition"},
      {ax::Role::kDescriptionListTerm, @"AXTerm"},
      {ax::Role::kDialog, @"AXApplicationDialog"},
      {ax::Role::kDocument, @"AXDocument"},
      {ax::Role::kEmphasis, @"AXEmphasisStyleGroup"},
      {ax::Role::kFooter, @"AXLandmarkContentInfo"},
      {ax::Role::kForm, @"AXLandmarkForm"},
      {ax::Role::kGraphicsDocument, @"AXDocument"},
      {ax::Role::kHeader, @"AXLandmarkBanner"},
      {ax::Role::kLog, @"AXApplicationLog"},
      {ax::Role::kMain, @"AXLandmarkMain"},
      {ax::Role::kMarquee, @"AXApplicationMarquee"},
      {ax::Role::kMath, @"AXDocumentMath"},
      {ax::Role::kNavigation, @"AXLandmarkNavigation"},
      {ax::Role::kNote, @"AXDocumentNote"},
      {ax::Role::kRegion, @"AXLandmarkRegion"},
      {ax::Role::kSearch, @"AXLandmarkSearch"},
      {ax::Role::kSearchBox, @"AXSearchField"},
      {ax::Role::kSection, @"AXLandmarkRegion"},
      {ax::Role::kStatus, @"AXApplicationStatus"},
      {ax::Role::kStrong, @"AXStrongStyleGroup"},
      {ax::Role::kSwitch, @"AXSwitch"},
      {ax::Role::kTabPanel, @"AXTabPanel"},
      {ax::Role::kTerm, @"AXTerm"},
      {ax::Role::kTime, @"AXTimeGroup"},
      {ax::Role::kTimer, @"AXApplicationTimer"},
      {ax::Role::kToggleButton, @"AXToggleButton"},
      {ax::Role::kTooltip, @"AXUserInterfaceTooltip"},
      {ax::Role::kTreeItem, NSAccessibilityOutlineRowSubrole},
  };

  return RoleMap(begin(subroles), end(subroles));
}

EventMap BuildEventMap() {
  const EventMap::value_type events[] = {
      {ax::Event::kCheckedStateChanged, NSAccessibilityValueChangedNotification},
      {ax::Event::kFocus, NSAccessibilityFocusedUIElementChangedNotification},
      {ax::Event::kFocusContext, NSAccessibilityFocusedUIElementChangedNotification},
      {ax::Event::kTextChanged, NSAccessibilityTitleChangedNotification},
      {ax::Event::kValueChanged, NSAccessibilityValueChangedNotification},
      {ax::Event::kTextSelectionChanged, NSAccessibilitySelectedTextChangedNotification},
      // TODO(patricialor): Add more events.
  };

  return EventMap(begin(events), end(events));
}

ActionList BuildActionList() {
  const ActionList::value_type entries[] = {
      // NSAccessibilityPressAction must come first in this list.
      {ax::Action::kDoDefault, NSAccessibilityPressAction},
      {ax::Action::kScrollToMakeVisible, NSAccessibilityScrollToVisibleAction},
      {ax::Action::kDecrement, NSAccessibilityDecrementAction},
      {ax::Action::kIncrement, NSAccessibilityIncrementAction},
      {ax::Action::kShowContextMenu, NSAccessibilityShowMenuAction},
  };
  return ActionList(begin(entries), end(entries));
}

const ActionList& GetActionList() {
  static const base::NoDestructor<ActionList> action_map(BuildActionList());
  return *action_map;
}

void PostAnnouncementNotification(NSString* announcement, NSWindow* window, bool is_polite) {
  NSAccessibilityPriorityLevel priority =
      is_polite ? NSAccessibilityPriorityMedium : NSAccessibilityPriorityHigh;
  NSDictionary* notification_info =
      @{NSAccessibilityAnnouncementKey : announcement,
        NSAccessibilityPriorityKey : @(priority)};
  // On Mojave, announcements from an inactive window aren't spoken.
  NSAccessibilityPostNotificationWithUserInfo(
      window, NSAccessibilityAnnouncementRequestedNotification, notification_info);
}
void NotifyMacEvent(AXPlatformNodeCocoa* target, ax::Event event_type) {
  NSString* notification = [AXPlatformNodeCocoa nativeNotificationFromAXEvent:event_type];
  if (notification)
    NSAccessibilityPostNotification(target, notification);
}

// Returns true if |action| should be added implicitly for |data|.
bool HasImplicitAction(const ax::AXNodeData& data, ax::Action action) {
  return action == ax::Action::kDoDefault && data.IsClickable();
}

// For roles that show a menu for the default action, ensure "show menu" also
// appears in available actions, but only if that's not already used for a
// context menu. It will be mapped back to the default action when performed.
bool AlsoUseShowMenuActionForDefaultAction(const ax::AXNodeData& data) {
  return HasImplicitAction(data, ax::Action::kDoDefault) &&
         !data.HasAction(ax::Action::kShowContextMenu) && data.role == ax::Role::kPopUpButton;
}

}  // namespace

@interface AXPlatformNodeCocoa (Private)
// Helper function for string attributes that don't require extra processing.
- (NSString*)getStringAttribute:(ax::StringAttribute)attribute;
// Returns AXValue, or nil if AXValue isn't an NSString.
- (NSString*)getAXValueAsString;
// Returns the data necessary to queue an NSAccessibility announcement if
// |eventType| should be announced, or nullptr otherwise.
- (std::unique_ptr<AnnouncementSpec>)announcementForEvent:(ax::Event)eventType;
// Ask the system to announce |announcementText|. This is debounced to happen
// at most every |kLiveRegionDebounceMillis| per node, with only the most
// recent announcement text read, to account for situations with multiple
// notifications happening one after another (for example, results for
// find-in-page updating rapidly as they come in from subframes).
- (void)scheduleLiveRegionAnnouncement:(std::unique_ptr<AnnouncementSpec>)announcement;
@end

@implementation AXPlatformNodeCocoa {
  ax::AXPlatformNodeBase* _node;  // Weak. Retains us.
  std::unique_ptr<AnnouncementSpec> _pendingAnnouncement;
}

@synthesize node = _node;

+ (NSString*)nativeRoleFromAXRole:(ax::Role)role {
  static const base::NoDestructor<RoleMap> role_map(BuildRoleMap());
  RoleMap::const_iterator it = role_map->find(role);
  return it != role_map->end() ? it->second : NSAccessibilityUnknownRole;
}

+ (NSString*)nativeSubroleFromAXRole:(ax::Role)role {
  static const base::NoDestructor<RoleMap> subrole_map(BuildSubroleMap());
  RoleMap::const_iterator it = subrole_map->find(role);
  return it != subrole_map->end() ? it->second : nil;
}

+ (NSString*)nativeNotificationFromAXEvent:(ax::Event)event {
  static const base::NoDestructor<EventMap> event_map(BuildEventMap());
  EventMap::const_iterator it = event_map->find(event);
  return it != event_map->end() ? it->second : nil;
}

- (instancetype)initWithNode:(ax::AXPlatformNodeBase*)node {
  if ((self = [super init])) {
    _node = node;
  }
  return self;
}

- (void)detach {
  if (!_node)
    return;
  _node = nil;
  NSAccessibilityPostNotification(self, NSAccessibilityUIElementDestroyedNotification);
}

- (NSRect)boundsInScreen {
  if (!_node || !_node->GetDelegate())
    return NSZeroRect;
  return gfx::ScreenRectToNSRect(_node->GetDelegate()->GetBoundsRect(
      ax::AXCoordinateSystem::kScreenDIPs, ax::AXClippingBehavior::kClipped));
}

- (NSString*)getStringAttribute:(ax::StringAttribute)attribute {
  std::string attributeValue;
  if (_node->GetStringAttribute(attribute, &attributeValue))
    return @(attributeValue.data());
  return nil;
}

- (NSString*)getAXValueAsString {
  id value = [self AXValueInternal];
  return [value isKindOfClass:[NSString class]] ? value : nil;
}

- (NSString*)getName {
  return @(_node->GetName().data());
}

- (std::unique_ptr<AnnouncementSpec>)announcementForEvent:(ax::Event)eventType {
  // Only alerts and live region changes should be announced.
  FML_DCHECK(eventType == ax::Event::kAlert || eventType == ax::Event::kLiveRegionChanged);
  std::string liveStatus = _node->GetStringAttribute(ax::StringAttribute::kLiveStatus);
  // If live status is explicitly set to off, don't announce.
  if (liveStatus == "off")
    return nullptr;

  NSString* name = [self getName];
  NSString* announcementText = name;
  if ([announcementText length] <= 0) {
    std::wstring_convert<std::codecvt_utf8_utf16<char16_t>, char16_t> convert;
    announcementText = @(convert.to_bytes(_node->GetInnerText()).data());
  }
  if ([announcementText length] == 0)
    return nullptr;

  auto announcement = std::make_unique<AnnouncementSpec>();
  announcement->announcement = fml::scoped_nsobject<NSString>([announcementText retain]);
  announcement->window = fml::scoped_nsobject<NSWindow>([[self AXWindowInternal] retain]);
  announcement->is_polite = liveStatus != "assertive";
  return announcement;
}

- (void)scheduleLiveRegionAnnouncement:(std::unique_ptr<AnnouncementSpec>)announcement {
  if (_pendingAnnouncement) {
    // An announcement is already in flight, so just reset the contents. This is
    // threadsafe because the dispatch is on the main queue.
    _pendingAnnouncement = std::move(announcement);
    return;
  }

  _pendingAnnouncement = std::move(announcement);
  dispatch_after(kLiveRegionDebounceMillis * NSEC_PER_MSEC, dispatch_get_main_queue(), ^{
    if (!_pendingAnnouncement) {
      return;
    }
    PostAnnouncementNotification(_pendingAnnouncement->announcement, _pendingAnnouncement->window,
                                 _pendingAnnouncement->is_polite);
    _pendingAnnouncement.reset();
  });
}
// NSAccessibility informal protocol implementation.

- (BOOL)accessibilityIsIgnored {
  if (!_node)
    return YES;

  return [[self AXRoleInternal] isEqualToString:NSAccessibilityUnknownRole] ||
         _node->GetData().HasState(ax::State::kInvisible);
}

- (id)accessibilityHitTest:(NSPoint)point {
  if (!NSPointInRect(point, [self boundsInScreen]))
    return nil;

  for (id child in [[self AXChildrenInternal] reverseObjectEnumerator]) {
    if (!NSPointInRect(point, [child accessibilityFrame]))
      continue;
    if (id foundChild = [child accessibilityHitTest:point])
      return foundChild;
  }

  // Hit self, but not any child.
  return NSAccessibilityUnignoredAncestor(self);
}

- (BOOL)accessibilityNotifiesWhenDestroyed {
  return YES;
}

- (id)accessibilityFocusedUIElement {
  return _node ? _node->GetDelegate()->GetFocus() : nil;
}

// This function and accessibilityPerformAction:, while deprecated, are a) still
// called by AppKit internally and b) not implemented by NSAccessibilityElement,
// so this class needs its own implementations.
- (NSArray*)accessibilityActionNames {
  if (!_node)
    return @[];

  fml::scoped_nsobject<NSMutableArray> axActions([[NSMutableArray alloc] init]);

  const ax::AXNodeData& data = _node->GetData();
  const ActionList& action_list = GetActionList();

  // VoiceOver expects the "press" action to be first. Note that some roles
  // should be given a press action implicitly.
  FML_DCHECK([action_list[0].second isEqualToString:NSAccessibilityPressAction]);
  for (const auto& item : action_list) {
    if (data.HasAction(item.first) || HasImplicitAction(data, item.first))
      [axActions addObject:item.second];
  }

  if (AlsoUseShowMenuActionForDefaultAction(data))
    [axActions addObject:NSAccessibilityShowMenuAction];

  return axActions.autorelease();
}

- (void)accessibilityPerformAction:(NSString*)action {
  // Actions are performed asynchronously, so it's always possible for an object
  // to change its mind after previously reporting an action as available.
  if (![[self accessibilityActionNames] containsObject:action])
    return;

  ax::AXActionData data;
  if ([action isEqualToString:NSAccessibilityShowMenuAction] &&
      AlsoUseShowMenuActionForDefaultAction(_node->GetData())) {
    data.action = ax::Action::kDoDefault;
  } else {
    for (const ActionList::value_type& entry : GetActionList()) {
      if ([action isEqualToString:entry.second]) {
        data.action = entry.first;
        break;
      }
    }
  }

  // Note ax::AX_ACTIONs which are just overwriting an accessibility attribute
  // are already implemented in -accessibilitySetValue:forAttribute:, so ignore
  // those here.

  if (data.action != ax::Action::kNone)
    _node->GetDelegate()->AccessibilityPerformAction(data);
}

- (NSString*)AXRoleInternal {
  if (!_node)
    return nil;

  return [[self class] nativeRoleFromAXRole:_node->GetData().role];
}

- (NSString*)AXRoleDescriptionInternal {
  switch (_node->GetData().role) {
    case ax::Role::kTab:
      // There is no NSAccessibilityTabRole or similar (AXRadioButton is used
      // instead). Do the same as NSTabView and put "tab" in the description.
      // return [l10n_util::GetNSStringWithFixup(IDS_ACCNAME_TAB_ROLE_DESCRIPTION)
      //     lowercaseString];
      return nil;
    case ax::Role::kDisclosureTriangle:
      // return [l10n_util::GetNSStringWithFixup(
      //     IDS_ACCNAME_DISCLOSURE_TRIANGLE_ROLE_DESCRIPTION) lowercaseString];
      return nil;
    default:
      break;
  }
  return NSAccessibilityRoleDescription([self AXRoleInternal], [self AXSubroleInternal]);
}

- (NSString*)AXSubroleInternal {
  ax::Role role = _node->GetData().role;
  switch (role) {
    case ax::Role::kTextField:
      if (_node->GetData().HasState(ax::State::kProtected))
        return NSAccessibilitySecureTextFieldSubrole;
      break;
    default:
      break;
  }
  return [AXPlatformNodeCocoa nativeSubroleFromAXRole:role];
}

- (NSString*)AXHelpInternal {
  // TODO(aleventhal) Key shortcuts attribute should eventually get
  // its own field. Follow what WebKit does for aria-keyshortcuts, see
  // https://bugs.webkit.org/show_bug.cgi?id=159215 (WebKit bug).
  NSString* desc = [self getStringAttribute:ax::StringAttribute::kDescription];
  NSString* key = [self getStringAttribute:ax::StringAttribute::kKeyShortcuts];
  if (!desc.length)
    return key.length ? key : @"";
  if (!key.length)
    return desc;
  return [NSString stringWithFormat:@"%@ %@", desc, key];
}

- (id)AXValueInternal {
  ax::Role role = _node->GetData().role;
  if (role == ax::Role::kTab)
    return [self AXSelectedInternal];

  if (ax::IsNameExposedInAXValueForRole(role))
    return [self getName];

  if (_node->IsPlatformCheckable()) {
    // Mixed checkbox state not currently supported in views, but could be.
    // See browser_accessibility_cocoa.mm for details.
    const auto checkedState =
        static_cast<ax::CheckedState>(_node->GetIntAttribute(ax::IntAttribute::kCheckedState));
    return checkedState == ax::CheckedState::kTrue ? @1 : @0;
  }
  return [self getStringAttribute:ax::StringAttribute::kValue];
}

- (NSNumber*)AXEnabledInternal {
  return @(_node->GetData().GetRestriction() != ax::Restriction::kDisabled);
}

- (NSNumber*)AXFocusedInternal {
  if (_node->GetData().HasState(ax::State::kFocusable))
    return @(_node->GetDelegate()->GetFocus() == _node->GetNativeViewAccessible());
  return @NO;
}

- (id)AXParentInternal {
  if (!_node)
    return nil;
  return NSAccessibilityUnignoredAncestor(_node->GetParent());
}

- (NSArray*)AXChildrenInternal {
  if (!_node)
    return @[];

  int count = _node->GetChildCount();
  NSMutableArray* children = [NSMutableArray arrayWithCapacity:count];
  for (auto child_iterator_ptr = _node->GetDelegate()->ChildrenBegin();
       *child_iterator_ptr != *_node->GetDelegate()->ChildrenEnd(); ++(*child_iterator_ptr)) {
    [children addObject:child_iterator_ptr->GetNativeViewAccessible()];
  }
  return NSAccessibilityUnignoredChildren(children);
}

- (id)AXWindowInternal {
  return _node->GetDelegate()->GetNSWindow();
}

- (id)AXTopLevelUIElementInternal {
  return [self AXWindowInternal];
}

- (NSValue*)AXPositionInternal {
  return [NSValue valueWithPoint:self.boundsInScreen.origin];
}

- (NSValue*)AXSizeInternal {
  return [NSValue valueWithSize:self.boundsInScreen.size];
}

- (NSString*)AXTitleInternal {
  if (ax::IsNameExposedInAXValueForRole(_node->GetData().role))
    return @"";

  return [self getName];
}

- (NSNumber*)AXSelectedInternal {
  return @(_node->GetData().GetBoolAttribute(ax::BoolAttribute::kSelected));
}

- (NSString*)AXPlaceholderValueInternal {
  return [self getStringAttribute:ax::StringAttribute::kPlaceholder];
}

- (NSString*)AXMenuItemMarkChar {
  if (!ax::IsMenuItem(_node->GetData().role))
    return nil;

  const auto checkedState =
      static_cast<ax::CheckedState>(_node->GetIntAttribute(ax::IntAttribute::kCheckedState));
  if (checkedState == ax::CheckedState::kTrue) {
    return @"\xE2\x9C\x93";  // UTF-8 for unicode 0x2713, "check mark"
  }

  return @"";
}

- (NSString*)AXSelectedTextInternal {
  NSRange selectedTextRange;
  [[self AXSelectedTextRangeInternal] getValue:&selectedTextRange];
  return [[self getAXValueAsString] substringWithRange:selectedTextRange];
}

- (NSValue*)AXSelectedTextRangeInternal {
  // Selection might not be supported. Return (NSRange){0,0} in that case.
  int start = 0, end = 0;
  if (_node->IsPlainTextField()) {
    start = _node->GetIntAttribute(ax::IntAttribute::kTextSelStart);
    end = _node->GetIntAttribute(ax::IntAttribute::kTextSelEnd);
  }

  // NSRange cannot represent the direction the text was selected in.
  return [NSValue valueWithRange:{static_cast<NSUInteger>(std::min(start, end)),
                                  static_cast<NSUInteger>(abs(end - start))}];
}

- (NSNumber*)AXNumberOfCharactersInternal {
  return @([[self getAXValueAsString] length]);
}

- (NSValue*)AXVisibleCharacterRangeInternal {
  return [NSValue valueWithRange:{0, [[self getAXValueAsString] length]}];
}

- (NSNumber*)AXInsertionPointLineNumberInternal {
  // Multiline is not supported on views.
  return @0;
}

// Method based accessibility APIs.

- (NSString*)description {
  return [NSString stringWithFormat:@"%@ - %@ (%@)", [super description], [self AXTitleInternal],
                                    [self AXRoleInternal]];
}

// The methods below implement the NSAccessibility protocol. These methods
// appear to be the minimum needed to avoid AppKit refusing to handle the
// element or crashing internally. Most of the remaining old API methods (the
// ones from NSObject) are implemented in terms of the new NSAccessibility
// methods.
//
// TODO(https://crbug.com/386671): Does this class need to implement the various
// accessibilityPerformFoo methods, or are the stub implementations from
// NSAccessibilityElement sufficient?
- (NSArray*)accessibilityChildren {
  return [self AXChildrenInternal];
}

- (BOOL)isAccessibilityElement {
  if (!_node)
    return NO;
  return (![[self AXRoleInternal] isEqualToString:NSAccessibilityUnknownRole] &&
          !_node->GetData().HasState(ax::State::kInvisible));
}
- (BOOL)isAccessibilityEnabled {
  return [[self AXEnabledInternal] boolValue];
}
- (NSRect)accessibilityFrame {
  return [self boundsInScreen];
}

- (NSString*)accessibilityLabel {
  // accessibilityLabel is "a short description of the accessibility element",
  // and accessibilityTitle is "the title of the accessibility element"; at
  // least in Chromium, the title usually is a short description of the element,
  // so it also functions as a label.
  return [self AXTitleInternal];
}

- (NSString*)accessibilityTitle {
  return [self AXTitleInternal];
}

- (id)accessibilityValue {
  return [self AXValueInternal];
}

- (NSAccessibilityRole)accessibilityRole {
  return [self AXRoleInternal];
}

- (NSString*)accessibilityRoleDescription {
  return [self AXRoleDescriptionInternal];
}

- (NSAccessibilitySubrole)accessibilitySubrole {
  return [self AXSubroleInternal];
}

- (NSString*)accessibilityHelp {
  return [self AXHelpInternal];
}

- (id)accessibilityParent {
  return [self AXParentInternal];
}

- (id)accessibilityWindow {
  return [self AXWindowInternal];
}

- (id)accessibilityTopLevelUIElement {
  return [self AXTopLevelUIElementInternal];
}

- (BOOL)accessibilitySelected {
  return [[self AXSelectedInternal] boolValue];
}

- (BOOL)isAccessibilitySelectorAllowed:(SEL)selector {
  if (!_node)
    return NO;

  const ax::Restriction restriction = _node->GetData().GetRestriction();
  if (restriction == ax::Restriction::kDisabled)
    return NO;

  if (selector == @selector(setAccessibilityValue:)) {
    // Tabs use the radio button role on Mac, so they are selected by calling
    // setSelected on an individual tab, rather than by setting the selected
    // element on the tabstrip as a whole.
    if (_node->GetData().role == ax::Role::kTab) {
      return !_node->GetData().GetBoolAttribute(ax::BoolAttribute::kSelected);
    }
    return restriction != ax::Restriction::kReadOnly;
  }

  // TODO(https://crbug.com/692362): Once the underlying bug in
  // views::Textfield::SetSelectionRange() described in that bug is fixed,
  // remove the check here; right now, this check serves to prevent
  // accessibility clients from trying to set the selection range, which won't
  // work because of 692362.
  if (selector == @selector(setAccessibilitySelectedText:) ||
      selector == @selector(setAccessibilitySelectedTextRange:) ||
      selector == @selector(setAccessibilitySelectedTextMarkerRange:)) {
    return restriction != ax::Restriction::kReadOnly;
  }

  if (selector == @selector(setAccessibilityFocused:))
    return _node->GetData().HasState(ax::State::kFocusable);

  // TODO(https://crbug.com/386671): What about role-specific selectors?
  return [super isAccessibilitySelectorAllowed:selector];
}

- (void)setAccessibilityValue:(id)value {
  if (!_node)
    return;

  ax::AXActionData data;
  data.action =
      _node->GetData().role == ax::Role::kTab ? ax::Action::kSetSelection : ax::Action::kSetValue;
  if ([value isKindOfClass:[NSString class]]) {
    data.value = std::string([value UTF8String]);
  } else if ([value isKindOfClass:[NSValue class]]) {
    // TODO(https://crbug.com/386671): Is this case actually needed? The
    // NSObject accessibility implementation supported this, but can it actually
    // occur?
    NSRange range = [value rangeValue];
    data.anchor_offset = range.location;
    data.focus_offset = NSMaxRange(range);
  }
  _node->GetDelegate()->AccessibilityPerformAction(data);
}

- (void)setAccessibilityFocused:(BOOL)isFocused {
  if (!_node)
    return;
  ax::AXActionData data;
  data.action = isFocused ? ax::Action::kFocus : ax::Action::kBlur;
  _node->GetDelegate()->AccessibilityPerformAction(data);
}

- (void)setAccessibilitySelectedText:(NSString*)text {
  if (!_node)
    return;
  ax::AXActionData data;
  data.action = ax::Action::kReplaceSelectedText;
  data.value = std::string([text UTF8String]);

  _node->GetDelegate()->AccessibilityPerformAction(data);
}

- (void)setAccessibilitySelectedTextRange:(NSRange)range {
  if (!_node)
    return;
  ax::AXActionData data;
  data.action = ax::Action::kSetSelection;
  data.anchor_offset = range.location;
  data.focus_offset = NSMaxRange(range);
  _node->GetDelegate()->AccessibilityPerformAction(data);
}

// "Configuring Text Elements" section of the NSAccessibility formal protocol.
// These are all "required" methods, although in practice the ones that are left
// FML_DCHECK(false) seem to not be called anywhere (and were FML_DCHECK false in
// the old API as well).

- (NSInteger)accessibilityInsertionPointLineNumber {
  return [[self AXInsertionPointLineNumberInternal] integerValue];
}

- (NSInteger)accessibilityNumberOfCharacters {
  if (!_node)
    return 0;
  return [[self AXNumberOfCharactersInternal] integerValue];
}

- (NSString*)accessibilityPlaceholderValue {
  if (!_node)
    return nil;

  return [self AXPlaceholderValueInternal];
}

- (NSString*)accessibilitySelectedText {
  if (!_node)
    return nil;

  return [self AXSelectedTextInternal];
}

- (NSRange)accessibilitySelectedTextRange {
  if (!_node)
    return NSMakeRange(0, 0);

  NSRange r;
  [[self AXSelectedTextRangeInternal] getValue:&r];
  return r;
}

- (NSArray*)accessibilitySelectedTextRanges {
  if (!_node)
    return nil;

  return @[ [self AXSelectedTextRangeInternal] ];
}

- (NSRange)accessibilitySharedCharacterRange {
  if (!_node)
    return NSMakeRange(0, 0);

  NSRange r;
  [[self AXSelectedTextRangeInternal] getValue:&r];
  return r;
}

- (NSArray*)accessibilitySharedTextUIElements {
  if (!_node)
    return nil;

  return @[ self ];
}

- (NSRange)accessibilityVisibleCharacterRange {
  if (!_node)
    return NSMakeRange(0, 0);

  return [[self AXVisibleCharacterRangeInternal] rangeValue];
}

- (NSString*)accessibilityStringForRange:(NSRange)range {
  if (!_node)
    return nil;

  return [[self getAXValueAsString] substringWithRange:range];
}

- (NSAttributedString*)accessibilityAttributedStringForRange:(NSRange)range {
  if (!_node)
    return nil;
  // TODO(https://crbug.com/958811): Implement this for real.
  fml::scoped_nsobject<NSAttributedString> attributedString(
      [[NSAttributedString alloc] initWithString:[self accessibilityStringForRange:range]]);
  return attributedString.autorelease();
}

- (NSData*)accessibilityRTFForRange:(NSRange)range {
  return nil;
}

- (NSRect)accessibilityFrameForRange:(NSRange)range {
  return NSZeroRect;
}

- (NSInteger)accessibilityLineForIndex:(NSInteger)index {
  // Views textfields are single-line.
  return 0;
}

- (NSRange)accessibilityRangeForIndex:(NSInteger)index {
  FML_DCHECK(false);
  return NSMakeRange(0, 0);
}

- (NSRange)accessibilityStyleRangeForIndex:(NSInteger)index {
  if (!_node)
    return NSMakeRange(0, 0);

  // TODO(https://crbug.com/958811): Implement this for real.
  return NSMakeRange(0, [self accessibilityNumberOfCharacters]);
}

- (NSRange)accessibilityRangeForLine:(NSInteger)line {
  if (!_node)
    return NSMakeRange(0, 0);

  if (line != 0) {
    FML_LOG(ERROR) << "Views textfields are single-line.";
    FML_DCHECK(false);
  }
  return NSMakeRange(0, [self accessibilityNumberOfCharacters]);
}

- (NSRange)accessibilityRangeForPosition:(NSPoint)point {
  FML_DCHECK(false);
  return NSMakeRange(0, 0);
}

// "Setting the Focus" section of the NSAccessibility formal protocol.
// These are all "required" methods.

- (NSArray*)accessibilitySharedFocusElements {
  if (![[self AXFocusedInternal] boolValue])
    return nil;
  return @[ self ];
}
- (id)accessibilityFocusedWindow {
  if (![[self AXFocusedInternal] boolValue])
    return nil;
  return self;
}
- (id)accessibilityApplicationFocusedUIElement {
  if (![[self AXFocusedInternal] boolValue])
    return nil;
  return self;
}
- (BOOL)isAccessibilityFocused {
  return [[self AXFocusedInternal] boolValue];
}

@end

namespace ax {

// static
AXPlatformNode* AXPlatformNode::Create(AXPlatformNodeDelegate* delegate) {
  AXPlatformNodeBase* node = new AXPlatformNodeMac();
  node->Init(delegate);
  return node;
}

// static
AXPlatformNode* AXPlatformNode::FromNativeViewAccessible(gfx::NativeViewAccessible accessible) {
  if ([accessible isKindOfClass:[AXPlatformNodeCocoa class]])
    return [accessible node];
  return nullptr;
}

AXPlatformNodeMac::AXPlatformNodeMac() {}

AXPlatformNodeMac::~AXPlatformNodeMac() {}

void AXPlatformNodeMac::Destroy() {
  if (native_node_)
    [native_node_ detach];
  AXPlatformNodeBase::Destroy();
}

// On Mac, the checked state is mapped to AXValue.
bool AXPlatformNodeMac::IsPlatformCheckable() const {
  if (GetData().role == ax::Role::kTab) {
    // On Mac, tabs are exposed as radio buttons, and are treated as checkable.
    // Also, the internal State::kSelected is be mapped to checked via AXValue.
    return true;
  }

  return AXPlatformNodeBase::IsPlatformCheckable();
}

gfx::NativeViewAccessible AXPlatformNodeMac::GetNativeViewAccessible() {
  if (!native_node_)
    native_node_.reset([[AXPlatformNodeCocoa alloc] initWithNode:this]);
  return native_node_.get();
}

void AXPlatformNodeMac::NotifyAccessibilityEvent(ax::Event event_type) {
  AXPlatformNodeBase::NotifyAccessibilityEvent(event_type);
  GetNativeViewAccessible();
  // Handle special cases.

  // Alerts and live regions go through the announcement API instead of the
  // regular NSAccessibility notification system.
  if (event_type == ax::Event::kAlert || event_type == ax::Event::kLiveRegionChanged) {
    if (auto announcement = [native_node_ announcementForEvent:event_type]) {
      [native_node_ scheduleLiveRegionAnnouncement:std::move(announcement)];
    }
    return;
  }
  if (event_type == ax::Event::kSelection) {
    ax::Role role = GetData().role;
    if (ax::IsMenuItem(role)) {
      // On Mac, map menu item selection to a focus event.
      NotifyMacEvent(native_node_, ax::Event::kFocus);
      return;
    } else if (ax::IsListItem(role)) {
      if (AXPlatformNodeBase* container = GetSelectionContainer()) {
        const ax::AXNodeData& data = container->GetData();
        if (data.role == ax::Role::kListBox && !data.HasState(ax::State::kMultiselectable) &&
            GetDelegate()->GetFocus() == GetNativeViewAccessible()) {
          NotifyMacEvent(native_node_, ax::Event::kFocus);
          return;
        }
      }
    }
  }
  // Otherwise, use mappings between ax::Event and NSAccessibility
  // notifications from the EventMap above.
  NotifyMacEvent(native_node_, event_type);
}

void AXPlatformNodeMac::AnnounceText(const std::u16string& text) {
  std::wstring_convert<std::codecvt_utf8_utf16<char16_t>, char16_t> convert;
  PostAnnouncementNotification(@(convert.to_bytes(text).data()), [native_node_ AXWindowInternal],
                               false);
}

bool IsNameExposedInAXValueForRole(ax::Role role) {
  switch (role) {
    case ax::Role::kListBoxOption:
    case ax::Role::kListMarker:
    case ax::Role::kMenuListOption:
    case ax::Role::kStaticText:
    case ax::Role::kTitleBar:
      return true;
    default:
      return false;
  }
}

void AXPlatformNodeMac::AddAttributeToList(const char* name,
                                           const char* value,
                                           PlatformAttributeList* attributes) {
  FML_DCHECK(false);
}

}  // namespace ax
