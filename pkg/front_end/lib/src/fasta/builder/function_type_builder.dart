// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library fasta.function_type_builder;

import 'package:kernel/ast.dart'
    show
        DartType,
        DynamicType,
        FunctionType,
        NamedType,
        Supertype,
        TypeParameter;
import 'package:kernel/src/unaliasing.dart';

import '../fasta_codes.dart' show messageSupertypeIsFunction, noLength;

import '../source/source_library_builder.dart';

import 'formal_parameter_builder.dart';
import 'library_builder.dart';
import 'named_type_builder.dart';
import 'nullability_builder.dart';
import 'omitted_type_builder.dart';
import 'type_builder.dart';
import 'type_variable_builder.dart';

class FunctionTypeBuilder extends TypeBuilder {
  final TypeBuilder returnType;
  final List<TypeVariableBuilder>? typeVariables;
  final List<ParameterBuilder>? formals;
  @override
  final NullabilityBuilder nullabilityBuilder;
  @override
  final Uri? fileUri;
  @override
  final int charOffset;

  FunctionType? _type;

  FunctionTypeBuilder(this.returnType, this.typeVariables, this.formals,
      this.nullabilityBuilder, this.fileUri, this.charOffset);

  @override
  String? get name => null;

  @override
  String get debugName => "Function";

  @override
  bool get isVoidType => false;

  @override
  StringBuffer printOn(StringBuffer buffer) {
    if (typeVariables != null) {
      buffer.write("<");
      bool isFirst = true;
      for (TypeVariableBuilder t in typeVariables!) {
        if (!isFirst) {
          buffer.write(", ");
        } else {
          isFirst = false;
        }
        buffer.write(t.name);
      }
      buffer.write(">");
    }
    buffer.write("(");
    if (formals != null) {
      bool isFirst = true;
      for (ParameterBuilder t in formals!) {
        if (!isFirst) {
          buffer.write(", ");
        } else {
          isFirst = false;
        }
        buffer.write(t.name);
      }
    }
    buffer.write(") ->");
    nullabilityBuilder.writeNullabilityOn(buffer);
    buffer.write(" ");
    buffer.write(returnType.fullNameForErrors);
    return buffer;
  }

  @override
  FunctionType build(LibraryBuilder library, TypeUse typeUse) {
    return _type ??= _buildInternal(library, typeUse) as FunctionType;
  }

  DartType _buildInternal(LibraryBuilder library, TypeUse typeUse) {
    DartType aliasedType = buildAliased(library, typeUse);
    return unalias(aliasedType,
        legacyEraseAliases: !library.isNonNullableByDefault);
  }

  @override
  DartType buildAliased(LibraryBuilder library, TypeUse typeUse) {
    DartType builtReturnType = returnType is OmittedTypeBuilder
        ? const DynamicType()
        : returnType.buildAliased(library, TypeUse.returnType);
    List<DartType> positionalParameters = <DartType>[];
    List<NamedType>? namedParameters;
    int requiredParameterCount = 0;
    if (formals != null) {
      for (ParameterBuilder formal in formals!) {
        DartType type = formal.type is OmittedTypeBuilder
            ? const DynamicType()
            : formal.type.buildAliased(library, TypeUse.parameterType);
        if (formal.isPositional) {
          positionalParameters.add(type);
          if (formal.isRequiredPositional) requiredParameterCount++;
        } else if (formal.isNamed) {
          namedParameters ??= <NamedType>[];
          namedParameters.add(new NamedType(formal.name!, type,
              isRequired: formal.isRequiredNamed));
        }
      }
      if (namedParameters != null) {
        namedParameters.sort();
      }
    }
    List<TypeParameter>? typeParameters;
    if (typeVariables != null) {
      typeParameters = <TypeParameter>[];
      for (TypeVariableBuilder t in typeVariables!) {
        typeParameters.add(t.parameter);
        // Build the bound to detect cycles in typedefs.
        t.bound?.build(library, TypeUse.typeParameterBound);
      }
    }
    return new FunctionType(positionalParameters, builtReturnType,
        nullabilityBuilder.build(library),
        namedParameters: namedParameters ?? const <NamedType>[],
        typeParameters: typeParameters ?? const <TypeParameter>[],
        requiredParameterCount: requiredParameterCount);
  }

  @override
  Supertype? buildSupertype(LibraryBuilder library) {
    library.addProblem(
        messageSupertypeIsFunction, charOffset, noLength, fileUri);
    return null;
  }

  @override
  Supertype? buildMixedInType(LibraryBuilder library) {
    return buildSupertype(library);
  }

  @override
  FunctionTypeBuilder clone(
      List<NamedTypeBuilder> newTypes,
      SourceLibraryBuilder contextLibrary,
      TypeParameterScopeBuilder contextDeclaration) {
    List<TypeVariableBuilder>? clonedTypeVariables;
    if (typeVariables != null) {
      clonedTypeVariables = contextLibrary.copyTypeVariables(
          typeVariables!, contextDeclaration,
          kind: TypeVariableKind.function);
    }
    List<ParameterBuilder>? clonedFormals;
    if (formals != null) {
      clonedFormals =
          new List<ParameterBuilder>.generate(formals!.length, (int i) {
        ParameterBuilder formal = formals![i];
        return formal.clone(newTypes, contextLibrary, contextDeclaration);
      }, growable: false);
    }
    return new FunctionTypeBuilder(
        returnType.clone(newTypes, contextLibrary, contextDeclaration),
        clonedTypeVariables,
        clonedFormals,
        nullabilityBuilder,
        fileUri,
        charOffset);
  }

  @override
  FunctionTypeBuilder withNullabilityBuilder(
      NullabilityBuilder nullabilityBuilder) {
    return new FunctionTypeBuilder(returnType, typeVariables, formals,
        nullabilityBuilder, fileUri, charOffset);
  }
}
