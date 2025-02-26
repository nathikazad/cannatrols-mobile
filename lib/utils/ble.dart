// bluetooth_manager.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

// UART service and characteristic UUIDs
const String UART_SERVICE_UUID = "6E400001-B5A3-F393-E0A9-E50E24DCCA9E";
const String UART_RX_UUID = "6E400002-B5A3-F393-E0A9-E50E24DCCA9E";  // RX from ESP32's perspective
const String UART_TX_UUID = "6E400003-B5A3-F393-E0A9-E50E24DCCA9E";  // TX from ESP32's perspective

// State class to represent all Bluetooth-related state
class BluetoothAppState {
  final List<ScanResult> discoveredDevices;
  final BluetoothDevice? connectedDevice;
  final bool isAuthenticated;
  final bool isAuthenticating;
  final bool isScanning;
  final List<String> messages;

  BluetoothAppState({
    this.discoveredDevices = const [],
    this.connectedDevice,
    this.isAuthenticated = false,
    this.isAuthenticating = false,
    this.isScanning = false,
    this.messages = const [],
  });

  // Create a copy of the current state with some modifications
  BluetoothAppState copyWith({
    List<ScanResult>? discoveredDevices,
    BluetoothDevice? connectedDevice,
    bool? isAuthenticated,
    bool? isAuthenticating,
    bool? isScanning,
    List<String>? messages,
  }) {
    return BluetoothAppState(
      discoveredDevices: discoveredDevices ?? this.discoveredDevices,
      connectedDevice: connectedDevice ?? this.connectedDevice,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isAuthenticating: isAuthenticating ?? this.isAuthenticating,
      isScanning: isScanning ?? this.isScanning,
      messages: messages ?? this.messages,
    );
  }
}

// Manager class to contain all Bluetooth logic
class BluetoothManager {
  // Constants for device filtering
  static const int MANUFACTURER_ID = 0x02A5;  // Must match ESP32
  static const String MANUFACTURER_DATA = "CANN";
  
  // Authentication settings
  static const String SECRET_KEY = "MySecretKey123"; // Must match ESP32
  static const String CHALLENGE_PREFIX = "CHALLENGE:";
  static const String RESPONSE_PREFIX = "RESPONSE:";
  static const String AUTH_SUCCESS = "AUTH_OK";
  static const String AUTH_FAILED = "AUTH_FAILED";
  
  // Current state
  BluetoothAppState _state = BluetoothAppState();
  
  // Callback to update the UI when state changes
  final Function(BluetoothAppState) onStateChanged;
  
  // Private members not exposed through BluetoothAppState
  BluetoothCharacteristic? _txCharacteristic;
  BluetoothCharacteristic? _rxCharacteristic;
  StreamSubscription<List<int>>? _messageStream;
  
  BluetoothManager({required this.onStateChanged});
  
  // Getters for read-only access to the current state
  BluetoothAppState get state => _state;
  
  // Initialize Bluetooth
  void initBluetooth() async {
    if (await FlutterBluePlus.isSupported) {
      FlutterBluePlus.adapterState.listen((adapterState) {
        if (adapterState == BluetoothAdapterState.on) {
          startScan();
        }
      });
    } else {
      print("Bluetooth not supported");
    }
  }
  
  // Start scanning for devices
  void startScan() async {
    // Update state to indicate scanning has started
    _updateState(_state.copyWith(
      discoveredDevices: [],
      isScanning: true,
    ));

    try {
      await FlutterBluePlus.startScan(timeout: Duration(seconds: 4));
      
      FlutterBluePlus.scanResults.listen((results) {
        // Filter only our devices
        List<ScanResult> ourDevices = results.where(_isOurDevice).toList();
        _updateState(_state.copyWith(discoveredDevices: ourDevices));
      });

      Future.delayed(Duration(seconds: 4), () {
        stopScan();
      });
    } catch (e) {
      print('Error scanning: $e');
      stopScan();
    }
  }
  
  // Stop scanning for devices
  void stopScan() {
    FlutterBluePlus.stopScan();
    _updateState(_state.copyWith(isScanning: false));
  }
  
  // Connect to a device
  Future<void> connect(BluetoothDevice device) async {
    try {
      await device.connect();
      
      // Discover services
      List<BluetoothService> services = await device.discoverServices();
      
      // Find UART service
      _txCharacteristic = null;
      _rxCharacteristic = null;
      
      for (BluetoothService service in services) {
        if (service.uuid.toString().toUpperCase() == UART_SERVICE_UUID) {
          // Find characteristics
          for (BluetoothCharacteristic characteristic in service.characteristics) {
            if (characteristic.uuid.toString().toUpperCase() == UART_TX_UUID) {
              _txCharacteristic = characteristic;
            } else if (characteristic.uuid.toString().toUpperCase() == UART_RX_UUID) {
              _rxCharacteristic = characteristic;
            }
          }
          break;
        }
      }

      if (_txCharacteristic != null && _rxCharacteristic != null) {
        List<String> updatedMessages = [..._state.messages, 'Connected to ${device.name}'];
        _updateState(_state.copyWith(
          connectedDevice: device,
          messages: updatedMessages,
        ));
        
        // Start authentication process
        await authenticate();
      } else {
        List<String> updatedMessages = [..._state.messages, 'UART service not found'];
        _updateState(_state.copyWith(messages: updatedMessages));
        await device.disconnect();
      }

    } catch (e) {
      print('Error connecting to device: $e');
      List<String> updatedMessages = [..._state.messages, 'Error connecting to device'];
      _updateState(_state.copyWith(messages: updatedMessages));
    }
  }
  
  // Send a message to the connected device
  Future<void> sendMessage(String text) async {
    if (text.isEmpty || _rxCharacteristic == null) return;
    
    try {
      List<int> bytes = utf8.encode(text + "\n");
      await _rxCharacteristic!.write(bytes);
      
      if (_state.isAuthenticated) {
        List<String> updatedMessages = [..._state.messages, "Sent: $text"];
        _updateState(_state.copyWith(messages: updatedMessages));
      }
    } catch (e) {
      print('Error sending message: $e');
    }
  }
  
  // Authenticate with the connected device
  Future<void> authenticate() async {
    if (_txCharacteristic == null || _rxCharacteristic == null) return;
    
    _updateState(_state.copyWith(
      isAuthenticating: true,
      isAuthenticated: false,
    ));

    try {
      // Set up message listener
      await _messageStream?.cancel();
      _messageStream = _txCharacteristic!.lastValueStream.listen((value) {
        print("received value $value");
        if (value.isNotEmpty) {
          String message = utf8.decode(value);
          print("message $message");
          _handleIncomingMessage(message);
        }
      });

      // Enable notifications
      await _txCharacteristic!.setNotifyValue(true);
      await _rxCharacteristic!.write(utf8.encode("REQUEST_CHALLENGE\n"));
      print("Challenge requested");

    } catch (e) {
      print('Error during authentication setup: $e');
      _updateState(_state.copyWith(
        isAuthenticating: false,
        isAuthenticated: false,
      ));
    }
  }
  
  // Clean up resources
  void dispose() {
    _messageStream?.cancel();
    _state.connectedDevice?.disconnect();
  }
  
  // PRIVATE METHODS
  
  // Update state and notify listeners
  void _updateState(BluetoothAppState newState) {
    _state = newState;
    onStateChanged(newState);
  }
  
  // Check if a device is one of our devices
  bool _isOurDevice(ScanResult result) {
    if (result.advertisementData.manufacturerData.isEmpty) return false;

    // Get the first manufacturer data entry
    var entry = result.advertisementData.manufacturerData.entries.first;
    int manufacturerId = entry.key;
    List<int> data = entry.value;

    // Check manufacturer ID
    if (manufacturerId != MANUFACTURER_ID) return false;

    // Check manufacturer data string
    if (data.length < MANUFACTURER_DATA.length) return false;
    String dataString = String.fromCharCodes(data.sublist(0, MANUFACTURER_DATA.length));
    return dataString == MANUFACTURER_DATA;
  }

  String _calculateResponse(String challenge) {
    String combined = challenge + SECRET_KEY;
    String response = "";
    
    // Simple hash algorithm to match the Arduino function
    for (int i = 0; i < combined.length; i++) {
      int value = combined.codeUnitAt(i);
      
      // Mix in the secret key
      value ^= SECRET_KEY.codeUnitAt(i % SECRET_KEY.length);
      
      // Add bit rotation for extra complexity
      value = ((value << 2) | (value >> 6)) & 0xFF; // Rotate 2 bits left, keep in byte range
      
      // Convert to hexadecimal (2 chars per byte)
      String hex = value.toRadixString(16).padLeft(2, '0');
      response += hex;
    }
    
    return response;
  }
  
  // Handle incoming message from device
  void _handleIncomingMessage(String message) {
    print('Received: $message');
    
    if (message.startsWith(CHALLENGE_PREFIX)) {
      // Handle challenge
      String challenge = message.substring(CHALLENGE_PREFIX.length).trim();
  
      // Calculate the response using our shared secret
      String responseValue = _calculateResponse(challenge);
      
      // Prepare the full response message with prefix
      String response = RESPONSE_PREFIX + responseValue;
      
      // Send the response back to the client
      sendMessage(response);
      
      print('Received challenge: $challenge');
      print('Sent response: $responseValue');
      
    } else if (message.contains(AUTH_SUCCESS)) {
      List<String> updatedMessages = [..._state.messages, "Authentication successful!"];
      _updateState(_state.copyWith(
        isAuthenticated: true,
        isAuthenticating: false,
        messages: updatedMessages,
      ));
      
    } else if (message.contains(AUTH_FAILED)) {
      List<String> updatedMessages = [..._state.messages, "Authentication failed!"];
      _updateState(_state.copyWith(
        isAuthenticated: false,
        isAuthenticating: false,
        messages: updatedMessages,
      ));
      
    } else if (_state.isAuthenticated) {
      List<String> updatedMessages = [..._state.messages, "Received: ${message.trim()}"];
      _updateState(_state.copyWith(messages: updatedMessages));
    }
  }
}