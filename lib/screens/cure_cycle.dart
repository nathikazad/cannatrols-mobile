// import 'package:cannatrol/setting/setting.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'dart:async';

class CureCycleScreen extends StatefulWidget {
  const CureCycleScreen({super.key});

  @override
  State<CureCycleScreen> createState() => _CureCycleScreenState();
}

class _CureCycleScreenState extends State<CureCycleScreen> {
  bool _isPlaying = false;
  int _totalSeconds = 248940; 
  double _temperature = 68.0; 
  double _dewPoint = 54.0; 
  int _humidity = 57; 
  late Timer _timer;
  String _durationText = 'Duration 2d 20:09';

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    if (_isPlaying) {
      _timer.cancel();
    }
    super.dispose();
  }

  void _startCountdown() {
    setState(() {
      _isPlaying = true;
    });
    
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        if (_totalSeconds > 0) {
          _totalSeconds--;
          _updateDurationText();
        } else {
          _timer.cancel();
          _isPlaying = false;
        }
      });
    });
  }

  void _pauseCountdown() {
    if (_isPlaying) {
      _timer.cancel();
      setState(() {
        _isPlaying = false;
      });
    }
  }

  void _resetCountdown() {
    if (_isPlaying) {
      _timer.cancel();
    }
    
    setState(() {
      _isPlaying = false;
      _totalSeconds = 248940; // Reset to 2d 20:09
      _updateDurationText();
    });
  }

  void _updateDurationText() {
    int days = _totalSeconds ~/ (24 * 3600);
    int hours = (_totalSeconds % (24 * 3600)) ~/ 3600;
    int minutes = (_totalSeconds % 3600) ~/ 60;
    
    _durationText = 'Duration ${days}d ${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
  }

  void _advanceToStore() {
    // Implement navigation to store screen
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Advancing to Store...'))
    );
    // You would typically use Navigator here to go to the Store screen
    // Navigator.push(context, MaterialPageRoute(builder: (context) => StoreScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: Color(0xFF5AAFDE),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row with Logo and Controls
                _buildTopRow(context),
                
                SizedBox(height: 60),

                // Temperature Display
                _buildParameterDisplaySection("Temperature", _temperature),
                
                // Dew Point Display
                _buildParameterDisplaySection("Dew Point", _dewPoint),
                
                // Humidity Display
                _buildHumiditySection(_humidity),

                Spacer(),

                // Bottom Logo and Edit Setting
                _buildBottomRow(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopRow(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Logo and Main Menu
        Column(
          children: [
            Container(
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xff404042),
              ),
              child: Image.asset("assets/images/c2_bg.png")),
            SizedBox(height: 4),
            Text(
              'Main Menu',
              style: TextStyle(
                color: Colors.black54,
                fontSize: 12,
                fontWeight: FontWeight.w600
              ),
            ),
          ],
        ),
        
        // Right Column: Control Buttons and Cure Cycle section
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Control Buttons
            Row(
              children: [
                // Show Play button only when not playing
                if (!_isPlaying)
                  _buildControlButton('Start', onTap: _startCountdown),
                
                // Show Pause button only when playing
                if (_isPlaying)
                  _buildControlButton('Pause', onTap: _pauseCountdown),
                
                SizedBox(width: 8),
                _buildControlButton('Reset', onTap: _resetCountdown),
              ],
            ),
            
            SizedBox(height: 20),
            
            // Cure Cycle Title and Duration (moved here)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'CURE CYCLE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 35,
                    fontWeight: FontWeight.bold,
                    height: 0.8, //
                  ),
                ),
                Text(
                  _durationText,
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 5),
                GestureDetector(
                  onTap: _advanceToStore,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        'Advance to Store',
                        style: TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.w500,
                          fontSize: 18,
                        ),
                      ),
                      SizedBox(width: 8),
                      Image.asset("assets/images/next.png")
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildParameterDisplaySection(String name, double value) {
  // Round to 1 decimal place
  double roundedValue = (value * 10).round() / 10;
  
  // Split into whole number and decimal parts
  int wholeNumber = roundedValue.floor();
  String decimal = (roundedValue - wholeNumber).toStringAsFixed(1).substring(1);
  
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '$wholeNumber',
            style: TextStyle(
              color: Colors.white,
              fontSize: 108,
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
          ),
          Text(
            "$decimal°F",
            style: TextStyle(
              color: Colors.black87,
              fontSize: 64,
              fontWeight: FontWeight.w700,
            ),
          )
        ],
      ),
      Transform.translate(
        offset: Offset(0, -10),
        child: Row(
          children: [
            Padding(
              padding: EdgeInsets.only(left: 10.0),
              child: Text(
                name,
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 24,
                  fontWeight: FontWeight.w500
                ),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

  Widget _buildHumiditySection(int value) {
    return Padding(
      padding: EdgeInsets.only(left: 10.0),
      child: Row(
        children: [
          Text(
            '$value%',
            style: TextStyle(
              color: Colors.black87,
              fontSize: 40,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(width: 6),
          Text(
            'Humidity',
            style: TextStyle(color: Colors.black87, fontSize: 32),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomRow(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Image.asset(
          'assets/images/logo.png',
          height: 40,
        ),
        GestureDetector(
          onTap: () {
            // Navigator.push(context, MaterialPageRoute(builder: (context) => SettingsScreen()));
          },
          child: DottedBorder(
            borderType: BorderType.RRect,
            dashPattern: [10, 10],
            child: ClipRRect(
              borderRadius: BorderRadius.all(Radius.circular(12)),
              child: SizedBox(
                height: 45,
                width: 110,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'MY COOL CURE 1',
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: 12,
                        fontWeight: FontWeight.w600
                      ),
                    ),
                    Text(
                      'EDIT SETTING',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        )
      ],
    );
  }

  Widget _buildControlButton(String label, {required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Image.asset(
            label == 'Start' ? "assets/images/start.png" :
            label == 'Pause' ? "assets/images/pause.png" :
            "assets/images/reset.png",
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.black54,
              fontSize: 12,
              fontWeight: FontWeight.w700
            ),
          ),
        ],
      ),
    );
  }
}