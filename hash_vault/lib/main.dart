import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'setup_screen.dart';
import 'login_screen.dart';

//it needs to check if the file with
//the passwords exists and also maybe a backup. The front end will have a
//simple password prompt. the hash should be encrypted in its own file. when
//the user types the password then the hashes are compared, if the password is
//failed 10 times in a row, all data is deleted. once the user is logged in it's
//a simple UI with a search, the website/ app name and the password on the right.
//it will be hidden until the user presses on it. background colour for each of the
//records also depends on factors. if it's been unchanged for a while or password
//used twice it is orange. if it's been a really long time it goes red. also a way to
//press a button to go to the website would be nice.

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Hash Vault',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FlutterSecureStorage _storage = FlutterSecureStorage();

  void _setConfig(bool config) async {
    await _storage.write(key: 'config', value: config.toString());
    _checkConfig();
  }

  Future<bool> _getConfig() async {
    String? configured = await _storage.read(key: 'config');
    if (configured == null) {
      return false;
    }
    return configured == 'true';
  }

  @override
  void initState() {
    super.initState();
    // _setConfig(false);
  }

  Future<void> _checkConfig() async {
    bool? configured = await _getConfig();
    if (configured) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => SetupScreen(
                  onConfigured: (value) => _setConfig(value),
                )),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    _checkConfig();

    return Scaffold(
      appBar: AppBar(title: const Text('Hash Vault')),
      body: const Center(child: CircularProgressIndicator()),
    );
  }
}
