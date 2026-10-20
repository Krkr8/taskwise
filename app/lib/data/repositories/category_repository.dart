import 'package:drift/drift.dart';
import 'package:taskwise_shared/taskwise_shared.dart';

import '../db/app_database.dart';
import 'repository_base.dart';

/// Reads and writes user-defined categories.
class CategoryRepository extends RepositoryBase {
  CategoryRepository(super.db, {required super.deviceId, super.clock});

  /// All non-deleted categories, alphabetically.
  Stream<List<Category>> watchCategories() =>
      (db.select(db.categories)
            ..where((c) => c.deleted.not())
            ..orderBy([
              (c) => OrderingTerm.asc(c.name.collate(Collate.noCase)),
            ]))
          .watch()
          .map((rows) => rows.map(_toCategory).toList());

  Future<Category> createCategory(String name, int colorValue) async {
    final category = Category(
      id: newId(),
      name: Task.validateTitle(name),
      colorValue: colorValue,
      updatedAt: now(),
      updatedByDevice: deviceId,
    );
    await db
        .into(db.categories)
        .insert(
          CategoriesCompanion.insert(
            id: category.id,
            name: category.name,
            colorValue: category.colorValue,
            updatedAt: category.updatedAt,
            updatedByDevice: Value(deviceId),
          ),
        );
    return category;
  }

  Future<void> updateCategory(String id, {String? name, int? colorValue}) =>
      (db.update(db.categories)..where((c) => c.id.equals(id))).write(
        CategoriesCompanion(
          name: name == null
              ? const Value.absent()
              : Value(Task.validateTitle(name)),
          colorValue: Value.absentIfNull(colorValue),
          updatedAt: Value(now()),
          updatedByDevice: Value(deviceId),
        ),
      );

  /// Tombstones a category and removes it from every task that used it.
  Future<void> deleteCategory(String id) => db.transaction(() async {
    final at = now();
    await (db.update(db.categories)..where((c) => c.id.equals(id))).write(
      CategoriesCompanion(
        deleted: const Value(true),
        updatedAt: Value(at),
        updatedByDevice: Value(deviceId),
      ),
    );
    await (db.update(db.tasks)..where((t) => t.categoryId.equals(id))).write(
      TasksCompanion(
        categoryId: const Value(null),
        updatedAt: Value(at),
        updatedByDevice: Value(deviceId),
      ),
    );
  });

  static Category _toCategory(CategoryRow row) => Category(
    id: row.id,
    name: row.name,
    colorValue: row.colorValue,
    updatedAt: row.updatedAt,
    deleted: row.deleted,
    updatedByDevice: row.updatedByDevice,
  );
}
