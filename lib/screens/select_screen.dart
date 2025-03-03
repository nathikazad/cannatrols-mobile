// home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_app/models/cure_model.dart';
import 'package:flutter_app/providers/device_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/auth.dart';

final supabase = Supabase.instance.client;

class DeviceSelectScreen extends ConsumerWidget {
  const DeviceSelectScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Top Logo
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: GestureDetector(
                onTap: () => context.pop(),
                child: Image.asset("assets/images/c2.png", height: 120),
              ),
            ),
            // Menu Buttons
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  menuButton('SYSTEM SELECTION', Color(0xFF9C27B0), () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => DeviceSelectScreen()),
                    );
                  }),

                ],
              ),
            ),

            _buildDeviceList(ref),
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

  Widget menuButton(String title, Color color, VoidCallback onPressed, {Color textColor = Colors.black54}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: SizedBox(
        width: double.infinity,
        height: 60,
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
                color: textColor,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeviceList(WidgetRef ref) {
    // Fixed height container instead of Expanded
    return Container(
      height: 200, // Fixed height - adjust this value as needed
      child: FutureBuilder<List<Device>>(
        future: ref.read(selectedDeviceProvider.notifier).getDevices(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No devices found'));
          }

          // Display the list of devices
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              final device = snapshot.data![index];
              return Align(
                alignment: Alignment.center,
                child: SizedBox(
                  width: 180, // Set a fixed width for the card
                  height: 45, // Reduced height for more compact layout
                  child: Card(
                    margin: EdgeInsets.zero, // Zero margin
                    color: Colors.transparent,
                    elevation: 0,
                    child: InkWell(
                      onTap: () {
                        ref.read(selectedDeviceProvider.notifier).selectDevice(device);
                        // show snackbar
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Selected ${device.name}')),
                        );
                        Navigator.pop(context);
                      },
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4), // Minimal padding
                        child: Row(
                          children: [
                            Image.asset("assets/images/next.png", height: 24),
                            SizedBox(width: 8),
                            Text(
                              '${device.name}',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20.0,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }



}


