import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Supabase.initialize(
    url: 'https://edlquuxypulyedwgweai.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVkbHF1dXh5cHVseWVkd2d3ZWFpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Mzk0Nzg3OTAsImV4cCI6MjA1NTA1NDc5MH0.EL4k_9sOoD9NR6sjVnJj0IjT5SoRYsDrktsdPH1dTgo',
  );
  
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Supabase Authentication',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.white,
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          filled: true,
          fillColor: Colors.grey[100],
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
      home: AuthOptionsPage(),
    );
  }
}

// Screen 1: Auth Options Page with both sign-in methods
class AuthOptionsPage extends StatelessWidget {
  final supabase = Supabase.instance.client;
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Sign In'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // App Logo or Icon
            Icon(
              Icons.lock_outline,
              size: 80,
              color: Theme.of(context).primaryColor,
            ),
            SizedBox(height: 40),
            
            // Email/Password Sign In Button
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EmailPasswordPage(),
                  ),
                );
              },
              icon: Icon(Icons.email),
              label: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  'Sign in with Email',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
            
            SizedBox(height: 16),
            
            // Or divider
            Row(
              children: [
                Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text('OR', style: TextStyle(color: Colors.grey)),
                ),
                Expanded(child: Divider()),
              ],
            ),
            
            SizedBox(height: 16),
            
            // Apple Sign In Button
            SignInWithAppleButton(
              onPressed: () => _signInWithApple(context),
              style: SignInWithAppleButtonStyle.black,
            ),
          ],
        ),
      ),
    );
  }
  
  /// Generates a random 16 character string.
  String _generateRandomString() {
    final random = Random.secure();
    return base64Url.encode(List<int>.generate(16, (_) => random.nextInt(256)));
  }
  
  /// Creates a SHA256 hash of the [input] string.
  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
  
  Future<void> _signInWithApple(BuildContext context) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(child: CircularProgressIndicator()),
      );
      
      // Generate a secure nonce
      final rawNonce = _generateRandomString();
      final nonce = _sha256ofString(rawNonce);
      
      // Request credential for Apple Sign In
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );
      
      // Use the credential to sign in with Supabase
      final idToken = credential.identityToken;
      if (idToken == null) {
        throw 'No identity token returned from Apple';
      }
      
      // Create sign in data for Supabase
      final AuthResponse res = await supabase.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: idToken,
        nonce: rawNonce,
      );
      
      final user = res.user;
      if (user == null) {
        throw 'No user returned from Supabase';
      }
      
      // Close loading dialog
      Navigator.of(context).pop();
      
      // Navigate to home page after successful login
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => HomePage()),
      );
      
    } catch (error) {
      // Close loading dialog
      Navigator.of(context).pop();
      
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sign in failed: ${error.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
      print('Error signing in with Apple: $error');
    }
  }
}

// Screen 2: Email/Password Sign In Page
class EmailPasswordPage extends StatefulWidget {
  @override
  _EmailPasswordPageState createState() => _EmailPasswordPageState();
}

class _EmailPasswordPageState extends State<EmailPasswordPage> {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _isSignUp = false; // Toggle between sign in and sign up
  bool _isLoading = false;
  
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isSignUp ? 'Create Account' : 'Sign In'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Email field
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
                autofillHints: [AutofillHints.email],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your email';
                  }
                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
              
              SizedBox(height: 16),
              
              // Password field
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: Icon(Icons.lock),
                ),
                obscureText: true,
                autofillHints: [AutofillHints.password],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your password';
                  }
                  if (_isSignUp && value.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
              ),
              
              SizedBox(height: 24),
              
              // Sign In/Up Button
              _isLoading
                ? Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: _handleSubmit,
                    child: Text(
                      _isSignUp ? 'Create Account' : 'Sign In',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
              
              SizedBox(height: 16),
              
              // Toggle between sign in and sign up
              TextButton(
                onPressed: () {
                  setState(() {
                    _isSignUp = !_isSignUp;
                  });
                },
                child: Text(
                  _isSignUp
                    ? 'Already have an account? Sign In'
                    : 'Don\'t have an account? Sign Up',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      
      AuthResponse res;
      
      if (_isSignUp) {
        print("Signing");
        // Sign up with Supabase
        res = await supabase.auth.signUp(
          email: email,
          password: password,
        );
        // Print the full response details

        // Or individually print components
        print('User: ${res.user?.toJson()}');
        print('Session: ${res.session?.toJson()}');
      } else {
        // Sign in with Supabase
        res = await supabase.auth.signInWithPassword(
          email: email,
          password: password,
        );
      }
      
      final user = res.user;
      final session = res.session;
      
      if (user == null || session == null) {
        throw 'Authentication failed';
      }
      
      if (_isSignUp) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Account created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
      
      // Navigate to home page
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => HomePage()),
      );
      
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${error.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}

// Home Page after successful authentication
class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final supabase = Supabase.instance.client;
  User? _user;
  
  @override
  void initState() {
    super.initState();
    _user = supabase.auth.currentUser;
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Home'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: _signOut,
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              color: Colors.green,
              size: 80,
            ),
            SizedBox(height: 24),
            Text(
              'Successfully Signed In!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Text(
              'Email: ${_user?.email ?? 'Unknown'}',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 8),
            Text(
              'User ID: ${_user?.id ?? 'Unknown'}',
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
  
  Future<void> _signOut() async {
    try {
      await supabase.auth.signOut();
      
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => AuthOptionsPage()),
      );
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error signing out: ${error.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}