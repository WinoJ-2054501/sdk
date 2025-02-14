// Copyright (c) 2017, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fasta.test.text_serialization_suite;

import 'suite_utils.dart' show internalMain;
import 'testing/suite.dart';

Future<FastaContext> createContext(
    Chain suite, Map<String, String> environment) {
  environment[COMPILATION_MODE] = CompileMode.full.name;
  environment[KERNEL_TEXT_SERIALIZATION] = "";
  return FastaContext.create(suite, environment);
}

Future<void> main(List<String> arguments) async {
  await internalMain(createContext, arguments: arguments);
}
