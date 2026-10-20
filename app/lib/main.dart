import 'package:flutter/material.dart';
import 'package:taskwise_shared/taskwise_shared.dart';

void main() {
  runApp(const TaskwiseApp());
}

/// Root widget. Real theming, localization and navigation arrive in M1.
class TaskwiseApp extends StatelessWidget {
  const TaskwiseApp({super.key});

  static const Color _seed = Colors.teal;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppInfo.name,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: _seed, brightness: Brightness.light),
      darkTheme: ThemeData(colorSchemeSeed: _seed, brightness: Brightness.dark),
      home: const PlaceholderHomePage(),
    );
  }
}

/// Temporary home screen shown until the task list lands in M1.
class PlaceholderHomePage extends StatelessWidget {
  const PlaceholderHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text(AppInfo.name)),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.task_alt,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(AppInfo.name, style: textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text('Coming soon: your tasks.', style: textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }
}
