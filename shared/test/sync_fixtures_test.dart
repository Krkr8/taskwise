// Checks the sync API fixtures (shared/test/fixtures/sync/) against the
// shared models. The server replays the same files in
// server/test/contract.test.ts, so both sides agree on the JSON shapes.
import 'dart:convert';
import 'dart:io';

import 'package:taskwise_shared/taskwise_shared.dart';
import 'package:test/test.dart';

typedef _Json = Map<String, Object?>;

/// Round-trips a record of each type through its model, where one exists.
final _models = <String, _Json Function(_Json)>{
  'task': (json) => Task.fromJson(json).toJson(),
  'subtask': (json) => Subtask.fromJson(json).toJson(),
  'category': (json) => Category.fromJson(json).toJson(),
  'tag': (json) => Tag.fromJson(json).toJson(),
  'taskTag': (json) => TaskTag.fromJson(json).toJson(),
  'reminder': (json) => Reminder.fromJson(json).toJson(),
  'place': (json) => Place.fromJson(json).toJson(),
  'taskTargetDevice': (json) => TaskTargetDevice.fromJson(json).toJson(),
  // Settings are key/value rows in the app database, without a model.
  'setting': (json) => json,
};

_Json _load(String name) =>
    jsonDecode(File('test/fixtures/sync/$name').readAsStringSync()) as _Json;

void _expectRecord(String type, _Json record) {
  final roundTrip = _models[type];
  expect(roundTrip, isNotNull, reason: 'unknown record type "$type"');
  expect(roundTrip!(record), record, reason: '$type ${record['id']}');
  // Envelope fields every synced record has (SPEC.md §4).
  expect(record['id'], isA<String>());
  expect(DateTime.parse(record['updatedAt']! as String).isUtc, isTrue);
  expect(record['deleted'], isA<bool>());
  expect(record.containsKey('updatedByDevice'), isTrue);
}

void main() {
  final records = (_load('records.json')['records']! as _Json)
      .cast<String, _Json>();
  final flow = _load('flow.json');
  final steps = (flow['steps']! as List<Object?>).cast<_Json>();

  test('records.json has one record of each synced type', () {
    expect(records.keys.toSet(), _models.keys.toSet());
    records.forEach(_expectRecord);
  });

  test('flow.json uses the shared API version', () {
    for (final step in steps) {
      final path = (step['request']! as _Json)['path']! as String;
      expect(path, startsWith(AppInfo.apiBasePath));
    }
  });

  group('flow.json', () {
    for (final step in steps) {
      final request = step['request']! as _Json;
      final response = step['response']! as _Json;
      final requestBody = request['body'];
      final responseBody = response['body'];
      final ok = response['status'] == 200;

      test('${step['name']}: records and devices match the models', () {
        // Pushed records (an invalid push is meant to fail).
        if (ok && requestBody is _Json && requestBody['changes'] is List) {
          for (final change
              in (requestBody['changes']! as List).cast<_Json>()) {
            _expectRecord(
              change['type']! as String,
              change['record']! as _Json,
            );
          }
        }
        if (responseBody is! _Json) return;
        // Pulled records.
        if (responseBody['changes'] case final List<Object?> changes) {
          for (final change in changes.cast<_Json>()) {
            expect(change['seq'], isA<int>());
            _expectRecord(
              change['type']! as String,
              change['record']! as _Json,
            );
          }
        }
        // Devices, alone or in a list.
        final devices = [
          if (responseBody['devices'] case final List<Object?> list)
            ...list.cast<_Json>(),
          if (responseBody['device'] case final _Json device) device,
          if (responseBody.containsKey('type') &&
              responseBody.containsKey('lastSeenAt'))
            responseBody,
        ];
        for (final device in devices) {
          expect(Device.fromJson(device).toJson(), device);
        }
      });
    }
  });
}
