import 'package:flutter/material.dart';
import 'package:flutter_app/providers/auth.dart';
import 'package:flutter_app/screens/home_screen.dart';
import 'package:flutter_app/screens/set_up.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment:CrossAxisAlignment.start,
            children: [
              // Logo and Main Menu text
              Row(
                mainAxisAlignment:MainAxisAlignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child:Column(
                      children: [
                        Image.asset("assets/images/c2.png",height:120,),
                        Text("Main Menu",style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),),
                      ],
                    ),),
                ],
              ),
              SizedBox(height:28,),
              // Settings Text
              const Text(
                'SETTINGS',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
               SizedBox(height:MediaQuery.sizeOf(context).height/9),
              // Settings Icons Grid
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildSettingItem("assets/images/language.png", 'Language', () {
                    // Add language settings logic here
                    print('Language settings tapped');
                  }),
                  _buildSettingItem("assets/images/bluetooth.png", 'BlueTooth', () {
                    GoRouter.of(context,).push('/ble',);
                  }),
                  _buildSettingItem("assets/images/cf.png", 'Temp', () {
                    // Add temperature settings logic here
                    print('Temperature settings tapped');
                  }),
                  _buildSettingItem("assets/images/wifi.png", 'WiFi', () {
                    // Add WiFi settings logic here
                    print('WiFi settings tapped');
                    ref.read(authProvider.notifier).signOut();
                  }),
                ],
              ),
              const Spacer(),
              // Factory Reset Button
              Row(
                mainAxisAlignment:MainAxisAlignment.center,
                children: [
                GestureDetector(
                  onTap:(){
                    Navigator.push(context, MaterialPageRoute(builder: (context)=>SetupScreen()));
                  },
                  child: Column(children: [
                    Image.asset("assets/images/factory.png"),
                    Text(
                      "Factory\nReset",
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ],),
                )
              ],),
              const Spacer(),
              // Bottom Navigation
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap:(){
                      Navigator.pop(context);
                    },
                    child: Column(children: [
                      Image.asset("assets/images/retun.png"),
                      Text(
                        "Return",
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ],),
                  ),
                  Image.asset(
                    'assets/images/logo.png',
                    height: 30,
                    color: Colors.white,
                  ),
                  GestureDetector(
                    onTap:(){
                      Navigator.push(context, MaterialPageRoute(builder: (context)=>Home()));
                    },
                    child: Column(children: [
                      Image.asset("assets/images/play.png"),
                      Text(
                        "Home",
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ],),
                  ),
                ],
              ),
            ],
          ),

        ),
      ),
    );
  }

  Widget _buildSettingItem(String icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Image.asset(icon),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }




}