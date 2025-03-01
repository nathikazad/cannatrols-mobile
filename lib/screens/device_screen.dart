// cure_cycle.dart
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/controllers/cure_controller.dart';
import 'package:flutter_app/models/cure_model.dart';
import 'package:flutter_app/stubs/mqtt_stub.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'package:go_router/go_router.dart';
class DevicesScreen extends ConsumerStatefulWidget {
  final String deviceId;
  
  const DevicesScreen({
    Key? key, 
    required this.deviceId,
  }) : super(key: key);

  @override
  ConsumerState<DevicesScreen> createState() => _DeviceScreenState();
}

class _DeviceScreenState extends ConsumerState<DevicesScreen> {
  bool _isPlaying = false;
  
  late Timer _timer;
  
  // Flags to track connection and data state
  bool _isDataReady = false;
  String? _connectionError;
  
  // Data values (will be populated from service)
  double? _temperature;
  double? _dewPoint;
  int? _humidity;
  int _totalSeconds = 0;

  bool _showStubControls = false;
  late final CureDataController _controller;

  @override
  void initState() {
    super.initState();
    
    // Store controller reference during initialization
    _controller = ref.read(cureDataControllerProvider(widget.deviceId));
    
    // Connect to the device when the screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _connectToDevice();
    });
  }
  
  Future<void> _connectToDevice() async {
    
    // Set up connection status listener
    _controller.connectionStatusStream.listen((status) {
      if (status == ConnectionStatus.error) {
        setState(() {
          _connectionError = 'Failed to connect to device. Please try again.';
        });
      }
    });
    
    // Set up data listener
    _controller.dataStream.listen((data) {
      setState(() {
        _temperature = data.temperature;
        _dewPoint = data.dewPoint;
        _humidity = data.humidity;
        _totalSeconds = data.timeLeft;
        _isDataReady = true;
        _connectionError = null;
      });
    });
    
    // Attempt to connect
    await _controller.connect();
  }

  @override
void dispose() {
  if (_isPlaying) {
    _timer.cancel();
  }
  
  // Get the controller reference before disposal
  _controller.disconnect();
  
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
      _totalSeconds = 0; // Reset to 2d 20:09
    });
  }


  String formatSecondsToCountdown(int totalSeconds) {
    // Calculate days, hours, and minutes
    int days = totalSeconds ~/ (24 * 3600);
    int hours = (totalSeconds % (24 * 3600)) ~/ 3600;
    int minutes = (totalSeconds % 3600) ~/ 60;
    
    // Format as "Xd HH:MM"
    return '${days}d ${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
  }

  void _advanceToStore() {
    // Implement navigation to store screen
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Advancing to Store...'))
    );
    // You would typically use Navigator here to go to the Store screen
    // Navigator.push(context, MaterialPageRoute(builder: (context) => StoreScreen()));
  }

  void _toggleStubControls() {
    setState(() {
      _showStubControls = !_showStubControls;
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(cureDataControllerProvider(widget.deviceId));
    final isUsingStubService = controller.isUsingStubService;
    
    return Scaffold(
      body: Container(
        color: Color(0xFF5AAFDE),
        child: SafeArea(
          child: Stack(
            children: [
              // Main content
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Row with Logo and Controls
                    _buildTopRow(context),
                    
                    SizedBox(height: 60),
                    
                    // Show loading, error, or data section
                    _buildMainContent(),

                    Spacer(),

                    // Bottom Logo and Edit Setting
                    _buildBottomRow(context),
                  ],
                ),
              ),
              
              // Debug floating button (only shown when using stub service)
              if (isUsingStubService)
                Positioned(
                  right: 16,
                  bottom: 70,
                  child: FloatingActionButton(
                    backgroundColor: Colors.white.withOpacity(0.8),
                    onPressed: _toggleStubControls,
                    mini: true,
                    child: Icon(
                      color: Color(0xFF5AAFDE),
                      _showStubControls ? Icons.close : Icons.build,
                    ),
                  ),
                ),
              
              // StubControls overlay
              if (_showStubControls && isUsingStubService)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: MediaQuery.of(context).size.width,
                    color: Colors.white.withOpacity(0.9),
                    child: SafeArea(
                      top: false,
                      child: StubControls(deviceId: widget.deviceId),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildMainContent() {
    // If there's a connection error
    if (_connectionError != null) {
      return _buildErrorDisplay(_connectionError!);
    }
    
    // If we're still waiting for data
    if (!_isDataReady) {
      return _buildLoadingDisplay();
    }
    
    // If data is ready, show the normal UI
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Temperature Display
        _buildParameterDisplaySection("Temperature", _temperature!),
        
        // Dew Point Display
        _buildParameterDisplaySection("Dew Point", _dewPoint!),
        
        // Humidity Display
        _buildHumiditySection(_humidity!),
      ],
    );
  }
  
  Widget _buildLoadingDisplay() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: Colors.white,
          ),
          SizedBox(height: 20),
          Text(
            'Connecting to device...',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Please wait while we establish connection',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildErrorDisplay(String errorMessage) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            color: Colors.red[300],
            size: 60,
          ),
          SizedBox(height: 20),
          Text(
            errorMessage,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 20),
          ElevatedButton(
            onPressed: _connectToDevice,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Color(0xFF5AAFDE),
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text('Retry Connection'),
          ),
        ],
      ),
    );
  }

 Widget _buildTopRow(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Logo and Main Menu
        GestureDetector(
          onTap: () => GoRouter.of(context).pop(),
          child: Column(
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
                  'Duration ${formatSecondsToCountdown(_totalSeconds)}',
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