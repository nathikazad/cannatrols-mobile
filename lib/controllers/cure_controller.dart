// cure_controller.dart
import 'package:flutter_app/models/cure_model.dart';
import 'package:flutter_app/stubs/mqtt_stub.dart';
import 'package:flutter_app/utils/mqtt2.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';


bool simulateData = true;


// Provider for the device data service
final cureDataServiceProvider = Provider<CureDataService>((ref) {
  // Create the appropriate service based on configuration
  final CureDataService service = simulateData
      ? StubCureDataService()
      : MqttCureDataService();
  
  // Dispose the service when the provider is disposed
  ref.onDispose(() {
    service.dispose();
  });
  
  return service;
});

// Provider for the device data controller
final cureDataControllerProvider = Provider.family<CureDataController, String>((ref, deviceId) {
  final service = ref.watch(cureDataServiceProvider);
  return CureDataController(service, deviceId);
});

// Provider for environmental data
final environmentalDataProvider = StreamProvider.family<EnvironmentalData, String>((ref, deviceId) {
  final controller = ref.watch(cureDataControllerProvider(deviceId));
  controller.connect();
  return controller.dataStream;
});

// Provider for connection status
final connectionStatusProvider = StreamProvider.family<ConnectionStatus, String>((ref, deviceId) {
  final controller = ref.watch(cureDataControllerProvider(deviceId));
  return controller.connectionStatusStream;
});

// Controller class to manage device data
class CureDataController {
  final CureDataService _service;
  final String _deviceId;
  bool _isConnected = false;
  
  CureDataController(this._service, this._deviceId);
  
  // Stream of environmental data
  Stream<EnvironmentalData> get dataStream => _service.dataStream;
  
  // Stream of connection status updates
  Stream<ConnectionStatus> get connectionStatusStream => _service.connectionStatusStream;
  
  // Current connection status
  ConnectionStatus get connectionStatus => _service.connectionStatus;
  
  // Connect to the device
  Future<void> connect() async {
    if (!_isConnected) {
      await _service.connect(_deviceId);
      _isConnected = true;
    }
  }
  
  // Disconnect from the device
  Future<void> disconnect() async {
    if (_isConnected) {
      await _service.disconnect();
      _isConnected = false;
    }
  }
  
  // For stub service only - access to additional testing methods
  StubCureDataService? get stubService => 
      _service is StubCureDataService ? _service : null;
  
  // Check if using stub service
  bool get isUsingStubService => _service is StubCureDataService;
  
  // Set simulation scenario (if using stub service)
  void setScenario(SimulationScenario scenario) {
    stubService?.setScenario(scenario);
  }

  void publishMessage(String topic, Map<String, dynamic> message) {
    _service.publishMessage(topic, message);
  }

  void advanceToDryCycle() {
    publishMessage('command', {'command': 'advanceCycle', 'cycle': 'dry'});
  }

  void advanceToCureCycle() {
    publishMessage('command', {'command': 'advanceCycle', 'cycle': 'cure'});
  }

  void advanceToStore() {
    publishMessage('command', {'command': 'advanceCycle', 'cycle': 'store'});
  }

  void restart() {
    publishMessage('command', {'command': 'restart'});
  }

  void play() {
    publishMessage('command', {'command': 'play'});
  }

  void pause() {
    publishMessage('command', {'command': 'pause'});
  }

  // In CureDataController class in cure_controller.dart
  SimulationScenario? get currentScenario {
    return stubService?.currentScenario;
  }
  
  // Manually set environmental data values (if using stub service)
  void setEnvironmentalData({
    double? temperature,
    double? dewPoint,
    int? humidity,
    CureCycle? cycle,
    int? timeLeft,
  }) {
    stubService?.setEnvironmentalData(
      temperature: temperature,
      dewPoint: dewPoint,
      humidity: humidity,
      cycle: cycle,
      timeLeft: timeLeft,
    );
  }

  EnvironmentalData? get currentData {
    return stubService?.currentData;
  }
}