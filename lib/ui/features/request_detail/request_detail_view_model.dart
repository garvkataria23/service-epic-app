import 'package:flutter/foundation.dart';

import '../../../core/utils/smart_search_engine.dart';
import '../../../data/repositories/request_repository.dart';
import '../../../domain/models/provider_response.dart';
import '../../../domain/models/service_request.dart';

enum QuoteSortOption {
  bestValue('Lowest Price'),
  highestRated('Highest Rated'),
  newest('Newest First');

  const QuoteSortOption(this.label);
  final String label;
}

class RequestDetailViewModel extends ChangeNotifier {
  RequestDetailViewModel({
    required RequestRepository repository,
    required ServiceRequest initialRequest,
  })  : _repository = repository,
        _request = initialRequest;

  final RequestRepository _repository;

  ServiceRequest _request;
  List<ProviderResponse> _responses = [];
  bool _isLoading = false;
  bool _isActionBusy = false;
  String? _errorMessage;
  String _quoteQuery = '';
  QuoteSortOption _sortOption = QuoteSortOption.bestValue;

  ServiceRequest get request => _request;
  bool get isLoading => _isLoading;
  bool get isActionBusy => _isActionBusy;
  String? get errorMessage => _errorMessage;
  String get quoteQuery => _quoteQuery;
  QuoteSortOption get sortOption => _sortOption;

  List<ProviderResponse> get filteredResponses {
    final parsed = SmartSearchEngine.parseQuery(_quoteQuery);
    final matches = SmartSearchEngine.search<ProviderResponse>(
      items: _responses,
      query: parsed,
      fieldsBuilder: (q) => [
        SearchField(value: q.providerName, weight: 4.0, label: 'Provider'),
        SearchField(value: q.message, weight: 2.0, label: 'Message'),
        SearchField(
          value: q.deliverables.join(' '),
          weight: 2.0,
          label: 'Deliverables',
        ),
        SearchField(value: q.status.label, weight: 1.5, label: 'Status'),
      ],
    );

    final list = matches.map((m) => m.item).toList();
    if (parsed.tokens.isEmpty) {
      switch (_sortOption) {
        case QuoteSortOption.bestValue:
          list.sort((a, b) => a.quotedPrice.compareTo(b.quotedPrice));
        case QuoteSortOption.highestRated:
          list.sort((a, b) => b.rating.compareTo(a.rating));
        case QuoteSortOption.newest:
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      }
    }
    return list;
  }

  Future<void> loadResponses() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _repository.getResponsesForRequest(_request.id);
    result.when(
      success: (list) => _responses = list,
      failure: (err) => _errorMessage = err.message,
    );

    _isLoading = false;
    notifyListeners();
  }

  void updateQuoteSearch(String query) {
    _quoteQuery = query;
    notifyListeners();
  }

  void setSortOption(QuoteSortOption option) {
    _sortOption = option;
    notifyListeners();
  }

  void applyUpdatedRequest(ServiceRequest updated) {
    _request = updated;
    notifyListeners();
  }

  Future<bool> acceptQuote(ProviderResponse quote) async {
    _isActionBusy = true;
    notifyListeners();

    final res = await _repository.acceptQuote(_request, quote, _responses);
    _isActionBusy = false;

    final ok = res.when(
      success: (_) => true,
      failure: (err) {
        _errorMessage = err.message;
        return false;
      },
    );

    if (ok) {
      await _reloadAll();
    } else {
      notifyListeners();
    }
    return ok;
  }

  Future<bool> declineQuote(ProviderResponse quote) async {
    _isActionBusy = true;
    notifyListeners();

    final res = await _repository.declineQuote(quote);
    _isActionBusy = false;

    final ok = res.when(
      success: (updated) {
        final idx = _responses.indexWhere((r) => r.id == updated.id);
        if (idx != -1) _responses[idx] = updated;
        return true;
      },
      failure: (err) {
        _errorMessage = err.message;
        return false;
      },
    );
    notifyListeners();
    return ok;
  }

  Future<bool> undeclineQuote(ProviderResponse quote) async {
    _isActionBusy = true;
    notifyListeners();

    final res = await _repository.undeclineQuote(quote);
    _isActionBusy = false;

    final ok = res.when(
      success: (updated) {
        final idx = _responses.indexWhere((r) => r.id == updated.id);
        if (idx != -1) _responses[idx] = updated;
        return true;
      },
      failure: (err) {
        _errorMessage = err.message;
        return false;
      },
    );
    notifyListeners();
    return ok;
  }

  Future<bool> sendMessage(ProviderResponse quote, String text) async {
    if (text.trim().isEmpty) return false;
    _isActionBusy = true;
    notifyListeners();

    final res = await _repository.sendNegotiationMessage(quote, text);
    _isActionBusy = false;

    final ok = res.when(
      success: (updated) {
        final idx = _responses.indexWhere((r) => r.id == updated.id);
        if (idx != -1) _responses[idx] = updated;
        return true;
      },
      failure: (err) {
        _errorMessage = err.message;
        return false;
      },
    );
    notifyListeners();
    return ok;
  }

  Future<bool> requestFreshQuote() async {
    _isActionBusy = true;
    notifyListeners();

    final res = await _repository.requestFreshQuote(_request);
    _isActionBusy = false;

    final ok = res.when(
      success: (quote) {
        _responses = [..._responses, quote];
        return true;
      },
      failure: (err) {
        _errorMessage = err.message;
        return false;
      },
    );
    if (ok) {
      await _reloadRequestOnly();
    }
    notifyListeners();
    return ok;
  }

  Future<bool> markCompleted() => _transition(
        RequestStatus.completed,
        title: 'Marked as Completed',
        subtitle: 'Client confirmed service delivery',
      );

  Future<bool> completeWithReview({
    required double rating,
    required String review,
  }) async {
    _isActionBusy = true;
    notifyListeners();

    final now = DateTime.now();
    final updated = _request.copyWith(
      status: RequestStatus.completed,
      clientRating: rating,
      clientReview: review.trim().isEmpty ? null : review.trim(),
      updatedAt: now,
      timeline: [
        ..._request.timeline,
        TimelineEvent(
          title: 'Service Completed (${rating.toStringAsFixed(1)} ★)',
          subtitle: review.trim().isEmpty
              ? 'Client confirmed delivery & released escrow'
              : '"${review.trim()}" — Escrow released',
          timestamp: now,
        ),
      ],
    );

    final res = await _repository.updateRequest(updated);
    _isActionBusy = false;

    final ok = res.when(
      success: (saved) {
        _request = saved;
        return true;
      },
      failure: (err) {
        _errorMessage = err.message;
        return false;
      },
    );
    notifyListeners();
    return ok;
  }

  Future<bool> cancelRequest() => _transition(
        RequestStatus.cancelled,
        title: 'Request Cancelled',
        subtitle: 'Cancelled by client',
      );

  Future<bool> cancelInProgressWithReason(String reason) => _transition(
        RequestStatus.cancelled,
        title: 'Cancelled & Escrow Refunded',
        subtitle: 'Reason: ${reason.trim()}',
      );

  Future<bool> reopenRequest() => _transition(
        RequestStatus.open,
        title: 'Request Reopened',
        subtitle: 'Reopened for new provider quotes',
      );

  Future<bool> _transition(
    RequestStatus status, {
    required String title,
    required String subtitle,
  }) async {
    _isActionBusy = true;
    notifyListeners();

    final res = await _repository.transitionRequestStatus(
      _request,
      status,
      eventTitle: title,
      eventSubtitle: subtitle,
    );
    _isActionBusy = false;

    final ok = res.when(
      success: (updated) {
        _request = updated;
        return true;
      },
      failure: (err) {
        _errorMessage = err.message;
        return false;
      },
    );
    notifyListeners();
    return ok;
  }

  Future<void> _reloadRequestOnly() async {
    final all = await _repository.getRequests();
    all.when(
      success: (list) {
        final match = list.where((r) => r.id == _request.id).firstOrNull;
        if (match != null) _request = match;
      },
      failure: (_) {},
    );
  }

  Future<void> _reloadAll() async {
    await _reloadRequestOnly();
    await loadResponses();
  }
}
