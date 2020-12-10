// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "ax_relative_bounds.h"

#include "ax_enum_util.h"

namespace ax {

AXRelativeBounds::AXRelativeBounds() : offset_container_id(-1) {}

AXRelativeBounds::~AXRelativeBounds() {}

AXRelativeBounds::AXRelativeBounds(const AXRelativeBounds& other) {
  offset_container_id = other.offset_container_id;
  bounds = other.bounds;
  transform = other.transform;
}

AXRelativeBounds& AXRelativeBounds::operator=(AXRelativeBounds other) {
  offset_container_id = other.offset_container_id;
  bounds = other.bounds;
  transform = other.transform;
  return *this;
}

bool AXRelativeBounds::operator==(const AXRelativeBounds& other) const {
  if (offset_container_id != other.offset_container_id)
    return false;
  if (bounds != other.bounds)
    return false;
  return transform == other.transform;
}

bool AXRelativeBounds::operator!=(const AXRelativeBounds& other) const {
  return !operator==(other);
}

std::string AXRelativeBounds::ToString() const {
  std::string result;

  if (offset_container_id != -1)
    result +=
        "offset_container_id=" + std::to_string(offset_container_id) + " ";

  result += "(" + std::to_string(bounds.x()) + ", " +
            std::to_string(bounds.y()) + ")-(" +
            std::to_string(bounds.width()) + ", " +
            std::to_string(bounds.height()) + ")";
  // result += " transform=" + transform->ToString();

  return result;
}

std::ostream& operator<<(std::ostream& stream, const AXRelativeBounds& bounds) {
  return stream << bounds.ToString();
}

}  // namespace ax
