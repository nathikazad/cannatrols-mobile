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

class CureTargets {
  final double temperature;
  final double dewPoint;
  final StepMode stepMode;
  final int timeLeft;

  CureTargets({
    required this.temperature,
    required this.dewPoint,
    required this.stepMode,
    required this.timeLeft,
  });

  factory CureTargets.fromJson(Map<String, dynamic> json, String cycle) {
    String firstLetter = cycle.substring(0, 1);
    print("${firstLetter}temp: ${json['${firstLetter}temp']}, ${firstLetter}dp: ${json['${firstLetter}dp']}, ${firstLetter}sm: ${json['${firstLetter}sm']}, ${firstLetter}time: ${json['${firstLetter}time']}");
    return CureTargets(
      temperature: (json['${firstLetter}temp'] as num).toDouble(),
      dewPoint: (json['${firstLetter}dp'] as num).toDouble(),
      stepMode: stringToStepMode(json["${firstLetter}sm"]),
      timeLeft: (json['${firstLetter}time'] as num).toInt()
    );
  }

  factory CureTargets.initial() {
    return CureTargets(
      temperature: 68.0,
      dewPoint: 54.0,
      stepMode: StepMode.step,
      timeLeft: 25 * 3600,
    );
  }
}

Map<CureCycle, CureTargets> jsonToCureTargets(Map<String, dynamic> json) {
  print(json);
  return {
    CureCycle.cure: CureTargets.fromJson(json, 'cure'),
    CureCycle.dry: CureTargets.fromJson(json, 'dry'),
    CureCycle.store: CureTargets.fromJson(json, 'store'),
  };
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

  CureState({
    required this.temperature,
    required this.dewPoint,
    required this.humidity,
    required this.timestamp,
    required this.cycle,
    required this.timeLeft,
    required this.isPlaying,
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
  }) {
    return CureState(
      temperature: temperature ?? this.temperature,
      dewPoint: dewPoint ?? this.dewPoint,
      humidity: humidity ?? this.humidity,
      timestamp: timestamp ?? this.timestamp,
      timeLeft: timeLeft ?? this.timeLeft,
      cycle: cycle ?? this.cycle,
      isPlaying: isPlaying ?? this.isPlaying,
    );
  }
}

// Connection status enum
enum ConnectionStatus {
  disconnected,
  connecting,
  connected,
  error,
  timedOut,
}

// Abstract interface for device data service
abstract class CureDataService {

  // Stream of environmental data
  Stream<CureState> get stateStream;

  // Stream of cure targets
  Stream<Map<CureCycle, CureTargets>> get cureTargetsStream;

  // Get current data
  CureState? get currentData;

  // declare dictionary of cure cycles
  Map<CureCycle, CureTargets> get cureTargets;

  // Stream of connection status updates
  Stream<ConnectionStatus> get connectionStatusStream;
  
  // Current connection status
  ConnectionStatus get connectionStatus;
  
  // Connect to a device
  Future<void> connect(String deviceId);
  
  // Disconnect from the device
  Future<void> disconnect();

  // Ask for cure targets
  Future<void> askForCureTargets();

  // Publish a message to a topic
  void publishMessage(Map<String, dynamic> message);
  
  // Dispose resources
  void dispose();
}