// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// @dart = 2.10

import 'dart:io';

import 'package:front_end/src/fasta/kernel/utils.dart' as ir
    show serializeComponent;
import 'package:front_end/src/fasta/kernel/utils.dart';
import 'package:kernel/ast.dart' as ir;
import 'package:kernel/binary/ast_from_binary.dart' show BinaryBuilder;

import '../diagnostics/diagnostic_listener.dart';
import '../environment.dart';
import '../inferrer/abstract_value_strategy.dart';
import '../inferrer/types.dart';
import '../js_model/js_world.dart';
import '../options.dart';
import '../source_file_provider.dart';
import '../util/sink_adapter.dart';
import 'serialization.dart';
import 'task.dart';

abstract class SerializationStrategy<T> {
  const SerializationStrategy();

  List<int> unpackAndSerializeComponent(GlobalTypeInferenceResults results) {
    JsClosedWorld closedWorld = results.closedWorld;
    ir.Component component = closedWorld.elementMap.programEnv.mainComponent;
    return serializeComponent(component);
  }

  List<T> serializeGlobalTypeInferenceResults(
      DataSourceIndices indices, GlobalTypeInferenceResults results);

  List<int> serializeComponent(ir.Component component) {
    return ir.serializeComponent(component);
  }

  ir.Component deserializeComponent(List<int> data) {
    ir.Component component = ir.Component();
    BinaryBuilder(data).readComponent(component);
    return component;
  }

  GlobalTypeInferenceResults deserializeGlobalTypeInferenceResults(
      CompilerOptions options,
      DiagnosticReporter reporter,
      Environment environment,
      AbstractValueStrategy abstractValueStrategy,
      ir.Component component,
      JsClosedWorld closedWorld,
      DataSourceIndices indices,
      List<T> globalTypeInferenceResultsData);

  List<T> serializeClosedWorld(JsClosedWorld closedWorld);

  ClosedWorldAndIndices deserializeClosedWorld(
      CompilerOptions options,
      DiagnosticReporter reporter,
      Environment environment,
      AbstractValueStrategy abstractValueStrategy,
      ir.Component component,
      List<T> data);
}

class BytesInMemorySerializationStrategy extends SerializationStrategy<int> {
  final bool useDataKinds;

  const BytesInMemorySerializationStrategy({this.useDataKinds = false});

  @override
  List<int> serializeGlobalTypeInferenceResults(
      DataSourceIndices indices, GlobalTypeInferenceResults results) {
    ByteSink byteSink = ByteSink();
    DataSinkWriter sink = DataSinkWriter(BinaryDataSink(byteSink),
        useDataKinds: useDataKinds, importedIndices: indices);
    serializeGlobalTypeInferenceResultsToSink(results, sink);
    return byteSink.builder.takeBytes();
  }

  @override
  GlobalTypeInferenceResults deserializeGlobalTypeInferenceResults(
      CompilerOptions options,
      DiagnosticReporter reporter,
      Environment environment,
      AbstractValueStrategy abstractValueStrategy,
      ir.Component component,
      JsClosedWorld closedWorld,
      DataSourceIndices indices,
      List<int> globalTypeInferenceResultsData) {
    DataSourceReader globalTypeInferenceResultsSource = DataSourceReader(
        BinaryDataSource(globalTypeInferenceResultsData),
        useDataKinds: useDataKinds,
        importedIndices: indices);
    return deserializeGlobalTypeInferenceResultsFromSource(
        options,
        reporter,
        environment,
        abstractValueStrategy,
        component,
        closedWorld,
        globalTypeInferenceResultsSource);
  }

  @override
  List<int> serializeClosedWorld(JsClosedWorld closedWorld) {
    ByteSink byteSink = ByteSink();
    DataSinkWriter sink =
        DataSinkWriter(BinaryDataSink(byteSink), useDataKinds: useDataKinds);
    serializeClosedWorldToSink(closedWorld, sink);
    return byteSink.builder.takeBytes();
  }

  @override
  ClosedWorldAndIndices deserializeClosedWorld(
      CompilerOptions options,
      DiagnosticReporter reporter,
      Environment environment,
      AbstractValueStrategy abstractValueStrategy,
      ir.Component component,
      List<int> data) {
    DataSourceReader source =
        DataSourceReader(BinaryDataSource(data), useDataKinds: useDataKinds);
    var closedWorld = deserializeClosedWorldFromSource(options, reporter,
        environment, abstractValueStrategy, component, source);
    return ClosedWorldAndIndices(closedWorld, source.exportIndices());
  }
}

class BytesOnDiskSerializationStrategy extends SerializationStrategy<int> {
  final bool useDataKinds;

  const BytesOnDiskSerializationStrategy({this.useDataKinds = false});

  @override
  List<int> serializeGlobalTypeInferenceResults(
      DataSourceIndices indices, GlobalTypeInferenceResults results) {
    Uri uri = Uri.base.resolve('world.data');
    DataSinkWriter sink = DataSinkWriter(
        BinaryDataSink(
            BinaryOutputSinkAdapter(RandomAccessBinaryOutputSink(uri))),
        useDataKinds: useDataKinds,
        importedIndices: indices);
    serializeGlobalTypeInferenceResultsToSink(results, sink);
    return File.fromUri(uri).readAsBytesSync();
  }

  @override
  GlobalTypeInferenceResults deserializeGlobalTypeInferenceResults(
      CompilerOptions options,
      DiagnosticReporter reporter,
      Environment environment,
      AbstractValueStrategy abstractValueStrategy,
      ir.Component component,
      JsClosedWorld closedWorld,
      DataSourceIndices indices,
      List<int> globalTypeInferenceResultsData) {
    DataSourceReader globalTypeInferenceResultsSource = DataSourceReader(
        BinaryDataSource(globalTypeInferenceResultsData),
        useDataKinds: useDataKinds,
        importedIndices: indices);
    return deserializeGlobalTypeInferenceResultsFromSource(
        options,
        reporter,
        environment,
        abstractValueStrategy,
        component,
        closedWorld,
        globalTypeInferenceResultsSource);
  }

  @override
  List<int> serializeClosedWorld(JsClosedWorld closedWorld) {
    Uri uri = Uri.base.resolve('closed_world.data');
    DataSinkWriter sink = DataSinkWriter(
        BinaryDataSink(
            BinaryOutputSinkAdapter(RandomAccessBinaryOutputSink(uri))),
        useDataKinds: useDataKinds);
    serializeClosedWorldToSink(closedWorld, sink);
    return File.fromUri(uri).readAsBytesSync();
  }

  @override
  ClosedWorldAndIndices deserializeClosedWorld(
      CompilerOptions options,
      DiagnosticReporter reporter,
      Environment environment,
      AbstractValueStrategy abstractValueStrategy,
      ir.Component component,
      List<int> data) {
    DataSourceReader source =
        DataSourceReader(BinaryDataSource(data), useDataKinds: useDataKinds);
    var closedWorld = deserializeClosedWorldFromSource(options, reporter,
        environment, abstractValueStrategy, component, source);
    return ClosedWorldAndIndices(closedWorld, source.exportIndices());
  }
}

class ObjectsInMemorySerializationStrategy
    extends SerializationStrategy<Object> {
  final bool useDataKinds;

  const ObjectsInMemorySerializationStrategy({this.useDataKinds = true});

  @override
  List<Object> serializeGlobalTypeInferenceResults(
      DataSourceIndices indices, GlobalTypeInferenceResults results) {
    List<Object> data = [];
    DataSinkWriter sink = DataSinkWriter(ObjectDataSink(data),
        useDataKinds: useDataKinds, importedIndices: indices);
    serializeGlobalTypeInferenceResultsToSink(results, sink);
    return data;
  }

  @override
  GlobalTypeInferenceResults deserializeGlobalTypeInferenceResults(
      CompilerOptions options,
      DiagnosticReporter reporter,
      Environment environment,
      AbstractValueStrategy abstractValueStrategy,
      ir.Component component,
      JsClosedWorld closedWorld,
      DataSourceIndices indices,
      List<Object> globalTypeInferenceResultsData) {
    DataSourceReader globalTypeInferenceResultsSource =
        DataSourceReader(ObjectDataSource(globalTypeInferenceResultsData));
    return deserializeGlobalTypeInferenceResultsFromSource(
        options,
        reporter,
        environment,
        abstractValueStrategy,
        component,
        closedWorld,
        globalTypeInferenceResultsSource);
  }

  @override
  List<Object> serializeClosedWorld(JsClosedWorld closedWorld) {
    List<Object> data = [];
    DataSinkWriter sink =
        DataSinkWriter(ObjectDataSink(data), useDataKinds: useDataKinds);
    serializeClosedWorldToSink(closedWorld, sink);
    return data;
  }

  @override
  ClosedWorldAndIndices deserializeClosedWorld(
      CompilerOptions options,
      DiagnosticReporter reporter,
      Environment environment,
      AbstractValueStrategy abstractValueStrategy,
      ir.Component component,
      List<Object> data) {
    DataSourceReader source =
        DataSourceReader(ObjectDataSource(data), useDataKinds: useDataKinds);
    var closedWorld = deserializeClosedWorldFromSource(options, reporter,
        environment, abstractValueStrategy, component, source);
    return ClosedWorldAndIndices(closedWorld, source.exportIndices());
  }
}
