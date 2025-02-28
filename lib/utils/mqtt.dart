import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;

final supabase = Supabase.instance.client;
class MqttConsole extends StatefulWidget {
  final String deviceId;
  
  const MqttConsole({
    Key? key, 
    required this.deviceId,
  }) : super(key: key);

  @override
  State<MqttConsole> createState() => _MqttConsoleState();
}

class _MqttConsoleState extends State<MqttConsole> {
  // Following the HiveMQ reference pattern
  late MqttServerClient _client;
  final List<String> _messages = [];
  
  // Connection states
  bool _isConnected = false;
  
  // MQTT configuration - define with defaults, will be updated later
  String _host = '';
  int _port = 8883; 
  String _username = '';
  String _password = '';
  String _identifier = '';
  String _topic = "";
  
  @override
  void initState() {
    super.initState();
    // Initialize connection parameters
    _initializeConnection();
  }
  
  Future<void> _initializeConnection() async {
    // Fetch credentials
    final credentials = await _fetchMQTTCredentials();
    final userId = supabase.auth.currentUser!.id;
    final deviceId = widget.deviceId;
    if (credentials != null) {
      setState(() {
        _host = credentials['host'];
        _username = credentials['username'];
        _password = credentials['password'];
        
        // Generate a unique identifier
        _identifier = 'flutter_${userId}_${DateTime.now().millisecondsSinceEpoch}';
        
        _topic = "$userId/$deviceId/state";

      });
      // Connect automatically
      _connectClient();
    } else {
      setState(() {
        _messages.add('Failed to fetch MQTT credentials');
      });
    }
  }

  @override
  void dispose() {
    if (_isConnected) {
      _client.disconnect();
    }
    super.dispose();
  }

  void _setupMqttClient() {
    _client = MqttServerClient.withPort(_host, _identifier, _port);
    _client.secure = true;
    _client.securityContext = SecurityContext.defaultContext;
    _client.keepAlivePeriod = 20;
    _client.onDisconnected = _onDisconnected;
    _client.onConnected = _onConnected;
    
    setState(() {
      _messages.add("Connecting to $_host...");
    });
  }

  // Fetch MQTT credentials from Supabase Edge Function
  Future<Map<String, dynamic>?> _fetchMQTTCredentials() async {
    try {
      // Get the auth token for the current user
      final token = supabase.auth.currentSession?.accessToken;
      if (token == null) {
        print('No auth token available');
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
        print('Error fetching MQTT credentials: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Exception fetching MQTT credentials: $e');
      return null;
    }
  }

  Future<void> _connectClient() async {
    if (_host.isEmpty || _username.isEmpty || _password.isEmpty) {
      setState(() {
        _messages.add("Missing connection details");
      });
      return;
    }
    
    try {
      _setupMqttClient();
      await _client.connect(_username, _password);
    } catch (e) {
      setState(() {
        _messages.add("Connection error: $e");
      });
      return;
    }

    if (_client.connectionStatus!.state == MqttConnectionState.connected) {
      setState(() {
        _isConnected = true;
        _messages.add("Connected successfully");
      });
      _subscribeToTopic(_topic);
    } else {
      setState(() {
        _messages.add("Connection failed");
      });
    }
  }

  void _subscribeToTopic(String topicName) {
    setState(() {
      _messages.add("Subscribing to topic: $topicName");
    });
    
    _client.subscribe(topicName, MqttQos.atLeastOnce);

    // Listen for messages
    _client.updates!.listen((List<MqttReceivedMessage<MqttMessage>> c) {
      final MqttPublishMessage recMess = c[0].payload as MqttPublishMessage;
      final String message = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);

      setState(() {
        _messages.add("Received: $message");
      });
    });
  }

  void _onDisconnected() {
    setState(() {
      _isConnected = false;
      _messages.add("Disconnected from broker");
    });
  }

  void _onConnected() {
    setState(() {
      _isConnected = true;
      _messages.add("Connected successfully");
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MQTT Console'),
        actions: [
          Icon(
            _isConnected ? Icons.wifi : Icons.wifi_off,
            color: _isConnected ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Connection Status: ${_isConnected ? "Connected" : "Disconnected"}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text('Messages:'),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4.0),
                    child: Text(_messages[index]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isConnected 
            ? () {
                _client.disconnect();
                setState(() {
                  _isConnected = false;
                  _messages.add("Manually disconnected");
                });
              }
            : _connectClient,
        child: Icon(_isConnected ? Icons.link_off : Icons.link),
      ),
    );
  }
}

// Simple message class
class Message {
  final String text;
  final DateTime time;

  Message({
    required this.text,
    required this.time,
  });
}