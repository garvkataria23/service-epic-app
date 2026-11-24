import 'package:flutter/foundation.dart';

import '../../../core/utils/debouncer.dart';
import '../../../core/utils/smart_search_engine.dart';
import '../../../data/repositories/request_repository.dart';
import '../../../domain/models/provider_response.dart';
import '../../../domain/models/service_request.dart';

class RequestsViewModel extends ChangeNotifier {
  RequestsViewModel({required RequestRepository repository})
      : _repository = repository;

  final RequestRepository _repository;
  final Debouncer _debouncer = Debouncer();

  List<ServiceRequest> _allRequests = [];
  Map<String, List<ProviderResponse>> _responsesByRequest = {};
  List<SmartSearchMatch<ServiceRequest>> _filteredRequests = [];

  bool _isLoading = false;
  String? _errorMessage;
  String _searchQuery = '';
  RequestStatus? _selectedStatus;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get searchQuery => _searchQuery;
  RequestStatus? get selectedStatus => _selectedStatus;
  List<SmartSearchMatch<ServiceRequest>> get filteredRequests =>
      _filteredRequests;
  List<ServiceRequest> get allRequests => _allRequests;

  int get activeCount => _allRequests
      .where((r) =>
          r.status == RequestStatus.open ||
          r.status == RequestStatus.quoted ||
          r.status == RequestStatus.inProgress)
      .length;

  int get pendingQuotesCount {
    var count = 0;
    for (final list in _responsesByRequest.values) {
      count += list
          .where((q) =>
              q.status == QuoteStatus.pending ||
              q.status == QuoteStatus.negotiating)
          .length;
    }
    return count;
  }

  int get completedCount =>
      _allRequests.where((r) => r.status == RequestStatus.completed).length;

  List<ProviderResponse> responsesFor(String requestId) =>
      _responsesByRequest[requestId] ?? const [];

  Future<void> loadRequests() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final reqResult = await _repository.getRequests();
    final respResult = await _repository.getAllResponsesGrouped();

    reqResult.when(
      success: (reqs) {
        _allRequests = reqs;
        respResult.when(
          success: (grouped) => _responsesByRequest = grouped,
          failure: (_) {},
        );
        _applyFilters();
      },
      failure: (err) {
        _errorMessage = err.message;
      },
    );

    _isLoading = false;
    notifyListeners();
  }

  void updateSearch(String query) {
    _searchQuery = query;
    _debouncer.run(() {
      _applyFilters();
      notifyListeners();
    });
  }

  void selectStatus(RequestStatus? status) {
    _selectedStatus = _selectedStatus == status ? null : status;
    _applyFilters();
    notifyListeners();
  }

  void clearFilters() {
    _debouncer.cancel();
    _searchQuery = '';
    _selectedStatus = null;
    _applyFilters();
    notifyListeners();
  }

  void _applyFilters() {
    final parsed = SmartSearchEngine.parseQuery(_searchQuery);
    final pool = _allRequests.where((r) {
      if (_selectedStatus != null && r.status != _selectedStatus) return false;
      if (parsed.maxPrice != null && r.budgetMin > parsed.maxPrice!) {
        return false;
      }
      return true;
    }).toList();

    _filteredRequests = SmartSearchEngine.search<ServiceRequest>(
      items: pool,
      query: parsed,
      fieldsBuilder: (r) {
        final quoteProviders = (_responsesByRequest[r.id] ?? const [])
            .map((q) => '${q.providerName} ${q.message}')
            .join(' ');
        return [
          SearchField(value: r.title, weight: 4.0, label: 'Title'),
          SearchField(value: r.id, weight: 3.5, label: 'Request ID'),
          SearchField(value: r.category.label, weight: 2.5, label: 'Category'),
          SearchField(value: r.location, weight: 2.0, label: 'Location'),
          SearchField(value: r.description, weight: 1.4, label: 'Description'),
          SearchField(value: quoteProviders, weight: 1.5, label: 'Quotes'),
        ];
      },
    );
  }

  @override
  void dispose() {
    _debouncer.dispose();
    super.dispose();
  }
}
