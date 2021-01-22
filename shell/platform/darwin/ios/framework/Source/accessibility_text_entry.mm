// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import <UIKit/UIKit.h>

#import "flutter/shell/platform/darwin/ios/framework/Source/accessibility_bridge.h"
#import "flutter/shell/platform/darwin/ios/framework/Source/accessibility_text_entry.h"
#include "flutter/fml/platform/darwin/string_range_sanitization.h"

static const UIAccessibilityTraits UIAccessibilityTraitUndocumentedEmptyLine = 0x800000000000;

static const char _kTextAffinityDownstream[] = "TextAffinity.downstream";
static const char _kTextAffinityUpstream[] = "TextAffinity.upstream";

// The "canonical" invalid CGRect, similar to CGRectNull, used to
// indicate a CGRect involved in firstRectForRange calculation is
// invalid. The specific value is chosen so that if firstRectForRange
// returns kInvalidFirstRect, iOS will not show the IME candidates view.
const CGRect kInvalidFirstRect = {{-1, -1}, {9999, 9999}};

@implementation TextInputSemanticsObject {
  int _textInputClient;
  const char* _selectionAffinity;
  FlutterTextRange* _selectedTextRange;
  CGRect _cachedFirstRect;
}

@synthesize tokenizer = _tokenizer;

static TextInputSemanticsObject* _active;

- (instancetype)initWithBridge:(fml::WeakPtr<flutter::AccessibilityBridgeIos>)bridge
                           uid:(int32_t)uid {
  self = [super initWithBridge:bridge uid:uid];

  if (self) {
    _textInputDelegate = [self bridge]->textInputDelegate();
    _textInputClient = 0;
    _selectionAffinity = _kTextAffinityUpstream;

    // UITextInput
    _text = [[NSMutableString alloc] init];
    _markedText = [[NSMutableString alloc] init];
    _selectedTextRange = [[FlutterTextRange alloc] initWithNSRange:NSMakeRange(0, 0)];
    _markedRect = kInvalidFirstRect;
    _cachedFirstRect = kInvalidFirstRect;
    // Initialize with the zero matrix which is not
    // an affine transform.
    _editableTransform = CATransform3D();

    // UITextInputTraits
    _autocapitalizationType = UITextAutocapitalizationTypeSentences;
    _autocorrectionType = UITextAutocorrectionTypeDefault;
    _spellCheckingType = UITextSpellCheckingTypeDefault;
    _enablesReturnKeyAutomatically = NO;
    _keyboardAppearance = UIKeyboardAppearanceDefault;
    _keyboardType = UIKeyboardTypeDefault;
    _returnKeyType = UIReturnKeyDone;
    _secureTextEntry = NO;
    if (@available(iOS 11.0, *)) {
      _smartQuotesType = UITextSmartQuotesTypeYes;
      _smartDashesType = UITextSmartDashesTypeYes;
    }
  }

  return self;
}

- (void)dealloc {
  [_tokenizer release];
  [super dealloc];
}

+ (TextInputSemanticsObject*)active {
  return _active;
}

- (void)setTextInputClient:(int)client {
  _textInputClient = client;
}

- (void)setTextInputState:(NSDictionary*)state {
  NSString* newText = state[@"text"];
  BOOL textChanged = ![self.text isEqualToString:newText];
  if (textChanged) {
    [self.inputDelegate textWillChange:self];
    [self.text setString:newText];
  }
  NSInteger composingBase = [state[@"composingBase"] intValue];
  NSInteger composingExtent = [state[@"composingExtent"] intValue];
  NSRange composingRange = [self clampSelection:NSMakeRange(MIN(composingBase, composingExtent),
                                                            ABS(composingBase - composingExtent))
                                        forText:self.text];

  self.markedTextRange =
      composingRange.length > 0 ? [FlutterTextRange rangeWithNSRange:composingRange] : nil;

  NSRange selectedRange = [self clampSelectionFromBase:[state[@"selectionBase"] intValue]
                                                extent:[state[@"selectionExtent"] intValue]
                                               forText:self.text];

  NSRange oldSelectedRange = [(FlutterTextRange*)self.selectedTextRange range];
  if (!NSEqualRanges(selectedRange, oldSelectedRange)) {
    [self.inputDelegate selectionWillChange:self];

    [self setSelectedTextRangeLocal:[FlutterTextRange rangeWithNSRange:selectedRange]];

    _selectionAffinity = _kTextAffinityDownstream;
    if ([state[@"selectionAffinity"] isEqualToString:@(_kTextAffinityUpstream)])
      _selectionAffinity = _kTextAffinityUpstream;
    [self.inputDelegate selectionDidChange:self];
  }

  if (textChanged) {
    [self.inputDelegate textDidChange:self];
  }
}

- (void)updateMarkedRect:(NSDictionary*)dictionary {
  NSAssert(dictionary[@"x"] != nil && dictionary[@"y"] != nil && dictionary[@"width"] != nil &&
               dictionary[@"height"] != nil,
           @"Expected a dictionary representing a CGRect, got %@", dictionary);
  CGRect rect = CGRectMake([dictionary[@"x"] doubleValue], [dictionary[@"y"] doubleValue],
                           [dictionary[@"width"] doubleValue], [dictionary[@"height"] doubleValue]);
  self.markedRect = rect.size.width < 0 && rect.size.height < 0 ? kInvalidFirstRect : rect;
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
  NSString* method = call.method;
  id args = call.arguments;
  if ([method isEqualToString:@"TextInput.show"]) {
    NSLog(@"TextInput show");
    [self becomeFirstResponder];
    result(nil);
  } else if ([method isEqualToString:@"TextInput.hide"]) {
    // [self hideTextInput];
    result(nil);
  } else if ([method isEqualToString:@"TextInput.setClient"]) {
    [self setTextInputClient:[args[0] intValue]];
    result(nil);
  } else if ([method isEqualToString:@"TextInput.setEditingState"]) {
    [self setTextInputState:args];
    result(nil);
  } else if ([method isEqualToString:@"TextInput.clearClient"]) {
    [self setTextInputClient:0];
    result(nil);
  } else if ([method isEqualToString:@"TextInput.setEditableSizeAndTransform"]) {
    [self setEditableTransform:args[@"transform"]];
    result(nil);
  } else if ([method isEqualToString:@"TextInput.setMarkedTextRect"]) {
    [self updateMarkedRect:args];
    result(nil);
  } else if ([method isEqualToString:@"TextInput.finishAutofillContext"]) {
    // [self triggerAutofillSave:[args boolValue]];
    result(nil);
  } else {
    result(FlutterMethodNotImplemented);
  }
}

#pragma mark - SemanticsObject overrides

- (void)setSemanticsNode:(const flutter::SemanticsNode*)node {
  [super setSemanticsNode:node];
  _text = [@(node->value.data()) mutableCopy];
  if ([self node].HasFlag(flutter::SemanticsFlags::kIsFocused)) {
    // The text input view must have a non-trivial size for the accessibility
    // system to send text editing events.
    _active = self;
  } else {
    if (_active == self) {
      _active = nil;
    }
  }
}

#pragma mark - UIAccessibility overrides

// /**
//  * The UITextInput whose accessibility properties we present to UIKit as
//  * substitutes for Flutter's text field properties.
//  *
//  * When the field is currently focused (i.e. it is being edited), we use
//  * the FlutterTextInputView used by FlutterTextInputPlugin. Otherwise,
//  * we use an FlutterInactiveTextInput.
//  */
// - (UIView<UITextInput>*)textInputSurrogate {
//   if ([self node].HasFlag(flutter::SemanticsFlags::kIsFocused)) {
//     return [self bridge]->textInputView();
//   } else {
//     return _inactive_text_input;
//   }
// }

// - (UIView*)textInputView {
//   return [self textInputSurrogate];
// }

// - (void)accessibilityElementDidBecomeFocused {
//   if (![self isAccessibilityBridgeAlive])
//     return;
//   [[self textInputSurrogate] accessibilityElementDidBecomeFocused];
//   [super accessibilityElementDidBecomeFocused];
// }

// - (void)accessibilityElementDidLoseFocus {
//   if (![self isAccessibilityBridgeAlive])
//     return;
//   [[self textInputSurrogate] accessibilityElementDidLoseFocus];
//   [super accessibilityElementDidLoseFocus];
// }

// - (BOOL)accessibilityElementIsFocused {
//   if (![self isAccessibilityBridgeAlive])
//     return false;
//   return [self node].HasFlag(flutter::SemanticsFlags::kIsFocused);
// }

// - (BOOL)accessibilityActivate {
//   if (![self isAccessibilityBridgeAlive])
//     return false;
//   return [[self textInputSurrogate] accessibilityActivate];
// }

// - (NSString*)accessibilityLabel {
//   if (![self isAccessibilityBridgeAlive])
//     return nil;

//   NSString* label = [super accessibilityLabel];
//   if (label != nil)
//     return label;
//   return [self textInputSurrogate].accessibilityLabel;
// }

// - (NSString*)accessibilityHint {
//   if (![self isAccessibilityBridgeAlive])
//     return nil;
//   NSString* hint = [super accessibilityHint];
//   if (hint != nil)
//     return hint;
//   return [self textInputSurrogate].accessibilityHint;
// }

- (NSString*)accessibilityValue {
  if (![self isAccessibilityBridgeAlive])
    return nil;
  NSString* value = [super accessibilityValue];
  if (value != nil)
    return value;
  return self.text;
}

- (UIAccessibilityTraits)accessibilityTraits {
  if (![self isAccessibilityBridgeAlive])
    return 0;
  // Adding UIAccessibilityTraitKeyboardKey to the trait list so that iOS treats it like
  // a keyboard entry control, thus adding support for text editing features, such as
  // pinch to select text, and up/down fling to move cursor.
  UIAccessibilityTraits results = [super accessibilityTraits] |
                                  // [self textInputSurrogate].accessibilityTraits |
                                  UIAccessibilityTraitKeyboardKey;
  // We remove an undocumented flag to get rid of a bug where single-tapping
  // a text input field incorrectly says "empty line".
  // See also: https://github.com/flutter/flutter/issues/52487
  return results & (~UIAccessibilityTraitUndocumentedEmptyLine);
}

#pragma mark - UITextInput overrides

- (NSString*)textInRange:(UITextRange*)range {
  if (!range) {
    return nil;
  }
  NSAssert([range isKindOfClass:[FlutterTextRange class]],
           @"Expected a FlutterTextRange for range (got %@).", [range class]);
  NSRange textRange = ((FlutterTextRange*)range).range;
  NSAssert(textRange.location != NSNotFound, @"Expected a valid text range.");
  return [self.text substringWithRange:textRange];
}

// Replace the text within the specified range with the given text,
// without notifying the framework.
- (void)replaceRangeLocal:(NSRange)range withText:(NSString*)text {
  NSRange selectedRange = _selectedTextRange.range;

  // Adjust the text selection:
  // * reduce the length by the intersection length
  // * adjust the location by newLength - oldLength + intersectionLength
  NSRange intersectionRange = NSIntersectionRange(range, selectedRange);
  if (range.location <= selectedRange.location)
    selectedRange.location += text.length - range.length;
  if (intersectionRange.location != NSNotFound) {
    selectedRange.location += intersectionRange.length;
    selectedRange.length -= intersectionRange.length;
  }

  [self.text replaceCharactersInRange:[self clampSelection:range forText:self.text]
                           withString:text];
  [self setSelectedTextRangeLocal:[FlutterTextRange
                                      rangeWithNSRange:[self clampSelection:selectedRange
                                                                    forText:self.text]]];
}

- (void)replaceRange:(UITextRange*)range withText:(NSString*)text {
  NSRange replaceRange = ((FlutterTextRange*)range).range;
  [self replaceRangeLocal:replaceRange withText:text];
  [self updateEditingState];
}

- (BOOL)shouldChangeTextInRange:(UITextRange*)range replacementText:(NSString*)text {
  if (self.returnKeyType == UIReturnKeyDefault && [text isEqualToString:@"\n"]) {
    [_textInputDelegate performAction:FlutterTextInputActionNewline withClient:_textInputClient];
    return YES;
  }

  if ([text isEqualToString:@"\n"]) {
    FlutterTextInputAction action;
    switch (self.returnKeyType) {
      case UIReturnKeyDefault:
        action = FlutterTextInputActionUnspecified;
        break;
      case UIReturnKeyDone:
        action = FlutterTextInputActionDone;
        break;
      case UIReturnKeyGo:
        action = FlutterTextInputActionGo;
        break;
      case UIReturnKeySend:
        action = FlutterTextInputActionSend;
        break;
      case UIReturnKeySearch:
      case UIReturnKeyGoogle:
      case UIReturnKeyYahoo:
        action = FlutterTextInputActionSearch;
        break;
      case UIReturnKeyNext:
        action = FlutterTextInputActionNext;
        break;
      case UIReturnKeyContinue:
        action = FlutterTextInputActionContinue;
        break;
      case UIReturnKeyJoin:
        action = FlutterTextInputActionJoin;
        break;
      case UIReturnKeyRoute:
        action = FlutterTextInputActionRoute;
        break;
      case UIReturnKeyEmergencyCall:
        action = FlutterTextInputActionEmergencyCall;
        break;
    }

    [_textInputDelegate performAction:action withClient:_textInputClient];
    return NO;
  }

  return YES;
}

- (UITextRange*)selectedTextRange {
  return [[_selectedTextRange copy] autorelease];
}

// Change the range of selected text, without notifying the framework.
- (void)setSelectedTextRangeLocal:(UITextRange*)selectedTextRange {
  if (_selectedTextRange != selectedTextRange) {
    UITextRange* oldSelectedRange = _selectedTextRange;
    if (self.hasText) {
      FlutterTextRange* flutterTextRange = (FlutterTextRange*)selectedTextRange;
      _selectedTextRange = [[FlutterTextRange
          rangeWithNSRange:fml::RangeForCharactersInRange(self.text, flutterTextRange.range)] copy];
    } else {
      _selectedTextRange = [selectedTextRange copy];
    }
    [oldSelectedRange release];
  }
}

- (void)setSelectedTextRange:(UITextRange*)selectedTextRange {
  [self setSelectedTextRangeLocal:selectedTextRange];
  [self updateEditingState];
}

- (void)setMarkedText:(NSString*)markedText selectedRange:(NSRange)markedSelectedRange {
  NSRange selectedRange = _selectedTextRange.range;
  NSRange markedTextRange = ((FlutterTextRange*)self.markedTextRange).range;

  if (markedText == nil)
    markedText = @"";

  if (markedTextRange.length > 0) {
    // Replace text in the marked range with the new text.
    [self replaceRangeLocal:markedTextRange withText:markedText];
    markedTextRange.length = markedText.length;
  } else {
    // Replace text in the selected range with the new text.
    [self replaceRangeLocal:selectedRange withText:markedText];
    markedTextRange = NSMakeRange(selectedRange.location, markedText.length);
  }

  self.markedTextRange =
      markedTextRange.length > 0 ? [FlutterTextRange rangeWithNSRange:markedTextRange] : nil;

  NSUInteger selectionLocation = markedSelectedRange.location + markedTextRange.location;
  selectedRange = NSMakeRange(selectionLocation, markedSelectedRange.length);
  [self setSelectedTextRangeLocal:[FlutterTextRange
                                      rangeWithNSRange:[self clampSelection:selectedRange
                                                                    forText:self.text]]];
  [self updateEditingState];
}

- (void)unmarkText {
  if (!self.markedTextRange)
    return;
  self.markedTextRange = nil;
  [self updateEditingState];
}

- (UITextStorageDirection)selectionAffinity {
  // TODO(chunhtai):: implement for real.
  return UITextStorageDirectionForward;
}

- (UITextPosition*)beginningOfDocument {
  return [FlutterTextPosition positionWithIndex:0];
}

- (UITextPosition*)endOfDocument {
  return [FlutterTextPosition positionWithIndex:self.text.length];
}

- (id<UITextInputTokenizer>)tokenizer {
  if (_tokenizer == nil) {
    _tokenizer = [[UITextInputStringTokenizer alloc] initWithTextInput:self];
  }
  return _tokenizer;
}

- (UITextRange*)textRangeFromPosition:(UITextPosition*)fromPosition
                           toPosition:(UITextPosition*)toPosition {
  NSUInteger fromIndex = ((FlutterTextPosition*)fromPosition).index;
  NSUInteger toIndex = ((FlutterTextPosition*)toPosition).index;
  if (toIndex >= fromIndex) {
    return [FlutterTextRange rangeWithNSRange:NSMakeRange(fromIndex, toIndex - fromIndex)];
  } else {
    // toIndex may be less than fromIndex, because
    // UITextInputStringTokenizer does not handle CJK characters
    // well in some cases. See:
    // https://github.com/flutter/flutter/issues/58750#issuecomment-644469521
    // Swap fromPosition and toPosition to match the behavior of native
    // UITextViews.
    return [FlutterTextRange rangeWithNSRange:NSMakeRange(toIndex, fromIndex - toIndex)];
  }
}

- (NSUInteger)decrementOffsetPosition:(NSUInteger)position {
  return fml::RangeForCharacterAtIndex(self.text, MAX(0, position - 1)).location;
}

- (NSUInteger)incrementOffsetPosition:(NSUInteger)position {
  NSRange charRange = fml::RangeForCharacterAtIndex(self.text, position);
  return MIN(position + charRange.length, self.text.length);
}

- (UITextPosition*)positionFromPosition:(UITextPosition*)position offset:(NSInteger)offset {
  NSUInteger offsetPosition = ((FlutterTextPosition*)position).index;

  NSInteger newLocation = (NSInteger)offsetPosition + offset;
  if (newLocation < 0 || newLocation > (NSInteger)self.text.length) {
    return nil;
  }

  if (offset >= 0) {
    for (NSInteger i = 0; i < offset && offsetPosition < self.text.length; ++i)
      offsetPosition = [self incrementOffsetPosition:offsetPosition];
  } else {
    for (NSInteger i = 0; i < ABS(offset) && offsetPosition > 0; ++i)
      offsetPosition = [self decrementOffsetPosition:offsetPosition];
  }
  return [FlutterTextPosition positionWithIndex:offsetPosition];
}

- (UITextPosition*)positionFromPosition:(UITextPosition*)position
                            inDirection:(UITextLayoutDirection)direction
                                 offset:(NSInteger)offset {
  // TODO(cbracken) Add RTL handling.
  switch (direction) {
    case UITextLayoutDirectionLeft:
    case UITextLayoutDirectionUp:
      return [self positionFromPosition:position offset:offset * -1];
    case UITextLayoutDirectionRight:
    case UITextLayoutDirectionDown:
      return [self positionFromPosition:position offset:1];
  }
}

- (NSComparisonResult)comparePosition:(UITextPosition*)position toPosition:(UITextPosition*)other {
  NSUInteger positionIndex = ((FlutterTextPosition*)position).index;
  NSUInteger otherIndex = ((FlutterTextPosition*)other).index;
  if (positionIndex < otherIndex)
    return NSOrderedAscending;
  if (positionIndex > otherIndex)
    return NSOrderedDescending;
  return NSOrderedSame;
}

- (NSInteger)offsetFromPosition:(UITextPosition*)from toPosition:(UITextPosition*)toPosition {
  return ((FlutterTextPosition*)toPosition).index - ((FlutterTextPosition*)from).index;
}

- (UITextPosition*)positionWithinRange:(UITextRange*)range
                   farthestInDirection:(UITextLayoutDirection)direction {
  NSUInteger index;
  switch (direction) {
    case UITextLayoutDirectionLeft:
    case UITextLayoutDirectionUp:
      index = ((FlutterTextPosition*)range.start).index;
      break;
    case UITextLayoutDirectionRight:
    case UITextLayoutDirectionDown:
      index = ((FlutterTextPosition*)range.end).index;
      break;
  }
  return [FlutterTextPosition positionWithIndex:index];
}

- (UITextRange*)characterRangeByExtendingPosition:(UITextPosition*)position
                                      inDirection:(UITextLayoutDirection)direction {
  NSUInteger positionIndex = ((FlutterTextPosition*)position).index;
  NSUInteger startIndex;
  NSUInteger endIndex;
  switch (direction) {
    case UITextLayoutDirectionLeft:
    case UITextLayoutDirectionUp:
      startIndex = [self decrementOffsetPosition:positionIndex];
      endIndex = positionIndex;
      break;
    case UITextLayoutDirectionRight:
    case UITextLayoutDirectionDown:
      startIndex = positionIndex;
      endIndex = [self incrementOffsetPosition:positionIndex];
      break;
  }
  return [FlutterTextRange rangeWithNSRange:NSMakeRange(startIndex, endIndex - startIndex)];
}

// Extracts the selection information from the editing state dictionary.
//
// The state may contain an invalid selection, such as when no selection was
// explicitly set in the framework. This is handled here by setting the
// selection to (0,0). In contrast, Android handles this situation by
// clearing the selection, but the result in both cases is that the cursor
// is placed at the beginning of the field.
- (NSRange)clampSelectionFromBase:(int)selectionBase
                           extent:(int)selectionExtent
                          forText:(NSString*)text {
  int loc = MIN(selectionBase, selectionExtent);
  int len = ABS(selectionExtent - selectionBase);
  return loc < 0 ? NSMakeRange(0, 0)
                 : [self clampSelection:NSMakeRange(loc, len) forText:self.text];
}

- (NSRange)clampSelection:(NSRange)range forText:(NSString*)text {
  int start = MIN(MAX(range.location, 0), text.length);
  int length = MIN(range.length, text.length - start);
  return NSMakeRange(start, length);
}

#pragma mark - UITextInput text direction handling

- (UITextWritingDirection)baseWritingDirectionForPosition:(UITextPosition*)position
                                              inDirection:(UITextStorageDirection)direction {
  // TODO(cbracken) Add RTL handling.
  return UITextWritingDirectionNatural;
}

- (void)setBaseWritingDirection:(UITextWritingDirection)writingDirection
                       forRange:(UITextRange*)range {
  // TODO(cbracken) Add RTL handling.
}

#pragma mark - UITextInput cursor, selection rect handling

- (void)setMarkedRect:(CGRect)markedRect {
  _markedRect = markedRect;
  // Invalidate the cache.
  _cachedFirstRect = kInvalidFirstRect;
}

// This method expects a 4x4 perspective matrix
// stored in a NSArray in column-major order.
- (void)setEditableTransform:(NSArray*)matrix {
  CATransform3D* transform = &_editableTransform;

  transform->m11 = [matrix[0] doubleValue];
  transform->m12 = [matrix[1] doubleValue];
  transform->m13 = [matrix[2] doubleValue];
  transform->m14 = [matrix[3] doubleValue];

  transform->m21 = [matrix[4] doubleValue];
  transform->m22 = [matrix[5] doubleValue];
  transform->m23 = [matrix[6] doubleValue];
  transform->m24 = [matrix[7] doubleValue];

  transform->m31 = [matrix[8] doubleValue];
  transform->m32 = [matrix[9] doubleValue];
  transform->m33 = [matrix[10] doubleValue];
  transform->m34 = [matrix[11] doubleValue];

  transform->m41 = [matrix[12] doubleValue];
  transform->m42 = [matrix[13] doubleValue];
  transform->m43 = [matrix[14] doubleValue];
  transform->m44 = [matrix[15] doubleValue];

  // Invalidate the cache.
  _cachedFirstRect = kInvalidFirstRect;
}

- (CGRect)firstRectForRange:(UITextRange*)range {
   NSAssert([range.start isKindOfClass:[FlutterTextPosition class]],
           @"Expected a FlutterTextPosition for range.start (got %@).", [range.start class]);
  NSAssert([range.end isKindOfClass:[FlutterTextPosition class]],
           @"Expected a FlutterTextPosition for range.end (got %@).", [range.end class]);

  NSUInteger start = ((FlutterTextPosition*)range.start).index;
  NSUInteger end = ((FlutterTextPosition*)range.end).index;
  if (_markedTextRange != nil) {
    // The candidates view can't be shown if _editableTransform is not affine,
    // or markedRect is invalid.
    if (CGRectEqualToRect(kInvalidFirstRect, _markedRect) ||
        !CATransform3DIsAffine(_editableTransform)) {
      return kInvalidFirstRect;
    }

    if (CGRectEqualToRect(_cachedFirstRect, kInvalidFirstRect)) {
      // If the width returned is too small, that means the framework sent us
      // the caret rect instead of the marked text rect. Expand it to 0.1 so
      // the IME candidates view show up.
      double nonZeroWidth = MAX(_markedRect.size.width, 0.1);
      CGRect rect = _markedRect;
      rect.size = CGSizeMake(nonZeroWidth, rect.size.height);
      _cachedFirstRect =
          CGRectApplyAffineTransform(rect, CATransform3DGetAffineTransform(_editableTransform));
    }

    return _cachedFirstRect;
  }

  [_textInputDelegate showAutocorrectionPromptRectForStart:start
                                                       end:end
                                                withClient:_textInputClient];
  // TODO(cbracken) Implement.
  return CGRectZero;
}

- (CGRect)caretRectForPosition:(UITextPosition*)position {
  // TODO(cbracken) Implement.
  return CGRectZero;
}

- (UITextPosition*)closestPositionToPoint:(CGPoint)point {
  NSUInteger currentIndex = ((FlutterTextPosition*)_selectedTextRange.start).index;
  return [FlutterTextPosition positionWithIndex:currentIndex];
}

- (UITextPosition*)closestPositionToPoint:(CGPoint)point withinRange:(UITextRange*)range {
  // TODO(cbracken) Implement.
  return range.start;
}

- (NSArray*)selectionRectsForRange:(UITextRange*)range {
  // TODO(cbracken) Implement.
  return @[];
}

- (UITextRange*)characterRangeAtPoint:(CGPoint)point {
  // TODO(cbracken) Implement.
  NSUInteger currentIndex = ((FlutterTextPosition*)_selectedTextRange.start).index;
  return [FlutterTextRange rangeWithNSRange:fml::RangeForCharacterAtIndex(self.text, currentIndex)];
}

- (void)beginFloatingCursorAtPoint:(CGPoint)point {
  [_textInputDelegate updateFloatingCursor:FlutterFloatingCursorDragStateStart
                                withClient:_textInputClient
                              withPosition:@{@"X" : @(point.x), @"Y" : @(point.y)}];
}

- (void)updateFloatingCursorAtPoint:(CGPoint)point {
  [_textInputDelegate updateFloatingCursor:FlutterFloatingCursorDragStateUpdate
                                withClient:_textInputClient
                              withPosition:@{@"X" : @(point.x), @"Y" : @(point.y)}];
}

- (void)endFloatingCursor {
  [_textInputDelegate updateFloatingCursor:FlutterFloatingCursorDragStateEnd
                                withClient:_textInputClient
                              withPosition:@{@"X" : @(0), @"Y" : @(0)}];
}

#pragma mark - UIKeyInput Overrides

- (void)updateEditingState {
  NSUInteger selectionBase = ((FlutterTextPosition*)_selectedTextRange.start).index;
  NSUInteger selectionExtent = ((FlutterTextPosition*)_selectedTextRange.end).index;

  // Empty compositing range is represented by the framework's TextRange.empty.
  NSInteger composingBase = -1;
  NSInteger composingExtent = -1;
  if (self.markedTextRange != nil) {
    composingBase = ((FlutterTextPosition*)self.markedTextRange.start).index;
    composingExtent = ((FlutterTextPosition*)self.markedTextRange.end).index;
  }

  NSDictionary* state = @{
    @"selectionBase" : @(selectionBase),
    @"selectionExtent" : @(selectionExtent),
    @"selectionAffinity" : @(_selectionAffinity),
    @"selectionIsDirectional" : @(false),
    @"composingBase" : @(composingBase),
    @"composingExtent" : @(composingExtent),
    @"text" : [NSString stringWithString:self.text],
  };

  // if (_textInputClient == 0 && _autofillId != nil) {
  //   [_textInputDelegate updateEditingClient:_textInputClient withState:state withTag:_autofillId];
  // } else {
  //   [_textInputDelegate updateEditingClient:_textInputClient withState:state];
  // }
  [_textInputDelegate updateEditingClient:_textInputClient withState:state];
}

- (BOOL)hasText {
  return self.text.length > 0;
}

- (void)insertText:(NSString*)text {
  _selectionAffinity = _kTextAffinityDownstream;
  [self replaceRange:_selectedTextRange withText:text];
}

- (void)deleteBackward {
   _selectionAffinity = _kTextAffinityDownstream;

  // When deleting Thai vowel, _selectedTextRange has location
  // but does not have length, so we have to manually set it.
  // In addition, we needed to delete only a part of grapheme cluster
  // because it is the expected behavior of Thai input.
  // https://github.com/flutter/flutter/issues/24203
  // https://github.com/flutter/flutter/issues/21745
  // https://github.com/flutter/flutter/issues/39399
  //
  // This is needed for correct handling of the deletion of Thai vowel input.
  // TODO(cbracken): Get a good understanding of expected behavior of Thai
  // input and ensure that this is the correct solution.
  // https://github.com/flutter/flutter/issues/28962
  if (_selectedTextRange.isEmpty && [self hasText]) {
    UITextRange* oldSelectedRange = _selectedTextRange;
    NSRange oldRange = ((FlutterTextRange*)oldSelectedRange).range;
    if (oldRange.location > 0) {
      NSRange newRange = NSMakeRange(oldRange.location - 1, 1);
      _selectedTextRange = [[FlutterTextRange rangeWithNSRange:newRange] copy];
      [oldSelectedRange release];
    }
  }

  if (!_selectedTextRange.isEmpty)
    [self replaceRange:_selectedTextRange withText:@""];
}


@end
