import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // for Clipboard
import 'package:url_launcher/url_launcher.dart';

import 'helper.dart'; // Assumes pbkdf2() is defined here.

/// Model class for a password entry.
class PasswordEntry {
  final String website;
  final String username;
  final String password;
  final DateTime lastChanged;

  PasswordEntry({
    required this.website,
    required this.username,
    required this.password,
    required this.lastChanged,
  });

  factory PasswordEntry.fromJson(Map<String, dynamic> json) {
    return PasswordEntry(
      website: json['website'] ?? '',
      username: json['username'] ?? '',
      password: json['password'] ?? '',
      lastChanged:
          DateTime.tryParse(json['lastChanged'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'website': website,
      'username': username,
      'password': password,
      'lastChanged': lastChanged.toIso8601String(),
    };
  }
}

/// The main vault screen showing the list of password entries.
/// Note: masterPassword, vaultFilePath, and vaultSalt are passed from LoginScreen.
class VaultScreen extends StatefulWidget {
  final List<dynamic> entries;
  final String masterPassword;
  final String vaultFilePath;
  final Uint8List vaultSalt; // extracted from vault.bin

  const VaultScreen({
    super.key,
    required this.entries,
    required this.masterPassword,
    required this.vaultFilePath,
    required this.vaultSalt,
  });

  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen> {
  final TextEditingController _searchController = TextEditingController();
  late List<PasswordEntry> _allEntries;
  late List<PasswordEntry> _filteredEntries;

  @override
  void initState() {
    super.initState();
    // Convert incoming JSON objects to PasswordEntry models.
    _allEntries = widget.entries
        .map((e) => PasswordEntry.fromJson(e as Map<String, dynamic>))
        .toList();
    _filteredEntries = List.from(_allEntries);
    _searchController.addListener(_filterEntries);
  }

  void _filterEntries() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredEntries = List.from(_allEntries);
      } else {
        _filteredEntries = _allEntries.where((entry) {
          return entry.website.toLowerCase().contains(query) ||
              entry.username.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Returns a color based on how long ago the password was changed.
  Color _getEntryColor(DateTime lastChanged) {
    final daysSince = DateTime.now().difference(lastChanged).inDays;
    if (daysSince > 180) {
      return Colors.redAccent;
    } else if (daysSince > 90) {
      return Colors.orangeAccent;
    } else {
      return Colors.green;
    }
  }

  /// Saves (re-encrypts) the current vault data to vault.bin.
  Future<void> _saveVault() async {
    const int iterations = 10000;
    const int keyLength = 32;
    // Derive vault key using the master password and the original salt.
    final vaultKeyBytes =
        pbkdf2(widget.masterPassword, widget.vaultSalt, iterations, keyLength);
    final vaultKey = encrypt.Key(vaultKeyBytes);

    final vaultContent = {
      'data': _allEntries.map((e) => e.toJson()).toList(),
    };
    final vaultJson = json.encode(vaultContent);
    final ivVault = encrypt.IV.fromSecureRandom(16);
    final encrypterVault = encrypt.Encrypter(
      encrypt.AES(vaultKey, mode: encrypt.AESMode.cbc, padding: 'PKCS7'),
    );
    final encryptedVault = encrypterVault.encrypt(vaultJson, iv: ivVault);

    // Create new vault file content: [salt (16 bytes)] + [new IV (16 bytes)] + [encrypted vault data].
    final Uint8List vaultFileData = Uint8List.fromList([
      ...widget.vaultSalt,
      ...ivVault.bytes,
      ...encryptedVault.bytes,
    ]);
    final vaultFile = File(widget.vaultFilePath);
    await vaultFile.writeAsBytes(vaultFileData);
    print("Vault file updated.");
  }

  /// Shows a dialog to add a new password entry.
  void _showAddEntryDialog() {
    final TextEditingController websiteController = TextEditingController();
    final TextEditingController usernameController = TextEditingController();
    final TextEditingController passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Add New Entry'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: websiteController,
                  decoration: const InputDecoration(
                    labelText: 'Website',
                  ),
                ),
                TextField(
                  controller: usernameController,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                  ),
                ),
                TextField(
                  controller: passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                  ),
                  obscureText: true,
                ),
                // Optionally, add a DatePicker for "last changed".
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                // Create a new entry.
                final newEntry = PasswordEntry(
                  website: websiteController.text.trim(),
                  username: usernameController.text.trim(),
                  password: passwordController.text.trim(),
                  lastChanged: DateTime.now(), // default to now
                );
                setState(() {
                  _allEntries.add(newEntry);
                  _filterEntries(); // update filtered list
                });

                // Re-encrypt and save updated vault data.
                await _saveVault();

                Navigator.of(context).pop();
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  /// Called when the "Add" button is pressed.
  void _addEntry() {
    _showAddEntryDialog();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Vault'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addEntry,
        child: const Icon(Icons.add),
      ),
      body: ListView.builder(
        itemCount: _filteredEntries.length,
        itemBuilder: (context, index) {
          final entry = _filteredEntries[index];
          return PasswordEntryTile(entry: entry, getEntryColor: _getEntryColor);
        },
      ),
    );
  }
}

/// A widget representing a single password entry in the list.
class PasswordEntryTile extends StatefulWidget {
  final PasswordEntry entry;
  final Color Function(DateTime) getEntryColor;

  const PasswordEntryTile(
      {super.key, required this.entry, required this.getEntryColor});

  @override
  State<PasswordEntryTile> createState() => _PasswordEntryTileState();
}

class _PasswordEntryTileState extends State<PasswordEntryTile> {
  bool _obscure = true;

  /// Launches the provided URL using the url_launcher package.
  void _launchURL(String url) async {
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Could not launch URL')));
    }
  }

  @override
  Widget build(BuildContext context) {
    Color entryColor = widget.getEntryColor(widget.entry.lastChanged);

    return Card(
      color: entryColor.withOpacity(0.1),
      child: ListTile(
        title: Text(
          widget.entry.website.isNotEmpty ? widget.entry.website : 'No Website',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Username: ${widget.entry.username}'),
            Text('Password: ${_obscure ? '•' * 8 : widget.entry.password}'),
            Text(
              'Last Changed: ${widget.entry.lastChanged.toLocal().toString().split(' ')[0]}',
              style: const TextStyle(fontStyle: FontStyle.italic),
            ),
          ],
        ),
        trailing: Wrap(
          spacing: 8,
          children: [
            // View button to toggle password visibility.
            IconButton(
              icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
              onPressed: () {
                setState(() {
                  _obscure = !_obscure;
                });
              },
            ),
            // Copy button.
            IconButton(
              icon: const Icon(Icons.copy),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: widget.entry.password));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Password copied to clipboard')));
              },
            ),
            // Website button, if available.
            if (widget.entry.website.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.open_in_browser),
                onPressed: () => _launchURL(widget.entry.website),
              ),
          ],
        ),
      ),
    );
  }
}
