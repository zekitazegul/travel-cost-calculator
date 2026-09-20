import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'travel_cost_api.dart';

class NavigationService {
  /// Creates a Google Maps directions URL.
  ///
  /// Google Maps supports:
  /// - origin
  /// - destination
  /// - up to 9 waypoints on supported platforms
  /// - driving mode
  ///
  /// Mobile browsers may support only up to 3 waypoints.
  static Uri googleMapsUrl({
    String? originAddress,
    Coordinate? originCoordinate,
    required String destinationAddress,
    List<String> waypoints = const [],
  }) {
    final parameters = <String, String>{
      'api': '1',
      'destination': destinationAddress.trim(),
      'travelmode': 'driving',
    };

    if (originCoordinate != null) {
      parameters['origin'] =
          '${originCoordinate.lat},${originCoordinate.lon}';
    } else if (originAddress != null &&
        originAddress.trim().isNotEmpty) {
      parameters['origin'] = originAddress.trim();
    }

    if (waypoints.isNotEmpty) {
      parameters['waypoints'] = waypoints
          .where((waypoint) => waypoint.trim().isNotEmpty)
          .join('|');
    }

    return Uri.https(
      'www.google.com',
      '/maps/dir/',
      parameters,
    );
  }

  /// Creates a Waze navigation URL.
  ///
  /// Waze officially supports navigating to a destination.
  /// It does not provide a documented equivalent of Google's
  /// multi-waypoint parameter, so only the final destination
  /// is sent here.
  static Uri wazeUrl({
    required String destinationAddress,
  }) {
    return Uri.https(
      'waze.com',
      '/ul',
      {
        'q': destinationAddress.trim(),
        'navigate': 'yes',
      },
    );
  }

  /// Creates an Apple Maps Unified Maps URL.
  ///
  /// Apple Maps supports multiple waypoint parameters by
  /// repeating `waypoint` in the query string.
  static Uri appleMapsUrl({
    String? sourceAddress,
    Coordinate? sourceCoordinate,
    required String destinationAddress,
    List<String> waypoints = const [],
  }) {
    final queryParts = <String>[];

    void addParameter(String name, String value) {
      if (value.trim().isEmpty) {
        return;
      }

      queryParts.add(
        '${Uri.encodeQueryComponent(name)}='
        '${Uri.encodeQueryComponent(value.trim())}',
      );
    }

    if (sourceCoordinate != null) {
      addParameter(
        'source',
        '${sourceCoordinate.lat},${sourceCoordinate.lon}',
      );
    } else if (sourceAddress != null &&
        sourceAddress.trim().isNotEmpty) {
      addParameter(
        'source',
        sourceAddress,
      );
    }

    addParameter(
      'destination',
      destinationAddress,
    );

    for (final waypoint in waypoints) {
      if (waypoint.trim().isNotEmpty) {
        addParameter(
          'waypoint',
          waypoint,
        );
      }
    }

    addParameter('mode', 'driving');

    return Uri.parse(
      'https://maps.apple.com/directions?${queryParts.join('&')}',
    );
  }

  /// Opens Google Maps.
  static Future<bool> openGoogleMaps({
    String? originAddress,
    Coordinate? originCoordinate,
    required String destinationAddress,
    List<String> waypoints = const [],
  }) {
    final uri = googleMapsUrl(
      originAddress: originAddress,
      originCoordinate: originCoordinate,
      destinationAddress: destinationAddress,
      waypoints: waypoints,
    );

    return _openUrl(uri);
  }

  /// Opens Waze.
  static Future<bool> openWaze({
    required String destinationAddress,
  }) {
    final uri = wazeUrl(
      destinationAddress: destinationAddress,
    );

    return _openUrl(uri);
  }

  /// Opens Apple Maps.
  static Future<bool> openAppleMaps({
    String? sourceAddress,
    Coordinate? sourceCoordinate,
    required String destinationAddress,
    List<String> waypoints = const [],
  }) {
    final uri = appleMapsUrl(
      sourceAddress: sourceAddress,
      sourceCoordinate: sourceCoordinate,
      destinationAddress: destinationAddress,
      waypoints: waypoints,
    );

    return _openUrl(uri);
  }

  static Future<bool> _openUrl(Uri uri) async {
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (launched) {
        return true;
      }

      return await launchUrl(
        uri,
        mode: LaunchMode.platformDefault,
      );
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }
}