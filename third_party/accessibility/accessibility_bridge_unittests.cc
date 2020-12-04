// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "accessibility_bridge.h"
#include "test_flutter_accessibility.h"

#include "gtest/gtest.h"

namespace ax {
namespace testing {

TEST(AccessibilityBridgeTest, basicTest) {
  AccessibilityBridge bridge(nullptr);
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

  TestFlutterAccessibility* root_node = static_cast<TestFlutterAccessibility*>(
      bridge.GetFlutterAccessibilityFromID(0));
  TestFlutterAccessibility* child1_node =
      static_cast<TestFlutterAccessibility*>(
          bridge.GetFlutterAccessibilityFromID(1));
  TestFlutterAccessibility* child2_node =
      static_cast<TestFlutterAccessibility*>(
          bridge.GetFlutterAccessibilityFromID(2));
  ASSERT_EQ(root_node->GetChildCount(), 2);
  ASSERT_EQ(root_node->GetData().child_ids[0], 1);
  ASSERT_EQ(root_node->GetData().child_ids[1], 2);
  ASSERT_EQ(root_node->GetName(), "root");

  ASSERT_EQ(child1_node->GetChildCount(), 0);
  ASSERT_EQ(child1_node->GetName(), "child 1");

  ASSERT_EQ(child2_node->GetChildCount(), 0);
  ASSERT_EQ(child2_node->GetName(), "child 2");
}

TEST(AccessibilityBridgeTest, canFireChildrenChangedCorrectly) {
  AccessibilityBridge bridge(nullptr);
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

  TestFlutterAccessibility* root_node = static_cast<TestFlutterAccessibility*>(
      bridge.GetFlutterAccessibilityFromID(0));
  TestFlutterAccessibility* child1_node =
      static_cast<TestFlutterAccessibility*>(
          bridge.GetFlutterAccessibilityFromID(1));
  ASSERT_EQ(root_node->GetChildCount(), 1);
  ASSERT_EQ(root_node->GetData().child_ids[0], 1);
  ASSERT_EQ(root_node->GetName(), "root");

  ASSERT_EQ(child1_node->GetChildCount(), 0);
  ASSERT_EQ(child1_node->GetName(), "child 1");
  root_node->accessibilitiy_events.clear();

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

  root_node = static_cast<TestFlutterAccessibility*>(
      bridge.GetFlutterAccessibilityFromID(0));

  ASSERT_EQ(root_node->GetChildCount(), 2);
  ASSERT_EQ(root_node->GetData().child_ids[0], 1);
  ASSERT_EQ(root_node->GetData().child_ids[1], 2);
  ASSERT_EQ(root_node->accessibilitiy_events.size(), size_t{1});
  ASSERT_EQ(root_node->accessibilitiy_events[0].event_params.event,
            AXEventGenerator::Event::CHILDREN_CHANGED);
}

TEST(AccessibilityBridgeTest, canHandleSelectionChangeCorrect) {
  AccessibilityBridge bridge(nullptr);
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

  TestFlutterAccessibility* root_node = static_cast<TestFlutterAccessibility*>(
      bridge.GetFlutterAccessibilityFromID(0));
  AXTree* tree = bridge.GetAXTree();
  ASSERT_EQ(tree->data().sel_anchor_object_id, AXNode::kInvalidAXID);
  root_node->accessibilitiy_events.clear();

  // Update the selection.
  root.text_selection_base = 0;
  root.text_selection_extent = 5;
  bridge.AddFlutterSemanticsNodeUpdate(&root);

  bridge.CommitUpdates();

  ASSERT_EQ(tree->data().sel_anchor_object_id, 0);
  ASSERT_EQ(tree->data().sel_anchor_offset, 0);
  ASSERT_EQ(tree->data().sel_focus_object_id, 0);
  ASSERT_EQ(tree->data().sel_focus_offset, 5);
  ASSERT_EQ(root_node->accessibilitiy_events.size(), size_t{2});
  ASSERT_EQ(root_node->accessibilitiy_events[0].event_params.event,
            AXEventGenerator::Event::DOCUMENT_SELECTION_CHANGED);
  ASSERT_EQ(root_node->accessibilitiy_events[1].event_params.event,
            AXEventGenerator::Event::OTHER_ATTRIBUTE_CHANGED);
}

}  // namespace testing
}  // namespace ax
