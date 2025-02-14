// Copyright (c) 2014, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analysis_server/protocol/protocol_generated.dart';
import 'package:test/test.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import '../support/integration_tests.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(ReanalyzeTest);
  });
}

@reflectiveTest
class ReanalyzeTest extends AbstractAnalysisServerIntegrationTest {
  Future<void> test_reanalyze() {
    var pathname = sourcePath('test.dart');
    var text = 'void f() {}';
    writeFile(pathname, text);
    standardAnalysisSetup();
    return analysisFinished.then((_) {
      // Make sure that reanalyze causes analysis to restart.
      var analysisRestarted = false;
      onServerStatus.listen((ServerStatusParams data) {
        var analysisStatus = data.analysis;
        if (analysisStatus != null && analysisStatus.isAnalyzing) {
          analysisRestarted = true;
        }
      });
      sendAnalysisReanalyze();
      return analysisFinished.then((_) {
        expect(analysisRestarted, isTrue);
      });
    });
  }
}
