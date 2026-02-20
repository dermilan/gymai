import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/app_user.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  AppUser? _appUser;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userSub;

  AppUser? get appUser => _appUser;
  User? get firebaseUser => _auth.currentUser;
  bool get isSignedIn => _auth.currentUser != null;

  AuthService() {
    _auth.authStateChanges().listen(_onAuthStateChanged);
  }

  Future<void> _onAuthStateChanged(User? user) async {
    _userSub?.cancel();
    _userSub = null;

    if (user == null) {
      _appUser = null;
      notifyListeners();
      return;
    }

    // Listen to user document
    _userSub = _firestore
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen((doc) {
      if (doc.exists) {
        _appUser = AppUser.fromFirestore(doc);
      } else {
        _appUser = null;
      }
      notifyListeners();
    });
  }

  Future<void> signInWithEmail(String email, String password) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> signUpWithEmail(String email, String password, {String? displayName}) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final user = credential.user;
    if (user == null) throw Exception('Failed to create user');

    // Create user document in Firestore
    final now = DateTime.now();
    final appUser = AppUser(
      uid: user.uid,
      email: email,
      displayName: displayName,
      tier: SubscriptionTier.free,
      aiRequestsThisMonth: 0,
      createdAt: now,
      updatedAt: now,
    );

    await _firestore.collection('users').doc(user.uid).set(appUser.toFirestore());

    if (displayName != null) {
      await user.updateDisplayName(displayName);
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  Future<void> updateDisplayName(String name) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await user.updateDisplayName(name);
    await _firestore.collection('users').doc(user.uid).update({
      'displayName': name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  void dispose() {
    _userSub?.cancel();
    super.dispose();
  }
}
