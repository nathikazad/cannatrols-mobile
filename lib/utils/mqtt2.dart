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
  
  // MQTT configuration
  String _host = '';
  int _port = 8883;
  String _username = '';
  String _password = '';
  String _identifier = '';
  String? _deviceId;
  String _topic = "";
  
  // Stream controllers
  final _dataStreamController = StreamController<EnvironmentalData>.broadcast();
  final _connectionStatusController = StreamController<ConnectionStatus>.broadcast();
  
  // Current state
  ConnectionStatus _connectionStatus = ConnectionStatus.disconnected;
  EnvironmentalData _lastData = EnvironmentalData.initial();
  
  // Get Supabase instance
  final supabase = Supabase.instance.client;
  
  @override
  Stream<EnvironmentalData> get dataStream => _dataStreamController.stream;
  
  @override
  Stream<ConnectionStatus> get connectionStatusStream => _connectionStatusController.stream;
  
  @override
  ConnectionStatus get connectionStatus => _connectionStatus;
  
  @override
  Future<void> connect(String deviceId) async {
    // Check if already connected to the same device
    if (_connectionStatus == ConnectionStatus.connected && _deviceId == deviceId) {
      return;
    }
    
    // Disconnect if connected to a different device
    if (_connectionStatus == ConnectionStatus.connected) {
      await disconnect();
    }
    
    _deviceId = deviceId;
    _updateConnectionStatus(ConnectionStatus.connecting);
    
    // Fetch credentials
    final credentials = await _fetchMQTTCredentials();
    if (credentials == null) {
      _updateConnectionStatus(ConnectionStatus.error);
      return;
    }
    
    // Set credentials
    final userId = supabase.auth.currentUser!.id;
    _host = credentials['host'];
    _username = credentials['username'];
    _password = credentials['password'];
    _identifier = 'flutter_${userId}_${DateTime.now().millisecondsSinceEpoch}';
    _topic = "$userId/$deviceId/state";
    
    // Connect to MQTT
    try {
      _setupMqttClient();
      await _client.connect(_username, _password);
    } catch (e) {
      _updateConnectionStatus(ConnectionStatus.error);
      return;
    }
    
    // Check connection status
    if (_client.connectionStatus!.state == MqttConnectionState.connected) {
      _updateConnectionStatus(ConnectionStatus.connected);
      _subscribeToTopic(_topic);
    } else {
      _updateConnectionStatus(ConnectionStatus.error);
    }
  }
  
  @override
  Future<void> disconnect() async {
    if (_connectionStatus == ConnectionStatus.connected ||
        _connectionStatus == ConnectionStatus.connecting) {
      _client.disconnect();
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
  void _setupMqttClient() {
    _client = MqttServerClient.withPort(_host, _identifier, _port);
    _client.secure = true;
    _client.securityContext = SecurityContext.defaultContext;
    _client.keepAlivePeriod = 20;
    _client.onDisconnected = _onDisconnected;
    _client.onConnected = _onConnected;
  }
  
  // Fetch MQTT credentials from Supabase Edge Function
  Future<Map<String, dynamic>?> _fetchMQTTCredentials() async {
    try {
      // Get the auth token for the current user
      final token = supabase.auth.currentSession?.accessToken;
      if (token == null) {
        return null;
      }
      
      // Call the edge function
      final response = await http.post(
        Uri.parse("https://edlquuxypulyedwgweai.supabase.co/functions/v1/get-mqtt"),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'apikey': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVkbHF1dXh5cHVseWVkd2d3ZWFpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Mzk0Nzg3OTAsImV4cCI6MjA1NTA1NDc5MH0.EL4k_9sOoD9NR6sjVnJj0IjT5SoRYsDrktsdPH1dTgo'
        },
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'];
      } else {
        return null;
      }
    } catch (e) {
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
      
      try {
        final Map<String, dynamic> data = jsonDecode(payload);
        final EnvironmentalData environmentalData = EnvironmentalData.fromJson(data);
        _lastData = environmentalData;
        _dataStreamController.add(environmentalData);
      } catch (e) {
        // Handle parsing errors
      }
    });
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