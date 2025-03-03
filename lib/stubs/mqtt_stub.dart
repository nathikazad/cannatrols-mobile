//mqtt_stub.dart

import 'dart:async';
import 'dart:math';
import 'package:flutter_app/controllers/cure_controller.dart';
import 'package:flutter_app/models/cure_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Simulation scenario types
enum SimulationScenario {
  stable,
  risingTemperature,
  fallingTemperature,
  fluctuating,
  connectionIssues,
}

// Stub implementation for development and testing
class StubCureDataService implements CureDataService {
  // Stream controllers
  final _dataStreamController = StreamController<EnvironmentalData>.broadcast();
  final _connectionStatusController =
      StreamController<ConnectionStatus>.broadcast();

  // Current state
  ConnectionStatus _connectionStatus = ConnectionStatus.disconnected;
  EnvironmentalData _currentData = EnvironmentalData.initial();
  String? _deviceId;

  // Simulation configuration
  SimulationScenario _scenario = SimulationScenario.stable;
  Timer? _simulationTimer;
  final Random _random = Random();
  int _simulationStep = 0;

  // Configuration
  final Duration updateInterval;

  // Constructor with optional configuration
  StubCureDataService({this.updateInterval = const Duration(seconds: 2)});

  @override
  Stream<EnvironmentalData> get dataStream => _dataStreamController.stream;

  @override
  Stream<ConnectionStatus> get connectionStatusStream =>
      _connectionStatusController.stream;

  @override
  ConnectionStatus get connectionStatus => _connectionStatus;

  @override
  Future<void> connect(String deviceId) async {
    _deviceId = deviceId;
    _updateConnectionStatus(ConnectionStatus.connecting);

    // Simulate connection delay
    await Future.delayed(const Duration(milliseconds: 800));

    // 90% chance of successful connection
    if (_random.nextDouble() < 0.9) {
      _updateConnectionStatus(ConnectionStatus.connected);
      _startSimulation();
    } else {
      _updateConnectionStatus(ConnectionStatus.error);
    }
  }

  @override
  Future<void> disconnect() async {
    if (_connectionStatus == ConnectionStatus.connected) {
      _stopSimulation();
      _updateConnectionStatus(ConnectionStatus.disconnected);
    }
  }

  @override
  void dispose() {
    _stopSimulation();
    _dataStreamController.close();
    _connectionStatusController.close();
  }

  @override
  void publishMessage(String topic, Map<String, dynamic> message) {
    // For testing, you can just log the message or handle it as needed
    print('StubService: Publishing to $topic: $message');
    // You might want to handle this message in some way in your stub
  }

  // Start the simulation
  void _startSimulation() {
    _simulationTimer?.cancel();
    _simulationTimer = Timer.periodic(updateInterval, (_) => _simulateData());
  }

  // Stop the simulation
  void _stopSimulation() {
    _simulationTimer?.cancel();
    _simulationTimer = null;
  }

  // Simulate data based on the current scenario
  void _simulateData() {
    if (_connectionStatus != ConnectionStatus.connected) return;

    // Check for connection issues scenario
    if (_scenario == SimulationScenario.connectionIssues) {
      _handleConnectionIssuesScenario();
      return;
    }

    // Update simulation step
    _simulationStep++;

    // Generate new data based on scenario
    EnvironmentalData newData;
    switch (_scenario) {
      case SimulationScenario.stable:
        newData = _generateStableData();
        break;
      case SimulationScenario.risingTemperature:
        newData = _generateRisingTemperatureData();
        break;
      case SimulationScenario.fallingTemperature:
        newData = _generateFallingTemperatureData();
        break;
      case SimulationScenario.fluctuating:
        newData = _generateFluctuatingData();
        break;
      default:
        newData = _generateStableData();
    }

    // Update current data and emit
    _currentData = newData;
    _dataStreamController.add(newData);
  }

  // Generate stable data with minor random fluctuations
  EnvironmentalData _generateStableData() {
    return EnvironmentalData(
      temperature: _currentData.temperature + _randomFluctuation(0.2),
      dewPoint: _currentData.dewPoint + _randomFluctuation(0.1),
      humidity: (_currentData.humidity + _randomFluctuationInt(1)).clamp(
        0,
        100,
      ),
      timestamp: DateTime.now(),
      cycle: _currentData.cycle,
      timeLeft: _currentData.timeLeft - 2,
      isPlaying: _currentData.isPlaying,
    );
  }

  // Generate rising temperature data
  EnvironmentalData _generateRisingTemperatureData() {
    return EnvironmentalData(
      temperature: _currentData.temperature + 0.1 + _randomFluctuation(0.1),
      dewPoint: _currentData.dewPoint + 0.05 + _randomFluctuation(0.1),
      humidity: (_currentData.humidity - 1 + _randomFluctuationInt(1)).clamp(
        0,
        100,
      ),
      timestamp: DateTime.now(),
      cycle: _currentData.cycle,
      timeLeft: _currentData.timeLeft - 2,
      isPlaying: _currentData.isPlaying,
    );
  }

  // Generate falling temperature data
  EnvironmentalData _generateFallingTemperatureData() {
    return EnvironmentalData(
      temperature: _currentData.temperature - 0.1 + _randomFluctuation(0.1),
      dewPoint: _currentData.dewPoint - 0.05 + _randomFluctuation(0.1),
      humidity: (_currentData.humidity + 1 + _randomFluctuationInt(1)).clamp(
        0,
        100,
      ),
      timestamp: DateTime.now(),
      cycle: _currentData.cycle,
      timeLeft: _currentData.timeLeft - 2,
      isPlaying: _currentData.isPlaying,
    );
  }

  // Generate fluctuating data with higher variance
  EnvironmentalData _generateFluctuatingData() {
    return EnvironmentalData(
      temperature: _currentData.temperature + _randomFluctuation(0.5),
      dewPoint: _currentData.dewPoint + _randomFluctuation(0.3),
      humidity: (_currentData.humidity + _randomFluctuationInt(3)).clamp(
        0,
        100,
      ),
      timestamp: DateTime.now(),
      cycle: _currentData.cycle,
      timeLeft: _currentData.timeLeft - 2,
      isPlaying: _currentData.isPlaying,
    );
  }

  // Handle connection issues scenario
  void _handleConnectionIssuesScenario() {
    // Every 10 steps, simulate a connection drop
    if (_simulationStep % 10 == 0) {
      _updateConnectionStatus(ConnectionStatus.disconnected);

      // Reconnect after a delay
      Future.delayed(const Duration(seconds: 3), () {
        _updateConnectionStatus(ConnectionStatus.connecting);

        Future.delayed(const Duration(seconds: 2), () {
          _updateConnectionStatus(ConnectionStatus.connected);
        });
      });
    } else {
      // Continue with normal data updates
      _dataStreamController.add(_generateStableData());
    }
  }

  // Generate a random fluctuation around zero
  double _randomFluctuation(double maxMagnitude) {
    return (_random.nextDouble() * 2 - 1) * maxMagnitude;
  }

  // Generate a random integer fluctuation around zero
  int _randomFluctuationInt(int maxMagnitude) {
    return _random.nextInt(maxMagnitude * 2 + 1) - maxMagnitude;
  }

  // Update connection status
  void _updateConnectionStatus(ConnectionStatus status) {
    _connectionStatus = status;
    _connectionStatusController.add(status);
  }

  // Public methods for testing UI with different scenarios

  // Set simulation scenario
  void setScenario(SimulationScenario scenario) {
    _scenario = scenario;
    _simulationStep = 0;
  }

  // In StubCureDataService, add a getter for _currentData
  EnvironmentalData get currentData => _currentData;

  // In StubCureDataService class in mqtt_stub.dart
  SimulationScenario get currentScenario => _scenario;

  // Manually set environmental data values (for UI testing)
  void setEnvironmentalData({
    double? temperature,
    double? dewPoint,
    int? humidity,
    CureCycle? cycle,
    int? timeLeft,
  }) {
    _currentData = _currentData.copyWith(
      temperature: temperature,
      dewPoint: dewPoint,
      humidity: humidity,
      timestamp: DateTime.now(),
      cycle: cycle,
      timeLeft: timeLeft,
    );
    _dataStreamController.add(_currentData);
  }

  // Manually trigger a connection status change (for UI testing)
  void setConnectionStatus(ConnectionStatus status) {
    _updateConnectionStatus(status);

    // If connecting, simulate a completed connection after a delay
    if (status == ConnectionStatus.connecting) {
      Future.delayed(const Duration(seconds: 2), () {
        _updateConnectionStatus(ConnectionStatus.connected);
      });
    }
  }
}

// Widget to enable debug controls for stub service
class StubControls extends ConsumerWidget {
  final String deviceId;

  const StubControls({Key? key, required this.deviceId}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(cureDataControllerProvider(deviceId));

    // Only show controls if using stub service
    if (!controller.isUsingStubService) {
      return const SizedBox.shrink();
    }

    // Get current values from the controller
    final currentTemperature = controller.currentData?.temperature ?? 68.0;
    final currentDewPoint = controller.currentData?.dewPoint ?? 54.0;
    final currentHumidity =
        controller.currentData?.humidity?.toDouble() ?? 57.0;

    return ExpansionTile(
      title: const Text('Debug Controls'),
      children: [
        ListTile(
          title: const Text('Cycle'),
          trailing: DropdownButton<CureCycle>(
            value: controller.currentData?.cycle ?? CureCycle.store,
            onChanged: (value) {
              if (value != null) {
                controller.setEnvironmentalData(cycle: value);
              }
            },
            items:
                CureCycle.values.map((cycle) {
                  return DropdownMenuItem(
                    value: cycle,
                    child: Text(cycle.toString().split('.').last),
                  );
                }).toList(),
          ),
        ),
        ListTile(
          title: const Text('Set Scenario'),
          trailing: DropdownButton<SimulationScenario>(
            value: controller.currentScenario ?? SimulationScenario.stable,
            onChanged: (value) {
              if (value != null) {
                controller.setScenario(value);
              }
            },
            items:
                SimulationScenario.values.map((scenario) {
                  return DropdownMenuItem(
                    value: scenario,
                    child: Text(scenario.toString().split('.').last),
                  );
                }).toList(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Temperature: ${currentTemperature.toStringAsFixed(1)}°F"),
              Slider(
                min: 50,
                max: 90,
                divisions: 40,
                label: '${currentTemperature.toStringAsFixed(1)}°F',
                value: currentTemperature,
                onChanged: (value) {
                  controller.setEnvironmentalData(temperature: value);
                },
              ),
              Text("Dew Point: ${currentDewPoint.toStringAsFixed(1)}°F"),
              Slider(
                min: 40,
                max: 70,
                divisions: 30,
                label: '${currentDewPoint.toStringAsFixed(1)}°F',
                value: currentDewPoint,
                onChanged: (value) {
                  controller.setEnvironmentalData(dewPoint: value);
                },
              ),
              Text("Humidity: ${currentHumidity.toStringAsFixed(1)}%"),
              Slider(
                min: 0,
                max: 100,
                divisions: 100,
                label: '${currentHumidity.round()}%',
                value: currentHumidity,
                onChanged: (value) {
                  controller.setEnvironmentalData(humidity: value.round());
                },
              ),
              Text("Time Left: ${controller.currentData?.timeLeft ?? 0}"),
              Slider(
                min: 0,
                max: 300000,
                divisions: 100,
                label: '${controller.currentData?.timeLeft ?? 0}',
                value: (controller.currentData?.timeLeft ?? 0).toDouble(),
                onChanged: (value) {
                  controller.setEnvironmentalData(timeLeft: value.round());
                },
              ),
            ],
          ),
        ),
        // Connection status controls remain unchanged
        ButtonBar(
          alignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () => controller.connect(),
              child: const Text('Connect'),
            ),
            ElevatedButton(
              onPressed: () => controller.disconnect(),
              child: const Text('Disconnect'),
            ),
            ElevatedButton(
              onPressed: () {
                if (controller.stubService != null) {
                  controller.stubService!.setConnectionStatus(
                    ConnectionStatus.error,
                  );
                }
              },
              child: const Text('Simulate Error'),
            ),
          ],
        ),
      ],
    );
  }
}
