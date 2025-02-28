import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/auth.dart';

final supabase = Supabase.instance.client;

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

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).state.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authProvider).signOut(),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Home Page'),
            if (user != null) Text('Email: ${user.email}'),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.bluetooth),
              label: const Text('Go to BLE Page'),
              onPressed: () => context.push('/ble')
            ),
            const SizedBox(height: 30),
            const Text('Your Devices:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Expanded(
              child: FutureBuilder<List<String>>(
                future: getDeviceIds(),
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
                      final deviceId = snapshot.data![index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: const Icon(Icons.devices),
                          title: Text('Device: $deviceId'),
                          trailing: const Icon(Icons.arrow_forward),
                          onTap: () => context.push('/mqtt/$deviceId'),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}