import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../domain/models/payment_transaction.dart';
import '../../domain/models/service_order.dart';
import '../../domain/models/service_request.dart';

/// Optional non-blocking Cloud Firestore sync layer.
/// Automatically syncs orders, requests, and transactions for signed-in
/// Firebase users while keeping local-first [AppDatabase] working offline/demo.
class FirestoreSyncService {
  FirestoreSyncService._();

  static String? get _uid {
    try {
      return FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {
      return null;
    }
  }

  static Future<void> syncOrder(ServiceOrder order) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('orders')
          .doc(order.id)
          .set(order.toJson(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('FirestoreSyncService.syncOrder skipped: $e');
    }
  }

  static Future<void> syncRequest(ServiceRequest request) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('requests')
          .doc(request.id)
          .set(request.toJson(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('FirestoreSyncService.syncRequest skipped: $e');
    }
  }

  static Future<void> syncTransaction(PaymentTransaction txn) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('transactions')
          .doc(txn.id)
          .set(txn.toJson(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('FirestoreSyncService.syncTransaction skipped: $e');
    }
  }
}
