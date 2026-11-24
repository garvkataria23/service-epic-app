import 'dart:math';

/// Represents a weighted searchable field of an entity.
class SearchField {
  const SearchField({
    required this.value,
    required this.weight,
    required this.label,
  });

  final String value;
  final double weight;
  final String label;
}

/// Natural-language constraints automatically extracted from a search query
/// such as `"plumber under $120 4.5+ stars verified"`.
class ParsedSearchQuery {
  const ParsedSearchQuery({
    required this.rawQuery,
    required this.semanticQuery,
    required this.tokens,
    this.maxPrice,
    this.minPrice,
    this.minRating,
    this.verifiedOnly = false,
    this.fastResponseOnly = false,
  });

  final String rawQuery;
  final String semanticQuery;
  final List<String> tokens;
  final double? maxPrice;
  final double? minPrice;
  final double? minRating;
  final bool verifiedOnly;
  final bool fastResponseOnly;

  bool get hasExtractedFilters =>
      maxPrice != null ||
      minPrice != null ||
      minRating != null ||
      verifiedOnly ||
      fastResponseOnly;
}

/// Scored search result with explanation and matched tokens for highlighting.
class SmartSearchMatch<T> {
  const SmartSearchMatch({
    required this.item,
    required this.score,
    required this.matchReason,
    required this.matchedTokens,
  });

  final T item;
  final double score;
  final String matchReason;
  final Set<String> matchedTokens;
}

/// High-precision, typo-tolerant, intent-aware Smart Search Engine
/// used across Services, Submitted Requests, and Provider Responses.
class SmartSearchEngine {
  SmartSearchEngine._();

  static const Map<String, List<String>> _synonymMap = {
    'leak': ['plumbing', 'pipe', 'water', 'drain', 'faucet'],
    'pipe': ['plumbing', 'leak', 'drain'],
    'tap': ['plumbing', 'faucet', 'sink'],
    'toilet': ['plumbing', 'bathroom', 'drain'],
    'ac': ['hvac', 'air conditioning', 'cooling', 'repair'],
    'aircon': ['hvac', 'air conditioning', 'cooling'],
    'heater': ['hvac', 'heating', 'thermostat'],
    'wire': ['electrical', 'electrician', 'wiring', 'circuit'],
    'power': ['electrical', 'electrician', 'outlet'],
    'light': ['electrical', 'lighting', 'fixture'],
    'app': ['mobile', 'flutter', 'ios', 'android', 'software'],
    'website': ['web', 'frontend', 'backend', 'fullstack', 'seo'],
    'site': ['web', 'website', 'landing'],
    'code': ['software', 'development', 'programming', 'api'],
    'bug': ['software', 'debugging', 'fix', 'api'],
    'logo': ['design', 'branding', 'graphic', 'illustrator'],
    'ui': ['design', 'ux', 'figma', 'prototype'],
    'maid': ['cleaning', 'housekeeping', 'sanitize'],
    'dirt': ['cleaning', 'deep clean', 'carpet'],
    'sofa': ['cleaning', 'upholstery', 'furniture'],
    'photo': ['photography', 'shoot', 'camera', 'portrait'],
    'video': ['videography', 'editing', 'media', 'event'],
    'wedding': ['events', 'photography', 'catering', 'dj'],
    'car': ['auto', 'mechanic', 'detailing', 'vehicle'],
    'move': ['moving', 'transport', 'relocation', 'packing'],
    'tutor': ['tutoring', 'coaching', 'math', 'language', 'learning'],
    'tax': ['accounting', 'consulting', 'finance', 'bookkeeping'],
    'fit': ['fitness', 'trainer', 'wellness', 'yoga'],
  };

  /// Extracts natural-language filters (price, rating, urgency, verified)
  /// and returns clean semantic tokens.
  static ParsedSearchQuery parseQuery(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return const ParsedSearchQuery(
        rawQuery: '',
        semanticQuery: '',
        tokens: [],
      );
    }

    var working = trimmed.toLowerCase();
    double? maxPrice;
    double? minPrice;
    double? minRating;
    var verifiedOnly = false;
    var fastResponseOnly = false;

    // Match range: "$50-$150" or "50 to 150"
    final rangeRegex = RegExp(
      r'\$?(\d+(?:\.\d+)?)\s*(?:-|to)\s*\$?(\d+(?:\.\d+)?)',
      caseSensitive: false,
    );
    final rangeMatch = rangeRegex.firstMatch(working);
    if (rangeMatch != null) {
      minPrice = double.tryParse(rangeMatch.group(1)!);
      maxPrice = double.tryParse(rangeMatch.group(2)!);
      working = working.replaceFirst(rangeMatch.group(0)!, ' ');
    }

    // Match max price: "under $120", "below 100", "max 80", "< 150"
    final maxPriceRegex = RegExp(
      r'(?:under|below|max|less than|<=?)\s*\$?(\d+(?:\.\d+)?)',
      caseSensitive: false,
    );
    final maxMatch = maxPriceRegex.firstMatch(working);
    if (maxMatch != null) {
      maxPrice = double.tryParse(maxMatch.group(1)!);
      working = working.replaceFirst(maxMatch.group(0)!, ' ');
    }

    // Match min price: "over $50", "above 100", ">= 50"
    final minPriceRegex = RegExp(
      r'(?:over|above|min|more than|>=?)\s*\$?(\d+(?:\.\d+)?)',
      caseSensitive: false,
    );
    final minMatch = minPriceRegex.firstMatch(working);
    if (minMatch != null) {
      minPrice = double.tryParse(minMatch.group(1)!);
      working = working.replaceFirst(minMatch.group(0)!, ' ');
    }

    // Match rating: "4.5+ stars", "4.5+", "rating > 4.2"
    final ratingRegex = RegExp(
      r'(?:rating\s*>=?\s*)?([34](?:\.\d+)?)\s*\+?\s*(?:stars?|rating)?',
      caseSensitive: false,
    );
    final ratingMatch = ratingRegex.firstMatch(working);
    if (ratingMatch != null &&
        (ratingMatch.group(0)!.contains('+') ||
            ratingMatch.group(0)!.contains('star') ||
            ratingMatch.group(0)!.contains('rating'))) {
      final parsed = double.tryParse(ratingMatch.group(1)!);
      if (parsed != null && parsed <= 5.0) {
        minRating = parsed;
        working = working.replaceFirst(ratingMatch.group(0)!, ' ');
      }
    }

    if (working.contains('top rated') || working.contains('best rated')) {
      minRating ??= 4.7;
      working = working
          .replaceAll('top rated', ' ')
          .replaceAll('best rated', ' ');
    }

    if (RegExp(r'\b(verified|certified|pro)\b').hasMatch(working)) {
      verifiedOnly = true;
      working = working.replaceAll(RegExp(r'\b(verified|certified|pro)\b'), ' ');
    }

    if (RegExp(r'\b(urgent|fast|quick|same day|asap|today)\b')
        .hasMatch(working)) {
      fastResponseOnly = true;
      working = working.replaceAll(
        RegExp(r'\b(urgent|fast|quick|same day|asap|today)\b'),
        ' ',
      );
    }

    final clean = working.replaceAll(RegExp(r'\s+'), ' ').trim();
    final tokens = _tokenize(clean);

    return ParsedSearchQuery(
      rawQuery: trimmed,
      semanticQuery: clean,
      tokens: tokens,
      maxPrice: maxPrice,
      minPrice: minPrice,
      minRating: minRating,
      verifiedOnly: verifiedOnly,
      fastResponseOnly: fastResponseOnly,
    );
  }

  /// Scores and ranks a list of items against a parsed query.
  static List<SmartSearchMatch<T>> search<T>({
    required List<T> items,
    required ParsedSearchQuery query,
    required List<SearchField> Function(T item) fieldsBuilder,
    double minThreshold = 0.22,
  }) {
    if (query.tokens.isEmpty) {
      return items
          .map(
            (item) => SmartSearchMatch<T>(
              item: item,
              score: 1.0,
              matchReason: '',
              matchedTokens: const {},
            ),
          )
          .toList();
    }

    final results = <SmartSearchMatch<T>>[];
    final fullQuery = query.semanticQuery.toLowerCase();

    for (final item in items) {
      final fields = fieldsBuilder(item);
      var totalScore = 0.0;
      var bestFieldWeight = 0.0;
      var bestReason = '';
      final matchedTokens = <String>{};

      for (final token in query.tokens) {
        var tokenBestScore = 0.0;
        var tokenReason = '';

        // Expand token with synonyms if available
        final expandedTerms = <String>[
          token,
          ...?_synonymMap[token],
        ];

        for (final field in fields) {
          final fieldText = field.value.toLowerCase();
          if (fieldText.isEmpty) continue;

          // 1. Exact full-query substring boost
          if (fullQuery.length >= 3 && fieldText.contains(fullQuery)) {
            final s = 1.0 * field.weight;
            if (s > tokenBestScore) {
              tokenBestScore = s;
              tokenReason = 'Exact match in ${field.label}';
              matchedTokens.add(token);
            }
          }

          // 2. Token / Synonym matching against words in field
          final fieldWords = _tokenize(fieldText);
          for (var i = 0; i < expandedTerms.length; i++) {
            final term = expandedTerms[i];
            final isSynonym = i > 0;
            final synonymPenalty = isSynonym ? 0.65 : 1.0;

            if (fieldText.contains(term)) {
              final isWholeWord = fieldWords.contains(term);
              final s =
                  (isWholeWord ? 0.95 : 0.78) * field.weight * synonymPenalty;
              if (s > tokenBestScore) {
                tokenBestScore = s;
                tokenReason = isSynonym
                    ? 'Smart intent: "$term" in ${field.label}'
                    : 'Matched ${field.label}';
                matchedTokens.add(isSynonym ? term : token);
              }
              continue;
            }

            // 3. Fuzzy edit-distance matching for typos (e.g. "plubming")
            for (final word in fieldWords) {
              if (word.length < 3 || term.length < 3) continue;
              if (word.startsWith(term)) {
                final s = 0.85 * field.weight * synonymPenalty;
                if (s > tokenBestScore) {
                  tokenBestScore = s;
                  tokenReason = 'Prefix match in ${field.label}';
                  matchedTokens.add(word);
                }
                continue;
              }

              final sim = _damerauSimilarity(term, word);
              if (sim >= 0.72) {
                final s = sim * 0.82 * field.weight * synonymPenalty;
                if (s > tokenBestScore) {
                  tokenBestScore = s;
                  tokenReason = 'Fuzzy match "$word"';
                  matchedTokens.add(word);
                }
              }
            }

            // 4. Compact subsequence match (e.g. "webdev" -> "web development")
            if (!isSynonym &&
                term.length >= 4 &&
                _isSubsequence(term, fieldText.replaceAll(' ', ''))) {
              final s = 0.55 * field.weight;
              if (s > tokenBestScore) {
                tokenBestScore = s;
                tokenReason = 'Shorthand match in ${field.label}';
                matchedTokens.add(token);
              }
            }
          }
        }

        totalScore += tokenBestScore;
        if (tokenBestScore > bestFieldWeight) {
          bestFieldWeight = tokenBestScore;
          bestReason = tokenReason;
        }
      }

      // Normalize by query token count so multi-word queries reward full coverage
      final normalized = totalScore / query.tokens.length;
      if (normalized >= minThreshold) {
        results.add(
          SmartSearchMatch<T>(
            item: item,
            score: normalized,
            matchReason: bestReason,
            matchedTokens: matchedTokens,
          ),
        );
      }
    }

    results.sort((a, b) => b.score.compareTo(a.score));
    return results;
  }

  static List<String> _tokenize(String input) {
    return input
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .where((t) => t.isNotEmpty)
        .toList();
  }

  static bool _isSubsequence(String needle, String haystack) {
    var i = 0;
    for (var j = 0; j < haystack.length && i < needle.length; j++) {
      if (needle[i] == haystack[j]) i++;
    }
    return i == needle.length;
  }

  /// Computes normalized Damerau-Levenshtein similarity in [0.0, 1.0],
  /// accounting for adjacent transpositions (common typing mistakes).
  static double _damerauSimilarity(String a, String b) {
    if (a == b) return 1.0;
    final lenA = a.length;
    final lenB = b.length;
    if (lenA == 0 || lenB == 0) return 0.0;
    if ((lenA - lenB).abs() > 3) return 0.0;

    final d = List.generate(lenA + 1, (_) => List<int>.filled(lenB + 1, 0));
    for (var i = 0; i <= lenA; i++) {
      d[i][0] = i;
    }
    for (var j = 0; j <= lenB; j++) {
      d[0][j] = j;
    }

    for (var i = 1; i <= lenA; i++) {
      for (var j = 1; j <= lenB; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        var minVal = min(
          d[i - 1][j] + 1,
          min(d[i][j - 1] + 1, d[i - 1][j - 1] + cost),
        );
        if (i > 1 &&
            j > 1 &&
            a[i - 1] == b[j - 2] &&
            a[i - 2] == b[j - 1]) {
          minVal = min(minVal, d[i - 2][j - 2] + cost);
        }
        d[i][j] = minVal;
      }
    }

    final maxLen = max(lenA, lenB);
    return 1.0 - (d[lenA][lenB] / maxLen);
  }
}
