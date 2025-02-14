// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analysis_server/lsp_protocol/protocol.dart';
import 'package:analysis_server/src/lsp/handlers/handlers.dart';

class WorkspaceFoldersHandler
    extends MessageHandler<DidChangeWorkspaceFoldersParams, void> {
  // Whether to update analysis roots based on the open workspace folders.
  bool updateAnalysisRoots;

  WorkspaceFoldersHandler(super.server, this.updateAnalysisRoots);

  @override
  Method get handlesMessage => Method.workspace_didChangeWorkspaceFolders;

  @override
  LspJsonHandler<DidChangeWorkspaceFoldersParams> get jsonHandler =>
      DidChangeWorkspaceFoldersParams.jsonHandler;

  @override
  Future<ErrorOr<void>> handle(DidChangeWorkspaceFoldersParams params,
      MessageInfo message, CancellationToken token) async {
    // Don't do anything if our analysis roots are not based on open workspaces.
    if (!updateAnalysisRoots) {
      return success(null);
    }

    final added =
        params.event.added.map((wf) => Uri.parse(wf.uri).toFilePath()).toList();

    final removed = params.event.removed
        .map((wf) => Uri.parse(wf.uri).toFilePath())
        .toList();

    await server.updateWorkspaceFolders(added, removed);

    return success(null);
  }
}
