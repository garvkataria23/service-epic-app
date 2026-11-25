import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../../domain/models/cart_item.dart';
import '../../domain/models/service_item.dart';
import '../../domain/models/service_order.dart';
import 'seed_data.dart';

/// Cross-platform persistent database:
/// - Uses native SQLite (`epic_infocus.db`) via `sqflite` on Android/iOS.
/// - Uses `SharedPreferences` structured JSON tables on Web & unit tests.
class AppDatabase {
  AppDatabase._(this._prefs, this._sqlite);

  final SharedPreferences _prefs;
  final Database? _sqlite;

  static const _webServicesKey = 'db_services_v2';
  static const _webCartKey = 'db_cart_v2';
  static const _webOrdersKey = 'db_orders_v2';

  String get engineName =>
      _sqlite != null ? 'SQLite (epic_infocus.db)' : 'Web LocalDB';

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
          version: 1,
          onCreate: (database, version) async {
            await database.execute(
              'CREATE TABLE services (id TEXT PRIMARY KEY, category TEXT, title TEXT, rating REAL, base_price REAL, payload TEXT NOT NULL)',
            );
            await database.execute(
              'CREATE TABLE cart_items (id TEXT PRIMARY KEY, service_id TEXT, quantity INTEGER, payload TEXT NOT NULL)',
            );
            await database.execute(
              'CREATE TABLE orders (id TEXT PRIMARY KEY, status TEXT, total_amount REAL, created_at TEXT, payload TEXT NOT NULL)',
            );
          },
        );
      } catch (_) {
        // Fallback cleanly in unit tests or unsupported environments
        db = null;
      }
    }

    final instance = AppDatabase._(prefs, db);
    await instance._seedServicesIfEmpty();
    return instance;
  }

  Future<void> _seedServicesIfEmpty() async {
    final existing = await getAllServices();
    if (existing.isEmpty) {
      await upsertServices(SeedData.services);
    }
    // Seed 1 realistic completed order for immediate order/return/replace visibility
    final orders = await getAllOrders();
    if (orders.isEmpty) {
      await upsertOrder(SeedData.initialOrder());
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

  Future<void> resetDatabase() async {
    if (_sqlite != null) {
      await _sqlite.delete('cart_items');
      await _sqlite.delete('orders');
      await _sqlite.delete('services');
    }
    await _prefs.remove(_webServicesKey);
    await _prefs.remove(_webCartKey);
    await _prefs.remove(_webOrdersKey);
    await _seedServicesIfEmpty();
  }

  Future<Map<String, int>> getTableCounts() async {
    final services = await getAllServices();
    final cart = await getCartItems();
    final orders = await getAllOrders();
    return {
      'services': services.length,
      'cart_items': cart.length,
      'orders': orders.length,
    };
  }
}
