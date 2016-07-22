//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2016 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#import <Foundation/Foundation.h>

#include <swift/Runtime/Debug.h>

#if __LP64__
typedef int64_t SwiftIntTy;
typedef uint64_t SwiftUIntTy;
#else
typedef int32_t SwiftIntTy;
typedef uint32_t SwiftUIntTy;
#endif

@interface _SwiftTypePreservingNSNumber : NSNumber
@end

enum _SwiftTypePreservingNSNumberTag {
  SwiftInt = 1,
  SwiftUInt = 2,
  SwiftFloat = 3,
  SwiftDouble = 4,
  SwiftCGFloat = 5,
  SwiftBool = 6
};

@implementation _SwiftTypePreservingNSNumber {
  @public _SwiftTypePreservingNSNumberTag tag;
  @public char storage[8];
}

- (id)init {
  self = [super init];
  if (self) {
    self->tag = SwiftInt;
    const int64_t value = 0;
    memcpy(self->storage, &value, 8);
  }
  return self;
}

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wobjc-designated-initializers"
- (id)initWithCoder:(NSCoder *)coder {
  swift::swift_reportError(
      /* flags = */ 0,
      "_SwiftTypePreservingNSNumber should not be archived.\n");
  abort();
}
#pragma GCC diagnostic pop

- (id)copyWithZone:(NSZone *)zone {
  return [self retain];
}

- (const char *)objCType {
  // When changing this method, make sure to keep the `getValue:` method in
  // sync (it should copy as many bytes as this property promises).
  switch(tag) {
  case SwiftInt:
#if __LP64__
    return "q";
#else
    return "i";
#endif
  case SwiftUInt:
#if __LP64__
    return "Q";
#else
    return "I";
#endif
  case SwiftFloat:
    return "f";
  case SwiftDouble:
    return "d";
  case SwiftCGFloat:
#if CGFLOAT_IS_DOUBLE
    return "d";
#else
    return "f";
#endif
  case SwiftBool:
    return "c";
  }
  swift::swift_reportError(
      /* flags = */ 0,
      "_SwiftTypePreservingNSNumber.tag is corrupted.\n");
}

- (void)getValue:(void *)value {
  // This method should copy as many bytes as the `objCType` property promises.
  switch(tag) {
  case SwiftInt:
    memcpy(value, self->storage, sizeof(SwiftIntTy));
    return;
  case SwiftUInt:
    memcpy(value, self->storage, sizeof(SwiftUIntTy));
    return;
  case SwiftFloat:
    memcpy(value, self->storage, sizeof(float));
    return;
  case SwiftDouble:
    memcpy(value, self->storage, sizeof(double));
    return;
  case SwiftCGFloat:
    memcpy(value, self->storage, sizeof(CGFloat));
    return;
  case SwiftBool:
    memcpy(value, self->storage, sizeof(uint8_t));
    return;
  }
  swift::swift_reportError(
      /* flags = */ 0,
      "_SwiftTypePreservingNSNumber.tag is corrupted.\n");
}

#define DEFINE_ACCESSOR(C_TYPE, METHOD_NAME) \
  - (C_TYPE)METHOD_NAME { \
    switch(tag) { \
    case SwiftInt: { \
      SwiftIntTy result; \
      memcpy(&result, self->storage, sizeof(result)); \
      return result; \
    } \
    case SwiftUInt: { \
      SwiftUIntTy result; \
      memcpy(&result, self->storage, sizeof(result)); \
      return result; \
    } \
    case SwiftFloat: { \
      float result; \
      memcpy(&result, self->storage, sizeof(result)); \
      return result; \
    } \
    case SwiftDouble: { \
      double result; \
      memcpy(&result, self->storage, sizeof(result)); \
      return result; \
    } \
    case SwiftCGFloat: { \
      CGFloat result; \
      memcpy(&result, self->storage, sizeof(result)); \
      return result; \
    } \
    case SwiftBool: { \
      uint8_t result; \
      memcpy(&result, self->storage, sizeof(result)); \
      return result; \
    } \
    } \
    swift::swift_reportError( \
        /* flags = */ 0, \
        "_SwiftTypePreservingNSNumber.tag is corrupted.\n"); \
  }

DEFINE_ACCESSOR(char, charValue)
DEFINE_ACCESSOR(int, intValue)
DEFINE_ACCESSOR(unsigned int, unsignedIntValue)
DEFINE_ACCESSOR(long long, longLongValue)
DEFINE_ACCESSOR(unsigned long long, unsignedLongLongValue)
DEFINE_ACCESSOR(float, floatValue)
DEFINE_ACCESSOR(double, doubleValue)

#undef DEFINE_ACCESSOR

- (Class)classForCoder {
  return [NSNumber class];
}
@end

#define DEFINE_INIT(C_TYPE, FUNCTION_NAME) \
  extern "C" NS_RETURNS_RETAINED NSNumber * \
  _swift_Foundation_TypePreservingNSNumberWith ## FUNCTION_NAME(C_TYPE value) { \
    _SwiftTypePreservingNSNumber *result = \
      [[_SwiftTypePreservingNSNumber alloc] init]; \
    result->tag = Swift ## FUNCTION_NAME; \
    memcpy(result->storage, &value, sizeof(value)); \
    return result; \
  }

#if __LP64__
DEFINE_INIT(int64_t, Int)
DEFINE_INIT(uint64_t, UInt)
#else
DEFINE_INIT(int32_t, Int)
DEFINE_INIT(uint32_t, UInt)
#endif
DEFINE_INIT(float, Float)
DEFINE_INIT(double, Double)
DEFINE_INIT(CGFloat, CGFloat)

extern "C" NS_RETURNS_RETAINED NSNumber *
_swift_Foundation_TypePreservingNSNumberWithBool(uint8_t value) {
  _SwiftTypePreservingNSNumber *result =
    [[_SwiftTypePreservingNSNumber alloc] init];
  result->tag = SwiftBool;
  value = (value == 0) ? 0 : 1; // Canonicalize to 0 or 1.
  memcpy(result->storage, &value, sizeof(value));
  return result;
}

#undef DEFINE_INIT

extern "C" uint32_t
_swift_Foundation_TypePreservingNSNumberGetKind(
  NSNumber *NS_RELEASES_ARGUMENT _Nonnull self_) {
  uint64_t result = 0;
  if ([self_ isKindOfClass: [_SwiftTypePreservingNSNumber class]]) {
    result = ((_SwiftTypePreservingNSNumber *) self_)->tag;
  }
  [self_ release];
  return result;
}

#define DEFINE_GETTER(C_TYPE, FUNCTION_NAME) \
  extern "C" C_TYPE \
  _swift_Foundation_TypePreservingNSNumberGetAs ## FUNCTION_NAME( \
      _SwiftTypePreservingNSNumber *NS_RELEASES_ARGUMENT _Nonnull self_) { \
    if (self_->tag != Swift ## FUNCTION_NAME) { \
      swift::swift_reportError( \
        /* flags = */ 0, "Incorrect tag.\n"); \
    } \
    C_TYPE result; \
    memcpy(&result, self_->storage, sizeof(result)); \
    [self_ release]; \
    return result; \
  }

#if __LP64__
DEFINE_GETTER(int64_t, Int)
DEFINE_GETTER(uint64_t, UInt)
#else
DEFINE_GETTER(int32_t, Int)
DEFINE_GETTER(uint32_t, UInt)
#endif
DEFINE_GETTER(float, Float)
DEFINE_GETTER(double, Double)
DEFINE_GETTER(CGFloat, CGFloat)
DEFINE_GETTER(uint8_t, Bool)

#undef DEFINE_GETTER

