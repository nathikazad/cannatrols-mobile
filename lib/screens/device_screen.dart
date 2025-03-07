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
  final Device device;
  const DevicesScreen({super.key, required this.device});

  @override
  ConsumerState<DevicesScreen> createState() => _DeviceScreenState();
}

class _DeviceScreenState extends ConsumerState<DevicesScreen> {

  // Flags to track connection and data state
  bool _isDataReady = false;
  String? _connectionError;

  // Data values (will be populated from service)
  EnvironmentalData? _currentData;
  int _totalSeconds = 0;

  bool _showStubControls = false;
  late final CureDataController _controller;
  late final Device _device;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _device = widget.device;
    _controller = ref.read(cureDataControllerProvider(_device.id));
    _connectToDevice();


    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (_currentData?.cycle != CureCycle.store &&
          _currentData?.isPlaying == true) {
        setState(() {
          if (_totalSeconds > 0) {
            _totalSeconds--;
          }
        });
      }
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
        _totalSeconds = data.timeLeft;
        _currentData = data;
        _isDataReady = true;
        _connectionError = null;
      });
    });

    // Attempt to connect
    await _controller.connect();
  }

  @override
  void dispose() {

    _timer?.cancel();

    _controller.disconnect();
    super.dispose();
  }

  String formatSecondsToCountdown(int totalSeconds) {
    // Calculate days, hours, and minutes
    int days = totalSeconds ~/ (24 * 3600);
    int hours = (totalSeconds % (24 * 3600)) ~/ 3600;
    int minutes = (totalSeconds % 3600) ~/ 60;

    // Format as "Xd HH:MM"
    return '${days}d ${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
  }

  void _advanceToNextCycle() {
    // if current cycle is store, advance to dry
    // if current cycle is dry, advance to cure
    // if current cycle is cure, advance to store
    String nextCycle;
    switch (_currentData?.cycle) {
      case CureCycle.store:
        _controller.advanceToDryCycle();
        nextCycle = 'Dry';
        break;
      case CureCycle.dry:
        _controller.advanceToCureCycle();
        nextCycle = 'Cure';
        break;
      case CureCycle.cure:
        _controller.advanceToStore();
        nextCycle = 'Store';
        break;
      default:
        _controller.advanceToStore();
        nextCycle = 'Store';
        break;
    }

    
    // Implement navigation to store screen
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Advancing to $nextCycle...')));
  }

  void _toggleStubControls() {
    setState(() {
      _showStubControls = !_showStubControls;
    });
  }

  Color _getDeviceColor() {
    switch (_currentData?.cycle) {
      case CureCycle.cure:
        return Color(0xFF5AAFDE);
      case CureCycle.dry:
        return Color(0xFF7859BF);
      default:
        return Color(0xFF53B738);
    }
  }

  void _navigateToDeviceConfig() async {
    // Navigate to config screen and await result
    final result = await GoRouter.of(context).push<Map<String, dynamic>>(
      '/device_config',
      extra: _currentData,
    );
    
    // Handle the returned configuration values
    if (result != null) {
      double temperature = result['temperature'];
      double dewPoint = result['dewPoint'];
      int timeInSeconds = result['timeInSeconds'];
      bool stepMode = result['stepMode'];
      
      // Update device with new configuration values
      // _controller.updateDeviceConfiguration(
      //   temperature: temperature,
      //   dewPoint: dewPoint,
      //   timeInSeconds: timeInSeconds,
      //   stepMode: stepMode,
      // );
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(cureDataControllerProvider(_device.id));
    final isUsingStubService = controller.isUsingStubService;

    return Scaffold(
      body: Container(
        color: _getDeviceColor(),
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
                      child: StubControls(deviceId: _device.id),
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
      children:
          _currentData != null
              ? [
                // Temperature Display
                _buildParameterDisplaySection(
                  "Temperature",
                  _currentData!.temperature,
                ),

                // Dew Point Display
                _buildParameterDisplaySection(
                  "Dew Point",
                  _currentData!.dewPoint,
                ),

                // Humidity Display
                _buildHumiditySection(_currentData!.humidity),
              ]
              : [],
    );
  }

  Widget _buildLoadingDisplay() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.white),
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
            style: TextStyle(color: Colors.white70, fontSize: 14),
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
          Icon(Icons.error_outline, color: Colors.red[300], size: 60),
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
                child: Image.asset("assets/images/c2_bg.png"),
              ),
              SizedBox(height: 4),
              Text(
                'Main Menu',
                style: TextStyle(
                  color: Colors.black54,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
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
            if(_currentData!= null)
              Row(
                children: [
                  // Show Play button only when not playing
                  if (_currentData!.cycle == CureCycle.store || !_currentData!.isPlaying)
                    _buildControlButton('Start', onTap: _currentData?.cycle == CureCycle.store ? _advanceToNextCycle : _controller.play)
                  else
                    _buildControlButton('Pause', onTap: _controller.pause),

                  SizedBox(width: 8),
                  if (_currentData != null && _currentData?.cycle != CureCycle.store)
                    _buildControlButton('Reset', onTap: _controller.restart),
                ],
              ),
            if (_currentData?.cycle != CureCycle.store) SizedBox(height: 20),

            if (_currentData != null && _currentData?.cycle != CureCycle.store)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _currentData?.cycle == CureCycle.cure
                        ? 'CURE CYCLE'
                        : 'DRY CYCLE',
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
                    onTap: _advanceToNextCycle,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          'Advance to ${_currentData?.cycle == CureCycle.cure ? 'Store' : 'Cure'}',
                          style: TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.w500,
                            fontSize: 18,
                          ),
                        ),
                        SizedBox(width: 8),
                        Image.asset("assets/images/next.png"),
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
    String decimal = (roundedValue - wholeNumber)
        .toStringAsFixed(1)
        .substring(1);

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
              "$decimal F",
              style: TextStyle(
                color: Colors.black87,
                fontSize: 64,
                fontWeight: FontWeight.w700,
              ),
            ),
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
                    fontWeight: FontWeight.w500,
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
        Image.asset('assets/images/logo.png', height: 40),
        GestureDetector(
          onTap: _navigateToDeviceConfig,
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
                      widget.device.name,
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'EDIT SETTING',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildControlButton(String label, {required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Image.asset(
            label == 'Start'
                ? "assets/images/start.png"
                : label == 'Pause'
                ? "assets/images/pause.png"
                : "assets/images/reset.png",
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.black54,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
