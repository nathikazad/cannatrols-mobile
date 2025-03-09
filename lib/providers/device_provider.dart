// device_provider.dart
import 'dart:convert';

import 'package:flutter_app/controllers/cure_controller.dart';
import 'package:flutter_app/models/cure_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

final supabase = Supabase.instance.client;
class DeviceNotifier extends StateNotifier<Device?> {
  final Function(String) callbackOnConnect;
  DeviceNotifier(this.callbackOnConnect) : super(null) {
    // Initialize with the first device if available
    _initializeWithFirstDevice();
  }
  
  Future<void> _initializeWithFirstDevice() async {
    final devices = await getDevices();
    if (devices.isNotEmpty) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? lastSelectedDeviceId = prefs.getString('selectedDeviceId');
      if (lastSelectedDeviceId != null) {
        selectDevice(devices.firstWhere((device) => device.id == lastSelectedDeviceId));
      } else {
        selectDevice(devices.first);
      }
    }
  }
  
  void selectDevice(Device device) {
    state = device;
    callbackOnConnect(device.id);
    SharedPreferences.getInstance().then((prefs) => prefs.setString('selectedDeviceId', device.id));
  }
  
  void clearSelection() {
    state = null;
  }

  // Fixed the function signature to return List<String>
  Future<List<Device>> getDevices() async {
    final userId = supabase.auth.currentUser!.id;
    try {
      final response = await supabase
          .from('machines')
          .select('machine_id, name',)
          .eq('user_id', userId);

      // Parse the response to extract machine_ids into a list
      List<Device> deviceIds = [];
      for (var item in response) {
        deviceIds.add(Device(id: item['machine_id'], name: item['name']));
      }
      return deviceIds;
    } catch (e) {
      print('Error getting devices: $e');
      return []; // Return empty list instead of null
    }
  }

  Future<void> addDevice(String deviceId, String name) async {
    try {
      // Call the Supabase function using the client SDK
      final response = await supabase.functions.invoke(
        'set-device-owner',
        body: {
          'deviceId': deviceId,
          'name': name
        },
      );
      
      if (response.status != 200) {
        throw Exception('Failed to add device: ${response.data}');
      }
    } catch (e) {
      print('Error adding device: $e');
      rethrow;
    }
  }

  Future<void> updateDevice(String deviceId, String name) async {
    final userId = supabase.auth.currentUser!.id;
    
    try {
      await supabase
          .from('machines')
          .update({'name': name})
          .eq('machine_id', deviceId)
          .eq('user_id', userId);
    } catch (e) {
      print('Error updating device: $e');
      rethrow;
    }
  }

  Future<void> removeDevice(String deviceId) async {
    final userId = supabase.auth.currentUser!.id;
    
    try {
      await supabase
          .from('machines')
          .update({'user_id': null})
          .eq('machine_id', deviceId)
          .eq('user_id', userId);
    } catch (e) {
      print('Error removing device: $e');
      rethrow;
    }
  }
}

final selectedDeviceProvider = StateNotifierProvider<DeviceNotifier, Device?>((ref) {
  return DeviceNotifier((String deviceId) {
    CureDataController controller = ref.read(cureControllerProvider);
    controller.connect(deviceId);
  });
});