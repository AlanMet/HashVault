import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart' show rootBundle;

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

  /// Custom InputDecoration to avoid default purple outlines.
  InputDecoration _inputDecoration(String hint,
      {String? errorText, required double scale}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.white38, fontSize: 14 * scale),
      filled: true,
      fillColor: Colors.grey[900],
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8 * scale),
        borderSide: BorderSide(color: Colors.grey.shade700, width: 1 * scale),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8 * scale),
        borderSide: BorderSide(color: Colors.grey.shade700, width: 1 * scale),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8 * scale),
        borderSide: BorderSide(color: Colors.teal, width: 2 * scale),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8 * scale),
        borderSide: BorderSide(color: Colors.red.shade700, width: 1 * scale),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8 * scale),
        borderSide: BorderSide(color: Colors.red.shade700, width: 2 * scale),
      ),
      errorText: errorText,
    );
  }

  /// Validates the password.
  String? validatePassword(String value) {
    if (value.isEmpty) return 'Please enter a password';
    final regex =
        RegExp(r'^(?=.*?[A-Z])(?=.*?[a-z])(?=.*?[0-9])(?=.*?[!@#\$&*~]).{8,}$');
    if (!regex.hasMatch(value)) {
      return 'Password must be 8+ characters, include upper, lower, number & special char';
    }
    return null;
  }

  Future<void> _storeConfig() async {
    final passwordBytes = utf8.encode(password);
    Digest digest;
    switch (selectedHashingAlgorithm) {
      case 'SHA-256':
        digest = sha256.convert(passwordBytes);
        break;
      case 'MD5':
        digest = md5.convert(passwordBytes);
        break;
      case 'SHA-1':
        digest = sha1.convert(passwordBytes);
        break;
      default:
        digest = sha256.convert(passwordBytes);
        break;
    }
    final String hashedPassword = digest.toString();

    // Derive encryption key (AES).
    final keyBytes = digest.bytes.length == 20
        ? digest.bytes.sublist(0, 16) // For AES key size
        : digest.bytes;
    final key = encrypt.Key(Uint8List.fromList(keyBytes));
    final iv = encrypt.IV.fromSecureRandom(16); // IV for AES encryption
    final encrypter =
        encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));

    // Sensitive data (could be passwords, other sensitive config).
    const String sensitiveData =
        '[]'; // Example: a placeholder for sensitive data.

    // Encrypt the sensitive data.
    final encryptedContent = encrypter.encrypt(sensitiveData, iv: iv);

    // Binary data to store: IV and encrypted content.
    final encryptedData = Uint8List.fromList([
      ...iv.bytes, // Append IV first
      ...encryptedContent.bytes, // Append encrypted data
    ]);

    // Store the binary data into a file.
    final directory = await getApplicationDocumentsDirectory();
    final filePath = 'assets/passwords.bin'; // Binary file
    final file = File(filePath);
    await file.writeAsBytes(encryptedData);

    // Store configuration details in secure storage.
    final FlutterSecureStorage storage = FlutterSecureStorage();
    await storage.write(key: 'hashed_password', value: hashedPassword);
    await storage.write(key: 'encryption', value: selectedEncryption);
    await storage.write(key: 'hashing', value: selectedHashingAlgorithm);
    await storage.write(key: 'password_file', value: filePath);

    setState(() {
      password = '';
      confirmPassword = '';
      passwordError = null;
    });

    print('Configuration stored in secure storage and encrypted binary file.');
    widget.onConfigured(true);
  }

  /// Handles the "Next/Finish" action.
  void _handleNext() async {
    if (_currentStep < 2) {
      setState(() {
        _currentStep++;
      });
    } else if (_currentStep == 2) {
      final error = validatePassword(password);
      if (error != null) {
        setState(() {
          passwordError = error;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: Colors.red.shade700),
        );
      } else {
        setState(() {
          passwordError = null;
          _currentStep++;
        });
      }
    } else if (_currentStep == 3) {
      if (password != confirmPassword) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: const Text('Passwords do not match'),
              backgroundColor: Colors.red.shade700),
        );
      } else {
        await _storeConfig();
      }
    }
  }

  /// Handles the "Back" action.
  void _handleBack() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
    }
  }

  /// Builds the content for the current step using the provided scale factor.
  Widget _buildCurrentStepContent(double scale) {
    switch (_currentStep) {
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Select Encryption Method',
                style: TextStyle(color: Colors.white70, fontSize: 16 * scale)),
            SizedBox(height: 8 * scale),
            DropdownButtonFormField<String>(
              value: selectedEncryption,
              dropdownColor: Colors.grey[800],
              decoration: _inputDecoration('Encryption Method', scale: scale),
              style: TextStyle(color: Colors.white, fontSize: 14 * scale),
              items: encryptionMethods
                  .map((method) =>
                      DropdownMenuItem(value: method, child: Text(method)))
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    selectedEncryption = value;
                  });
                }
              },
            ),
          ],
        );
      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Select Hashing Algorithm',
                style: TextStyle(color: Colors.white70, fontSize: 16 * scale)),
            SizedBox(height: 8 * scale),
            DropdownButtonFormField<String>(
              value: selectedHashingAlgorithm,
              dropdownColor: Colors.grey[800],
              decoration: _inputDecoration('Hashing Algorithm', scale: scale),
              style: TextStyle(color: Colors.white, fontSize: 14 * scale),
              items: hashingAlgorithms
                  .map((alg) => DropdownMenuItem(value: alg, child: Text(alg)))
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    selectedHashingAlgorithm = value;
                  });
                }
              },
            ),
          ],
        );
      case 2:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Enter Password',
                style: TextStyle(color: Colors.white70, fontSize: 16 * scale)),
            SizedBox(height: 8 * scale),
            TextField(
              obscureText: true,
              style: TextStyle(color: Colors.white, fontSize: 14 * scale),
              onChanged: (value) {
                setState(() {
                  password = value;
                  passwordError = validatePassword(value);
                });
              },
              decoration: _inputDecoration('Your password',
                  errorText: passwordError, scale: scale),
            ),
          ],
        );
      case 3:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Confirm Password',
                style: TextStyle(color: Colors.white70, fontSize: 16 * scale)),
            SizedBox(height: 8 * scale),
            TextField(
              obscureText: true,
              style: TextStyle(color: Colors.white, fontSize: 14 * scale),
              onChanged: (value) {
                setState(() {
                  confirmPassword = value;
                });
              },
              decoration: _inputDecoration('Confirm password', scale: scale),
            ),
            if (confirmPassword.isNotEmpty && password != confirmPassword)
              Padding(
                padding: EdgeInsets.only(top: 8 * scale),
                child: Text('Passwords do not match.',
                    style: TextStyle(
                        color: Colors.red.shade700, fontSize: 14 * scale)),
              ),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Compute a global scale factor for desktop based on screen width.
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // Ensure the screen size does not go below 1000x1000
    final double effectiveWidth = max(screenWidth, 1000);
    final double effectiveHeight = max(screenHeight, 1000);

    final double scale = effectiveWidth / 1280; // baseline width: 1280
    // Calculate card width: 50% of screen width up to a maximum (scales with screen size).
    final double cardWidth = min(effectiveWidth * 0.5, 800 * scale);

    return Scaffold(
      // Full-screen background.
      body: Container(
        width: effectiveWidth,
        height: effectiveHeight,
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/one.gif'),
            fit: BoxFit.cover,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(24 * scale),
            child: Container(
              width: cardWidth,
              padding: EdgeInsets.all(24 * scale),
              decoration: BoxDecoration(
                color: const Color(0xFF424242).withAlpha((0.95 * 255).toInt()),
                borderRadius: BorderRadius.circular(16 * scale),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withAlpha((0.8 * 255).toInt()),
                      offset: Offset(0, 4 * scale),
                      blurRadius: 12 * scale),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Setup Your Vault',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 24 * scale,
                          fontWeight: FontWeight.bold)),
                  SizedBox(height: 8 * scale),
                  Text('Step ${_currentStep + 1} of 4',
                      style: TextStyle(
                          color: Colors.white70, fontSize: 16 * scale)),
                  SizedBox(height: 24 * scale),
                  _buildCurrentStepContent(scale),
                  SizedBox(height: 24 * scale),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (_currentStep > 0)
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white70,
                            side: BorderSide(
                                color: Colors.white24, width: 1 * scale),
                          ),
                          onPressed: _handleBack,
                          child: Text('Back',
                              style: TextStyle(fontSize: 14 * scale)),
                        ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _handleNext,
                        child: Text(_currentStep == 3 ? 'Finish' : 'Next',
                            style: TextStyle(fontSize: 14 * scale)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
