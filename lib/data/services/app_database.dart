import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../../domain/models/app_notification.dart';
import '../../domain/models/cart_item.dart';
import '../../domain/models/payment_transaction.dart';
import '../../domain/models/provider_response.dart';
import '../../domain/models/service_item.dart';
import '../../domain/models/service_order.dart';
import '../../domain/models/service_request.dart';
import 'seed_data.dart';

/// Cross-platform persistent database:
/// - Uses native SQLite (`epic_infocus.db`, schema v2) via `sqflite` on Android/iOS.
/// - Uses `SharedPreferences` structured JSON tables on Web & unit tests.
class AppDatabase {
  AppDatabase._(this._prefs, this._sqlite);

  final SharedPreferences _prefs;
  final Database? _sqlite;

  static const _webServicesKey = 'db_services_v2';
  static const _webCartKey = 'db_cart_v2';
  static const _webOrdersKey = 'db_orders_v2';
  static const _requestsKey = 'service_epic_requests_v1';
  static const _responsesKey = 'service_epic_responses_v1';
  static const _transactionsKey = 'service_epic_transactions_v1';
  static const _notificationsKey = 'service_epic_notifications_v1';

  String get engineName =>
      _sqlite != null ? 'SQLite v2 (epic_infocus.db)' : 'Web LocalDB v2';

  static Future<AppDatabase> open(
    SharedPreferences prefs, {
    bool useSqlite = !kIsWeb,
  }) async {
    Database? db;
    if (useSqlite) {
      try {
        final dbPath = await getDatabasesPath();
        final fullPath = p.join(dbPath, 'epic_infocus.db');
        db = await openDatabase(
          fullPath,
          version: 2,
          onCreate: (database, version) async {
            await _createAllTables(database);
          },
          onUpgrade: (database, oldVersion, newVersion) async {
            if (oldVersion < 2) {
              await _createV2Tables(database);
            }
          },
        );
      } catch (_) {
        db = null;
      }
    }

    final instance = AppDatabase._(prefs, db);
    await instance._seedIfEmpty();
    return instance;
  }

  static Future<void> _createAllTables(Database database) async {
    await database.execute(
      'CREATE TABLE IF NOT EXISTS services (id TEXT PRIMARY KEY, category TEXT, title TEXT, rating REAL, base_price REAL, payload TEXT NOT NULL)',
    );
    await database.execute(
      'CREATE TABLE IF NOT EXISTS cart_items (id TEXT PRIMARY KEY, service_id TEXT, quantity INTEGER, payload TEXT NOT NULL)',
    );
    await database.execute(
      'CREATE TABLE IF NOT EXISTS orders (id TEXT PRIMARY KEY, status TEXT, total_amount REAL, created_at TEXT, payload TEXT NOT NULL)',
    );
    await _createV2Tables(database);
  }

  static Future<void> _createV2Tables(Database database) async {
    await database.execute(
      'CREATE TABLE IF NOT EXISTS requests (id TEXT PRIMARY KEY, status TEXT, updated_at TEXT, payload TEXT NOT NULL)',
    );
    await database.execute(
      'CREATE TABLE IF NOT EXISTS provider_responses (id TEXT PRIMARY KEY, request_id TEXT, status TEXT, payload TEXT NOT NULL)',
    );
    await database.execute(
      'CREATE TABLE IF NOT EXISTS transactions (id TEXT PRIMARY KEY, request_id TEXT, status TEXT, created_at TEXT, payload TEXT NOT NULL)',
    );
    await database.execute(
      'CREATE TABLE IF NOT EXISTS notifications (id TEXT PRIMARY KEY, is_read INTEGER, created_at TEXT, payload TEXT NOT NULL)',
    );
  }

  Future<void> _seedIfEmpty() async {
    final existing = await getAllServices();
    if (existing.isEmpty) {
      await upsertServices(SeedData.services);
    }
    final orders = await getAllOrders();
    if (orders.isEmpty) {
      await upsertOrder(SeedData.initialOrder());
    }
    if (_sqlite != null) {
      final reqCount =
          Sqflite.firstIntValue(
            await _sqlite.rawQuery('SELECT COUNT(*) FROM requests'),
          ) ??
          0;
      if (reqCount == 0) {
        await saveRequests(SeedData.initialRequests());
        await saveResponses(SeedData.initialResponses());
        await saveTransactions(SeedData.initialTransactions());
        await saveNotifications(SeedData.initialNotifications());
      }
    }
  }

  Future<List<ServiceItem>> getAllServices() async {
    if (_sqlite != null) {
      final rows = await _sqlite.query('services');
      return rows
          .map(
            (r) => ServiceItem.fromJson(
              jsonDecode(r['payload'] as String) as Map<String, dynamic>,
            ),
          )
          .toList();
    }
    final raw = _prefs.getString(_webServicesKey);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => ServiceItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> upsertServices(List<ServiceItem> items) async {
    if (_sqlite != null) {
      final batch = _sqlite.batch();
      for (final s in items) {
        batch.insert(
          'services',
          {
            'id': s.id,
            'category': s.category.id,
            'title': s.title,
            'rating': s.rating,
            'base_price': s.basePrice,
            'payload': jsonEncode(s.toJson()),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
      return;
    }
    await _prefs.setString(
      _webServicesKey,
      jsonEncode(items.map((s) => s.toJson()).toList()),
    );
  }

  Future<List<CartItem>> getCartItems() async {
    if (_sqlite != null) {
      final rows = await _sqlite.query('cart_items');
      return rows
          .map(
            (r) => CartItem.fromJson(
              jsonDecode(r['payload'] as String) as Map<String, dynamic>,
            ),
          )
          .toList();
    }
    final raw = _prefs.getString(_webCartKey);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => CartItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveCartItems(List<CartItem> items) async {
    if (_sqlite != null) {
      await _sqlite.delete('cart_items');
      final batch = _sqlite.batch();
      for (final item in items) {
        batch.insert(
          'cart_items',
          {
            'id': item.id,
            'service_id': item.serviceId,
            'quantity': item.quantity,
            'payload': jsonEncode(item.toJson()),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
      return;
    }
    await _prefs.setString(
      _webCartKey,
      jsonEncode(items.map((i) => i.toJson()).toList()),
    );
  }

  Future<List<ServiceOrder>> getAllOrders() async {
    if (_sqlite != null) {
      final rows = await _sqlite.query(
        'orders',
        orderBy: 'created_at DESC',
      );
      return rows
          .map(
            (r) => ServiceOrder.fromJson(
              jsonDecode(r['payload'] as String) as Map<String, dynamic>,
            ),
          )
          .toList();
    }
    final raw = _prefs.getString(_webOrdersKey);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    final orders = list
        .map((e) => ServiceOrder.fromJson(e as Map<String, dynamic>))
        .toList();
    orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return orders;
  }

  Future<void> upsertOrder(ServiceOrder order) async {
    if (_sqlite != null) {
      await _sqlite.insert(
        'orders',
        {
          'id': order.id,
          'status': order.status.id,
          'total_amount': order.totalAmount,
          'created_at': order.createdAt.toIso8601String(),
          'payload': jsonEncode(order.toJson()),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return;
    }
    final orders = await getAllOrders();
    final idx = orders.indexWhere((o) => o.id == order.id);
    if (idx != -1) {
      orders[idx] = order;
    } else {
      orders.insert(0, order);
    }
    await _prefs.setString(
      _webOrdersKey,
      jsonEncode(orders.map((o) => o.toJson()).toList()),
    );
  }

  Future<void> saveRequests(List<ServiceRequest> requests) async {
    if (_sqlite != null) {
      await _sqlite.delete('requests');
      final batch = _sqlite.batch();
      for (final r in requests) {
        batch.insert(
          'requests',
          {
            'id': r.id,
            'status': r.status.id,
            'updated_at': r.updatedAt.toIso8601String(),
            'payload': jsonEncode(r.toJson()),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    }
    await _prefs.setString(
      _requestsKey,
      jsonEncode(requests.map((r) => r.toJson()).toList()),
    );
  }

  Future<void> saveResponses(List<ProviderResponse> responses) async {
    if (_sqlite != null) {
      await _sqlite.delete('provider_responses');
      final batch = _sqlite.batch();
      for (final r in responses) {
        batch.insert(
          'provider_responses',
          {
            'id': r.id,
            'request_id': r.requestId,
            'status': r.status.id,
            'payload': jsonEncode(r.toJson()),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    }
    await _prefs.setString(
      _responsesKey,
      jsonEncode(responses.map((r) => r.toJson()).toList()),
    );
  }

  Future<void> saveTransactions(List<PaymentTransaction> txns) async {
    if (_sqlite != null) {
      await _sqlite.delete('transactions');
      final batch = _sqlite.batch();
      for (final t in txns) {
        batch.insert(
          'transactions',
          {
            'id': t.id,
            'request_id': t.requestId,
            'status': t.status.id,
            'created_at': t.createdAt.toIso8601String(),
            'payload': jsonEncode(t.toJson()),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    }
    await _prefs.setString(
      _transactionsKey,
      jsonEncode(txns.map((t) => t.toJson()).toList()),
    );
  }

  Future<void> saveNotifications(List<AppNotification> items) async {
    if (_sqlite != null) {
      await _sqlite.delete('notifications');
      final batch = _sqlite.batch();
      for (final n in items) {
        batch.insert(
          'notifications',
          {
            'id': n.id,
            'is_read': n.isRead ? 1 : 0,
            'created_at': n.createdAt.toIso8601String(),
            'payload': jsonEncode(n.toJson()),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    }
    await _prefs.setString(
      _notificationsKey,
      jsonEncode(items.map((n) => n.toJson()).toList()),
    );
  }

  Future<void> resetDatabase() async {
    if (_sqlite != null) {
      await _sqlite.delete('cart_items');
      await _sqlite.delete('orders');
      await _sqlite.delete('services');
      await _sqlite.delete('requests');
      await _sqlite.delete('provider_responses');
      await _sqlite.delete('transactions');
      await _sqlite.delete('notifications');
    }
    await _prefs.remove(_webServicesKey);
    await _prefs.remove(_webCartKey);
    await _prefs.remove(_webOrdersKey);
    await _seedIfEmpty();
  }

  Future<Map<String, int>> getTableCounts() async {
    final services = await getAllServices();
    final cart = await getCartItems();
    final orders = await getAllOrders();
    final reqCount = _decodeListCount(_requestsKey);
    final respCount = _decodeListCount(_responsesKey);
    final txnCount = _decodeListCount(_transactionsKey);
    final notifCount = _decodeListCount(_notificationsKey);
    return {
      'services': services.length,
      'cart_items': cart.length,
      'orders': orders.length,
      'requests': reqCount,
      'quotes': respCount,
      'transactions': txnCount,
      'notifications': notifCount,
    };
  }

  int _decodeListCount(String key) {
    final raw = _prefs.getString(key);
    if (raw == null || raw.isEmpty) return 0;
    return (jsonDecode(raw) as List<dynamic>).length;
  }
}
