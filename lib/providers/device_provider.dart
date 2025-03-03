// device_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;
class DeviceNotifier extends StateNotifier<String?> {
  DeviceNotifier() : super(null) {
    // Initialize with the first device if available
    _initializeWithFirstDevice();
  }
  
  Future<void> _initializeWithFirstDevice() async {
    final deviceIds = await getDeviceIds();
    if (deviceIds.isNotEmpty) {
      state = deviceIds.first;
    }
  }
  
  void selectDevice(String deviceId) {
    state = deviceId;
  }
  
  void clearSelection() {
    state = null;
  }

  // Fixed the function signature to return List<String>
  Future<List<String>> getDeviceIds() async {
    final userId = supabase.auth.currentUser!.id;
    try {
      final response = await supabase
          .from('machines')
          .select('machine_id')
          .eq('user_id', userId);

      // Parse the response to extract machine_ids into a list
      List<String> deviceIds = [];
      for (var item in response) {
        deviceIds.add(item['machine_id']);
      }
      return deviceIds;
    } catch (e) {
      print('Error getting devices: $e');
      return []; // Return empty list instead of null
    }
  }
}

final selectedDeviceProvider = StateNotifierProvider<DeviceNotifier, String?>((ref) {
  return DeviceNotifier();
});