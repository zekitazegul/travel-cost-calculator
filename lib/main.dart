import 'package:flutter/material.dart';

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
    });
  }

  void removeStop(int index) {
    setState(() {
      stopControllers[index].dispose();
      stopControllers.removeAt(index);
    });
  }

  void calculateDemo() {
    final price = double.tryParse(
      priceController.text.replaceAll(',', '.'),
    );

    if (price == null || price < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid price per kilometer.'),
        ),
      );
      return;
    }

    // Temporary demo distance.
    // Real OpenStreetMap routing will replace this later.
    const demoDistance = 0.0;

    setState(() {
      totalDistance = demoDistance;
      totalCost = totalDistance * price;
    });
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
            onPressed: () {},
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
              decoration: const InputDecoration(
                labelText: 'Start address',
                hintText: 'Enter starting address',
                prefixIcon: Icon(Icons.trip_origin),
              ),
            ),
            const SizedBox(height: 16),
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
                      onPressed: () => removeStop(index),
                      icon: const Icon(Icons.close),
                    ),
                  ),
                ),
              ),
            ),
            OutlinedButton.icon(
              onPressed: addStop,
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
        onPressed: calculateDemo,
        icon: const Icon(Icons.calculate_outlined),
        label: const Text(
          'Calculate Route',
          style: TextStyle(
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
          children: [
            const Text(
              'Result',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _resultItem(
                  'Distance',
                  '${totalDistance.toStringAsFixed(1)} km',
                  Icons.route,
                ),
                _resultItem(
                  'Total cost',
                  '€${totalCost.toStringAsFixed(2)}',
                  Icons.euro,
                ),
              ],
            ),
          ],
        ),
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
    return Column(
      children: [
        Text(
          'Travel Cost Calculator is free to use.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.coffee_outlined),
          label: const Text('Support the Developer'),
        ),
      ],
    );
  }
}