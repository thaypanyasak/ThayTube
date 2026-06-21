import 'package:flutter/foundation.dart';

class AuthService extends ChangeNotifier {
  final bool _isLoggedIn = true;
  final bool _isGuest = true;
  final bool _isGoogle = false;
  bool _isInitialized = false;

  final String _displayName = 'Guest User';
  final String _email = 'guest@thaytube.local';
  final String _photoUrl = '';

  bool get isLoggedIn => _isLoggedIn;
  bool get isGuest => _isGuest;
  bool get isGoogle => _isGoogle;
  bool get isInitialized => _isInitialized;

  String get displayName => _displayName;
  String get email => _email;
  String get photoUrl => _photoUrl;

  AuthService() {
    _init();
  }

  Future<void> _init() async {
    _isInitialized = true;
    notifyListeners();
  }

  Future<bool> signInWithGoogle() async {
    return false;
  }

  void signInAsMock() {}
  void signInAsGuest() {}
  Future<void> signOut() async {}
}
