import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:taskwise_shared/taskwise_shared.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../location/geocoder.dart';
import '../../../../location/location_reminder_sync.dart';
import '../../../../state/providers.dart';
import '../../../shared/location/map_providers.dart';
import '../../../shared/tasks/labels.dart';
import '../../../shared/theme/tokens.dart';

/// What the picker returns.
final class PickedLocation {
  const PickedLocation({
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    this.placeId,
    this.label,
    this.trigger = LocationTrigger.arrive,
    this.newPlaceName,
  });

  /// A saved place, when one was picked as it is.
  final String? placeId;
  final double latitude;
  final double longitude;

  /// The search result's name for a spot (not a saved place).
  final String? label;
  final int radiusMeters;
  final LocationTrigger trigger;

  /// The place's name: in place mode, or when "Save as a place" was on (the
  /// caller then saves the place first).
  final String? newPlaceName;
}

/// Picks a place on an OpenStreetMap map: search an address, tap to drop a
/// pin, or pick a saved place; with a radius circle preview.
///
/// [LocationPickerPage.reminder] also asks for Arrive / Leave and offers
/// "Save as a place". [LocationPickerPage.place] edits a saved place (name,
/// position, default radius).
class LocationPickerPage extends ConsumerStatefulWidget {
  const LocationPickerPage.reminder({super.key, this.initial})
    : forPlace = false,
      place = null;

  const LocationPickerPage.place({super.key, this.place})
    : forPlace = true,
      initial = null;

  /// The reminder being edited (reminder mode).
  final Reminder? initial;

  /// The place being edited (place mode; null adds one).
  final Place? place;
  final bool forPlace;

  @override
  ConsumerState<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends ConsumerState<LocationPickerPage> {
  final _map = MapController();
  final _search = TextEditingController();
  final _name = TextEditingController();

  LatLng? _pin;
  String? _placeId;
  String? _label;
  late int _radius;
  LocationTrigger _trigger = LocationTrigger.arrive;
  bool _saveAsPlace = false;

  List<GeocodeResult>? _results;
  bool _searching = false;
  String? _searchError;
  String? _error;

  @override
  void initState() {
    super.initState();
    _radius = ref.read(appSettingsProvider).defaultLocationRadius;
    if (widget.place case final place?) {
      _pin = LatLng(place.latitude, place.longitude);
      _radius = place.radiusMeters;
      _name.text = place.name;
    }
    if (widget.initial case final r?) {
      _trigger = r.trigger ?? LocationTrigger.arrive;
      _radius = r.radiusMeters ?? _radius;
      _placeId = r.placeId;
      _label = r.label;
      if ((r.latitude, r.longitude) case (final lat?, final lon?)) {
        _pin = LatLng(lat, lon);
      }
    }
    _radius = _radius.clamp(minLocationRadius, maxLocationRadius);
  }

  @override
  void dispose() {
    _map.dispose();
    _search.dispose();
    _name.dispose();
    super.dispose();
  }

  /// Fills in the pin of a saved place (known only once places load).
  LatLng? _effectivePin(List<Place> places) {
    if (_placeId case final id?) {
      for (final p in places) {
        if (p.id == id) return LatLng(p.latitude, p.longitude);
      }
    }
    return _pin;
  }

  void _moveTo(LatLng point, {double zoom = 17}) {
    try {
      _map.move(point, zoom);
    } on Object {
      // The map isn't laid out yet; it starts at the pin anyway.
    }
  }

  void _drop(LatLng point, {String? label}) => setState(() {
    _pin = point;
    _placeId = null;
    _label = label;
    _error = null;
    if (_saveAsPlace && label != null && _name.text.isEmpty) {
      _name.text = label;
    }
  });

  void _pickPlace(Place place) {
    setState(() {
      _placeId = place.id;
      _pin = LatLng(place.latitude, place.longitude);
      _label = null;
      _radius = place.radiusMeters.clamp(minLocationRadius, maxLocationRadius);
      _saveAsPlace = false;
      _error = null;
    });
    _moveTo(LatLng(place.latitude, place.longitude));
  }

  Future<void> _runSearch() async {
    final query = _search.text.trim();
    if (query.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _searching = true;
      _searchError = null;
      _results = null;
    });
    final l10n = context.l10n;
    try {
      final results = await ref
          .read(geocoderProvider)
          .search(query, language: l10n.localeName);
      if (!mounted) return;
      setState(() => _results = results);
    } on GeocodeException {
      if (!mounted) return;
      setState(() => _searchError = l10n.locSearchFailed);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _pickResult(GeocodeResult r) {
    final point = LatLng(r.latitude, r.longitude);
    _drop(point, label: r.name);
    setState(() => _results = null);
    _moveTo(point);
  }

  Future<void> _useMyLocation() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final fix = await ref.read(locationPlatformProvider).currentLocation();
    if (!mounted) return;
    if (fix == null) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.locNoFix)));
      return;
    }
    final point = LatLng(fix.latitude, fix.longitude);
    _drop(point);
    _moveTo(point);
  }

  void _save(List<Place> places) {
    final l10n = context.l10n;
    final pin = _effectivePin(places);
    final name = _name.text.trim();
    if (pin == null) {
      setState(() => _error = l10n.locNeedPin);
      return;
    }
    if ((widget.forPlace || _saveAsPlace) && name.isEmpty) {
      setState(() => _error = l10n.fieldRequired);
      return;
    }
    Navigator.of(context).pop(
      PickedLocation(
        placeId: widget.forPlace ? widget.place?.id : _placeId,
        latitude: pin.latitude,
        longitude: pin.longitude,
        label: _placeId == null
            ? (_label ?? (_saveAsPlace ? name : null))
            : null,
        radiusMeters: _radius,
        trigger: _trigger,
        newPlaceName: widget.forPlace || (_saveAsPlace && _placeId == null)
            ? name
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final places = ref.watch(placesProvider).value ?? const <Place>[];
    final phone = ref.watch(locationPlatformProvider).supported;
    final pin = _effectivePin(places);
    final start =
        pin ??
        (places.isEmpty
            ? const LatLng(25, 30)
            : LatLng(places.first.latitude, places.first.longitude));

    final title = widget.forPlace
        ? (widget.place == null ? l10n.addPlace : l10n.editPlace)
        : l10n.locPickerTitle;

    final map = FlutterMap(
      mapController: _map,
      options: MapOptions(
        initialCenter: start,
        initialZoom: pin != null || places.isNotEmpty ? 16 : 2,
        onTap: (_, point) => _drop(point),
      ),
      children: [
        if (ref.watch(mapTilesEnabledProvider))
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'io.github.krkr8.taskwise',
          ),
        if (pin != null) ...[
          CircleLayer(
            circles: [
              CircleMarker(
                point: pin,
                radius: _radius.toDouble(),
                useRadiusInMeter: true,
                color: scheme.primary.withValues(alpha: 0.18),
                borderColor: scheme.primary,
                borderStrokeWidth: 2,
              ),
            ],
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: pin,
                width: 40,
                height: 40,
                alignment: Alignment.topCenter,
                child: Icon(Icons.location_on, size: 40, color: scheme.error),
              ),
            ],
          ),
        ],
        const SimpleAttributionWidget(
          source: Text('OpenStreetMap contributors'),
        ),
      ],
    );

    final controls = <Widget>[
      if (widget.forPlace)
        TextField(
          controller: _name,
          decoration: InputDecoration(labelText: l10n.locPlaceName),
          textInputAction: TextInputAction.done,
        ),
      if (!widget.forPlace) ...[
        if (places.isNotEmpty)
          Wrap(
            spacing: Spacing.sm,
            runSpacing: Spacing.xs,
            children: [
              for (final p in places)
                ChoiceChip(
                  avatar: const Icon(Icons.place_outlined, size: 18),
                  label: Text(p.name),
                  selected: _placeId == p.id,
                  onSelected: (_) => _pickPlace(p),
                ),
            ],
          ),
        const SizedBox(height: Spacing.sm),
        Text(l10n.locRemindWhen, style: theme.textTheme.bodyLarge),
        const SizedBox(height: Spacing.xs),
        SegmentedButton<LocationTrigger>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(
              value: LocationTrigger.arrive,
              label: Text(l10n.locArrive),
              icon: const Icon(Icons.login),
            ),
            ButtonSegment(
              value: LocationTrigger.leave,
              label: Text(l10n.locLeave),
              icon: const Icon(Icons.logout),
            ),
          ],
          selected: {_trigger},
          onSelectionChanged: (s) => setState(() => _trigger = s.single),
        ),
      ],
      const SizedBox(height: Spacing.sm),
      Row(
        children: [
          Text(l10n.locRadius, style: theme.textTheme.bodyLarge),
          Expanded(
            child: Slider(
              value: _radius.toDouble(),
              min: minLocationRadius.toDouble(),
              max: maxLocationRadius.toDouble(),
              divisions: (maxLocationRadius - minLocationRadius) ~/ 10,
              label: l10n.meters(_radius),
              onChanged: (v) => setState(() => _radius = v.round()),
            ),
          ),
          SizedBox(
            width: 64,
            child: Text(
              l10n.meters(_radius),
              textAlign: TextAlign.end,
              style: theme.textTheme.titleSmall,
            ),
          ),
        ],
      ),
      if (!widget.forPlace && _placeId == null) ...[
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.locSaveAsPlace),
          value: _saveAsPlace,
          onChanged: (on) => setState(() {
            _saveAsPlace = on;
            if (on && _name.text.isEmpty) _name.text = _label ?? '';
          }),
        ),
        if (_saveAsPlace)
          TextField(
            controller: _name,
            decoration: InputDecoration(labelText: l10n.locPlaceName),
          ),
      ],
      if (!phone && !widget.forPlace)
        Padding(
          padding: const EdgeInsets.only(top: Spacing.sm),
          child: Row(
            children: [
              Icon(
                Icons.phone_iphone,
                size: 18,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: Spacing.xs),
              Flexible(
                child: Text(
                  l10n.locOnlyPhones,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      if (_error case final error?)
        Padding(
          padding: const EdgeInsets.only(top: Spacing.sm),
          child: Text(
            error,
            style: theme.textTheme.bodyMedium?.copyWith(color: scheme.error),
          ),
        ),
    ];

    final searchBar = Padding(
      padding: const EdgeInsets.fromLTRB(
        Spacing.lg,
        Spacing.sm,
        Spacing.lg,
        Spacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => unawaited(_runSearch()),
              decoration: InputDecoration(
                hintText: l10n.locSearchHint,
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: Spacing.sm),
          if (_searching)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            IconButton.filledTonal(
              tooltip: l10n.locSearch,
              icon: const Icon(Icons.arrow_forward),
              onPressed: () => unawaited(_runSearch()),
            ),
          if (phone)
            IconButton(
              tooltip: l10n.locUseMyLocation,
              icon: const Icon(Icons.my_location),
              onPressed: () => unawaited(_useMyLocation()),
            ),
        ],
      ),
    );

    final results = _results;
    final searchFeedback = _searchError != null || (results?.isEmpty ?? false)
        ? Padding(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
            child: Text(
              _searchError ?? l10n.locSearchNoResults,
              style: theme.textTheme.bodySmall?.copyWith(
                color: _searchError != null
                    ? scheme.error
                    : scheme.onSurfaceVariant,
              ),
            ),
          )
        : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: Spacing.sm),
            child: FilledButton(
              onPressed: () => _save(places),
              child: Text(l10n.save),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            searchBar,
            ?searchFeedback,
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(child: map),
                  if (pin == null)
                    PositionedDirectional(
                      top: Spacing.sm,
                      start: Spacing.sm,
                      end: Spacing.sm,
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(Spacing.sm),
                          child: Text(l10n.locTapToDrop),
                        ),
                      ),
                    ),
                  if (results != null && results.isNotEmpty)
                    PositionedDirectional(
                      top: 0,
                      start: Spacing.lg,
                      end: Spacing.lg,
                      child: Card(
                        elevation: 4,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 280),
                          child: ListView(
                            shrinkWrap: true,
                            padding: EdgeInsets.zero,
                            children: [
                              for (final r in results)
                                ListTile(
                                  dense: true,
                                  leading: const Icon(Icons.place_outlined),
                                  title: Text(r.name),
                                  subtitle: Text(
                                    r.address,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  onTap: () => _pickResult(r),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.45,
              ),
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(
                  Spacing.lg,
                  Spacing.md,
                  Spacing.lg,
                  Spacing.lg,
                ),
                children: controls,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Opens the picker for a location reminder.
Future<PickedLocation?> pickReminderLocation(
  BuildContext context, {
  Reminder? initial,
}) => Navigator.of(context).push<PickedLocation>(
  MaterialPageRoute(
    fullscreenDialog: true,
    builder: (_) => LocationPickerPage.reminder(initial: initial),
  ),
);

/// Opens the picker to add or edit a saved place.
Future<PickedLocation?> pickPlace(BuildContext context, {Place? place}) =>
    Navigator.of(context).push<PickedLocation>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => LocationPickerPage.place(place: place),
      ),
    );

/// Name of the place a location reminder points to: the saved place's
/// name, the reminder's label, or "dropped pin".
String locationName(
  AppLocalizations l10n,
  Reminder reminder,
  List<Place> places,
) {
  if (reminder.placeId case final id?) {
    for (final p in places) {
      if (p.id == id) return p.name;
    }
  }
  return reminder.label ?? l10n.locDroppedPin;
}

/// "Arrive at Home · 30 m".
String locationReminderLabel(
  AppLocalizations l10n,
  Reminder reminder,
  List<Place> places,
) {
  final name = locationName(l10n, reminder, places);
  final what = reminder.trigger == LocationTrigger.leave
      ? l10n.locChipLeave(name)
      : l10n.locChipArrive(name);
  return '$what · ${l10n.meters(reminder.radiusMeters ?? Place.defaultRadiusMeters)}';
}
