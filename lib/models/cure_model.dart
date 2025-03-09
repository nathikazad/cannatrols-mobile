import 'dart:async';


enum CureCycle {
  cure,
  dry,
  store
}

CureCycle stringToCureCycle(String cycleString) {
  return CureCycle.values.firstWhere(
    (cycle) => cycle.toString().split('.').last == cycleString,
    orElse: () => CureCycle.store, // Default value if not found
  );
}

String cycleToString(CureCycle cycle) {
  return cycle.toString().split('.').last;
}

class Device {
  final String id;
  final String name;

  Device({required this.id, required this.name});
}

enum StepMode {
  step,
  slope
}

StepMode stringToStepMode(String stepModeString) {
  return StepMode.values.firstWhere(
    (stepMode) => stepMode.toString().split('.').last == stepModeString,
    orElse: () => StepMode.step, // Default value if not found
  );
}

String stepModeToString(StepMode stepMode) {
  return stepMode.toString().split('.').last;
}
// Data model for environmental data
class CureState {
  final double temperature;
  final double dewPoint;
  final int humidity;
  final CureCycle cycle;
  final int timeLeft;
  final DateTime timestamp;
  final bool isPlaying;

  final double targetTemperature;
  final double targetDewPoint;
  final StepMode targetStepMode;
  final int targetTime;

  CureState({
    required this.temperature,
    required this.dewPoint,
    required this.humidity,
    required this.timestamp,
    required this.cycle,
    required this.timeLeft,
    required this.isPlaying,
    required this.targetTemperature,
    required this.targetDewPoint,
    required this.targetStepMode,
    required this.targetTime
  });

  // Create from JSON map
  factory CureState.fromJson(Map<String, dynamic> json) {
    print(json);
    return CureState(
      temperature: (json['temperature'] as num).toDouble(),
      dewPoint: (json['dewPoint'] as num).toDouble(),
      humidity: (json['humidity'] as num).toInt(),
      cycle: stringToCureCycle(json["cycle"]),
      timeLeft: (json['timeLeft'] as num).toInt(),
      timestamp: DateTime.now(),
      isPlaying: (json['isPlaying'] as bool),
      targetTemperature: (json['targetTemperature'] as num).toDouble(),
      targetDewPoint: (json['targetDewPoint'] as num).toDouble(),
      targetStepMode: stringToStepMode(json["stepMode"]),
      targetTime: (json['targetTime'] as num).toInt()
    );
  }

  // Default values for initial state
  factory CureState.initial() {
    return CureState(
      temperature: 68.0,
      dewPoint: 54.0,
      humidity: 57,
      timeLeft: 248940,
      cycle: CureCycle.store,
      timestamp: DateTime.now(),
      isPlaying: false,
      targetTemperature: 68.0,
      targetDewPoint: 57.0,
      targetStepMode: StepMode.step,
      targetTime: 248940
    );
  }

  // Create a copy with updated values
  CureState copyWith({
    double? temperature,
    double? dewPoint,
    int? humidity,
    DateTime? timestamp,
    CureCycle? cycle,
    int? timeLeft,
    bool? isPlaying,
    double? targetTemperature,
    double? targetDewPoint,
    StepMode? targetStepMode,
    int? targetTime
  }) {
    return CureState(
      temperature: temperature ?? this.temperature,
      dewPoint: dewPoint ?? this.dewPoint,
      humidity: humidity ?? this.humidity,
      timestamp: timestamp ?? this.timestamp,
      timeLeft: timeLeft ?? this.timeLeft,
      cycle: cycle ?? this.cycle,
      isPlaying: isPlaying ?? this.isPlaying,
      targetTemperature: targetTemperature ?? this.targetTemperature,
      targetDewPoint: targetDewPoint ?? this.targetDewPoint,
      targetStepMode: targetStepMode ?? this.targetStepMode,
      targetTime: targetTime ?? this.targetTime,
    );
  }
}

// Connection status enum
enum ConnectionStatus {
  disconnected,
  connecting,
  connected,
  error,
}

// Abstract interface for device data service
abstract class CureDataService {

  // Stream of environmental data
  Stream<CureState> get stateStream;

  // Get current data
  CureState? get currentData;

  // Stream of connection status updates
  Stream<ConnectionStatus> get connectionStatusStream;
  
  // Current connection status
  ConnectionStatus get connectionStatus;
  
  // Connect to a device
  Future<void> connect(String deviceId);
  
  // Disconnect from the device
  Future<void> disconnect();

  // Publish a message to a topic
  void publishMessage(Map<String, dynamic> message);
  
  // Dispose resources
  void dispose();
}