// device_provider.dart
import 'package:flutter_app/models/cure_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;
class DeviceNotifier extends StateNotifier<Device?> {
  DeviceNotifier() : super(null) {
    // Initialize with the first device if available
    _initializeWithFirstDevice();
  }
  
  Future<void> _initializeWithFirstDevice() async {
    final devices = await getDevices();
    if (devices.isNotEmpty) {
      state = devices.first;
    }
  }
  
  void selectDevice(Device device) {
    state = device;
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
}

final selectedDeviceProvider = StateNotifierProvider<DeviceNotifier, Device?>((ref) {
  return DeviceNotifier();
});