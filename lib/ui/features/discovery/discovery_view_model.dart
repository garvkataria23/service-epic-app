import 'package:flutter/foundation.dart';

import '../../../core/utils/debouncer.dart';
import '../../../core/utils/smart_search_engine.dart';
import '../../../data/repositories/service_repository.dart';
import '../../../domain/models/service_category.dart';
import '../../../domain/models/service_item.dart';

enum DiscoverySortOption {
  relevance('Smart Relevance'),
  ratingHigh('Highest Rated'),
  priceLow('Price: Low to High'),
  priceHigh('Price: High to Low'),
  fastestResponse('Fastest Response');

  const DiscoverySortOption(this.label);
  final String label;
}

class DiscoveryViewModel extends ChangeNotifier {
  DiscoveryViewModel({required ServiceRepository repository})
      : _repository = repository {
    _favoriteIds = _repository.getFavoriteIds();
    _recentSearches = _repository.getRecentSearches();
  }

  final ServiceRepository _repository;
  final Debouncer _debouncer = Debouncer();

  List<ServiceItem> _allServices = [];
  List<SmartSearchMatch<ServiceItem>> _results = [];
  ParsedSearchQuery _parsedQuery = const ParsedSearchQuery(
    rawQuery: '',
    semanticQuery: '',
    tokens: [],
  );

  bool _isLoading = false;
  String? _errorMessage;

  String _rawQuery = '';
  ServiceCategory? _selectedCategory;
  double? _maxPriceFilter;
  double? _minRatingFilter;
  bool _verifiedOnly = false;
  bool _fastResponseOnly = false;
  bool _favoritesOnly = false;
  DiscoverySortOption _sortOption = DiscoverySortOption.relevance;

  Set<String> _favoriteIds = {};
  List<String> _recentSearches = [];

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get rawQuery => _rawQuery;
  ParsedSearchQuery get parsedQuery => _parsedQuery;
  List<SmartSearchMatch<ServiceItem>> get results => _results;
  List<ServiceItem> get featuredServices =>
      _allServices.where((s) => s.isFeatured).toList();

  ServiceCategory? get selectedCategory => _selectedCategory;
  double? get maxPriceFilter => _maxPriceFilter;
  double? get minRatingFilter => _minRatingFilter;
  bool get verifiedOnly => _verifiedOnly;
  bool get fastResponseOnly => _fastResponseOnly;
  bool get favoritesOnly => _favoritesOnly;
  DiscoverySortOption get sortOption => _sortOption;
  Set<String> get favoriteIds => _favoriteIds;
  List<String> get recentSearches => _recentSearches;

  bool get hasActiveSearchOrFilters =>
      _rawQuery.trim().isNotEmpty ||
      _selectedCategory != null ||
      _maxPriceFilter != null ||
      _minRatingFilter != null ||
      _verifiedOnly ||
      _fastResponseOnly ||
      _favoritesOnly;

  int get activeFilterCount {
    var count = 0;
    if (_selectedCategory != null) count++;
    if (_maxPriceFilter != null) count++;
    if (_minRatingFilter != null) count++;
    if (_verifiedOnly) count++;
    if (_fastResponseOnly) count++;
    if (_favoritesOnly) count++;
    if (_sortOption != DiscoverySortOption.relevance) count++;
    return count;
  }

  List<String> get smartSuggestions {
    final q = _rawQuery.trim().toLowerCase();
    if (q.isEmpty) {
      return const [
        'plumber under \$120',
        'urgent flutter app',
        'top rated cleaning',
        'verified electrical',
        'logo design figma',
      ];
    }
    final suggestions = <String>{};
    for (final s in _allServices) {
      if (s.title.toLowerCase().contains(q)) {
        suggestions.add(s.title);
      }
      for (final tag in s.tags) {
        if (tag.toLowerCase().contains(q)) {
          suggestions.add(tag);
        }
      }
    }
    return suggestions.take(6).toList();
  }

  Future<void> loadServices({bool forceRefresh = false}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _repository.getServices(forceRefresh: forceRefresh);
    result.when(
      success: (items) {
        _allServices = items;
        _applySearchAndFilters();
      },
      failure: (err) {
        _errorMessage = err.message;
      },
    );

    _isLoading = false;
    notifyListeners();
  }

  void updateQuery(String query) {
    _rawQuery = query;
    _debouncer.run(() {
      _applySearchAndFilters();
      notifyListeners();
    });
  }

  Future<void> submitSearch(String query) async {
    _debouncer.cancel();
    _rawQuery = query;
    _applySearchAndFilters();
    if (query.trim().length >= 2) {
      _recentSearches = await _repository.addRecentSearch(query);
    }
    notifyListeners();
  }

  Future<void> removeRecentSearch(String query) async {
    _recentSearches = await _repository.removeRecentSearch(query);
    notifyListeners();
  }

  Future<void> clearRecentSearches() async {
    await _repository.clearRecentSearches();
    _recentSearches = [];
    notifyListeners();
  }

  void selectCategory(ServiceCategory? category) {
    _selectedCategory = _selectedCategory == category ? null : category;
    _applySearchAndFilters();
    notifyListeners();
  }

  void setFilters({
    ServiceCategory? category,
    bool clearCategory = false,
    double? maxPrice,
    bool clearMaxPrice = false,
    double? minRating,
    bool clearMinRating = false,
    bool? verifiedOnly,
    bool? fastResponseOnly,
    bool? favoritesOnly,
    DiscoverySortOption? sortOption,
  }) {
    if (clearCategory) {
      _selectedCategory = null;
    } else if (category != null) {
      _selectedCategory = category;
    }

    if (clearMaxPrice) {
      _maxPriceFilter = null;
    } else if (maxPrice != null) {
      _maxPriceFilter = maxPrice;
    }

    if (clearMinRating) {
      _minRatingFilter = null;
    } else if (minRating != null) {
      _minRatingFilter = minRating;
    }

    if (verifiedOnly != null) _verifiedOnly = verifiedOnly;
    if (fastResponseOnly != null) _fastResponseOnly = fastResponseOnly;
    if (favoritesOnly != null) _favoritesOnly = favoritesOnly;
    if (sortOption != null) _sortOption = sortOption;

    _applySearchAndFilters();
    notifyListeners();
  }

  void resetAll() {
    _debouncer.cancel();
    _rawQuery = '';
    _selectedCategory = null;
    _maxPriceFilter = null;
    _minRatingFilter = null;
    _verifiedOnly = false;
    _fastResponseOnly = false;
    _favoritesOnly = false;
    _sortOption = DiscoverySortOption.relevance;
    _applySearchAndFilters();
    notifyListeners();
  }

  Future<void> toggleFavorite(String serviceId) async {
    _favoriteIds = await _repository.toggleFavorite(serviceId);
    if (_favoritesOnly) {
      _applySearchAndFilters();
    }
    notifyListeners();
  }

  void _applySearchAndFilters() {
    _parsedQuery = SmartSearchEngine.parseQuery(_rawQuery);

    // Combine explicit UI filters with Natural Language extracted filters
    final effectiveMaxPrice = _maxPriceFilter ?? _parsedQuery.maxPrice;
    final effectiveMinPrice = _parsedQuery.minPrice;
    final effectiveMinRating = _minRatingFilter ?? _parsedQuery.minRating;
    final effectiveVerified = _verifiedOnly || _parsedQuery.verifiedOnly;
    final effectiveFast = _fastResponseOnly || _parsedQuery.fastResponseOnly;

    final filteredPool = _allServices.where((service) {
      if (_selectedCategory != null && service.category != _selectedCategory) {
        return false;
      }
      if (_favoritesOnly && !_favoriteIds.contains(service.id)) {
        return false;
      }
      if (effectiveMaxPrice != null && service.basePrice > effectiveMaxPrice) {
        return false;
      }
      if (effectiveMinPrice != null && service.basePrice < effectiveMinPrice) {
        return false;
      }
      if (effectiveMinRating != null && service.rating < effectiveMinRating) {
        return false;
      }
      if (effectiveVerified && !service.isVerifiedProvider) {
        return false;
      }
      if (effectiveFast && service.responseTimeMinutes > 30) {
        return false;
      }
      return true;
    }).toList();

    var matches = SmartSearchEngine.search<ServiceItem>(
      items: filteredPool,
      query: _parsedQuery,
      fieldsBuilder: (s) => [
        SearchField(value: s.title, weight: 4.0, label: 'Title'),
        SearchField(value: s.category.label, weight: 3.0, label: 'Category'),
        SearchField(value: s.tags.join(' '), weight: 2.6, label: 'Tags'),
        SearchField(value: s.providerName, weight: 2.0, label: 'Provider'),
        SearchField(value: s.description, weight: 1.1, label: 'Description'),
      ],
    );

    switch (_sortOption) {
      case DiscoverySortOption.relevance:
        // Already sorted by smart score; tie-break by rating & featured
        if (_parsedQuery.tokens.isEmpty) {
          matches.sort((a, b) => b.item.rating.compareTo(a.item.rating));
        }
      case DiscoverySortOption.ratingHigh:
        matches.sort((a, b) => b.item.rating.compareTo(a.item.rating));
      case DiscoverySortOption.priceLow:
        matches.sort((a, b) => a.item.basePrice.compareTo(b.item.basePrice));
      case DiscoverySortOption.priceHigh:
        matches.sort((a, b) => b.item.basePrice.compareTo(a.item.basePrice));
      case DiscoverySortOption.fastestResponse:
        matches.sort(
          (a, b) => a.item.responseTimeMinutes
              .compareTo(b.item.responseTimeMinutes),
        );
    }

    _results = matches;
  }

  @override
  void dispose() {
    _debouncer.dispose();
    super.dispose();
  }
}
