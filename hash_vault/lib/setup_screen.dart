import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SetupScreen extends StatefulWidget {
  final void Function(bool) onConfigured;

  const SetupScreen({super.key, required this.onConfigured});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  int _currentStep = 0;

  // Variables to hold user input for encryption, hashing, and password
  String? selectedEncryption = 'AES'; // Default encryption method
  String? selectedHashingAlgorithm = 'SHA-256'; // Default hashing algorithm
  String password = '';
  String confirmPassword = '';
  String? passwordError;

  // List of options for encryption and hashing methods
  final List<String> encryptionMethods = ['AES', 'RSA', 'DES'];
  final List<String> hashingAlgorithms = ['SHA-256', 'MD5', 'SHA-1'];

  // Password validation regex function
  String? validatePassword(String value) {
    RegExp regex =
        RegExp(r'^(?=.*?[A-Z])(?=.*?[a-z])(?=.*?[0-9])(?=.*?[!@#\$&*~]).{8,}$');
    if (value.isEmpty) {
      return 'Please enter a password';
    } else {
      if (!regex.hasMatch(value)) {
        return 'Password must be at least 8 characters, with an uppercase letter, a lowercase letter, a number, and a special character';
      } else {
        return null;
      }
    }
  }

  List<Step> getSteps() {
    return [
      Step(
        title: const Text("Encryption Method"),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButton<String>(
              value: selectedEncryption,
              items: encryptionMethods.map((String method) {
                return DropdownMenuItem<String>(
                  value: method,
                  child: Text(method),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedEncryption = value;
                });
              },
            ),
          ],
        ),
        isActive: _currentStep >= 0,
      ),
      Step(
        title: const Text("Hashing Algorithm"),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButton<String>(
              value: selectedHashingAlgorithm,
              items: hashingAlgorithms.map((String algorithm) {
                return DropdownMenuItem<String>(
                  value: algorithm,
                  child: Text(algorithm),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedHashingAlgorithm = value;
                });
              },
            ),
          ],
        ),
        isActive: _currentStep >= 1,
      ),
      Step(
        title: const Text("Password"),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              obscureText: true,
              onChanged: (value) {
                setState(() {
                  password = value;
                  passwordError =
                      validatePassword(value); // Validate password on change
                });
              },
              decoration: InputDecoration(
                labelText: "Enter your password",
                errorText: passwordError,
              ),
            ),
          ],
        ),
        isActive: _currentStep >= 2,
      ),
      Step(
        title: const Text("Confirm Password"),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              obscureText: true,
              onChanged: (value) {
                setState(() {
                  confirmPassword = value;
                });
              },
              decoration:
                  const InputDecoration(labelText: "Confirm your password"),
            ),
            if (password.isNotEmpty &&
                confirmPassword.isNotEmpty &&
                password != confirmPassword)
              const Padding(
                padding: EdgeInsets.only(top: 8.0),
                child: Text(
                  "Passwords do not match.",
                  style: TextStyle(color: Colors.red),
                ),
              ),
          ],
        ),
        isActive: _currentStep >= 3,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Setup Screen")),
      body: Stepper(
        currentStep: _currentStep,
        onStepTapped: (step) {
          setState(() {
            _currentStep = step;
          });
        },
        onStepContinue: () {
          if (_currentStep == 2) {
            // Validate password only when the user is on step 2 (Password step)
            setState(() {
              passwordError =
                  validatePassword(password); // Re-validate password
            });

            if (passwordError == null) {
              setState(() {
                _currentStep++;
              });
            } else {
              // Show a snack bar with the error
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Invalid password')),
              );
            }
          } else if (_currentStep == 3) {
            // Only proceed to step 4 if passwords match
            if (password == confirmPassword) {
              setState(() {
                _currentStep++;
              });
            } else {
              // Show a snack bar with the error
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Passwords do not match')),
              );
            }
          } else if (_currentStep == getSteps().length - 1) {
            // At the last step, don't increment _currentStep anymore
            widget.onConfigured(true); // Call the callback to notify completion
          } else {
            // Proceed to the next step if we're not on the password steps
            if (_currentStep < getSteps().length - 1) {
              setState(() {
                _currentStep++;
              });
            }
          }
        },
        onStepCancel: () {
          if (_currentStep > 0) {
            setState(() {
              _currentStep--;
            });
          }
        },
        steps: getSteps(),
      ),
    );
  }
}
