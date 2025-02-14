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
import 'vault_screen.dart'; // Import the VaultScreen class.

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String password = '';
  String? passwordError;
  bool _isLoading = false;

  final FlutterSecureStorage _storage = FlutterSecureStorage();

  /// Validates the entered password.
  String? validatePassword(String value) {
    if (value.isEmpty) return 'Please enter a password';
    return null;
  }

  /// Handles the login action.
  Future<void> _handleLogin() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
    });

    final error = validatePassword(password);
    if (error != null) {
      setState(() {
        passwordError = error;
        _isLoading = false;
      });
      return;
    }

    // Retrieve configuration details.
    final keyFilePath = await _storage.read(key: 'key_file');
    final vaultFilePath = await _storage.read(key: 'vault_file');
    final selectedHashingAlgorithm = await _storage.read(key: 'hashing');
    final seedStr = await _storage.read(key: 'seed');

    if (keyFilePath == null ||
        vaultFilePath == null ||
        selectedHashingAlgorithm == null ||
        seedStr == null) {
      setState(() {
        passwordError =
            'Configuration not found. Please set up the vault first.';
        _isLoading = false;
      });
      return;
    }

    // --- 1. Decrypt key.bin to verify the master password ---
    final keyFile = File(keyFilePath);
    if (!await keyFile.exists()) {
      setState(() {
        passwordError = 'Key file not found.';
        _isLoading = false;
      });
      return;
    }
    final keyFileBytes = await keyFile.readAsBytes();
    if (keyFileBytes.length < 16) {
      setState(() {
        passwordError = 'Key file is corrupted.';
        _isLoading = false;
      });
      return;
    }
    // Extract IV (first 16 bytes) and encrypted hash.
    final ivKey = encrypt.IV(keyFileBytes.sublist(0, 16));
    final encryptedHashBytes = keyFileBytes.sublist(16);

    // Retrieve the seed (generated at setup) from secure storage.
    final seed = base64.decode(seedStr);
    final seedKey = encrypt.Key(seed);
    final encrypterKey = encrypt.Encrypter(
        encrypt.AES(seedKey, mode: encrypt.AESMode.cbc, padding: 'PKCS7'));

    String storedHash;
    try {
      storedHash = encrypterKey
          .decrypt(encrypt.Encrypted(encryptedHashBytes), iv: ivKey)
          .trim();
    } catch (e) {
      setState(() {
        passwordError = 'Failed to decrypt key file.';
        _isLoading = false;
      });
      return;
    }

    // Compute the hash of the entered master password.
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
    final computedHash = digest.toString();

    // Compare stored hash with computed hash.
    if (storedHash != computedHash) {
      setState(() {
        passwordError = 'Incorrect password. Please try again.';
        _isLoading = false;
      });
      return;
    }

    // --- 2. Decrypt the vault.bin file ---
    final vaultFile = File(vaultFilePath);
    if (!await vaultFile.exists()) {
      setState(() {
        passwordError = 'Vault file not found.';
        _isLoading = false;
      });
      return;
    }
    final vaultBytes = await vaultFile.readAsBytes();
    if (vaultBytes.length < 32) {
      setState(() {
        passwordError = 'Vault file is corrupted.';
        _isLoading = false;
      });
      return;
    }
    // Extract salt (first 16 bytes), IV (next 16 bytes), and encrypted vault data.
    final vaultSalt = vaultBytes.sublist(0, 16);
    final ivVault = encrypt.IV(vaultBytes.sublist(16, 32));
    final encryptedVaultData = vaultBytes.sublist(32);

    const int iterations = 10000;
    const int keyLength = 32;
    final vaultKeyBytes = pbkdf2(password, vaultSalt, iterations, keyLength);
    final vaultKey = encrypt.Key(vaultKeyBytes);
    final encrypterVault = encrypt.Encrypter(
        encrypt.AES(vaultKey, mode: encrypt.AESMode.cbc, padding: 'PKCS7'));

    String vaultJson;
    try {
      vaultJson = encrypterVault
          .decrypt(encrypt.Encrypted(encryptedVaultData), iv: ivVault)
          .trim();
    } catch (e) {
      setState(() {
        passwordError = 'Failed to decrypt vault data.';
        _isLoading = false;
      });
      return;
    }

    dynamic vaultData;
    try {
      vaultData = json.decode(vaultJson);
    } catch (e) {
      setState(() {
        passwordError = 'Failed to parse vault data.';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = false;
    });
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Login successful!')));
    // Print the decrypted password data to the console.
    // print("Decrypted vault data: ${vaultData['data']}");
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => VaultScreen(
          entries: vaultData['data'] as List<dynamic>,
          masterPassword: password,
          vaultFilePath: vaultFilePath,
          vaultSalt: vaultSalt,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Enforce minimum screen size and adjust scale for larger screens.
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final double effectiveWidth = max(screenWidth, 1000);
    final double effectiveHeight = max(screenHeight, 1000);
    double scale = effectiveWidth / 1280;
    if (effectiveWidth > 1600) {
      scale = effectiveWidth / 1600;
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          image: const DecorationImage(
            image: AssetImage('assets/one.gif'),
            fit: BoxFit.cover,
          ),
        ),
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(16 * scale),
            child: Card(
              color: const Color(0xFF424242).withOpacity(0.95),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16 * scale),
              ),
              elevation: 8.0,
              child: Padding(
                padding: EdgeInsets.all(24 * scale),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Login to Your Vault',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24 * scale,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 16 * scale),
                    TextField(
                      obscureText: true,
                      onChanged: (value) {
                        setState(() {
                          password = value;
                          passwordError = null;
                        });
                      },
                      style:
                          TextStyle(color: Colors.white, fontSize: 14 * scale),
                      decoration: InputDecoration(
                        hintText: 'Enter Password',
                        errorText: passwordError,
                        filled: true,
                        fillColor: Colors.grey[900],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8 * scale),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8 * scale),
                          borderSide:
                              BorderSide(color: Colors.teal, width: 2 * scale),
                        ),
                      ),
                    ),
                    SizedBox(height: 16 * scale),
                    _isLoading
                        ? CircularProgressIndicator(color: Colors.teal)
                        : ElevatedButton(
                            onPressed: _handleLogin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal,
                              minimumSize: Size(100 * scale, 40 * scale),
                            ),
                            child: Text('Login',
                                style: TextStyle(fontSize: 14 * scale)),
                          ),
                    SizedBox(height: 16 * scale),
                    if (passwordError != null)
                      Text(
                        passwordError!,
                        style:
                            TextStyle(color: Colors.red, fontSize: 14 * scale),
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
