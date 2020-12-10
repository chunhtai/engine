// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef ACCESSIBILITY_AX_AX_TREE_ID_H_
#define ACCESSIBILITY_AX_AX_TREE_ID_H_

#include <string>

#include "base/no_destructor.h"

#include "ax_base_export.h"
#include "ax_enums.h"

namespace mojo {
template <typename DataViewType, typename T>
struct UnionTraits;
}

namespace ax {
namespace mojom {
class AXTreeIDDataView;
}
}  // namespace ax

namespace ax {

// A unique ID representing an accessibility tree.
class AX_BASE_EXPORT AXTreeID {
 public:
  // Create an Unknown AXTreeID.
  AXTreeID();

  // Copy constructor.
  AXTreeID(const AXTreeID& other);

  // Create a new unique AXTreeID.
  static AXTreeID CreateNewAXTreeID();

  // Unserialize an AXTreeID from a string. This is used so that tree IDs
  // can be stored compactly as a string attribute in an AXNodeData, and
  // so that AXTreeIDs can be passed to JavaScript bindings in the
  // automation API.
  static AXTreeID FromString(const std::string& string);

  // Convenience method to unserialize an AXTreeID from an UnguessableToken.
  // static AXTreeID FromToken(const base::UnguessableToken& token);

  AXTreeID& operator=(const AXTreeID& other);

  std::string ToString() const;

  ax::AXTreeIDType type() const { return type_; }

  bool operator==(const AXTreeID& rhs) const;
  bool operator!=(const AXTreeID& rhs) const;
  bool operator<(const AXTreeID& rhs) const;
  bool operator<=(const AXTreeID& rhs) const;
  bool operator>(const AXTreeID& rhs) const;
  bool operator>=(const AXTreeID& rhs) const;

 private:
  explicit AXTreeID(ax::AXTreeIDType type);
  explicit AXTreeID(const std::string& string);

  friend class base::NoDestructor<AXTreeID>;
  friend void swap(AXTreeID& first, AXTreeID& second);

  ax::AXTreeIDType type_;
};

// For use in std::unordered_map.
struct AX_BASE_EXPORT AXTreeIDHash {
  size_t operator()(const ax::AXTreeID& tree_id) const;
};

AX_BASE_EXPORT std::ostream& operator<<(std::ostream& stream,
                                        const AXTreeID& value);

// The value to use when an AXTreeID is unknown.
AX_BASE_EXPORT extern const AXTreeID& AXTreeIDUnknown();

}  // namespace ax

#endif  // ACCESSIBILITY_AX_AX_TREE_ID_H_
