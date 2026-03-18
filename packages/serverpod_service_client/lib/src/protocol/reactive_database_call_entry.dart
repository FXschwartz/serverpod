/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod_client/serverpod_client.dart' as _i1;

/// An entry in the reactive database call outbox, created by PostgreSQL
/// triggers when watched data changes.
abstract class ReactiveDatabaseCallEntry implements _i1.SerializableModel {
  ReactiveDatabaseCallEntry._({
    this.id,
    required this.handlerName,
    required this.sourceTable,
    required this.operation,
    required this.rowData,
    required this.createdAt,
  });

  factory ReactiveDatabaseCallEntry({
    int? id,
    required String handlerName,
    required String sourceTable,
    required String operation,
    required String rowData,
    required DateTime createdAt,
  }) = _ReactiveDatabaseCallEntryImpl;

  factory ReactiveDatabaseCallEntry.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return ReactiveDatabaseCallEntry(
      id: jsonSerialization['id'] as int?,
      handlerName: jsonSerialization['handlerName'] as String,
      sourceTable: jsonSerialization['sourceTable'] as String,
      operation: jsonSerialization['operation'] as String,
      rowData: jsonSerialization['rowData'] as String,
      createdAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
    );
  }

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  int? id;

  /// Name of the ReactiveDatabaseCall handler to invoke.
  String handlerName;

  /// Source table that was modified.
  String sourceTable;

  /// The operation that triggered the event (INSERT, UPDATE, or DELETE).
  String operation;

  /// The row data serialized as JSON via row_to_json().
  String rowData;

  /// When the trigger fired.
  DateTime createdAt;

  /// Returns a shallow copy of this [ReactiveDatabaseCallEntry]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  ReactiveDatabaseCallEntry copyWith({
    int? id,
    String? handlerName,
    String? sourceTable,
    String? operation,
    String? rowData,
    DateTime? createdAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'serverpod.ReactiveDatabaseCallEntry',
      if (id != null) 'id': id,
      'handlerName': handlerName,
      'sourceTable': sourceTable,
      'operation': operation,
      'rowData': rowData,
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _ReactiveDatabaseCallEntryImpl extends ReactiveDatabaseCallEntry {
  _ReactiveDatabaseCallEntryImpl({
    int? id,
    required String handlerName,
    required String sourceTable,
    required String operation,
    required String rowData,
    required DateTime createdAt,
  }) : super._(
         id: id,
         handlerName: handlerName,
         sourceTable: sourceTable,
         operation: operation,
         rowData: rowData,
         createdAt: createdAt,
       );

  /// Returns a shallow copy of this [ReactiveDatabaseCallEntry]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  ReactiveDatabaseCallEntry copyWith({
    Object? id = _Undefined,
    String? handlerName,
    String? sourceTable,
    String? operation,
    String? rowData,
    DateTime? createdAt,
  }) {
    return ReactiveDatabaseCallEntry(
      id: id is int? ? id : this.id,
      handlerName: handlerName ?? this.handlerName,
      sourceTable: sourceTable ?? this.sourceTable,
      operation: operation ?? this.operation,
      rowData: rowData ?? this.rowData,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
