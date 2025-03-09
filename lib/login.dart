import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:qr_code_scanner/scanner.dart';

class LoginPage extends StatefulWidget {
  final String? currentEventId;
  const LoginPage({Key? key, this.currentEventId}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  TextEditingController eventIdController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.currentEventId != null) {
      eventIdController.text = widget.currentEventId!;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('Login Entrance Scanner'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final double width = constraints.maxWidth;
          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 30.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo
                  CircleAvatar(
                    radius: width * 0.20,
                    backgroundImage: const AssetImage('assets/logo.png'),
                  ),
                  const SizedBox(height: 30),

                  // Titel
                  const Text(
                    'Enter Your Event Code:',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),

                  // EventID Input
                  TextField(
                    controller: eventIdController,
                    decoration: InputDecoration(
                      labelText: 'EventID',
                      hintText: 'Enter EventID',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      prefixIcon: const Icon(Icons.event_available_outlined),
                    ),
                    textAlign: TextAlign.left,
                  ),
                  const SizedBox(height: 30),

                  // Login-knop
                  ElevatedButton.icon(
                    onPressed: () {
                      if (eventIdController.text.isNotEmpty) {
                        _showLoadingDialog();
                        verification(eventIdController.text).then((String? eventOmschrijving) {
                          Navigator.of(context).pop(); // Sluit de loading-popup

                          if (eventOmschrijving != null) {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ScannerPage(
                                  eventId: eventIdController.text,
                                  eventName: eventOmschrijving.trim(),
                                ),
                              ),
                            );
                          } else {
                            _showErrorMessage("Enter a valid EventID or try to connect to WiFi.");
                          }
                        });
                      } else {
                        _showErrorMessage("Please enter an EventID.");
                      }
                    },
                    icon: const Icon(Icons.login),
                    label: const Text('Login'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 30),
                      textStyle: const TextStyle(fontSize: 18),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<String?> verification(String eventCode) async {
    const url = 'https://scanninghappening.azurewebsites.net/api/event';
    final uri = Uri.parse(url);

    try {
      var response = await http.post(
        uri,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"eventId": eventCode}),
      );

      debugPrint(response.body);
      debugPrint(response.statusCode.toString());

      if (response.statusCode == 200) {
        Map<String, dynamic> jsonData = jsonDecode(response.body);
        if (jsonData.containsKey('eventOmschrijving')) {
          return jsonData['eventOmschrijving'];
        }
      }
      return null;
    } catch (error) {
      debugPrint('Error during API call: $error');
      return null;
    }
  }

  void _showErrorMessage(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF062029),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              const Icon(Icons.error, color: Colors.red, size: 40),
              const SizedBox(height: 10),
              Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text("OK"),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // Voorkomt dat de gebruiker het sluit
      builder: (BuildContext context) {
        return const AlertDialog(
          backgroundColor: Color(0xFF062029),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: 10),
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 10),
              Text(
                "Logging in...",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }
}
