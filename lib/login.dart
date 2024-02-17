import 'dart:convert';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:qr_code_scanner/main.dart';

class LoginPage extends StatefulWidget {
  final String? currentEventId; // Non-required parameter
  const LoginPage({Key? key, this.currentEventId}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  TextEditingController eventIdController = TextEditingController();
  bool isLoading = false;

  @override
  void initState() {
    super.initState();

    // Prefill the controller if currentEventId is not null
    if (widget.currentEventId != null) {
      eventIdController.text = widget.currentEventId!;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get the screen width
    double screenWidth = MediaQuery.of(context).size.width;

    // Calculate the desired image height to fill 2/3 of the width
    double desiredWidth = (2 / 3) * screenWidth;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Image.asset(
              'assets/logo_full_background.png', // Replace with the actual path to your logo
              width: desiredWidth, // Adjust the height as needed
            ),
            const SizedBox(height: 20),
            const Text(
              'Login Scanner',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Event Code:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: 200, // Adjust the width as needed
              child: TextField(
                controller: eventIdController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () {
                      // Check if the text field is not empty
                      if (eventIdController.text.isNotEmpty) {
                        // Set isLoading to true before starting the API call
                        setState(() {
                          isLoading = true;
                        });

                        // Call the verification function
                        verification(eventIdController.text)
                            .then((String? eventOmschrijving) {
                          if (eventOmschrijving != null) {
                            // If the verification is successful, navigate to the main page
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => MyHomePage(
                                  eventId: eventIdController.text,
                                  eventName: eventOmschrijving.trim(),
                                ),
                              ),
                            );
                          } else {
                            setState(() {
                              isLoading = false;
                            });
                            _showErrorMessageAPI();
                          }
                        });
                      } else {
                        _showErrorMessageText();
                      }
                    },
              child: isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Login'),
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> verification(String eventCode) async {
    const url = 'https://scanninghappening.azurewebsites.net/api/event';
    final uri = Uri.parse(url);

    try {
      // Make the HTTP POST request
      var response = await http.post(
        uri,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"eventId": eventCode}),
      );

      debugPrint(response.body);
      debugPrint(response.statusCode.toString());

      // Check if the response has a successful status code (2xx)
      if (response.statusCode == 200) {
        // Parse the JSON string
        Map<String, dynamic> jsonData = jsonDecode(response.body);

        // Check if the response body contains the expected data
        if (response.body.contains('eventOmschrijving')) {
          // Retrieve and return the eventOmschrijving
          String eventOmschrijving = jsonData['eventOmschrijving'];
          return eventOmschrijving;
        } else {
          // If the response does not contain the expected data, return null
          return null;
        }
      } else {
        // If the API call is not successful, return null
        return null;
      }
    } catch (error) {
      // Handle any errors that occur during the API call
      debugPrint('Error during API call: $error');
      return null;
    }
  }

  void _showErrorMessageAPI() {
    Fluttertoast.showToast(
      msg: "Enter a valid EventID or try to connect to wifi.",
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.CENTER,
      timeInSecForIosWeb: 2,
      backgroundColor: Colors.red,
      textColor: Colors.white,
      fontSize: 16.0,
    );
  }

  void _showErrorMessageText() {
    Fluttertoast.showToast(
      msg: "Please enter an eventID.",
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 2,
      backgroundColor: Colors.red,
      textColor: Colors.white,
      fontSize: 16.0,
    );
  }
}
