import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

import 'helper.dart'; // Assumes pbkdf2() is defined here.

class SetupScreen extends StatefulWidget {
  final void Function(bool) onConfigured;

  const SetupScreen({Key? key, required this.onConfigured}) : super(key: key);

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  int _currentStep = 0;

  // Configuration values.
  String selectedEncryption = 'AES';
  String selectedHashingAlgorithm = 'SHA-256';
  String password = '';
  String confirmPassword = '';
  String? passwordError;

  // Text controllers for password fields.
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  // Booleans to toggle password visibility.
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  // Options for dropdowns.
  final List<String> encryptionMethods = ['AES', 'RSA', 'DES'];
  final List<String> hashingAlgorithms = ['SHA-256', 'MD5', 'SHA-1'];

  /// Custom InputDecoration.
  InputDecoration _inputDecoration(String hint,
      {String? errorText, required double scale, Widget? suffixIcon}) {
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
      suffixIcon: suffixIcon,
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

  /// Stores the vault configuration.
  Future<void> _storeConfig() async {
    final random = Random.secure();

    // --- 1. Generate a random seed for encrypting the hashed password ---
    final seed = Uint8List(32); // 32 bytes for AES-256.
    for (int i = 0; i < seed.length; i++) {
      seed[i] = random.nextInt(256);
    }

    // --- 2. Compute the hash of the master password ---
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

    // --- 3. Encrypt the hashed password using a key derived from the random seed ---
    final seedKey = encrypt.Key(seed); // Use seed directly as AES key.
    final ivKey = encrypt.IV.fromSecureRandom(16);
    final encrypterKey = encrypt.Encrypter(
        encrypt.AES(seedKey, mode: encrypt.AESMode.cbc, padding: 'PKCS7'));
    final encryptedHash = encrypterKey.encrypt(hashedPassword, iv: ivKey);
    // Create the key file content: [IV (16 bytes)] + [encrypted hash].
    final Uint8List keyFileData =
        Uint8List.fromList([...ivKey.bytes, ...encryptedHash.bytes]);

    // --- 4. Prepare the vault data file (password data) ---
    // Generate a random salt for vault data encryption.
    final vaultSalt = Uint8List(16);
    for (int i = 0; i < vaultSalt.length; i++) {
      vaultSalt[i] = random.nextInt(256);
    }
    const int iterations = 10000;
    const int keyLength = 32; // For AES-256.
    final vaultKeyBytes = pbkdf2(password, vaultSalt, iterations, keyLength);
    final vaultKey = encrypt.Key(vaultKeyBytes);
    // The vault data (initially empty, e.g. an empty array).
    final vaultContent = {"data": []};
    final vaultJson = json.encode(vaultContent);
    final ivVault = encrypt.IV.fromSecureRandom(16);
    final encrypterVault = encrypt.Encrypter(
        encrypt.AES(vaultKey, mode: encrypt.AESMode.cbc, padding: 'PKCS7'));
    final encryptedVault = encrypterVault.encrypt(vaultJson, iv: ivVault);
    // Create the vault file content: [salt (16 bytes)] + [IV (16 bytes)] + [encrypted vault data].
    final Uint8List vaultFileData = Uint8List.fromList(
        [...vaultSalt, ...ivVault.bytes, ...encryptedVault.bytes]);

    // --- 5. Save files and configuration ---
    // (For testing purposes, we're saving to assets folder; adjust paths as needed.)
    final keyFilePath = 'assets/key.bin';
    final vaultFilePath = 'assets/vault.bin';

    final keyFile = File(keyFilePath);
    await keyFile.writeAsBytes(keyFileData);

    final vaultFile = File(vaultFilePath);
    await vaultFile.writeAsBytes(vaultFileData);

    // Store configuration details (and the seed) in secure storage.
    final FlutterSecureStorage storage = FlutterSecureStorage();
    await storage.write(key: 'hashing', value: selectedHashingAlgorithm);
    await storage.write(key: 'key_file', value: keyFilePath);
    await storage.write(key: 'vault_file', value: vaultFilePath);
    // Encode the seed in Base64 for storage.
    await storage.write(key: 'seed', value: base64.encode(seed));

    setState(() {
      password = '';
      confirmPassword = '';
      _passwordController.clear();
      _confirmPasswordController.clear();
      passwordError = null;
    });

    print('Key file stored at $keyFilePath');
    print('Vault file stored at $vaultFilePath');
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
          // Clear the confirm field when moving to confirm step.
          _confirmPasswordController.clear();
          confirmPassword = '';
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

  /// Builds the content for the current step.
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
              controller: _passwordController,
              obscureText: _obscurePassword,
              style: TextStyle(color: Colors.white, fontSize: 14 * scale),
              onChanged: (value) {
                setState(() {
                  password = value;
                  passwordError = validatePassword(value);
                  // Clear confirm field when password changes.
                  _confirmPasswordController.clear();
                  confirmPassword = '';
                });
              },
              decoration: _inputDecoration(
                'Your password',
                errorText: passwordError,
                scale: scale,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                    color: Colors.white38,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
              ),
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
              controller: _confirmPasswordController,
              obscureText: _obscureConfirmPassword,
              style: TextStyle(color: Colors.white, fontSize: 14 * scale),
              onChanged: (value) {
                setState(() {
                  confirmPassword = value;
                });
              },
              decoration: _inputDecoration(
                'Confirm password',
                scale: scale,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirmPassword
                        ? Icons.visibility_off
                        : Icons.visibility,
                    color: Colors.white38,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscureConfirmPassword = !_obscureConfirmPassword;
                    });
                  },
                ),
              ),
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
  void dispose() {
    // Dispose controllers.
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Enforce a minimum screen size and adjust scale for larger screens.
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final double effectiveWidth = max(screenWidth, 1000);
    final double effectiveHeight = max(screenHeight, 1000);
    double scale = effectiveWidth / 1280;
    if (effectiveWidth > 1600) {
      scale = effectiveWidth /
          1600; // reduce text size slightly on very large screens.
    }
    final double cardWidth = min(effectiveWidth * 0.5, 800 * scale);

    return Scaffold(
      body: Container(
        width: effectiveWidth,
        height: effectiveHeight,
        color: const Color(0xFF424242),
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(24 * scale),
            child: Container(
              width: cardWidth,
              padding: EdgeInsets.all(24 * scale),
              decoration: BoxDecoration(
                color: const Color(0xFF424242).withOpacity(0.95),
                borderRadius: BorderRadius.circular(16 * scale),
                boxShadow: [
                  BoxShadow(
                    color: const Color.fromARGB(255, 139, 139, 139),
                    offset: Offset(-5 * scale, -5 * scale),
                    blurRadius: 9 * scale,
                  ),
                  BoxShadow(
                    color: const Color.fromARGB(255, 49, 49, 49),
                    offset: Offset(5 * scale, 5 * scale),
                    blurRadius: 9 * scale,
                  ),
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
                          minimumSize: Size(100 * scale, 40 * scale),
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
