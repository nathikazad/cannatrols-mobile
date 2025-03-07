// bluetooth_app.dart

import 'package:flutter/material.dart';
import 'package:flutter_app/models/cure_model.dart';
import 'package:flutter_app/providers/device_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'utils/ble.dart';  
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BluetoothScreen extends ConsumerStatefulWidget {
  const BluetoothScreen({super.key});

  @override
  ConsumerState<BluetoothScreen> createState() => _BluetoothScreenState();
}

class _BluetoothScreenState extends ConsumerState<BluetoothScreen> {
  // Manager instance
  late BluetoothManager _bluetoothManager;
  
  // Local state to hold the manager state
  late BluetoothAppState _state;
  
  TextEditingController nameController = TextEditingController();
  TextEditingController wifiNameController = TextEditingController();
  TextEditingController wifiPasswordController = TextEditingController();
  
  List<Device> userDevices = [];
  bool isLoading = true;

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
    
    // Initialize Bluetooth and load user devices
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bluetoothManager.initBluetooth();
      _loadUserDevices();
    });
  }

  Future<void> _loadUserDevices() async {
    setState(() {
      isLoading = true;
    });
    
    try {
      final deviceProvider = ref.read(selectedDeviceProvider.notifier);
      final devices = await deviceProvider.getDevices();
      
      setState(() {
        userDevices = devices;
        isLoading = false;
        
        // Force a rebuild of the UI to reflect the updated device names
        if (_state.discoveredDevices.isNotEmpty) {
          // Create a new state object with the same discovered devices
          // This will trigger the UI to rebuild with the updated device names
          _state = BluetoothAppState(
            isScanning: _state.isScanning,
            discoveredDevices: List.from(_state.discoveredDevices),
            connectedDevice: _state.connectedDevice,
            isAuthenticated: _state.isAuthenticated,
            messages: _state.messages,
            wifiConnectedDevices: _state.wifiConnectedDevices,
          );
        }
      });
    } catch (e) {
      print('Error loading devices: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  String? getDeviceIdFromDevice(ScanResult result) {
    // Look for user ID in service data
    final serviceData = result.advertisementData.serviceData;
    final deviceIdUuid = Guid("FFF1");

    if (serviceData.containsKey(deviceIdUuid)) {
      List<int> deviceIdData = serviceData[deviceIdUuid]!;
      return String.fromCharCodes(deviceIdData);
    }

    return null; // No user ID found
  }

  bool isUserDevice(String? deviceId) {
    if (deviceId == null) return false;
    return userDevices.any((device) => device.id == deviceId);
  }

  Device? getUserDevice(String? deviceId) {
    if (deviceId == null) return null;
    try {
      return userDevices.firstWhere((device) => device.id == deviceId);
    } catch (e) {
      return null;
    }
  }

  // First, let's create helper methods for showing dialogs and snackbars
  void _showDialog({
    required String title,
    required Widget content,
    required List<Widget> actions,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: content,
        actions: actions,
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // Helper method for creating dialog actions
  List<Widget> _createDialogActions({
    required VoidCallback onSave,
    required String saveText,
    String cancelText = 'Cancel',
  }) {
    return [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(cancelText),
      ),
      TextButton(
        onPressed: onSave,
        child: Text(saveText),
      ),
    ];
  }

  // Refactored method for showing the add device dialog
  void _showAddDeviceDialog(String deviceId, String deviceName) {
    nameController.text = deviceName.isEmpty ? "My Device" : deviceName;
    
    _showDialog(
      title: 'Add Device',
      content: TextField(
        controller: nameController,
        decoration: InputDecoration(labelText: 'Device Name'),
      ),
      actions: _createDialogActions(
        saveText: 'Add',
        onSave: () async {
          final name = nameController.text;
          
          if (name.isEmpty) {
            _showSnackBar('Please enter a device name');
            return;
          }
          
          Navigator.pop(context);
          
          try {
            final deviceProvider = ref.read(selectedDeviceProvider.notifier);
            await deviceProvider.addDevice(deviceId, name);
            _showSnackBar('Device added successfully');
            _loadUserDevices();
          } catch (e) {
            _showSnackBar('Error: $e');
          }
        },
      ),
    );
  }

  // Refactored method for showing the edit name dialog
  void _showEditNameDialog(Device device) {
    nameController.text = device.name;
    
    _showDialog(
      title: 'Edit Device Name',
      content: TextField(
        controller: nameController,
        decoration: InputDecoration(labelText: 'Device Name'),
      ),
      actions: _createDialogActions(
        saveText: 'Save',
        onSave: () async {
          final name = nameController.text;
          
          if (name.isEmpty) {
            _showSnackBar('Device name cannot be empty');
            return;
          }
          
          Navigator.pop(context);
          
          try {
            final deviceProvider = ref.read(selectedDeviceProvider.notifier);
            await deviceProvider.updateDevice(device.id, name);
            _showSnackBar('Device name updated successfully');
            _loadUserDevices();
          } catch (e) {
            _showSnackBar('Error updating device name: $e');
          }
        },
      ),
    );
  }

  // Refactored method for showing the WiFi config dialog
  void _showWifiConfigDialog(Device device) {
    wifiNameController.text = "";
    wifiPasswordController.text = "";
    
    _showDialog(
      title: 'Configure WiFi',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: wifiNameController,
            decoration: InputDecoration(labelText: 'WiFi Network Name'),
          ),
          TextField(
            controller: wifiPasswordController,
            decoration: InputDecoration(labelText: 'WiFi Password'),
            obscureText: true,
          ),
        ],
      ),
      actions: _createDialogActions(
        saveText: 'Configure',
        onSave: () async {
          final wifiName = wifiNameController.text;
          final wifiPassword = wifiPasswordController.text;
          
          if (wifiName.isEmpty || wifiPassword.isEmpty) {
            _showSnackBar('Please fill in all fields');
            return;
          }
          
          Navigator.pop(context);
          
          try {
            await _configureDeviceWifi(device.id, wifiName, wifiPassword);
          } catch (e) {
            _showSnackBar('Error configuring WiFi: $e');
          }
        },
      ),
    );
  }

  // Helper method for configuring device WiFi
  Future<void> _configureDeviceWifi(String deviceId, String wifiName, String wifiPassword) async {
    // Find the device in the list of discovered devices
    final deviceResult = _state.discoveredDevices.firstWhere(
      (result) => getDeviceIdFromDevice(result) == deviceId,
      orElse: () => throw Exception('Device not found in scan results'),
    );
    
    // Show a loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Configuring WiFi'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Updating device WiFi settings...'),
          ],
        ),
      ),
    );
    
    try {
      // Connect to device first
      await _bluetoothManager.connect(deviceResult.device);
      
      // Send credentials only if authenticated
      bool success = false;
      if (_state.isAuthenticated) {
        success = await _bluetoothManager.sendWifiCredentials(deviceResult.device, wifiName, wifiPassword);
      }
      
      // Disconnect from device
      _bluetoothManager.disconnect();
      
      Navigator.pop(context); // Close the loading dialog
      
      if (!_state.isAuthenticated) {
        _showSnackBar('Authentication failed');
      } else if (!success) {
        _showSnackBar('WiFi configuration failed');
      } else {
        _showSnackBar('WiFi configured successfully');
      }
    } catch (e) {
      Navigator.pop(context); // Close the loading dialog
      rethrow; // Re-throw to be caught by the caller
    }
  }

  // Helper method for removing a device
  Future<void> _removeDevice(Device device) async {
    try {
      final deviceProvider = ref.read(selectedDeviceProvider.notifier);
      await deviceProvider.removeDevice(device.id);
      _showSnackBar('Device removed successfully');
      _loadUserDevices();
    } catch (e) {
      _showSnackBar('Error: $e');
    }
  }

  // Widget for creating a section header
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // Widget for creating a device card
  Widget _buildDeviceCard({
    required String title,
    required String subtitle,
    required Widget trailing,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
      child: ListTile(
        title: Text(
          title,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(subtitle),
        trailing: trailing,
      ),
    );
  }

  // Widget for creating a user device card
  Widget _buildUserDeviceCard(ScanResult scanResult) {
    final deviceId = getDeviceIdFromDevice(scanResult);
    final userDevice = getUserDevice(deviceId);
    
    return _buildDeviceCard(
      title: userDevice?.name ?? 'Unknown Device',
      subtitle: deviceId ?? 'No ID',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(Icons.edit),
            tooltip: 'Edit Name',
            onPressed: userDevice != null 
              ? () => _showEditNameDialog(userDevice)
              : null,
          ),
          IconButton(
            icon: _state.wifiConnectedDevices[scanResult.device.remoteId] == null
                ? Icon(Icons.wifi_find)
                : _state.wifiConnectedDevices[scanResult.device.remoteId] == true
                    ? Icon(Icons.wifi)
                    : Icon(Icons.wifi_off),
            tooltip: 'Configure WiFi',
            onPressed: userDevice != null && _state.wifiConnectedDevices[scanResult.device.remoteId] != null
              ? () => _showWifiConfigDialog(userDevice)
              : null,
          ),
          IconButton(
            icon: Icon(Icons.delete),
            tooltip: 'Remove Device',
            onPressed: userDevice != null 
              ? () => _removeDevice(userDevice)
              : null,
          ),
        ],
      ),
    );
  }

  // Widget for creating an available device card
  Widget _buildAvailableDeviceCard(ScanResult scanResult) {
    final deviceId = getDeviceIdFromDevice(scanResult);
    
    return _buildDeviceCard(
      title: scanResult.device.advName,
      subtitle: deviceId ?? 'No ID',
      trailing: TextButton(
        style: TextButton.styleFrom(
          backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
        ),
        onPressed: deviceId != null 
          ? () => _showAddDeviceDialog(deviceId, scanResult.device.platformName)
          : null,
        child: Icon(Icons.add), 
      ),
    );
  }

  // Widget for creating an empty state message
  Widget _buildEmptyState(String message) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Center(
        child: Text(
          message,
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Group devices into user devices and available devices
    final userBleDevices = _state.discoveredDevices
        .where((result) => isUserDevice(getDeviceIdFromDevice(result)))
        .toList();
    
    final availableBleDevices = _state.discoveredDevices
        .where((result) => !isUserDevice(getDeviceIdFromDevice(result)))
        .toList();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => GoRouter.of(context).pop(),
        ),
        title: const Text('Devices'),
        actions: [
          IconButton(
            icon: Icon(_state.isScanning ? Icons.stop : Icons.refresh),
            onPressed: _state.isScanning 
              ? () => _bluetoothManager.stopScan()
              : () => _bluetoothManager.startScan(),
          ),
        ],
      ),
      body: isLoading 
        ? Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _loadUserDevices,
            child: ListView(
              children: [
                // Your Devices Section
                _buildSectionHeader('Your Devices'),
                if (userBleDevices.isEmpty)
                  _buildEmptyState('No paired devices found')
                else
                  ...userBleDevices.map(_buildUserDeviceCard),
                
                // Available Devices Section
                _buildSectionHeader('Available Devices'),
                if (availableBleDevices.isEmpty)
                  _buildEmptyState('No available devices found')
                else
                  ...availableBleDevices.map(_buildAvailableDeviceCard),
              ],
            ),
          ),
    );
  }

  @override
  void dispose() {
    _bluetoothManager.dispose();
    nameController.dispose();
    wifiNameController.dispose();
    wifiPasswordController.dispose();
    super.dispose();
  }
}