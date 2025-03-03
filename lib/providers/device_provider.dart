// device_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DeviceNotifier extends StateNotifier<String?> {
  DeviceNotifier() : super(null);
  
  void selectDevice(String deviceId) {
    state = deviceId;
  }
  
  void clearSelection() {
    state = null;
  }
}

final selectedDeviceProvider = StateNotifierProvider<DeviceNotifier, String?>((ref) {
  return DeviceNotifier();
});