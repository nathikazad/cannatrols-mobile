// bluetooth_manager.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

// UART service and characteristic UUIDs
const String UART_SERVICE_UUID = "6E400001-B5A3-F393-E0A9-E50E24DCCA9E";
const String UART_RX_UUID =
    "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"; // RX from ESP32's perspective
const String UART_TX_UUID =
    "6E400003-B5A3-F393-E0A9-E50E24DCCA9E"; // TX from ESP32's perspective

// State class to represent all Bluetooth-related state
class BluetoothAppState {
  final List<ScanResult> discoveredDevices;
  // dictionary of device id to device
  Map<DeviceIdentifier, bool> wifiConnectedDevices = {};
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
    this.wifiConnectedDevices = const {},
  });

  // Create a copy of the current state with some modifications
  BluetoothAppState copyWith({
    List<ScanResult>? discoveredDevices,
    BluetoothDevice? connectedDevice,
    bool? isAuthenticated,
    bool? isAuthenticating,
    bool? isScanning,
    List<String>? messages,
    Map<DeviceIdentifier, bool>? wifiConnectedDevices,
  }) {
    return BluetoothAppState(
      discoveredDevices: discoveredDevices ?? this.discoveredDevices,
      connectedDevice: connectedDevice ?? this.connectedDevice,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isAuthenticating: isAuthenticating ?? this.isAuthenticating,
      isScanning: isScanning ?? this.isScanning,
      messages: messages ?? this.messages,
      wifiConnectedDevices: wifiConnectedDevices ?? this.wifiConnectedDevices,
    );
  }
}

// Manager class to contain all Bluetooth logic
class BluetoothManager {
  // Constants for device filtering
  static const int MANUFACTURER_ID = 0x02A5; // Must match ESP32
  static const String MANUFACTURER_DATA = "CANN";

  // Authentication settings
  static const String SECRET_KEY = "MySecretKey123"; // Must match ESP32
  static const String CHALLENGE_PREFIX = "CHALLENGE:";
  static const String RESPONSE_PREFIX = "RESPONSE:";
  static const String AUTH_SUCCESS = "AUTH_OK";
  static const String AUTH_FAILED = "AUTH_FAILED";

  // WiFi related constants
  static const String WIFI_COMMAND_PREFIX = "SET_WIFI_CREDENTIALS:";
  static const String WIFI_SUCCESS_MESSAGE = "WIFI_CONNECTED:SUCCESS";
  static const String WIFI_FAILURE_MESSAGE = "WIFI_CONNECTED:FAILED";
  static const Duration WIFI_TIMEOUT = Duration(seconds: 5);

  // Internet connection status constants
  static const String INTERNET_STATUS_COMMAND = "IS_WIFI_CONNECTED";
  static const Duration INTERNET_STATUS_TIMEOUT = Duration(seconds: 3);

  // Current state
  BluetoothAppState _state = BluetoothAppState();

  // Callback to update the UI when state changes
  final Function(BluetoothAppState) onStateChanged;

  // Private members not exposed through BluetoothAppState
  BluetoothCharacteristic? _txCharacteristic;
  BluetoothCharacteristic? _rxCharacteristic;
  StreamSubscription<List<int>>? _messageStream;

  // WiFi connection callback
  Completer<bool>? _wifiConnectionCompleter;

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
    _updateState(_state.copyWith(discoveredDevices: [], isScanning: true));

    try {
      await FlutterBluePlus.startScan(timeout: Duration(seconds: 4));
      _state.wifiConnectedDevices = {};
      FlutterBluePlus.scanResults.listen((results) {
        // Filter only our devices
        List<ScanResult> ourDevices = results.where(_isOurDevice).toList();
        _updateState(_state.copyWith(discoveredDevices: ourDevices));
      });

      Future.delayed(Duration(seconds: 4), () async {
        print("Scanning finished");
        for (var device in _state.discoveredDevices) {
          _state.wifiConnectedDevices[device
              .device
              .remoteId] = await isWifiConnected(device.device);
          _updateState(
            _state.copyWith(wifiConnectedDevices: _state.wifiConnectedDevices),
          );
        }
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
          for (BluetoothCharacteristic characteristic
              in service.characteristics) {
            if (characteristic.uuid.toString().toUpperCase() == UART_TX_UUID) {
              _txCharacteristic = characteristic;
            } else if (characteristic.uuid.toString().toUpperCase() ==
                UART_RX_UUID) {
              _rxCharacteristic = characteristic;
            }
          }
          break;
        }
      }

      if (_txCharacteristic != null && _rxCharacteristic != null) {
        List<String> updatedMessages = [
          ..._state.messages,
          'Connected to ${device.name}',
        ];
        _updateState(
          _state.copyWith(connectedDevice: device, messages: updatedMessages),
        );

        // Start authentication process
        await authenticate();
      } else {
        List<String> updatedMessages = [
          ..._state.messages,
          'UART service not found',
        ];
        _updateState(_state.copyWith(messages: updatedMessages));
        await device.disconnect();
      }
    } catch (e) {
      print('Error connecting to device: $e');
      List<String> updatedMessages = [
        ..._state.messages,
        'Error connecting to device',
      ];
      _updateState(_state.copyWith(messages: updatedMessages));
    }
  }

  // Send a message to the connected device
  Future<void> sendMessage(String text) async {
    if (text.isEmpty || _rxCharacteristic == null) return;

    try {
      List<int> bytes = utf8.encode("$text\n");
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

    _updateState(
      _state.copyWith(isAuthenticating: true, isAuthenticated: false),
    );

    try {
      // Set up message listener
      await _messageStream?.cancel();
      _messageStream = _txCharacteristic!.lastValueStream.listen((value) {
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

      // Create a completer to handle the authentication result
      Completer<bool> authCompleter = Completer<bool>();

      // Listen for authentication status changes
      late StreamSubscription<BluetoothAppState> authSubscription;
      authSubscription = Stream.periodic(
        Duration(milliseconds: 100),
      ).map((_) => _state).listen((currentState) {
        // Check if authentication status has been determined
        if (!currentState.isAuthenticating) {
          if (!authCompleter.isCompleted) {
            authCompleter.complete(currentState.isAuthenticated);
          }
          authSubscription.cancel();
        }
      });

      // Set a timeout for authentication
      Future.delayed(Duration(seconds: 2), () {
        if (!authCompleter.isCompleted) {
          print('Authentication timed out');
          authCompleter.complete(false);

          List<String> updatedMessages = [
            ..._state.messages,
            'Authentication timed out',
          ];
          _updateState(
            _state.copyWith(
              isAuthenticating: false,
              isAuthenticated: false,
              messages: updatedMessages,
            ),
          );
        }
      });

      // Wait for authentication to complete or timeout
      await authCompleter.future;
    } catch (e) {
      print('Error during authentication setup: $e');
      _updateState(
        _state.copyWith(isAuthenticating: false, isAuthenticated: false),
      );
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
    String dataString = String.fromCharCodes(
      data.sublist(0, MANUFACTURER_DATA.length),
    );
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
      value =
          ((value << 2) | (value >> 6)) &
          0xFF; // Rotate 2 bits left, keep in byte range

      // Convert to hexadecimal (2 chars per byte)
      String hex = value.toRadixString(16).padLeft(2, '0');
      response += hex;
    }

    return response;
  }

  // Send WiFi credentials and wait for response
  Future<bool> sendWifiCredentials(BluetoothDevice device, String ssid, String password) async {
    try {
      // Connect to the device
      print("Connecting to device ${device.remoteId}");
      await connect(device);

      // If authentication failed, return false
      if (!_state.isAuthenticated) {
        print('Could not authenticate with device: ${device.id.id}');
        return false;
      }

      print("Authenticated with device ${device.remoteId}");

      // Cancel any existing completer
      // _wifiConnectionCompleter?.complete(false);
      _wifiConnectionCompleter = Completer<bool>();
      _wifiConnectionCompleter = Completer<bool>();

      // Send the command
      final wifiCommand = "$WIFI_COMMAND_PREFIX$ssid,$password";
      print("Sending WiFi command: $wifiCommand");
      await sendMessage(wifiCommand);

      // Set a timeout
      Future.delayed(WIFI_TIMEOUT, () {
        if (_wifiConnectionCompleter != null &&
            !_wifiConnectionCompleter!.isCompleted) {
          _wifiConnectionCompleter!.complete(false);

          List<String> updatedMessages = [
            ..._state.messages,
            "WiFi connection timed out",
          ];
          _updateState(_state.copyWith(messages: updatedMessages));
        }
      });

      // Wait for the completer to complete
      return _wifiConnectionCompleter!.future;
    } finally {
      // Always disconnect when done
      disconnect();
    }
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
      List<String> updatedMessages = [
        ..._state.messages,
        "Authentication successful!",
      ];
      _updateState(
        _state.copyWith(
          isAuthenticated: true,
          isAuthenticating: false,
          messages: updatedMessages,
        ),
      );
    } else if (message.contains(AUTH_FAILED)) {
      List<String> updatedMessages = [
        ..._state.messages,
        "Authentication failed!",
      ];
      _updateState(
        _state.copyWith(
          isAuthenticated: false,
          isAuthenticating: false,
          messages: updatedMessages,
        ),
      );
    } else if (message.contains(WIFI_SUCCESS_MESSAGE)) {
      // Handle WiFi connection success
      List<String> updatedMessages = [
        ..._state.messages,
        "WiFi connected successfully!",
      ];
      _updateState(_state.copyWith(messages: updatedMessages));

      if (_wifiConnectionCompleter != null &&
          !_wifiConnectionCompleter!.isCompleted) {
        _wifiConnectionCompleter!.complete(true);
        print("WiFi connection successful");
      }
    } else if (message.contains(WIFI_FAILURE_MESSAGE)) {
      // Handle WiFi connection failure
      List<String> updatedMessages = [
        ..._state.messages,
        "WiFi connection failed!",
      ];
      _updateState(_state.copyWith(messages: updatedMessages));

      if (_wifiConnectionCompleter != null &&
          !_wifiConnectionCompleter!.isCompleted) {
        _wifiConnectionCompleter!.complete(false);
        print("WiFi connection failed");
      }
    } else if (_state.isAuthenticated) {
      List<String> updatedMessages = [
        ..._state.messages,
        "Received: ${message.trim()}",
      ];
      _updateState(_state.copyWith(messages: updatedMessages));
    }
  }

  // Disconnect from the connected device
  void disconnect() async {
    if (_state.connectedDevice != null) {
      try {
        await _state.connectedDevice!.disconnect();
        _messageStream?.cancel();
        _messageStream = null;
        _txCharacteristic = null;
        _rxCharacteristic = null;

        List<String> updatedMessages = [
          ..._state.messages,
          'Disconnected from device',
        ];
        _updateState(
          _state.copyWith(
            connectedDevice: null,
            isAuthenticated: false,
            messages: updatedMessages,
          ),
        );
      } catch (e) {
        print('Error disconnecting from device: $e');
      }
    }
  }

  // Check if WiFi is connected on the device
  Future<bool> isWifiConnected(BluetoothDevice device) async {
    print("isWifiConnected ${device.remoteId}");
    try {
      // Connect to the device
      print("Connecting to device ${device.remoteId}");
      await connect(device);

      // If authentication failed, return false
      if (!_state.isAuthenticated) {
        print('Could not authenticate with device: ${device.id.id}');
        return false;
      }

      print("Authenticated with device ${device.remoteId}");

      // Cancel any existing completer
      // _wifiConnectionCompleter?.complete(false);
      _wifiConnectionCompleter = Completer<bool>();

      print("Sending internet status command to device ${device.remoteId}");

      // Send the command to check internet status
      await sendMessage(INTERNET_STATUS_COMMAND);

      print(
        "Waiting for internet status command response from device ${device.remoteId}",
      );

      // Set a timeout
      var timeoutTimer = Timer(INTERNET_STATUS_TIMEOUT, () {
        if (_wifiConnectionCompleter != null &&
            !_wifiConnectionCompleter!.isCompleted) {
          _wifiConnectionCompleter!.complete(false);

          List<String> updatedMessages = [
            ..._state.messages,
            "WiFi status check timed out",
          ];
          _updateState(_state.copyWith(messages: updatedMessages));
        }
      });

      // Wait for the completer to complete
      bool result = await _wifiConnectionCompleter!.future;
      print("Internet status check result: $result");
      timeoutTimer.cancel();
      return result;
    } finally {
      // Always disconnect when done
      disconnect();
    }
  }
}
