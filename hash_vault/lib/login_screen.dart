import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:encrypt/encrypt.dart' as encrypt;

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String password = '';
  String? passwordError;
  String? storedEncryptedPassword;
  String? selectedEncryption;
  String? selectedHashingAlgorithm;
  bool _isLoading = false;

  final FlutterSecureStorage _storage = FlutterSecureStorage();

  // Add your decryption key (this should be securely managed)
  final String _decryptionKey = 'your_secure_key_here';

  /// Validates the entered password.
  String? validatePassword(String value) {
    if (value.isEmpty) return 'Please enter a password';
    return null;
  }

  /// Decrypts the stored password using AES decryption.
  String _decryptPassword(String encryptedPassword) {
    final key =
        encrypt.Key.fromUtf8(_decryptionKey.padRight(32, ' ')); // 32-byte key
    final iv = encrypt.IV.fromLength(16); // 16-byte IV
    final encrypter = encrypt.Encrypter(encrypt.AES(key));

    // Perform decryption
    final decrypted = encrypter.decrypt64(encryptedPassword, iv: iv);
    return decrypted;
  }

  /// Handles login action.
  Future<void> _handleLogin() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
    });

    // Validate password.
    final error = validatePassword(password);
    if (error != null) {
      setState(() {
        passwordError = error;
      });
      setState(() {
        _isLoading = false;
      });
      return;
    }

    // Retrieve the encrypted password from secure storage.
    storedEncryptedPassword = await _storage.read(key: 'encrypted_password');
    selectedEncryption = await _storage.read(key: 'encryption');
    selectedHashingAlgorithm = await _storage.read(key: 'hashing');

    if (storedEncryptedPassword == null ||
        selectedEncryption == null ||
        selectedHashingAlgorithm == null) {
      setState(() {
        passwordError =
            'Configuration not found. Please set up the vault first.';
      });
      setState(() {
        _isLoading = false;
      });
      return;
    }

    // Decrypt the stored password
    String decryptedPassword = _decryptPassword(storedEncryptedPassword!);

    // Hash the entered password
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

    // Check if the entered password hash matches the decrypted stored password
    if (hashedPassword == decryptedPassword) {
      setState(() {
        _isLoading = false;
      });
      // Proceed to next screen after successful login.
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Login successful!')));
      // Navigate to the next screen
    } else {
      setState(() {
        passwordError = 'Incorrect password. Please try again.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(
                'assets/one.gif'), // Your GIF file should be in the assets folder
            fit: BoxFit.cover,
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              color: const Color(0xFF424242).withAlpha((0.95 * 255).toInt()),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.0),
              ),
              elevation: 8.0,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Login to Your Vault',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      obscureText: true,
                      onChanged: (value) {
                        setState(() {
                          password = value;
                          passwordError = null;
                        });
                      },
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Enter Password',
                        errorText: passwordError,
                        filled: true,
                        fillColor: Colors.grey[900],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                          borderSide:
                              const BorderSide(color: Colors.teal, width: 2.0),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _isLoading
                        ? const CircularProgressIndicator(color: Colors.teal)
                        : ElevatedButton(
                            onPressed: _handleLogin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal,
                            ),
                            child: const Text('Login'),
                          ),
                    const SizedBox(height: 16),
                    if (passwordError != null)
                      Text(
                        passwordError!,
                        style: const TextStyle(color: Colors.red, fontSize: 14),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
