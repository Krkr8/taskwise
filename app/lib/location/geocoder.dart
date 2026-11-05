import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:taskwise_shared/taskwise_shared.dart';

/// A place found by an address search.
typedef GeocodeResult = ({
  String name,
  String address,
  double latitude,
  double longitude,
});

/// Turns a search text into places. Swappable (SPEC.md section 2): the app
/// uses [NominatimGeocoder]; tests use a fake.
abstract interface class Geocoder {
  /// Places matching [query], best first. Throws [GeocodeException] when
  /// the search service can't be reached.
  Future<List<GeocodeResult>> search(String query, {String? language});

  /// Attribution to show next to results.
  String get attribution;
}

class GeocodeException implements Exception {
  const GeocodeException(this.message);

  final String message;

  @override
  String toString() => 'GeocodeException: $message';
}

/// OpenStreetMap's Nominatim search, used within its usage policy
/// (https://operations.osmfoundation.org/policies/nominatim/): an
/// identifying User-Agent, at most one request per second, and searches
/// only when the user submits (no search-as-you-type).
class NominatimGeocoder implements Geocoder {
  NominatimGeocoder({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _base = Uri.parse(baseUrl ?? 'https://nominatim.openstreetmap.org/');

  final http.Client _client;
  final Uri _base;
  DateTime? _last;

  static const _minGap = Duration(seconds: 1);

  @override
  String get attribution => '© OpenStreetMap contributors (Nominatim)';

  @override
  Future<List<GeocodeResult>> search(String query, {String? language}) async {
    final text = query.trim();
    if (text.isEmpty) return const [];
    if (_last case final last?) {
      final wait = _minGap - DateTime.now().difference(last);
      if (wait > Duration.zero) await Future<void>.delayed(wait);
    }
    _last = DateTime.now();
    final uri = _base
        .resolve('search')
        .replace(
          queryParameters: {'q': text, 'format': 'jsonv2', 'limit': '8'},
        );
    final http.Response response;
    try {
      response = await _client
          .get(
            uri,
            headers: {
              'User-Agent': AppInfo.userAgent,
              'Accept-Language': ?language,
            },
          )
          .timeout(const Duration(seconds: 15));
    } on Object catch (e) {
      throw GeocodeException('$e');
    }
    if (response.statusCode != 200) {
      throw GeocodeException('HTTP ${response.statusCode}');
    }
    final list = jsonDecode(utf8.decode(response.bodyBytes));
    if (list is! List) return const [];
    return [
      for (final item in list)
        if (item is Map)
          if ((
                double.tryParse('${item['lat']}'),
                double.tryParse('${item['lon']}'),
              )
              case (final lat?, final lon?))
            (
              name: _name(item),
              address: item['display_name'] as String? ?? '',
              latitude: lat,
              longitude: lon,
            ),
    ];
  }

  static String _name(Map<Object?, Object?> item) {
    final name = item['name'];
    if (name is String && name.isNotEmpty) return name;
    final display = item['display_name'] as String? ?? '';
    return display.split(',').first.trim();
  }
}
