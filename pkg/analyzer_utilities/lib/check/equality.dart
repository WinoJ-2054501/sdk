// Copyright (c) 2021, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer_utilities/check/check.dart';

extension EqualityExtension<T> on CheckTarget<T> {
  void isEqualTo(Object? other) {
    if (value != other) {
      fail('is not equal to $other');
    }
  }

  void isIdenticalTo(Object? other) {
    if (!identical(value, other)) {
      fail('is not identical to $other');
    }
  }

  void isNotEqualTo(Object? other) {
    if (value == other) {
      fail('is equal to $other');
    }
  }
}
