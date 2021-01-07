// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "accessibility_bridge.h"

#include "gtest/gtest.h"

#include "test_accessibility_bridge.h"

namespace ui {
namespace testing {

TEST(AccessibilityBridgeTest, basicTest) {
  AccessibilityBridge bridge(
      std::make_unique<TestAccessibilityBridgeDelegate>(), nullptr);
  FlutterSemanticsNode root;
  root.id = 0;
  root.label = "root";
  root.hint = "";
  root.value = "";
  root.increased_value = "";
  root.decreased_value = "";
  root.child_count = 2;
  int32_t children[] = {1, 2};
  root.children_in_traversal_order = children;
  root.custom_accessibility_actions_count = 0;
  bridge.AddFlutterSemanticsNodeUpdate(&root);

  FlutterSemanticsNode child1;
  child1.id = 1;
  child1.label = "child 1";
  child1.hint = "";
  child1.value = "";
  child1.increased_value = "";
  child1.decreased_value = "";
  child1.child_count = 0;
  child1.custom_accessibility_actions_count = 0;
  bridge.AddFlutterSemanticsNodeUpdate(&child1);

  FlutterSemanticsNode child2;
  child2.id = 2;
  child2.label = "child 2";
  child2.hint = "";
  child2.value = "";
  child2.increased_value = "";
  child2.decreased_value = "";
  child2.child_count = 0;
  child2.custom_accessibility_actions_count = 0;
  bridge.AddFlutterSemanticsNodeUpdate(&child2);

  bridge.CommitUpdates();

  FlutterAccessibility* root_node = bridge.GetFlutterAccessibilityFromID(0);
  FlutterAccessibility* child1_node = bridge.GetFlutterAccessibilityFromID(1);
  FlutterAccessibility* child2_node = bridge.GetFlutterAccessibilityFromID(2);
  EXPECT_EQ(root_node->GetChildCount(), 2);
  EXPECT_EQ(root_node->GetData().child_ids[0], 1);
  EXPECT_EQ(root_node->GetData().child_ids[1], 2);
  EXPECT_EQ(root_node->GetName(), "root");

  EXPECT_EQ(child1_node->GetChildCount(), 0);
  EXPECT_EQ(child1_node->GetName(), "child 1");

  EXPECT_EQ(child2_node->GetChildCount(), 0);
  EXPECT_EQ(child2_node->GetName(), "child 2");
}

TEST(AccessibilityBridgeTest, canFireChildrenChangedCorrectly) {
  AccessibilityBridge bridge(
      std::make_unique<TestAccessibilityBridgeDelegate>(), nullptr);
  TestAccessibilityBridgeDelegate* delegate =
      (TestAccessibilityBridgeDelegate*)bridge.GetDelegate();
  FlutterSemanticsNode root;
  root.id = 0;
  root.flags = static_cast<FlutterSemanticsFlag>(0);
  root.actions = static_cast<FlutterSemanticsAction>(0);
  root.text_selection_base = -1;
  root.text_selection_extent = -1;
  root.label = "root";
  root.hint = "";
  root.value = "";
  root.increased_value = "";
  root.decreased_value = "";
  root.child_count = 1;
  int32_t children[] = {1};
  root.children_in_traversal_order = children;
  root.custom_accessibility_actions_count = 0;
  bridge.AddFlutterSemanticsNodeUpdate(&root);

  FlutterSemanticsNode child1;
  child1.id = 1;
  child1.flags = static_cast<FlutterSemanticsFlag>(0);
  child1.actions = static_cast<FlutterSemanticsAction>(0);
  child1.text_selection_base = -1;
  child1.text_selection_extent = -1;
  child1.label = "child 1";
  child1.hint = "";
  child1.value = "";
  child1.increased_value = "";
  child1.decreased_value = "";
  child1.child_count = 0;
  child1.custom_accessibility_actions_count = 0;
  bridge.AddFlutterSemanticsNodeUpdate(&child1);

  bridge.CommitUpdates();

  FlutterAccessibility* root_node = bridge.GetFlutterAccessibilityFromID(0);
  FlutterAccessibility* child1_node = bridge.GetFlutterAccessibilityFromID(1);
  EXPECT_EQ(root_node->GetChildCount(), 1);
  EXPECT_EQ(root_node->GetData().child_ids[0], 1);
  EXPECT_EQ(root_node->GetName(), "root");

  EXPECT_EQ(child1_node->GetChildCount(), 0);
  EXPECT_EQ(child1_node->GetName(), "child 1");
  delegate->accessibilitiy_events.clear();

  // Add a child to root.
  root.child_count = 2;
  int32_t new_children[] = {1, 2};
  root.children_in_traversal_order = new_children;
  bridge.AddFlutterSemanticsNodeUpdate(&root);

  FlutterSemanticsNode child2;
  child2.id = 2;
  child2.flags = static_cast<FlutterSemanticsFlag>(0);
  child2.actions = static_cast<FlutterSemanticsAction>(0);
  child2.text_selection_base = -1;
  child2.text_selection_extent = -1;
  child2.label = "child 2";
  child2.hint = "";
  child2.value = "";
  child2.increased_value = "";
  child2.decreased_value = "";
  child2.child_count = 0;
  child2.custom_accessibility_actions_count = 0;
  bridge.AddFlutterSemanticsNodeUpdate(&child2);

  bridge.CommitUpdates();

  root_node = bridge.GetFlutterAccessibilityFromID(0);

  EXPECT_EQ(root_node->GetChildCount(), 2);
  EXPECT_EQ(root_node->GetData().child_ids[0], 1);
  EXPECT_EQ(root_node->GetData().child_ids[1], 2);
  EXPECT_EQ(delegate->accessibilitiy_events.size(), size_t{2});
  std::set<AXEventGenerator::Event> actual_event;
  actual_event.insert(delegate->accessibilitiy_events[0].event_params.event);
  actual_event.insert(delegate->accessibilitiy_events[1].event_params.event);
  EXPECT_NE(actual_event.find(AXEventGenerator::Event::CHILDREN_CHANGED),
            actual_event.end());
  EXPECT_NE(actual_event.find(AXEventGenerator::Event::SUBTREE_CREATED),
            actual_event.end());
}

TEST(AccessibilityBridgeTest, canHandleSelectionChangeCorrectly) {
  AccessibilityBridge bridge(
      std::make_unique<TestAccessibilityBridgeDelegate>(), nullptr);
  FlutterSemanticsNode root;
  root.id = 0;
  root.flags = FlutterSemanticsFlag::kFlutterSemanticsFlagIsTextField;
  root.actions = static_cast<FlutterSemanticsAction>(0);
  root.text_selection_base = -1;
  root.text_selection_extent = -1;
  root.label = "root";
  root.hint = "";
  root.value = "";
  root.increased_value = "";
  root.decreased_value = "";
  root.child_count = 0;
  root.custom_accessibility_actions_count = 0;
  bridge.AddFlutterSemanticsNodeUpdate(&root);

  bridge.CommitUpdates();

  TestAccessibilityBridgeDelegate* delegate =
      (TestAccessibilityBridgeDelegate*)bridge.GetDelegate();
  AXTree* tree = bridge.GetAXTree();
  EXPECT_EQ(tree->data().sel_anchor_object_id, AXNode::kInvalidAXID);
  delegate->accessibilitiy_events.clear();

  // Update the selection.
  root.text_selection_base = 0;
  root.text_selection_extent = 5;
  bridge.AddFlutterSemanticsNodeUpdate(&root);

  bridge.CommitUpdates();

  EXPECT_EQ(tree->data().sel_anchor_object_id, 0);
  EXPECT_EQ(tree->data().sel_anchor_offset, 0);
  EXPECT_EQ(tree->data().sel_focus_object_id, 0);
  EXPECT_EQ(tree->data().sel_focus_offset, 5);
  EXPECT_EQ(delegate->accessibilitiy_events.size(), size_t{2});
  EXPECT_EQ(delegate->accessibilitiy_events[0].event_params.event,
            AXEventGenerator::Event::DOCUMENT_SELECTION_CHANGED);
  EXPECT_EQ(delegate->accessibilitiy_events[1].event_params.event,
            AXEventGenerator::Event::OTHER_ATTRIBUTE_CHANGED);
}

}  // namespace testing
}  // namespace ui
