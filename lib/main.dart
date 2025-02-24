import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

// UART service and characteristic UUIDs
const String UART_SERVICE_UUID = "6E400001-B5A3-F393-E0A9-E50E24DCCA9E";
const String UART_RX_UUID = "6E400002-B5A3-F393-E0A9-E50E24DCCA9E";  // RX from ESP32's perspective
const String UART_TX_UUID = "6E400003-B5A3-F393-E0A9-E50E24DCCA9E";  // TX from ESP32's perspective

class BluetoothApp extends StatefulWidget {
  @override
  _BluetoothAppState createState() => _BluetoothAppState();
}

class _BluetoothAppState extends State<BluetoothApp> {
  
  List<ScanResult> discoveredDevices = [];
  BluetoothDevice? connectedDevice;
  BluetoothCharacteristic? txCharacteristic;
  BluetoothCharacteristic? rxCharacteristic;

  static const int MANUFACTURER_ID = 0x02A5;  // Must match ESP32
  static const String MANUFACTURER_DATA = "MYCO";
  
  // Authentication settings
  static const String SECRET_KEY = "MySecretKey123"; // Must match ESP32
  static const String CHALLENGE_PREFIX = "CHALLENGE:";
  static const String RESPONSE_PREFIX = "RESPONSE:";
  static const String AUTH_SUCCESS = "AUTH_OK";
  static const String AUTH_FAILED = "AUTH_FAILED";
  
  bool isAuthenticated = false;
  bool isAuthenticating = false;
  bool isScanning = false;
  
  TextEditingController messageController = TextEditingController();
  List<String> messages = [];
  StreamSubscription<List<int>>? messageStream;

  @override
  void initState() {
    super.initState();
    initBluetooth();
  }

  void initBluetooth() async {
    // Check if Bluetooth is available and turned on
    if (await FlutterBluePlus.isSupported) {
      FlutterBluePlus.adapterState.listen((state) {
        if (state == BluetoothAdapterState.on) {
          // Bluetooth is on
          setState(() {});
        }
      });
    } else {
      print("Bluetooth not supported");
    }
  }

  bool isOurDevice(ScanResult result) {
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

  void startScan() async {
    setState(() {
      discoveredDevices.clear();
      isScanning = true;
    });

    try {
      await FlutterBluePlus.startScan(timeout: Duration(seconds: 4));
      
      FlutterBluePlus.scanResults.listen((results) {
        setState(() {
          // Filter only our devices
          discoveredDevices = results.where((result) => isOurDevice(result)).toList();
        });
      });

      Future.delayed(Duration(seconds: 4), () {
        stopScan();
      });
    } catch (e) {
      print('Error scanning: $e');
      stopScan();
    }
  }

  void stopScan() {
    FlutterBluePlus.stopScan();
    setState(() {
      isScanning = false;
    });
  }

  String calculateResponse(String challenge) {
    // Simple response calculation: challenge + SECRET_KEY
    // In production, use a proper cryptographic hash function
    return challenge + SECRET_KEY;
  }

  Future<void> authenticate() async {
    if (txCharacteristic == null || rxCharacteristic == null) return;
    
    setState(() {
      isAuthenticating = true;
      isAuthenticated = false;
    });

    try {
      // Set up message listener
      await messageStream?.cancel();
      messageStream = txCharacteristic!.lastValueStream.listen((value) {
        print("received value $value");
        if (value.isNotEmpty) {
          String message = utf8.decode(value);
          print("message $message");
          handleIncomingMessage(message);
        }
      });

      // Enable notifications
      await txCharacteristic!.setNotifyValue(true);
      await rxCharacteristic!.write(utf8.encode("REQUEST_CHALLENGE\n"));
      print("Challenge requested");

    } catch (e) {
      print('Error during authentication setup: $e');
      setState(() {
        isAuthenticating = false;
        isAuthenticated = false;
      });
    }
  }

  void handleIncomingMessage(String message) {
    print('Received: $message');
    
    if (message.startsWith(CHALLENGE_PREFIX)) {
      // Handle challenge
      String challenge = message.substring(CHALLENGE_PREFIX.length).trim();
      String response = RESPONSE_PREFIX + calculateResponse(challenge);
      sendMessage(response);
      
    } else if (message.contains(AUTH_SUCCESS)) {
      setState(() {
        isAuthenticated = true;
        isAuthenticating = false;
        messages.add("Authentication successful!");
      });
      
    } else if (message.contains(AUTH_FAILED)) {
      setState(() {
        isAuthenticated = false;
        isAuthenticating = false;
        messages.add("Authentication failed!");
      });
      
    } else if (isAuthenticated) {
      setState(() {
        messages.add("Received: ${message.trim()}");
      });
    }
  }

  Future<void> connect(BluetoothDevice device) async {
    try {
      await device.connect();
      connectedDevice = device;
      
      // Discover services
      List<BluetoothService> services = await device.discoverServices();
      
      // Find UART service
      for (BluetoothService service in services) {
        if (service.uuid.toString().toUpperCase() == UART_SERVICE_UUID) {
          // Find characteristics
          for (BluetoothCharacteristic characteristic in service.characteristics) {
            if (characteristic.uuid.toString().toUpperCase() == UART_TX_UUID) {
              txCharacteristic = characteristic;
            } else if (characteristic.uuid.toString().toUpperCase() == UART_RX_UUID) {
              rxCharacteristic = characteristic;
            }
          }
          break;
        }
      }

      if (txCharacteristic != null && rxCharacteristic != null) {
        setState(() {
          messages.add('Connected to ${device.name}');
        });
        // Start authentication process
        await authenticate();
      } else {
        messages.add('UART service not found');
        await device.disconnect();
      }

    } catch (e) {
      print('Error connecting to device: $e');
      setState(() {
        messages.add('Error connecting to device');
      });
    }
  }

  Future<void> sendMessage(String text) async {
    if (text.isEmpty || rxCharacteristic == null) return;
    
    try {
      List<int> bytes = utf8.encode(text + "\n");
      await rxCharacteristic!.write(bytes);
      
      if (isAuthenticated) {
        setState(() {
          messages.add("Sent: $text");
          messageController.clear();
        });
      }
    } catch (e) {
      print('Error sending message: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Secure BLE UART'),
        actions: [
          IconButton(
            icon: Icon(isScanning ? Icons.stop : Icons.refresh),
            onPressed: isScanning ? stopScan : startScan,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 1,
            child: ListView.builder(
              itemCount: discoveredDevices.length,
              itemBuilder: (context, index) {
                BluetoothDevice device = discoveredDevices[index].device;
                return ListTile(
                  title: Text(device.name.isEmpty ? "Unknown Device" : device.name),
                  subtitle: Text(device.id.id),
                  trailing: ElevatedButton(
                    child: Text(connectedDevice?.id.id == device.id.id
                      ? (isAuthenticated ? 'Connected' : 'Authenticating...')
                      : 'Connect'),
                    onPressed: () => connect(device),
                  ),
                );
              },
            ),
          ),
          Expanded(
            flex: 2,
            child: ListView.builder(
              itemCount: messages.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(messages[index]),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: messageController,
                    decoration: InputDecoration(
                      hintText: isAuthenticated 
                        ? 'Type a message' 
                        : 'Authenticate first...',
                    ),
                    enabled: isAuthenticated,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: isAuthenticated 
                    ? () => sendMessage(messageController.text)
                    : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    messageStream?.cancel();
    connectedDevice?.disconnect();
    super.dispose();
  }
}

// Usage in main.dart
void main() {
  runApp(MaterialApp(
    home: BluetoothApp(),
  ));
}