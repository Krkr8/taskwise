import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../location/geocoder.dart';

/// The address search used by every design's map picker. Tests override it
/// with a fake.
final geocoderProvider = Provider<Geocoder>((ref) => NominatimGeocoder());

/// Whether the map loads OpenStreetMap tiles. Widget tests turn it off (no
/// network there).
final mapTilesEnabledProvider = Provider<bool>((ref) => true);
