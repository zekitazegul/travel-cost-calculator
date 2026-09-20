import 'dart:convert';

import 'package:http/http.dart' as http;

class Coordinate {
  final double lat;
  final double lon;

  const Coordinate({
    required this.lat,
    required this.lon,
  });
}

class RouteResult {
  final double distanceKm;
  final double durationMinutes;

  const RouteResult({
    required this.distanceKm,
    required this.durationMinutes,
  });
}

class TravelCostApi {
  static const String baseUrl =
      'https://travel-cost-api.zekitazegul.workers.dev';

  static Future<Coordinate> geocode(String address) async {
    final response = await http.post(
      Uri.parse('$baseUrl/geocode'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'address': address,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Geocoding failed: ${response.statusCode} ${response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    return Coordinate(
      lat: (data['lat'] as num).toDouble(),
      lon: (data['lon'] as num).toDouble(),
    );
  }

  static Future<RouteResult> calculateRoute(
    List<Coordinate> coordinates,
  ) async {
    if (coordinates.length < 2) {
      throw ArgumentError(
        'At least two coordinates are required.',
      );
    }

    final response = await http.post(
      Uri.parse('$baseUrl/route'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'coordinates': coordinates
            .map(
              (coordinate) => {
                'lat': coordinate.lat,
                'lon': coordinate.lon,
              },
            )
            .toList(),
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Route calculation failed: '
        '${response.statusCode} ${response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    return RouteResult(
      distanceKm: (data['distanceKm'] as num).toDouble(),
      durationMinutes: (data['durationMinutes'] as num).toDouble(),
    );
  }
}
