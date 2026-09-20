import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'services/travel_cost_api.dart';
import 'services/navigation_service.dart';

void main() {
  runApp(const TravelCostCalculatorApp());
}

class TravelCostCalculatorApp extends StatelessWidget {
  const TravelCostCalculatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Travel Cost Calculator',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
        scaffoldBackgroundColor: const Color(0xFFF5F7FB),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Colors.grey.shade300,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: Colors.indigo,
              width: 2,
            ),
          ),
        ),
      ),
      home: const CalculatorPage(),
    );
  }
}

class CalculatorPage extends StatefulWidget {
  const CalculatorPage({super.key});

  @override
  State<CalculatorPage> createState() => _CalculatorPageState();
}

class _CalculatorPageState extends State<CalculatorPage> {
  final TextEditingController startController = TextEditingController();
  final TextEditingController destinationController =
      TextEditingController();
  final TextEditingController priceController =
      TextEditingController(text: '0.25');

  final List<TextEditingController> stopControllers = [];

  double totalDistance = 0.0;
  double totalCost = 0.0;
  double durationMinutes = 0.0;

  List<String> routeAddresses = [];

  bool isCalculating = false;
  bool hasResult = false;
  bool isUsingCurrentLocation = false;
  bool isGettingLocation = false;
  bool isSharing = false;

  Coordinate? currentLocation;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    final savedStartAddress =
        prefs.getString('default_start_address') ?? '';
    final savedPrice =
        prefs.getDouble('price_per_km') ?? 0.25;

    if (!mounted) return;

    setState(() {
      startController.text = savedStartAddress;
      priceController.text = savedPrice.toStringAsFixed(2);
    });
  }

  @override
  void dispose() {
    startController.dispose();
    destinationController.dispose();
    priceController.dispose();

    for (final controller in stopControllers) {
      controller.dispose();
    }

    super.dispose();
  }

  void addStop() {
    setState(() {
      stopControllers.add(TextEditingController());
      hasResult = false;
    });
  }

  void removeStop(int index) {
    setState(() {
      stopControllers[index].dispose();
      stopControllers.removeAt(index);
      hasResult = false;
    });
  }

  Future<void> _useCurrentLocation() async {
    if (isGettingLocation || isCalculating) {
      return;
    }

    setState(() {
      isGettingLocation = true;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        _showError(
          'Location services are disabled. Please enable location services and try again.',
        );
        return;
      }

      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        _showError(
          'Location permission was denied. You can enter the start address manually.',
        );
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        _showError(
          'Location permission is permanently denied. Please enable it in your device settings.',
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (!mounted) return;

      setState(() {
        currentLocation = Coordinate(
          lat: position.latitude,
          lon: position.longitude,
        );
        isUsingCurrentLocation = true;
        startController.clear();
        hasResult = false;
      });

      _showMessage('Current location selected.');
    } catch (error) {
      if (!mounted) return;

      _showError(
        'Unable to get your current location. '
        'Please enter the start address manually.',
      );
    } finally {
      if (mounted) {
        setState(() {
          isGettingLocation = false;
        });
      }
    }
  }

  void _useManualStartAddress() {
    if (isCalculating || isGettingLocation) {
      return;
    }

    setState(() {
      isUsingCurrentLocation = false;
      currentLocation = null;
      hasResult = false;
    });
  }

  Future<void> calculateRoute() async {
    final startAddress = startController.text.trim();
    final destinationAddress = destinationController.text.trim();

    final price = double.tryParse(
      priceController.text.replaceAll(',', '.').trim(),
    );

    if (!isUsingCurrentLocation && startAddress.isEmpty) {
      _showError(
        'Please enter a start address or use your current location.',
      );
      return;
    }

    if (isUsingCurrentLocation && currentLocation == null) {
      _showError(
        'Please select your current location again.',
      );
      return;
    }

    if (destinationAddress.isEmpty) {
      _showError('Please enter a destination address.');
      return;
    }

    if (price == null || price < 0) {
      _showError('Please enter a valid price per kilometer.');
      return;
    }

    final stopAddresses = <String>[];

    for (var i = 0; i < stopControllers.length; i++) {
      final address = stopControllers[i].text.trim();

      if (address.isEmpty) {
        _showError('Please enter an address for Stop ${i + 1}.');
        return;
      }

      stopAddresses.add(address);
    }

    setState(() {
      isCalculating = true;
      hasResult = false;
    });

    try {
      final addresses = <String>[
        if (isUsingCurrentLocation)
          'Current location'
        else
          startAddress,
        ...stopAddresses,
        destinationAddress,
      ];

      final coordinates = <Coordinate>[];

      if (isUsingCurrentLocation) {
        coordinates.add(currentLocation!);
      } else {
        coordinates.add(
          await TravelCostApi.geocode(startAddress),
        );
      }

      for (final address in stopAddresses) {
        final coordinate = await TravelCostApi.geocode(address);
        coordinates.add(coordinate);
      }

      final destinationCoordinate =
          await TravelCostApi.geocode(destinationAddress);

      coordinates.add(destinationCoordinate);

      final route = await TravelCostApi.calculateRoute(coordinates);

      if (!mounted) return;

      setState(() {
        routeAddresses = List<String>.from(addresses);
        totalDistance = route.distanceKm;
        durationMinutes = route.durationMinutes;
        totalCost = totalDistance * price;
        hasResult = true;
      });
    } catch (error) {
      if (!mounted) return;

      _showError(
        'Unable to calculate the route. '
        'Please check the addresses and try again.',
      );
    } finally {
      if (mounted) {
        setState(() {
          isCalculating = false;
        });
      }
    }
  }

  Future<void> _shareResult() async {
    if (!hasResult || isSharing) {
      return;
    }

    setState(() {
      isSharing = true;
    });

    try {
      final buffer = StringBuffer();

      buffer.writeln('Travel Cost Calculator');
      buffer.writeln();
      buffer.writeln('Route:');

      for (var index = 0; index < routeAddresses.length; index++) {
        final address = routeAddresses[index];

        if (index == 0) {
          buffer.writeln('Start: $address');
        } else if (index == routeAddresses.length - 1) {
          buffer.writeln('Destination: $address');
        } else {
          buffer.writeln('Stop $index: $address');
        }
      }

      buffer.writeln();
      buffer.writeln(
        'Distance: ${totalDistance.toStringAsFixed(1)} km',
      );
      buffer.writeln(
        'Travel time: ${_formatDuration(durationMinutes)}',
      );

      final price = double.tryParse(
        priceController.text.replaceAll(',', '.').trim(),
      );

      if (price != null) {
        buffer.writeln(
          'Rate: €${price.toStringAsFixed(2)}/km',
        );
      }

      buffer.writeln(
        'Total cost: €${totalCost.toStringAsFixed(2)}',
      );

      final shareResult = await SharePlus.instance.share(
        ShareParams(
          text: buffer.toString(),
          title: 'Travel Cost Calculator',
          subject: 'Travel Cost Calculation',
        ),
      );

      if (!mounted) return;

      if (shareResult.status == ShareResultStatus.success) {
        _showMessage('Result shared successfully.');
      }
    } catch (error) {
      if (!mounted) return;

      _showError(
        'Unable to share the result. Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() {
          isSharing = false;
        });
      }
    }
  }

  Future<void> _openGoogleMaps() async {
    if (!hasResult || routeAddresses.length < 2) {
      return;
    }

    final destination = routeAddresses.last;

    final waypoints = routeAddresses
        .sublist(1, routeAddresses.length - 1)
        .where((address) => address.trim().isNotEmpty)
        .toList();

    final opened = await NavigationService.openGoogleMaps(
      originAddress:
          isUsingCurrentLocation ? null : routeAddresses.first,
      originCoordinate:
          isUsingCurrentLocation ? currentLocation : null,
      destinationAddress: destination,
      waypoints: waypoints,
    );

    if (!mounted) return;

    if (!opened) {
      _showError(
        'Unable to open Google Maps.',
      );
    }
  }

  Future<void> _openWaze() async {
    if (!hasResult || routeAddresses.length < 2) {
      return;
    }

    final hasStops = routeAddresses.length > 2;

    final opened = await NavigationService.openWaze(
      destinationAddress: routeAddresses.last,
    );

    if (!mounted) return;

    if (!opened) {
      _showError(
        'Unable to open Waze.',
      );
      return;
    }

    if (hasStops) {
      _showMessage(
        'Waze opens the final destination. '
        'Your intermediate stops are not transferred.',
      );
    }
  }

  Future<void> _openAppleMaps() async {
    if (!hasResult || routeAddresses.length < 2) {
      return;
    }

    final destination = routeAddresses.last;

    final waypoints = routeAddresses
        .sublist(1, routeAddresses.length - 1)
        .where((address) => address.trim().isNotEmpty)
        .toList();

    final opened = await NavigationService.openAppleMaps(
      sourceAddress:
          isUsingCurrentLocation ? null : routeAddresses.first,
      sourceCoordinate:
          isUsingCurrentLocation ? currentLocation : null,
      destinationAddress: destination,
      waypoints: waypoints,
    );

    if (!mounted) return;

    if (!opened) {
      _showError(
        'Unable to open Apple Maps.',
      );
    }
  }
  void _showError(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const SettingsPage(),
      ),
    );

    await _loadSettings();
  }

  String _formatDuration(double minutes) {
    final totalMinutes = minutes.round();
    final hours = totalMinutes ~/ 60;
    final remainingMinutes = totalMinutes % 60;

    if (hours == 0) {
      return '$remainingMinutes min';
    }

    if (remainingMinutes == 0) {
      return '$hours h';
    }

    return '$hours h $remainingMinutes min';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Travel Cost Calculator',
          style: TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Settings',
            onPressed: isCalculating ? null : _openSettings,
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 850,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(),
                const SizedBox(height: 24),
                _buildRouteCard(),
                const SizedBox(height: 20),
                _buildPriceCard(),
                const SizedBox(height: 20),
                _buildCalculateButton(),
                const SizedBox(height: 24),
                _buildResultCard(),
                const SizedBox(height: 32),
                _buildSupportSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Calculate your travel cost',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Enter your route, add stops if needed, and calculate the travel cost.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.grey.shade700,
              ),
        ),
      ],
    );
  }

  Widget _buildRouteCard() {
    return Card(
      elevation: 0,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Route',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: startController,
              enabled: !isUsingCurrentLocation &&
                  !isCalculating &&
                  !isGettingLocation,
              onChanged: (_) {
                if (isUsingCurrentLocation) {
                  setState(() {
                    isUsingCurrentLocation = false;
                    currentLocation = null;
                    hasResult = false;
                  });
                }
              },
              decoration: const InputDecoration(
                labelText: 'Start address',
                hintText: 'Enter starting address',
                prefixIcon: Icon(Icons.trip_origin),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isCalculating || isGettingLocation
                        ? null
                        : _useCurrentLocation,
                    icon: isGettingLocation
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.my_location),
                    label: Text(
                      isGettingLocation
                          ? 'Getting location...'
                          : 'Use current location',
                    ),
                  ),
                ),
                if (isUsingCurrentLocation) ...[
                  const SizedBox(width: 12),
                  IconButton(
                    tooltip: 'Use manual start address',
                    onPressed: isCalculating || isGettingLocation
                        ? null
                        : _useManualStartAddress,
                    icon: const Icon(Icons.edit_location_alt_outlined),
                  ),
                ],
              ],
            ),
            if (isUsingCurrentLocation) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      color: Colors.indigo.shade700,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Your current location will be used as the start point.',
                        style: TextStyle(
                          color: Colors.indigo.shade900,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            ...List.generate(
              stopControllers.length,
              (index) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: TextField(
                  controller: stopControllers[index],
                  decoration: InputDecoration(
                    labelText: 'Stop ${index + 1}',
                    hintText: 'Enter stop address',
                    prefixIcon: const Icon(Icons.location_on_outlined),
                    suffixIcon: IconButton(
                      tooltip: 'Remove stop',
                      onPressed:
                          isCalculating ? null : () => removeStop(index),
                      icon: const Icon(Icons.close),
                    ),
                  ),
                ),
              ),
            ),
            OutlinedButton.icon(
              onPressed: isCalculating ? null : addStop,
              icon: const Icon(Icons.add),
              label: const Text('Add stop'),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: destinationController,
              decoration: const InputDecoration(
                labelText: 'Destination',
                hintText: 'Enter destination address',
                prefixIcon: Icon(Icons.flag_outlined),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceCard() {
    return Card(
      elevation: 0,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pricing',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: priceController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Price per kilometer',
                prefixIcon: Icon(Icons.euro),
                suffixText: '/ km',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalculateButton() {
    return SizedBox(
      height: 54,
      child: FilledButton.icon(
        onPressed: isCalculating ? null : calculateRoute,
        icon: isCalculating
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.calculate_outlined),
        label: Text(
          isCalculating ? 'Calculating...' : 'Calculate Route',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildResultCard() {
    return Card(
      elevation: 0,
      color: Colors.indigo.shade50,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Result',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 20),
            if (!hasResult)
              Text(
                'Enter a route and calculate to see the result.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade700,
                ),
              )
            else ...[
              _buildRouteSummary(),
              const SizedBox(height: 28),
              const Divider(),
              const SizedBox(height: 24),
              Wrap(
                alignment: WrapAlignment.spaceEvenly,
                spacing: 40,
                runSpacing: 24,
                children: [
                  _resultItem(
                    'Distance',
                    '${totalDistance.toStringAsFixed(1)} km',
                    Icons.route,
                  ),
                  _resultItem(
                    'Travel time',
                    _formatDuration(durationMinutes),
                    Icons.schedule_outlined,
                  ),
                  _resultItem(
                    'Total cost',
                    '€${totalCost.toStringAsFixed(2)}',
                    Icons.euro,
                  ),
                ],
              ),
              const SizedBox(height: 28),
              OutlinedButton.icon(
                onPressed: isSharing ? null : _shareResult,
                icon: isSharing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.share_outlined),
                label: Text(
                  isSharing ? 'Sharing...' : 'Share Result',
                ),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 20),
              const Text(
                'Navigate Route',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 12,
                children: [
                  OutlinedButton.icon(
                    onPressed: _openGoogleMaps,
                    icon: const Icon(Icons.map_outlined),
                    label: const Text('Google Maps'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _openWaze,
                    icon: const Icon(Icons.navigation_outlined),
                    label: const Text('Waze'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _openAppleMaps,
                    icon: const Icon(Icons.map),
                    label: const Text('Apple Maps'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRouteSummary() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Route',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        for (int index = 0; index < routeAddresses.length; index++)
          _buildRouteAddress(
            routeAddresses[index],
            index,
            routeAddresses.length,
          ),
      ],
    );
  }

  Widget _buildRouteAddress(
    String address,
    int index,
    int totalAddresses,
  ) {
    final bool isStart = index == 0;
    final bool isDestination = index == totalAddresses - 1;

    final IconData icon;
    final String label;

    if (isStart) {
      icon = Icons.location_on;
      label = 'Start';
    } else if (isDestination) {
      icon = Icons.flag;
      label = 'Destination';
    } else {
      icon = Icons.stop_circle_outlined;
      label = 'Stop $index';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 22,
            color: Colors.indigo,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  address,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultItem(
    String label,
    String value,
    IconData icon,
  ) {
    return Column(
      children: [
        Icon(
          icon,
          size: 30,
          color: Colors.indigo,
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _buildSupportSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 18,
      ),
      decoration: BoxDecoration(
        color: Colors.brown.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.brown.shade100,
        ),
      ),
      child: Column(
        children: [
          Text(
            'Travel Cost Calculator is free to use.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'If you find it useful, you can support its development.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                final uri = Uri.parse(
                  'https://www.ing.nl/payreq/m/?trxid=wsmGphDfkuMkMXH6kARq3iOeNVkvhj6n',
                );

                try {
                  final opened = await launchUrl(
                    uri,
                    mode: LaunchMode.externalApplication,
                  );

                  if (!opened && mounted) {
                    _showError(
                      'Unable to open payment page.',
                    );
                  }
                } catch (_) {
                  if (mounted) {
                    _showError(
                      'Unable to open payment page.',
                    );
                  }
                }
              },
              icon: const Icon(
                Icons.coffee_outlined,
                size: 32,
              ),
              label: const Text(
                'Support the Developer',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 20,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final TextEditingController startAddressController =
      TextEditingController();

  final TextEditingController priceController =
      TextEditingController();

  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    final savedStartAddress =
        prefs.getString('default_start_address') ?? '';

    final savedPrice =
        prefs.getDouble('price_per_km') ?? 0.25;

    if (!mounted) return;

    setState(() {
      startAddressController.text = savedStartAddress;
      priceController.text = savedPrice.toStringAsFixed(2);
    });
  }

  Future<void> _saveSettings() async {
    final price = double.tryParse(
      priceController.text.replaceAll(',', '.'),
    );

    if (price == null || price < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please enter a valid price per kilometer.',
          ),
        ),
      );
      return;
    }

    setState(() {
      isSaving = true;
    });

    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      'default_start_address',
      startAddressController.text.trim(),
    );

    await prefs.setDouble(
      'price_per_km',
      price,
    );

    if (!mounted) return;

    setState(() {
      isSaving = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Settings saved.'),
      ),
    );

    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    startAddressController.dispose();
    priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 700,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  elevation: 0,
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Default Route Settings',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'These values will be used automatically when you start a new calculation.',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 24),
                        TextField(
                          controller: startAddressController,
                          decoration: const InputDecoration(
                            labelText: 'Default start address',
                            hintText: 'e.g. Poortugaal, Netherlands',
                            prefixIcon: Icon(Icons.home_outlined),
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: priceController,
                          keyboardType:
                              const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Default price per kilometer',
                            prefixIcon: Icon(Icons.euro),
                            suffixText: '/ km',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 54,
                  child: FilledButton.icon(
                    onPressed: isSaving ? null : _saveSettings,
                    icon: isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(
                      isSaving ? 'Saving...' : 'Save Settings',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


