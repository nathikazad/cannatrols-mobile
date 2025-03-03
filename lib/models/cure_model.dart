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

// Data model for environmental data
class EnvironmentalData {
  final double temperature;
  final double dewPoint;
  final int humidity;
  final CureCycle cycle;
  final int timeLeft;
  final DateTime timestamp;
  final bool isPlaying;

  EnvironmentalData({
    required this.temperature,
    required this.dewPoint,
    required this.humidity,
    required this.timestamp,
    required this.cycle,
    required this.timeLeft,
    required this.isPlaying
  });

  // Create from JSON map
  factory EnvironmentalData.fromJson(Map<String, dynamic> json) {
    return EnvironmentalData(
      temperature: (json['temperature'] as num).toDouble(),
      dewPoint: 0.0,//(json['dewPoint'] as num).toDouble(),
      humidity: 0,//(json['humidity'] as num).toInt(),
      cycle: stringToCureCycle("store"),
      timeLeft: 0,
      timestamp: DateTime.now(),
      isPlaying: false
    );
  }

  // Default values for initial state
  factory EnvironmentalData.initial() {
    return EnvironmentalData(
      temperature: 68.0,
      dewPoint: 54.0,
      humidity: 57,
      timeLeft: 248940,
      cycle: CureCycle.store,
      timestamp: DateTime.now(),
      isPlaying: false
    );
  }

  // Create a copy with updated values
  EnvironmentalData copyWith({
    double? temperature,
    double? dewPoint,
    int? humidity,
    DateTime? timestamp,
    CureCycle? cycle,
    int? timeLeft,
    bool? isPlaying
  }) {
    return EnvironmentalData(
      temperature: temperature ?? this.temperature,
      dewPoint: dewPoint ?? this.dewPoint,
      humidity: humidity ?? this.humidity,
      timestamp: timestamp ?? this.timestamp,
      timeLeft: timeLeft ?? this.timeLeft,
      cycle: cycle ?? this.cycle,
      isPlaying: isPlaying ?? this.isPlaying
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
  Stream<EnvironmentalData> get dataStream;
  
  // Stream of connection status updates
  Stream<ConnectionStatus> get connectionStatusStream;
  
  // Current connection status
  ConnectionStatus get connectionStatus;
  
  // Connect to a device
  Future<void> connect(String deviceId);
  
  // Disconnect from the device
  Future<void> disconnect();

  // Publish a message to a topic
  void publishMessage(String topic, Map<String, dynamic> message);
  
  // Dispose resources
  void dispose();
}