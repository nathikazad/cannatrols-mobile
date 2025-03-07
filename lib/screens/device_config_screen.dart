import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/models/cure_model.dart';

class DeviceConfigScreen extends StatefulWidget {
  final EnvironmentalData? environmentalData;
  
  const DeviceConfigScreen({
    super.key, 
    this.environmentalData,
  });

  @override
  _DeviceConfigScreenState createState() => _DeviceConfigScreenState();
}

class _DeviceConfigScreenState extends State<DeviceConfigScreen> {
  double temperatureValue = 68.0;
  double daysValue = 60.0;
  double dewPointValue = 54.0;
  double hoursValue = 20.0;
  StepMode stepMode = StepMode.step;

  @override
  void initState() {
    super.initState();
    // Initialize values from provided data if available
    if (widget.environmentalData != null) {
      temperatureValue = widget.environmentalData!.targetTemperature;
      dewPointValue = widget.environmentalData!.targetDewPoint;
      if (temperatureValue < 58) {
        temperatureValue = 58;
      }
      if (temperatureValue > 76) {
        temperatureValue = 76;
      }
      if (dewPointValue < 45) {
        dewPointValue = 45;
      }
      if (dewPointValue > 65) {
        dewPointValue = 65;
      }
      
      
      // Convert seconds to days and hours
      int totalSeconds = widget.environmentalData!.timeLeft;
      daysValue = (totalSeconds / (24 * 3600)).floorToDouble();
      hoursValue = ((totalSeconds % (24 * 3600)) / 3600).floorToDouble();
      stepMode = widget.environmentalData!.targetStepMode;
    }
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
    switch (widget.environmentalData!.cycle) {
      case CureCycle.cure:
        return 'CURE \nCYCLE \nSETTINGS';
      case CureCycle.dry:
        return 'DRY \nCYCLE \nSETTINGS';
      default:
        return 'STORE \nSETTINGS';
    }
  }

    Color _getDeviceColor() {
    switch (widget.environmentalData!.cycle) {
      case CureCycle.cure:
        return Color(0xFF5AAFDE);
      case CureCycle.dry:
        return Color(0xFF7859BF);
      default:
        return Color(0xFF53B738);
    }
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
                    Column(
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
              SizedBox(height: 100),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  buildSlider("Temperature", temperatureValue, (val) {
                    setState(() {
                      temperatureValue = val;
                    });
                  }, 58, 76),
                  if (widget.environmentalData!.cycle != CureCycle.store)
                    buildSlider("Days", daysValue, (val) {
                      setState(() {
                        daysValue = val;
                      });
                    }, 0, 23),
                ],
              ),
              SizedBox(height: 50),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  buildSlider("Dew Point", dewPointValue, (val) {
                    setState(() {
                      dewPointValue = val;
                    });
                  }, 45, 65),
                  if (widget.environmentalData!.cycle != CureCycle.store)
                    buildSlider("Hours", hoursValue, (val) {
                      setState(() {
                        hoursValue = val;
                      });
                    }, 0, 23),
                ],
              ),
              SizedBox(height:38,),
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
              Spacer(),
              Padding(
                padding: const EdgeInsets.only(bottom:10.0, left: 20, right: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Image.asset(
                      'assets/images/logo.png',
                      height: 40,
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(context, {
                          'temperature': double.parse(temperatureValue.toStringAsFixed(1)),
                          'dewPoint': double.parse(dewPointValue.toStringAsFixed(1)),
                          'timeInSeconds': getTotalSeconds(),
                          'stepMode': stepMode,
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
                                  'MY COOL CURE 1',
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
                    )
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  Widget buildSlider(String label, double value, Function(double) onChanged, int min, int max) {
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
              child: isSelected
                  ? Image.asset("assets/images/selected.png"):Image.asset("assets/images/select.png") // Selected imag, // Unselected image
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 25,
            ),
          ),
        ],
      ),
    );
  }
}
