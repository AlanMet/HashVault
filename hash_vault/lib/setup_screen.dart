import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SetupScreen extends StatefulWidget {
  final void Function(bool) onConfigured;

  const SetupScreen({Key? key, required this.onConfigured}) : super(key: key);

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  int _currentStep = 0;

  // Configuration values
  String selectedEncryption = 'AES';
  String selectedHashingAlgorithm = 'SHA-256';
  String password = '';
  String confirmPassword = '';
  String? passwordError;

  // Options for dropdowns
  final List<String> encryptionMethods = ['AES', 'RSA', 'DES'];
  final List<String> hashingAlgorithms = ['SHA-256', 'MD5', 'SHA-1'];

  /// Validates the password using a regular expression.
  /// Returns an error message if the password is invalid, otherwise null.
  String? validatePassword(String value) {
    if (value.isEmpty) {
      return 'Please enter a password';
    }

    // The password must be at least 8 characters long and include:
    // an uppercase letter, a lowercase letter, a number, and a special character.
    final regex =
        RegExp(r'^(?=.*?[A-Z])(?=.*?[a-z])(?=.*?[0-9])(?=.*?[!@#\$&*~]).{8,}$');
    if (!regex.hasMatch(value)) {
      return 'Password must be at least 8 characters long and include an uppercase letter, a lowercase letter, a number, and a special character';
    }
    return null;
  }

  /// Stores the configuration values securely.
  Future<void> _storeConfig() async {
    final storage = FlutterSecureStorage();
    print('Storing configuration...');
    await storage.write(key: 'encryption', value: selectedEncryption);
    await storage.write(key: 'hashing', value: selectedHashingAlgorithm);
    // Note: In a real-world application, consider hashing the password before storage.
    await storage.write(key: 'password', value: password);
  }

  /// Returns the list of steps for the Stepper widget.
  List<Step> get _steps => [
        Step(
          title: const Text('Encryption Method'),
          content: DropdownButton<String>(
            value: selectedEncryption,
            items: encryptionMethods
                .map(
                  (method) => DropdownMenuItem(
                    value: method,
                    child: Text(method),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  selectedEncryption = value;
                });
              }
            },
          ),
          isActive: _currentStep >= 0,
        ),
        Step(
          title: const Text('Hashing Algorithm'),
          content: DropdownButton<String>(
            value: selectedHashingAlgorithm,
            items: hashingAlgorithms
                .map(
                  (algorithm) => DropdownMenuItem(
                    value: algorithm,
                    child: Text(algorithm),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  selectedHashingAlgorithm = value;
                });
              }
            },
          ),
          isActive: _currentStep >= 1,
        ),
        Step(
          title: const Text('Password'),
          content: TextField(
            obscureText: true,
            onChanged: (value) {
              setState(() {
                password = value;
                // Validate the password as the user types.
                passwordError = validatePassword(value);
              });
            },
            decoration: InputDecoration(
              labelText: 'Enter your password',
              errorText: passwordError,
            ),
          ),
          isActive: _currentStep >= 2,
        ),
        Step(
          title: const Text('Confirm Password'),
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
                decoration: const InputDecoration(
                  labelText: 'Confirm your password',
                ),
              ),
              // Show an inline error if the passwords do not match.
              if (confirmPassword.isNotEmpty && password != confirmPassword)
                const Padding(
                  padding: EdgeInsets.only(top: 8.0),
                  child: Text(
                    'Passwords do not match.',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
            ],
          ),
          isActive: _currentStep >= 3,
        ),
      ];

  /// Handles the logic when the "Continue" button is pressed.
  Future<void> _onStepContinue() async {
    switch (_currentStep) {
      // For steps 0 (Encryption) and 1 (Hashing), simply go to the next step.
      case 0:
      case 1:
        setState(() {
          _currentStep++;
        });
        break;
      // Step 2: Validate the password.
      case 2:
        final error = validatePassword(password);
        setState(() {
          passwordError = error;
        });
        if (error != null) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(error)));
        } else {
          setState(() {
            _currentStep++;
          });
        }
        break;
      // Final step: Confirm the password and store the configuration.
      case 3:
        if (password != confirmPassword) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Passwords do not match')),
          );
        } else {
          await _storeConfig();
          // Notify the parent widget that configuration is complete.
          widget.onConfigured(true);
        }
        break;
      default:
        break;
    }
  }

  /// Handles the logic when the "Cancel" button is pressed.
  void _onStepCancel() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Setup Screen')),
      body: Stepper(
        currentStep: _currentStep,
        steps: _steps,
        onStepTapped: (step) => setState(() => _currentStep = step),
        onStepContinue: _onStepContinue,
        onStepCancel: _onStepCancel,
      ),
    );
  }
}
