// cure_controller.dart
import 'package:flutter_app/models/cure_model.dart';
import 'package:flutter_app/stubs/mqtt_stub.dart';
import 'package:flutter_app/utils/mqtt2.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';


bool simulateData = false;


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
// Provider for the device data controller (removed family parameter)
final cureControllerProvider = Provider<CureDataController>((ref) {
  final service = ref.watch(cureDataServiceProvider);
  return CureDataController(service);
});

// Controller class to manage device data
class CureDataController {
  final CureDataService _service;
  String? _connectedDeviceId;

  bool _isConnected = false;
  
  CureDataController(this._service);
  
  // Stream of environmental data
  Stream<CureState> get stateStream => _service.stateStream;
  
  // Stream of connection status updates
  Stream<ConnectionStatus> get connectionStatusStream => _service.connectionStatusStream;
  
  // Current connection status
  ConnectionStatus get connectionStatus => _service.connectionStatus;
  
  // Connect to the device
  Future<void> connect(String deviceId) async {
    print('Connecting to device: $deviceId');
    // If connected to a different device, disconnect first
    if (_isConnected && _connectedDeviceId != deviceId) {
      print('Already connected, so disconnecting from device: $_connectedDeviceId');
      await disconnect();
    }
    
    // Connect to the new device
    if (!_isConnected) {
      await _service.connect(deviceId);
      _isConnected = true;
      _connectedDeviceId = deviceId;
    }
  }
  
  // Disconnect from the device
  Future<void> disconnect() async {
    print('Disconnecting from device: $_connectedDeviceId');
    if (_isConnected) {
      await _service.disconnect();
      _isConnected = false;
      _connectedDeviceId = null;
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

  void publishMessage(Map<String, dynamic> message) {   
    _service.publishMessage(message);
  }

  void advanceToDryCycle() {
    publishMessage({'command': 'advanceCycle', 'cycle': 'dry'});
  }

  void advanceToCureCycle() {
    publishMessage({'command': 'advanceCycle', 'cycle': 'cure'});
  }

  void advanceToStore() {
    publishMessage({'command': 'advanceCycle', 'cycle': 'store'});
  }

  void restart() {
    publishMessage({'command': 'restart'});
  }

  void play() {
    publishMessage({'command': 'play'});
  }

  void pause() {
    publishMessage({'command': 'pause'});
  }

  void updateDeviceConfiguration({
    required CureCycle cycle,
    required double temperature, 
    required double dewPoint, 
    required int timeInSeconds, 
    required StepMode stepMode}) {
    print('Updating device configuration: $temperature, $dewPoint, $timeInSeconds, $stepMode');
    publishMessage({'command': 'setTargets', 'cycle': cycleToString(cycle), 'targetTemperature': temperature, 'targetDewPoint': dewPoint, 'stepMode': stepModeToString(stepMode), 'targetTime': timeInSeconds});
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

  CureState? get currentData {
    return _service.currentData;
  }
}