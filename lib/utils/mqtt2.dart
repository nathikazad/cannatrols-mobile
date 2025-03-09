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
  Map<CureCycle, CureTargets> _cureTargets = {};
  // Stream controllers
  final _dataStreamController = StreamController<CureState>.broadcast();
  final _connectionStatusController = StreamController<ConnectionStatus>.broadcast();
  final _cureTargetsStreamController = StreamController<Map<CureCycle, CureTargets>>.broadcast();
  
  // Current state
  ConnectionStatus _connectionStatus = ConnectionStatus.disconnected;

  Timer? _timeoutTimer;
  DateTime? _lastMessageTime;
  
  // Get Supabase instance
  final supabase = Supabase.instance.client;
  
  @override
  Stream<CureState> get stateStream => _dataStreamController.stream;
  
  @override
  Stream<ConnectionStatus> get connectionStatusStream => _connectionStatusController.stream;

  @override
  Stream<Map<CureCycle, CureTargets>> get cureTargetsStream => _cureTargetsStreamController.stream;

  @override
  Map<CureCycle, CureTargets> get cureTargets => _cureTargets;

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

    _lastMessageTime = DateTime.now();
    _timeoutTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      print("Checking if MQTT connection timed out");
      if (_lastMessageTime != null && _lastMessageTime!.isBefore(DateTime.now().subtract(Duration(seconds: 10)))) {
        _updateConnectionStatus(ConnectionStatus.timedOut);
        print("MQTT connection timed out");
      }
    });
    
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
      _subscribeToStateTopic();
      askForCureTargets();
    } else {
      _updateConnectionStatus(ConnectionStatus.error);
      // Otherwise keep trying with the timedOut status set by the timer
    }
  }

  @override
  Future<void> askForCureTargets() async {
    publishMessage({'command': 'getTargets'});
  }
  
  @override
  Future<void> disconnect() async {
    if (_connectionStatus == ConnectionStatus.connected ||
        _connectionStatus == ConnectionStatus.connecting) {
      _client.disconnect();
      _currentData = null;
      _cureTargets = {};
      _updateConnectionStatus(ConnectionStatus.disconnected);
    }
  }
  
  @override
  void dispose() {
    if (_connectionStatus == ConnectionStatus.connected) {
      _client.disconnect();
    }
    _timeoutTimer?.cancel();
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
  void _subscribeToStateTopic() {
    final userId = supabase.auth.currentUser!.id;
    String stateTopic = "$userId/$_deviceId/state";
    _client.subscribe(stateTopic, MqttQos.atLeastOnce);
    String targetsTopic = "$userId/$_deviceId/targets";
    _client.subscribe(targetsTopic, MqttQos.atLeastOnce);
    // Listen for messages
    _client.updates!.listen((List<MqttReceivedMessage<MqttMessage>> c) {

      _lastMessageTime = DateTime.now();
      if (_connectionStatus == ConnectionStatus.timedOut) {
        _updateConnectionStatus(ConnectionStatus.connected);
      }
      
      final MqttPublishMessage recMess = 
      c[0].payload as MqttPublishMessage;
      final String payload = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
      
      // try {
        final Map<String, dynamic> data = jsonDecode(payload);
        if (c[0].topic == stateTopic) {
          final CureState environmentalData = CureState.fromJson(data);
          _currentData = environmentalData;
          _dataStreamController.add(environmentalData);
        } else if (c[0].topic == targetsTopic) {
          final Map<CureCycle, CureTargets> targets = jsonToCureTargets(data);
          _cureTargets = targets;
          _cureTargetsStreamController.add(targets);
        }
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