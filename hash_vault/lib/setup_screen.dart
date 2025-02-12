import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SetupScreen extends StatefulWidget {
  final Function onSetupComplete; // Define the callback function

  const SetupScreen({super.key, required this.onSetupComplete});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  int _currentStep = 0; // Move _currentStep here to persist its value
  TextEditingController _masterPasswordController = TextEditingController();
  TextEditingController _confirmPasswordController = TextEditingController();
  String? _selectedEncryptionMethod;

  final FlutterSecureStorage _storage = FlutterSecureStorage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Setup Your Password Manager')),
      body: Stepper(
        currentStep: _currentStep,
        onStepContinue: () {
          setState(() {
            if (_currentStep < 4) {
              _currentStep++;
            } else {
              widget.onSetupComplete(); // Mark as configured
              Navigator.pop(context); // Go back to the main screen
            }
          });
        },
        onStepCancel: () {
          setState(() {
            if (_currentStep > 0) {
              _currentStep--;
            }
          });
        },
        steps: [
          Step(
            title: const Text('Welcome'),
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('Welcome to the Password Manager setup wizard!'),
                Text('Please follow the steps to configure your app.'),
              ],
            ),
            isActive: _currentStep >= 0,
            state: _currentStep == 0 ? StepState.editing : StepState.complete,
          ),
          Step(
            title: const Text('Encryption Method'),
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Choose your encryption method:'),
                DropdownButton<String>(
                  value: _selectedEncryptionMethod,
                  items: const <String>['AES-256', 'RSA-2048']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedEncryptionMethod = value;
                    });
                  },
                  hint: const Text('Select Encryption Method'),
                ),
              ],
            ),
            isActive: _currentStep >= 1,
            state: _currentStep == 1 ? StepState.editing : StepState.complete,
          ),
          Step(
            title: const Text('Set Master Password'),
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _masterPasswordController,
                  obscureText: true,
                  decoration:
                      const InputDecoration(labelText: "Master Password"),
                ),
              ],
            ),
            isActive: _currentStep >= 2,
            state: _currentStep == 2 ? StepState.editing : StepState.complete,
          ),
          Step(
            title: const Text('Confirm Password'),
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _confirmPasswordController,
                  obscureText: true,
                  decoration:
                      const InputDecoration(labelText: "Confirm Password"),
                ),
              ],
            ),
            isActive: _currentStep >= 3,
            state: _currentStep == 3 ? StepState.editing : StepState.complete,
          ),
          Step(
            title: const Text('Backup Encryption'),
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Would you like to set a backup encryption method?'),
                SwitchListTile(
                  title: const Text('Enable Backup Encryption'),
                  value: false,
                  onChanged: (value) {
                    // Handle backup encryption logic
                  },
                ),
              ],
            ),
            isActive: _currentStep >= 4,
            state: _currentStep == 4 ? StepState.editing : StepState.complete,
          ),
        ],
      ),
    );
  }
}
