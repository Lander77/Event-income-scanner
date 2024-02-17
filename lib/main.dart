import 'dart:async';
import 'dart:convert';

import 'package:qr_code_scanner/login.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_code_scanner/qr_overlay.dart';
import 'package:http/http.dart' as http;
import 'package:connectivity/connectivity.dart';
import 'package:fluttertoast/fluttertoast.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: LoginPage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  final String eventId;
  final String eventName;

  const MyHomePage({Key? key, required this.eventId, required this.eventName})
      : super(key: key);

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  MobileScannerController cameraController = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates, detectionTimeoutMs: 500);
  OverlayEntry? overlayEntry;
  late ConnectivityResult _connectionStatus;
  late Timer _connectivityTimer;
  bool isDetectionAllowed = true;

  @override
  void initState() {
    super.initState();

    // Initialize the timer to check connectivity every 5 seconds (adjust as needed)
    _connectivityTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _checkConnectivity();
    });

    // Initial connectivity check
    _checkConnectivity();
  }

  void _checkConnectivity() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    setState(() {
      _connectionStatus = connectivityResult;
    });

    if (_connectionStatus == ConnectivityResult.none) {
      // Show the error message
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
    // Cancel the timer when the widget is disposed
    _connectivityTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          color: Colors.white,
          icon: const Icon(Icons.arrow_back, color: Colors.white),
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
                color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color.fromARGB(255, 132, 56, 56),
        actions: [
          IconButton(
            color: Colors.white,
            icon: ValueListenableBuilder(
              valueListenable: cameraController.torchState,
              builder: (context, state, child) {
                switch (state) {
                  case TorchState.off:
                    return const Icon(Icons.flash_off, color: Colors.grey);
                  case TorchState.on:
                    return const Icon(Icons.flash_on, color: Colors.yellow);
                }
              },
            ),
            iconSize: 32.0,
            onPressed: () => cameraController.toggleTorch(),
          ),
          IconButton(
            color: Colors.white,
            icon: ValueListenableBuilder(
              valueListenable: cameraController.cameraFacingState,
              builder: (context, state, child) {
                switch (state) {
                  case CameraFacing.front:
                    return const Icon(Icons.camera_front);
                  case CameraFacing.back:
                    return const Icon(Icons.camera_rear);
                }
              },
            ),
            iconSize: 32.0,
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
