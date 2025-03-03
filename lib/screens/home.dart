import 'package:flutter/material.dart';
import 'package:flutter_app/providers/device_provider.dart';
import 'package:flutter_app/screens/device_screen.dart';
import 'package:flutter_app/screens/select_screen.dart';
import 'package:flutter_app/screens/set_up.dart';
import 'package:flutter_app/screens/setting.dart';
import 'package:flutter_app/screens/wifi_setup.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class Home extends ConsumerWidget {
  const Home({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String? deviceId = ref.watch(selectedDeviceProvider);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Top Logo
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Image.asset("assets/images/c2.png", height: 120),
            ),
            // Menu Buttons
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  menuButton('CHECK CYCLE', Color(0xFF4CAF50), () {
                    if (deviceId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Please select a device first'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DevicesScreen(deviceId: deviceId),
                        ),
                      );
                    }
                  }),
                  menuButton('EDIT CYCLES', Color(0xFF2196F3), () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => WifiSetupScreen(),
                      ),
                    );
                  }),
                  menuButton('SYSTEM SELECTION', Color(0xFF9C27B0), () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => DeviceSelectScreen()),
                    );
                  }),
                  menuButton('SYSTEM SET UP', Color(0xFF1976D2), () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => SettingsScreen()),
                    );
                    print('SYSTEM SET UP tapped');
                  }),
                ],
              ),
            ),

            // Bottom Device Image and Logo
            Column(
              children: [
                Image.asset("assets/images/bottom.png", height: 180),
                SizedBox(height: 16),
                Image.asset("assets/images/logo.png", height: 40),
                SizedBox(height: 16),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget menuButton(String title, Color color, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: SizedBox(
        width: double.infinity,
        height: 80,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(0),
            ),
          ),
          child: FittedBox(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 38,
                fontWeight: FontWeight.bold,
                color: Colors.black54,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
