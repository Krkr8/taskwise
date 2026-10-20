import 'sync_record.dart';

/// A user-defined category. A task has zero or one category.
final class Category implements SyncRecord {
  const Category({
    required this.id,
    required this.name,
    required this.colorValue,
    required this.updatedAt,
    this.deleted = false,
    this.updatedByDevice,
  });

  factory Category.fromJson(Map<String, Object?> json) => Category(
    id: json['id']! as String,
    name: json['name']! as String,
    colorValue: json['colorValue']! as int,
    updatedAt: JsonFields.parseRequiredDateTime(json['updatedAt']),
    deleted: json['deleted'] as bool? ?? false,
    updatedByDevice: json['updatedByDevice'] as String?,
  );

  @override
  final String id;
  final String name;

  /// ARGB colour as a 32-bit integer (e.g. `0xFF2E7D32`).
  final int colorValue;
  @override
  final DateTime updatedAt;
  @override
  final bool deleted;
  @override
  final String? updatedByDevice;

  Category copyWith({
    String? name,
    int? colorValue,
    DateTime? updatedAt,
    bool? deleted,
    String? Function()? updatedByDevice,
  }) => Category(
    id: id,
    name: name ?? this.name,
    colorValue: colorValue ?? this.colorValue,
    updatedAt: updatedAt ?? this.updatedAt,
    deleted: deleted ?? this.deleted,
    updatedByDevice: updatedByDevice != null
        ? updatedByDevice()
        : this.updatedByDevice,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'colorValue': colorValue,
    'updatedAt': JsonFields.dateTime(updatedAt),
    'deleted': deleted,
    'updatedByDevice': updatedByDevice,
  };

  @override
  bool operator ==(Object other) =>
      other is Category &&
      other.id == id &&
      other.name == name &&
      other.colorValue == colorValue &&
      other.updatedAt == updatedAt &&
      other.deleted == deleted &&
      other.updatedByDevice == updatedByDevice;

  @override
  int get hashCode =>
      Object.hash(id, name, colorValue, updatedAt, deleted, updatedByDevice);

  @override
  String toString() => 'Category($id, "$name")';
}
