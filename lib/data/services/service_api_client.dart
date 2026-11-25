import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../../core/config/app_env.dart';
import '../../core/errors/app_exception.dart';
import '../../domain/models/provider_response.dart';
import '../../domain/models/service_item.dart';
import '../../domain/models/service_request.dart';
import 'local_storage_service.dart';
import 'seed_data.dart';

/// REST API Client using `package:http` with configurable remote baseUrl
/// and a built-in local-first Mock REST Adapter for standalone offline/APK
/// evaluation. Includes simulated network latency, error injection, and
/// exponential-backoff retry.
class ServiceApiClient {
  ServiceApiClient({
    required LocalStorageService storage,
    http.Client? httpClient,
    this.baseUrl,
  })  : _storage = storage,
        _httpClient = httpClient ?? http.Client();

  final LocalStorageService _storage;
  final http.Client _httpClient;
  final String? baseUrl;
  final _uuid = const Uuid();
  final _random = Random();

  Future<void> _ensureSeeded() async {
    if (!_storage.isSeeded) {
      await _storage.saveRequests(SeedData.initialRequests());
      await _storage.saveResponses(SeedData.initialResponses());
      await _storage.saveTransactions(SeedData.initialTransactions());
      await _storage.saveNotifications(SeedData.initialNotifications());
      await _storage.markSeeded();
    }
  }

  Future<void> _simulateNetwork({int minMs = 180, int maxMs = 420}) async {
    final delay = minMs + _random.nextInt(maxMs - minMs);
    await Future<void>.delayed(Duration(milliseconds: delay));
    if (_storage.simulateApiError) {
      throw const NetworkException(
        'Simulated network failure (Demo Error Mode is enabled in Settings).',
      );
    }
  }

  /// Example of real `http.Client` GET with timeout & status code handling.
  /// Used automatically when [baseUrl] is configured.
  Future<dynamic> _remoteGet(String path) async {
    final uri = Uri.parse('$baseUrl$path');
    try {
      final response = await _httpClient
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body);
      }
      if (response.statusCode == 404) {
        throw const NotFoundException();
      }
      throw ServerException(
        'Server returned ${response.statusCode}',
        statusCode: response.statusCode,
      );
    } on TimeoutException {
      rethrow;
    } on AppException {
      rethrow;
    } catch (e) {
      throw NetworkException('Network request failed: $e', e);
    }
  }

  Future<dynamic> _remotePost(String path, Map<String, dynamic> body) async {
    final uri = Uri.parse('$baseUrl$path');
    try {
      final response = await _httpClient
          .post(
            uri,
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body);
      }
      throw ServerException(
        'Server returned ${response.statusCode}',
        statusCode: response.statusCode,
      );
    } on AppException {
      rethrow;
    } catch (e) {
      throw NetworkException('Network POST failed: $e', e);
    }
  }

  Future<dynamic> _remotePatch(String path, Map<String, dynamic> body) async {
    final uri = Uri.parse('$baseUrl$path');
    try {
      final response = await _httpClient
          .patch(
            uri,
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body);
      }
      throw ServerException(
        'Server returned ${response.statusCode}',
        statusCode: response.statusCode,
      );
    } on AppException {
      rethrow;
    } catch (e) {
      throw NetworkException('Network PATCH failed: $e', e);
    }
  }

  /// GET /api/v1/services
  Future<List<ServiceItem>> fetchServices() async {
    if (baseUrl != null) {
      final json = await _remoteGet('/api/v1/services') as List<dynamic>;
      return json
          .map((e) => ServiceItem.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    await _simulateNetwork();
    // Simulate JSON round-trip serialization as a real REST API would
    final payload = jsonEncode(SeedData.services.map((s) => s.toJson()).toList());
    final decoded = jsonDecode(payload) as List<dynamic>;
    return decoded
        .map((e) => ServiceItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// GET /api/v1/requests
  Future<List<ServiceRequest>> fetchRequests() async {
    await _ensureSeeded();
    if (baseUrl != null) {
      final json = await _remoteGet('/api/v1/requests') as List<dynamic>;
      return json
          .map((e) => ServiceRequest.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    await _simulateNetwork();
    final list = _storage.loadRequests();
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  /// POST /api/v1/requests
  Future<ServiceRequest> createRequest(ServiceRequest draft) async {
    await _ensureSeeded();
    if (baseUrl != null) {
      final json =
          await _remotePost('/api/v1/requests', draft.toJson())
              as Map<String, dynamic>;
      return ServiceRequest.fromJson(json);
    }
    await _simulateNetwork(minMs: 280, maxMs: 550);

    final now = DateTime.now();
    final id = 'REQ-${1050 + _random.nextInt(8900)}';
    final created = ServiceRequest(
      id: id,
      serviceId: draft.serviceId,
      serviceTitle: draft.serviceTitle,
      title: draft.title,
      category: draft.category,
      description: draft.description,
      budgetMin: draft.budgetMin,
      budgetMax: draft.budgetMax,
      urgency: draft.urgency,
      preferredDate: draft.preferredDate,
      location: draft.location,
      contactEmail: draft.contactEmail,
      contactPhone: draft.contactPhone,
      customAnswers: draft.customAnswers,
      attachmentLabels: draft.attachmentLabels,
      status: RequestStatus.quoted,
      createdAt: now,
      updatedAt: now,
      timeline: [
        TimelineEvent(
          title: 'Request Submitted',
          subtitle: 'Matched with verified ${draft.category.label} providers',
          timestamp: now,
        ),
        TimelineEvent(
          title: 'Initial Provider Quote Received',
          subtitle: 'Relevant specialists reviewed your requirements',
          timestamp: now.add(const Duration(seconds: 1)),
        ),
      ],
    );

    final requests = _storage.loadRequests();
    requests.insert(0, created);
    await _storage.saveRequests(requests);

    // Automatically generate 2 relevant provider quotes for the new request
    final existingResponses = _storage.loadResponses();
    final generated = _generateQuotesForRequest(created, count: 2);
    existingResponses.addAll(generated);
    await _storage.saveResponses(existingResponses);

    unawaited(_syncRequestToFirestore(created));
    return created;
  }

  Future<void> _syncRequestToFirestore(ServiceRequest req) async {
    if (!AppEnv.firebaseInitialized) return;
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      await FirebaseFirestore.instance
          .collection('service_epic_requests')
          .doc(req.id)
          .set({
        ...req.toJson(),
        'ownerUid': uid,
      });
    } catch (_) {
      // Gracefully keep local-first persistence if Firestore rules restrict custom collections
    }
  }

  /// PATCH /api/v1/requests/:id
  Future<ServiceRequest> updateRequest(ServiceRequest updated) async {
    await _ensureSeeded();
    if (baseUrl != null) {
      final json =
          await _remotePatch('/api/v1/requests/${updated.id}', updated.toJson())
              as Map<String, dynamic>;
      return ServiceRequest.fromJson(json);
    }
    await _simulateNetwork();
    final requests = _storage.loadRequests();
    final idx = requests.indexWhere((r) => r.id == updated.id);
    if (idx == -1) {
      throw const NotFoundException('Service request not found.');
    }
    requests[idx] = updated;
    await _storage.saveRequests(requests);
    return updated;
  }

  /// GET /api/v1/requests/:id/responses
  Future<List<ProviderResponse>> fetchResponsesForRequest(
    String requestId,
  ) async {
    await _ensureSeeded();
    await _simulateNetwork(minMs: 140, maxMs: 300);
    return _storage
        .loadResponses()
        .where((r) => r.requestId == requestId)
        .toList();
  }

  /// GET /api/v1/responses
  Future<List<ProviderResponse>> fetchAllResponses() async {
    await _ensureSeeded();
    await _simulateNetwork(minMs: 100, maxMs: 220);
    return _storage.loadResponses();
  }

  /// POST /api/v1/requests/:id/responses (simulate receiving a fresh quote)
  Future<ProviderResponse> requestFreshQuote(ServiceRequest request) async {
    await _ensureSeeded();
    await _simulateNetwork(minMs: 300, maxMs: 600);
    final quote = _generateQuotesForRequest(request, count: 1).first;
    final responses = _storage.loadResponses()..add(quote);
    await _storage.saveResponses(responses);

    // Also update request status if it was open
    if (request.status == RequestStatus.open) {
      await updateRequest(
        request.copyWith(
          status: RequestStatus.quoted,
          updatedAt: DateTime.now(),
          timeline: [
            ...request.timeline,
            TimelineEvent(
              title: 'New Quote Received',
              subtitle: '${quote.providerName} quoted \$${quote.quotedPrice.toStringAsFixed(0)}',
              timestamp: DateTime.now(),
            ),
          ],
        ),
      );
    }
    return quote;
  }

  /// PATCH /api/v1/responses/:id
  Future<ProviderResponse> updateProviderResponse(
    ProviderResponse updated,
  ) async {
    await _ensureSeeded();
    await _simulateNetwork(minMs: 150, maxMs: 320);
    final responses = _storage.loadResponses();
    final idx = responses.indexWhere((r) => r.id == updated.id);
    if (idx == -1) {
      throw const NotFoundException('Provider quote not found.');
    }
    responses[idx] = updated;
    await _storage.saveResponses(responses);
    return updated;
  }

  List<ProviderResponse> _generateQuotesForRequest(
    ServiceRequest request, {
    int count = 2,
  }) {
    final matchingServices = SeedData.services
        .where((s) => s.category == request.category)
        .toList();
    final fallback = matchingServices.isEmpty
        ? SeedData.services
        : matchingServices;

    final quotes = <ProviderResponse>[];
    final midBudget = (request.budgetMin + request.budgetMax) / 2;

    for (var i = 0; i < count; i++) {
      final srv = fallback[i % fallback.length];
      final variance = 0.85 + (_random.nextDouble() * 0.28);
      final price = (midBudget * variance).clamp(
        max(15.0, request.budgetMin * 0.8),
        request.budgetMax * 1.12,
      );
      final roundedPrice = (price / 5).round() * 5.0;
      final now = DateTime.now();

      quotes.add(
        ProviderResponse(
          id: 'QUO-${_uuid.v4().substring(0, 6).toUpperCase()}',
          requestId: request.id,
          providerName: i == 0 ? srv.providerName : '${srv.providerName} Plus',
          providerRole: srv.providerTitle,
          rating: srv.rating,
          completedJobs: srv.completedJobs + (i * 15),
          isVerified: srv.isVerifiedProvider,
          quotedPrice: roundedPrice,
          estimatedDuration: request.urgency == RequestUrgency.emergency
              ? 'Same Day (2–4 hrs)'
              : srv.packages.isNotEmpty
                  ? srv.packages.first.deliveryLabel
                  : '2–3 Days',
          message:
              'We reviewed "${request.title}" and can fulfill all requirements within your timeline. Our quote includes full quality assurance and direct progress updates.',
          deliverables: srv.highlights.isNotEmpty
              ? srv.highlights
              : ['Requirement analysis', 'Execution & verification'],
          status: QuoteStatus.pending,
          createdAt: now,
          messages: [
            ResponseMessage(
              id: _uuid.v4(),
              senderIsClient: false,
              senderName: i == 0 ? srv.providerName : '${srv.providerName} Plus',
              text:
                  'Hello! We are available for your preferred date. Feel free to ask any questions or propose a counter-offer.',
              timestamp: now,
            ),
          ],
        ),
      );
    }
    return quotes;
  }
}
