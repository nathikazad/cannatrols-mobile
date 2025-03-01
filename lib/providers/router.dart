// router.dart
import 'package:flutter_app/ble_screen.dart';
import 'package:flutter_app/screens/cure_cycle.dart';
import 'package:flutter_app/utils/mqtt.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import './auth.dart';
import '../screens/login_screen.dart';
import '../screens/home_screen.dart';

final routerProvider = Provider((ref) {
  final authState = ref.watch(authProvider).state;


  return GoRouter(
    initialLocation: '/login',
    refreshListenable: ref.watch(authProvider),

    redirect: (context, state) {
      final isLoggedIn = authState.user != null;
      final isLoginRoute = state.uri.path == '/login';  

      if (!isLoggedIn && !isLoginRoute) return '/login';
      if (isLoggedIn && isLoginRoute) return '/home';
      
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/ble',
        builder: (context, state) =>  BluetoothScreen(),
      ),
      GoRoute(
        path: '/mqtt/:deviceId',  // The colon indicates a path parameter
        builder: (context, state) => MqttConsole(
          deviceId: state.pathParameters['deviceId'] ?? '',
        ),
      ),
      GoRoute(
        path: '/cure',
        builder: (context, state) =>  CureCycleScreen(),
      ),
    ],
  );
});