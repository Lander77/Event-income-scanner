import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_code_scanner/login.dart';
import 'package:qr_code_scanner/qr_overlay.dart';
import 'package:vibration/vibration.dart';
import 'package:http/http.dart' as http;
import 'package:wakelock_plus/wakelock_plus.dart';


class ScannerPage extends StatefulWidget {
  final String eventId;
  final String eventName;

  const ScannerPage({Key? key, required this.eventId, required this.eventName})
      : super(key: key);

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  MobileScannerController cameraController = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates, detectionTimeoutMs: 500);
  OverlayEntry? overlayEntry;
  late ConnectivityResult _connectionStatus;
  late Timer _connectivityTimer;
  bool isDetectionAllowed = true;

  @override
  void initState() {
    super.initState();

    // Scherm aanhouden
    WakelockPlus.enable();

    // Initialize the timer to check connectivity every 5 seconds (adjust as needed)
    _connectivityTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _checkConnectivity();
    });

    // Initial connectivity check
    _checkConnectivity();
  }

  void _checkConnectivity() async {
    List<ConnectivityResult> connectivityResults = await Connectivity().checkConnectivity();
    
    // Pick the first active connection or set as `none`
    ConnectivityResult connectionStatus = connectivityResults.isNotEmpty 
        ? connectivityResults.first 
        : ConnectivityResult.none;

    setState(() {
      _connectionStatus = connectionStatus;
    });

    if (_connectionStatus == ConnectivityResult.none) {
      _showErrorMessage();
    }
  }

  void _showErrorMessage() {
    Fluttertoast.showToast(
      msg: "Please reconnect to WiFi or mobile data network to scan",
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 1,
      backgroundColor: Colors.red,
      textColor: Colors.white,
      fontSize: 16.0,
    );

    // Navigate to the login screen
    _navigateToLoginPage();
  }

  void _navigateToLoginPage() {
    // Replace this line with your navigation logic
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
          builder: (context) => LoginPage(currentEventId: widget.eventId)),
    );
  }

  @override
  void dispose() {
    _connectivityTimer.cancel();
    cameraController.dispose(); // Dispose the camera properly
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.logout, color: Colors.black),
          onPressed: () {
            // Navigate back to the login page
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const LoginPage()),
            );
          },
        ),
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.center,
          child: Text(
            widget.eventName.toString(),
            style: const TextStyle(
                color: Colors.black, fontWeight: FontWeight.bold),
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        actions: [
          IconButton(
            color: Colors.black,
            icon: const Icon(Icons.cameraswitch_outlined),
            onPressed: () => cameraController.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
              // fit: BoxFit.contain,

              controller: cameraController,
              onDetect: (capture) async {
                if (!isDetectionAllowed) {
                  return; // Ignore detection if it's not allowed
                }

                final List<Barcode> barcodes = capture.barcodes;
                for (final barcode in barcodes) {
                  if (barcode.rawValue?.length == 36) {
                    debugPrint(barcode.rawValue);
                    _vibrateAccept(); // Vibrate only when the length is 36 characters
                    _showIconOverlayAccept(context); // Show icon overlay
                    sendPostRequest(barcode.rawValue!, widget.eventName);
                  } else {
                    // Handle the case when the length is not 36 characters
                    debugPrint('Barcode length is not 36 characters');
                    _vibrateDeny();
                    _showIconOverlayDeny(context); // Show icon overlay
                  }

                  // Set a flag to prevent further detections for 2 seconds
                  isDetectionAllowed = false;
                  Timer(const Duration(seconds: 2), () {
                    isDetectionAllowed = true;
                  });
                }
              }),
          QRScannerOverlay(overlayColour: Colors.black.withOpacity(0.5))
        ],
      ),
    );
  }

  // Function to trigger vibration
  void _vibrateAccept() async {
    // Check if the device supports vibration
    bool? hasVibrator = await Vibration.hasVibrator();

    // Check if hasVibrator is not null and is true
    if (hasVibrator == true) {
      // Vibrate for 500 milliseconds
      Vibration.vibrate(duration: 500);
    }
  }

  void _vibrateDeny() async {
    // Check if the device supports vibration
    bool? hasVibrator = await Vibration.hasVibrator();

    // Check if hasVibrator is not null and is true
    if (hasVibrator == true) {
      // Vibrate for 500 milliseconds (first time)
      Vibration.vibrate(duration: 250);

      // Wait for a short duration (e.g., 200 milliseconds)
      await Future.delayed(const Duration(milliseconds: 100));

      // Vibrate for 500 milliseconds (second time)
      Vibration.vibrate(duration: 250);
    }
  }

  // green circle overlay
  void _showIconOverlayAccept(BuildContext context) {
    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).size.height / 2 -
            ((MediaQuery.of(context).size.width < 400 ||
                    MediaQuery.of(context).size.height < 400)
                ? 30
                : 75.0), // Adjust as needed
        left: MediaQuery.of(context).size.width / 2 -
            ((MediaQuery.of(context).size.width < 400 ||
                    MediaQuery.of(context).size.height < 400)
                ? 75.0
                : 130.0), // Adjust as needed
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: (MediaQuery.of(context).size.width < 400 ||
                    MediaQuery.of(context).size.height < 400)
                ? 150.0
                : 260.0,
            height: (MediaQuery.of(context).size.width < 400 ||
                    MediaQuery.of(context).size.height < 400)
                ? 150.0
                : 260.0,
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/checked.png'),
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(overlayEntry!);

    // Remove the overlay after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      overlayEntry?.remove();
    });
  }

  // red circle overlay
  // green circle overlay
  void _showIconOverlayDeny(BuildContext context) {
    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).size.height / 2 -
            ((MediaQuery.of(context).size.width < 400 ||
                    MediaQuery.of(context).size.height < 400)
                ? 30
                : 75.0), // Adjust as needed
        left: MediaQuery.of(context).size.width / 2 -
            ((MediaQuery.of(context).size.width < 400 ||
                    MediaQuery.of(context).size.height < 400)
                ? 75.0
                : 130.0), // Adjust as needed
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: (MediaQuery.of(context).size.width < 400 ||
                    MediaQuery.of(context).size.height < 400)
                ? 150.0
                : 260.0,
            height: (MediaQuery.of(context).size.width < 400 ||
                    MediaQuery.of(context).size.height < 400)
                ? 150.0
                : 260.0,
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage(
                    'assets/delete.png'), // Replace with your actual image path
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(overlayEntry!);

    // Remove the overlay after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      overlayEntry?.remove();
    });
  }

  Future<void> sendPostRequest(String codeValue, String eventCode) async {
    const url = 'https://scanninghappening.azurewebsites.net/api/scan';
    final uri = Uri.parse(url);
    var response = await http.post(
      uri,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"id": codeValue, "eventId": eventCode}),
    );
    debugPrint(response.body);
  }
}