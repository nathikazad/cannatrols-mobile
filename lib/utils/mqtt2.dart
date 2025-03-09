// mqtt2.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_app/models/cure_model.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;

// Real implementation using MQTT
class MqttCureDataService implements CureDataService {
  // MQTT client
  late MqttServerClient _client;
  
  String? _deviceId;
  CureState? _currentData;

  // Stream controllers
  final _dataStreamController = StreamController<CureState>.broadcast();
  final _connectionStatusController = StreamController<ConnectionStatus>.broadcast();
  
  // Current state
  ConnectionStatus _connectionStatus = ConnectionStatus.disconnected;
  
  // Get Supabase instance
  final supabase = Supabase.instance.client;
  
  @override
  Stream<CureState> get stateStream => _dataStreamController.stream;
  
  @override
  Stream<ConnectionStatus> get connectionStatusStream => _connectionStatusController.stream;
  
  @override
  ConnectionStatus get connectionStatus => _connectionStatus;

  @override
  CureState? get currentData => _currentData;
  
  @override
  Future<void> connect(String deviceId) async {
    print("Connecting to MQTT");
    // Check if already connected to the same device
    if (_connectionStatus == ConnectionStatus.connected) {
      return;
    }
    
    // Disconnect if connected to a different device
    if (_connectionStatus == ConnectionStatus.connected) {
      await disconnect();
    }
    
    _deviceId = deviceId;
    _updateConnectionStatus(ConnectionStatus.connecting);
    
    // Fetch credentials
    final Map<String, dynamic>? credentials = await _fetchMQTTCredentials();
    if (credentials == null || credentials['data'] == null) {
      _updateConnectionStatus(ConnectionStatus.error);
      return;
    }
    
    // Set credentials
    final userId = supabase.auth.currentUser!.id;
    String host = credentials['data']['host'];
    String username = credentials['data']['username'];
    String password = credentials['data']['password'];
    String identifier = 'flutter_${userId}_${DateTime.now().millisecondsSinceEpoch}';
    String stateTopic = "$userId/$deviceId/state";
    
    // Connect to MQTT
    try {
      _setupMqttClient(host, identifier, 8883);
      print("Connecting to MQTT");
      await _client.connect(username, password);
    } catch (e) {
      _updateConnectionStatus(ConnectionStatus.error);
      print("Error connecting to MQTT: $e");
      return;
    }
    
    // Check connection status
    if (_client.connectionStatus!.state == MqttConnectionState.connected) {
      _updateConnectionStatus(ConnectionStatus.connected);
      _subscribeToTopic(stateTopic);
    } else {
      _updateConnectionStatus(ConnectionStatus.error);
    }
  }
  
  @override
  Future<void> disconnect() async {
    if (_connectionStatus == ConnectionStatus.connected ||
        _connectionStatus == ConnectionStatus.connecting) {
      _client.disconnect();
      _currentData = null;
      _updateConnectionStatus(ConnectionStatus.disconnected);
    }
  }
  
  @override
  void dispose() {
    if (_connectionStatus == ConnectionStatus.connected) {
      _client.disconnect();
    }
    _dataStreamController.close();
    _connectionStatusController.close();
  }
  
  // Set up MQTT client
  void _setupMqttClient(String host, String identifier, int port) {
    _client = MqttServerClient.withPort(host, identifier, port);
    _client.secure = true;
    _client.securityContext = SecurityContext.defaultContext;
    _client.keepAlivePeriod = 20;
    _client.onDisconnected = _onDisconnected;
    _client.onConnected = _onConnected;
  }
  
  // Fetch MQTT credentials from Supabase Edge Function
  Future<Map<String, dynamic>?> _fetchMQTTCredentials() async {
    print("Fetching MQTT credentials");
    try {
      // Call the edge function using the Supabase client SDK
      final response = await supabase.functions.invoke(
        'get-mqtt',
        // No need to pass any parameters as the function likely uses the authenticated user
      );
      // print("Response: $response");
      if (response.status == 200) {
        return response.data;
      } else {
        return null;
      }
    } catch (e) {
      print("Error fetching MQTT credentials: $e");
      return null;
    }
  }
  // Subscribe to a topic
  void _subscribeToTopic(String topicName) {
    _client.subscribe(topicName, MqttQos.atLeastOnce);
    // Listen for messages
    _client.updates!.listen((List<MqttReceivedMessage<MqttMessage>> c) {
      
      final MqttPublishMessage recMess = c[0].payload as MqttPublishMessage;
      final String payload = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
      
      // try {
        final Map<String, dynamic> data = jsonDecode(payload);
        final CureState environmentalData = CureState.fromJson(data);
        _currentData = environmentalData;
        _dataStreamController.add(environmentalData);
      // } catch (e) {
      //   // Handle parsing errors
      //   print("Error parsing message: $e");
      // }
    });
  }

  // Publish a json   message to a topic
  @override
  void publishMessage(Map<String, dynamic> message) {
    final userId = supabase.auth.currentUser!.id;
    String commandTopic = "$userId/$_deviceId/command"; 
    final jsonString = jsonEncode(message);
    print("Publishing message: $jsonString to topic: $commandTopic");
    _client.publishMessage(commandTopic, MqttQos.atLeastOnce, MqttClientPayloadBuilder().addString(jsonString).payload!);
  }
  
  // Disconnection handler
  void _onDisconnected() {
    _updateConnectionStatus(ConnectionStatus.disconnected);
  }
  
  // Connection handler
  void _onConnected() {
    _updateConnectionStatus(ConnectionStatus.connected);
  }
  
  // Update connection status
  void _updateConnectionStatus(ConnectionStatus status) {
    _connectionStatus = status;
    _connectionStatusController.add(status);
  }
}