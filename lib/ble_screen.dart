// bluetooth_app.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth.dart';
import 'utils/ble.dart';  // Import the manager
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BluetoothScreen extends ConsumerStatefulWidget {
  @override
  ConsumerState<BluetoothScreen> createState() => _BluetoothScreenState();
}

class _BluetoothScreenState extends ConsumerState<BluetoothScreen> {
  // Manager instance
  late BluetoothManager _bluetoothManager;
  
  // Local state to hold the manager state
  late BluetoothAppState _state;
  
  TextEditingController messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    
    // Initialize the manager with a callback
    _bluetoothManager = BluetoothManager(
      onStateChanged: (newState) {
        // This will be called whenever the bluetooth state changes
        if (mounted) {
          setState(() {
            _state = newState;
          });
        }
      }
    );
    
    // Set initial state
    _state = _bluetoothManager.state;
    
    // Initialize Bluetooth
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bluetoothManager.initBluetooth();
      
      // Print user information
      final user = ref.read(authProvider).state.user;
      if (user != null) {
        print('User Information:');
        print(user);
        // print('Email: ${user.email}');
        // print('UID: ${user.id}');
        // // Print any other user properties you have
        // print('Display Name: ${user.}');
        // print('Phone Number: ${user.phoneNumber}');
        // print('Photo URL: ${user.photoURL}');
        // print('Email Verified: ${user.emailVerified}');
        // print('-------------------');
      } else {
        print('No user is currently logged in');
      }
    });
  }


  String? getUserIdFromDevice(ScanResult result) {
    // Look for user ID in service data
    final serviceData = result.advertisementData.serviceData;
    final userServiceUuid = Guid("FFF1");

    if (serviceData.containsKey(userServiceUuid)) {
      List<int> userData = serviceData[userServiceUuid]!;
      String userId = String.fromCharCodes(userData);

      return (userId == "NONE") ? "Unregistered" : userId;
    }

    return null; // No user ID found
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => GoRouter.of(context).pop(),
        ),
        title: const Text('Secure BLE UART'),
        actions: [
          IconButton(
            icon: Icon(_state.isScanning ? Icons.stop : Icons.refresh),
            onPressed: _state.isScanning 
              ? () => _bluetoothManager.stopScan()
              : () => _bluetoothManager.startScan(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 1,
            child: ListView.builder(
              itemCount: _state.discoveredDevices.length,
              itemBuilder: (context, index) {
                final device = _state.discoveredDevices[index].device;
                final isConnected = _state.connectedDevice?.remoteId.str == device.remoteId.str;
                final userId = getUserIdFromDevice(_state.discoveredDevices[index]);
                return ListTile(
                  title: Text(device.platformName.isEmpty ? "Unknown Device" : device.platformName),
                  subtitle: Text("$userId"),
                  trailing: ElevatedButton(
                    child: Text(isConnected
                      ? (_state.isAuthenticated ? 'Connected' : 'Authenticating...')
                      : 'Connect'),
                    onPressed: () => _bluetoothManager.connect(device),
                  ),
                );
              },
            ),
          ),
          Expanded(
            flex: 2,
            child: ListView.builder(
              itemCount: _state.messages.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(_state.messages[index]),
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
                      hintText: _state.isAuthenticated 
                        ? 'Type a message' 
                        : 'Authenticate first...',
                    ),
                    enabled: _state.isAuthenticated,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _state.isAuthenticated 
                    ? () {
                        _bluetoothManager.sendMessage(messageController.text);
                        messageController.clear();
                      }
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
    _bluetoothManager.dispose();
    messageController.dispose();
    super.dispose();
  }
}