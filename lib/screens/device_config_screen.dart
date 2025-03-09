import 'dart:async';

import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/controllers/cure_controller.dart';
import 'package:flutter_app/models/cure_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class DeviceConfigScreen extends ConsumerStatefulWidget {
  final CureCycle initialCycle;
  final Device device;
  const DeviceConfigScreen({super.key, required this.initialCycle, required this.device});

  @override
  ConsumerState<DeviceConfigScreen> createState() => _DeviceConfigScreenState();
}

class _DeviceConfigScreenState extends ConsumerState<DeviceConfigScreen> {
  double temperatureValue = 68.0;
  double daysValue = 60.0;
  double dewPointValue = 54.0;
  double hoursValue = 20.0;
  StepMode stepMode = StepMode.step;
  // EnvironmentalData? environmentalData;
  late final CureDataController _controller;
  late CureCycle _currentCycle;
  late StreamSubscription<Map<CureCycle, CureTargets>> _targetSubscription;
  late StreamSubscription<ConnectionStatus> _connectionStatusSubscription;
  // Add loading state flag
  bool _isDataReady = false;
  ConnectionStatus _connectionStatus = ConnectionStatus.connecting;

  @override
  void initState() {
    super.initState();
    _controller = ref.read(cureControllerProvider);
    _currentCycle = widget.initialCycle;

    _targetSubscription = _controller.cureTargetsStream.listen((cureTargets) {
      if (mounted) {
        setState(() {
          if (cureTargets.isNotEmpty && cureTargets[_currentCycle] != null) {
            temperatureValue = cureTargets[_currentCycle]!.temperature;
            dewPointValue = cureTargets[_currentCycle]!.dewPoint;
            daysValue =
                (cureTargets[_currentCycle]!.timeLeft / (24 * 3600))
                    .floorToDouble();
            hoursValue =
                ((cureTargets[_currentCycle]!.timeLeft % (24 * 3600)) / 3600)
                    .floorToDouble();
            stepMode = cureTargets[_currentCycle]!.stepMode;
            _isDataReady = true;
          }
        });
      }
    });

    _connectionStatusSubscription = _controller.connectionStatusStream.listen((
      status,
    ) {
      if (mounted) {
        // Check if widget is still mounted
        setState(() {
          _connectionStatus = status;
        });
      }
    });
    
    // Connect to device and request cure targets
    _controller.connect(widget.device.id).then((_) {
      _controller.askForCureTargets();
    });
    
    // Initialize values from provided data if available
    if (_controller.cureTargets.isNotEmpty && _controller.cureTargets[_currentCycle] != null) {
      updateCureTargets(_controller.cureTargets, _currentCycle);
      _isDataReady = true;
    }
  }

  void updateCureTargets(Map<CureCycle, CureTargets> cureTargets, CureCycle cycle) {
    setState(() {
      temperatureValue = cureTargets[cycle]!.temperature;
      dewPointValue = cureTargets[cycle]!.dewPoint;
      daysValue = (cureTargets[cycle]!.timeLeft / (24 * 3600)).floorToDouble();
      hoursValue = ((cureTargets[cycle]!.timeLeft % (24 * 3600)) / 3600).floorToDouble();
      stepMode = cureTargets[cycle]!.stepMode;
    });
  }

  // Calculate total seconds from days and hours
  int getTotalSeconds() {
    int days = (daysValue == 0 ? 1 : daysValue).toInt();
    int hours = (hoursValue == 0 ? 1 : hoursValue).toInt();
    int daysInSeconds = (days * 24 * 60 * 60).toInt();
    int hoursInSeconds = (hours * 60 * 60).toInt();
    return daysInSeconds + hoursInSeconds;
  }

  String getCureCycleSetting() {
    switch (_currentCycle) {
      case CureCycle.cure:
        return 'CURE \nCYCLE \nSETTINGS';
      case CureCycle.dry:
        return 'DRY \nCYCLE \nSETTINGS';
      default:
        return 'STORE \nSETTINGS';
    }
  }

  Color _getDeviceColor() {
    switch (_currentCycle) {
      case CureCycle.cure:
        return Color(0xFF5AAFDE);
      case CureCycle.dry:
        return Color(0xFF7859BF);
      default:
        return Color(0xFF53B738);
    }
  }

  CureCycle getNextCycle() {
    CureCycle nextCycle;
    switch (_currentCycle) {
      case CureCycle.cure:
        nextCycle = CureCycle.store;
      case CureCycle.dry:
        nextCycle = CureCycle.cure;
      case CureCycle.store:
        nextCycle = CureCycle.dry;
    }
    updateCureTargets(_controller.cureTargets, nextCycle);
    return nextCycle;
  }
  
  @override
  void dispose() {
    _targetSubscription.cancel();
    _connectionStatusSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: _getDeviceColor(),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: () => GoRouter.of(context).pop(),
                      child: Column(
                        children: [
                          Image.asset("assets/images/c2_bg.png", height: 100),
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
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        GestureDetector(
                          onTap: () {
                            Navigator.pop(context);
                          },
                          child: Column(
                            children: [
                              Image.asset("assets/images/retun.png"),
                              Text(
                                "Return",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.black54,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 20),
                        Text(
                          getCureCycleSetting(),
                          textAlign: TextAlign.end,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            height: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Main content area - show loading, error, or configuration UI
              Expanded(
                child: _buildMainContent(),
              ),

              if(_connectionStatus == ConnectionStatus.timedOut)
                _buildTimedOutDisplay()
              else
                SizedBox(height: 0),
              
              // Bottom section with logo and save button
              Padding(
                padding: const EdgeInsets.only(
                  bottom: 10.0,
                  left: 20,
                  right: 20,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Image.asset('assets/images/logo.png', height: 40),
                    if (_isDataReady)
                      GestureDetector(
                        onTap: () {
                          CureDataController controller = ref.read(cureControllerProvider);
                          controller.updateDeviceConfiguration(
                            cycle: _currentCycle,
                            temperature: double.parse(temperatureValue.toStringAsFixed(1)),
                            dewPoint: double.parse(dewPointValue.toStringAsFixed(1)),
                            timeInSeconds: getTotalSeconds(),
                            stepMode: stepMode,
                          );
                          setState(() {
                            _currentCycle = getNextCycle();
                          });
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
                                    widget.device.name,
                                    style: TextStyle(
                                      color: Colors.black87,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    'SAVE AND NEXT',
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimedOutDisplay() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Center(
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 10.0, horizontal: 16.0),
          decoration: BoxDecoration(
            color: Color(0xFFF5F2E9), // Cream color background
            borderRadius: BorderRadius.circular(8.0),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: Colors.red, size: 20),
              SizedBox(width: 8.0),
              Text(
                "Connection timed out",
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // New method to build the main content based on loading state
  Widget _buildMainContent() {
    // If there's a connection error
    if (_connectionStatus == ConnectionStatus.error) {
      return _buildErrorDisplay("Failed to connect to device. Please try again.");
    }

    // If we're still waiting for data
    if (!_isDataReady) {
      return _buildLoadingDisplay();
    }

    // If data is ready, show the configuration UI
    return Column(
      children: [
        SizedBox(height: 50),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            buildSlider(
              "Temperature",
              temperatureValue,
              (val) {
                setState(() {
                  temperatureValue = val;
                });
              },
              58,
              76,
            ),
            if (_currentCycle != CureCycle.store)
              buildSlider(
                "Days",
                daysValue,
                (val) {
                  setState(() {
                    daysValue = val;
                  });
                },
                0,
                23,
              ),
          ],
        ),
        SizedBox(height: 50),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            buildSlider(
              "Dew Point",
              dewPointValue,
              (val) {
                setState(() {
                  dewPointValue = val;
                });
              },
              45,
              65,
            ),
            if (_currentCycle != CureCycle.store)
              buildSlider(
                "Hours",
                hoursValue,
                (val) {
                  setState(() {
                    hoursValue = val;
                  });
                },
                0,
                23,
              ),
          ],
        ),
        SizedBox(height: 38),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildRadioOption('Step', stepMode == StepMode.step, () {
              setState(() => stepMode = StepMode.step);
            }),
            const SizedBox(width: 40),
            _buildRadioOption('Slope', stepMode == StepMode.slope, () {
              setState(() => stepMode = StepMode.slope);
            }),
          ],
        ),
      ],
    );
  }

  // New method to display loading state
  Widget _buildLoadingDisplay() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.white),
          SizedBox(height: 20),
          Text(
            'Loading configuration...',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Please wait while we retrieve device settings',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }

  // New method to display error state
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
            onPressed: () {

              _controller.connect(widget.device.id).then((_) {
                _controller.askForCureTargets();
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: _getDeviceColor(),
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text('Retry Connection'),
          ),
        ],
      ),
    );
  }

  Widget buildSlider(
    String label,
    double value,
    Function(double) onChanged,
    int min,
    int max,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                (label == "Temperature" || label == "Dew Point")
                    ? value.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '.0')
                    : value.toInt().toString(),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 59,
                  fontWeight: FontWeight.w400,
                  height: 0.9,
                ),
              ),
              if (label == "Temperature" || label == "Dew Point")
                Text(
                  " F",
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: 30,
                    fontWeight: FontWeight.w600,
                    height: 0.9,
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 0, top: 0, left: 20),
          child: Text(
            label,
            style: TextStyle(
              color: Colors.black87,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        SizedBox(
          width: 180,
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 8,
              thumbShape: RoundSliderThumbShape(enabledThumbRadius: 12),
              overlayShape: RoundSliderOverlayShape(overlayRadius: 24),
              activeTrackColor: Colors.yellow,
              inactiveTrackColor: Colors.black,
              thumbColor: Colors.yellow,
            ),
            child: Slider(
              value: value,
              min: min.toDouble(),
              max: max.toDouble(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRadioOption(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Center(
            child:
                isSelected
                    ? Image.asset("assets/images/selected.png")
                    : Image.asset(
                      "assets/images/select.png",
                    ), // Selected imag, // Unselected image
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(color: Colors.black54, fontSize: 25),
          ),
        ],
      ),
    );
  }
}
