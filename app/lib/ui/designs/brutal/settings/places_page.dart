import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taskwise_shared/taskwise_shared.dart';

import '../../../../state/providers.dart';
import '../location/location_picker_page.dart';
import '../../../shared/tasks/labels.dart';
import '../theme/tokens.dart';

/// Add, edit and delete saved places (Settings → Saved places).
class PlacesPage extends ConsumerWidget {
  const PlacesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final repo = ref.read(placeRepositoryProvider);
    final places = ref.watch(placesProvider).value ?? const <Place>[];

    Future<void> add() async {
      final picked = await pickPlace(context);
      final name = picked?.newPlaceName;
      if (picked == null || name == null) return;
      await repo.createPlace(
        name: name,
        latitude: picked.latitude,
        longitude: picked.longitude,
        radiusMeters: picked.radiusMeters,
      );
    }

    Future<void> edit(Place place) async {
      final picked = await pickPlace(context, place: place);
      if (picked == null) return;
      await repo.updatePlace(
        place.id,
        name: picked.newPlaceName,
        latitude: picked.latitude,
        longitude: picked.longitude,
        radiusMeters: picked.radiusMeters,
      );
    }

    Future<void> delete(Place place) async {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.deletePlaceTitle),
          content: Text(l10n.deletePlaceBody(place.name)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.delete),
            ),
          ],
        ),
      );
      if (ok ?? false) await repo.deletePlace(place.id);
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.placesTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: add,
        icon: const Icon(Icons.add_location_alt_outlined),
        label: Text(l10n.addPlace),
      ),
      body: places.isEmpty
          ? Center(child: Text(l10n.placesEmpty))
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                Spacing.sm,
                Spacing.sm,
                Spacing.sm,
                96,
              ),
              children: [
                for (final p in places)
                  ListTile(
                    leading: const Icon(Icons.place_outlined),
                    title: Text(p.name),
                    subtitle: Text(
                      '${p.latitude.toStringAsFixed(5)}, '
                      '${p.longitude.toStringAsFixed(5)} · '
                      '${l10n.meters(p.radiusMeters)}',
                    ),
                    onTap: () => edit(p),
                    trailing: IconButton(
                      tooltip: l10n.delete,
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => delete(p),
                    ),
                  ),
              ],
            ),
    );
  }
}
