import 'package:flutter_test/flutter_test.dart';
import 'package:service_epic/core/utils/smart_search_engine.dart';
import 'package:service_epic/data/services/seed_data.dart';
import 'package:service_epic/domain/models/service_item.dart';

void main() {
  group('SmartSearchEngine.parseQuery', () {
    test('extracts maxPrice, minRating, verifiedOnly, and fastResponseOnly', () {
      final parsed = SmartSearchEngine.parseQuery(
        'plumber under \$120 4.5+ stars verified urgent',
      );

      expect(parsed.maxPrice, 120);
      expect(parsed.minRating, 4.5);
      expect(parsed.verifiedOnly, isTrue);
      expect(parsed.fastResponseOnly, isTrue);
      expect(parsed.semanticQuery, 'plumber');
      expect(parsed.tokens, ['plumber']);
    });

    test('extracts price range', () {
      final parsed = SmartSearchEngine.parseQuery('web dev \$200-\$500');
      expect(parsed.minPrice, 200);
      expect(parsed.maxPrice, 500);
      expect(parsed.tokens, ['web', 'dev']);
    });
  });

  group('SmartSearchEngine.search', () {
    List<SmartSearchMatch<ServiceItem>> runSearch(String raw) {
      final parsed = SmartSearchEngine.parseQuery(raw);
      return SmartSearchEngine.search<ServiceItem>(
        items: SeedData.services,
        query: parsed,
        fieldsBuilder: (s) => [
          SearchField(value: s.title, weight: 4.0, label: 'Title'),
          SearchField(value: s.category.label, weight: 3.0, label: 'Category'),
          SearchField(value: s.tags.join(' '), weight: 2.6, label: 'Tags'),
          SearchField(value: s.providerName, weight: 2.0, label: 'Provider'),
          SearchField(value: s.description, weight: 1.1, label: 'Description'),
        ],
      );
    }

    test('handles typos via Damerau-Levenshtein fuzzy matching', () {
      final matches = runSearch('plubming');
      expect(matches, isNotEmpty);
      expect(matches.first.item.id, 'srv-01');
    });

    test('expands intent synonyms (e.g., leak -> plumbing)', () {
      final matches = runSearch('leak');
      expect(matches, isNotEmpty);
      expect(matches.first.item.id, 'srv-01');
    });

    test('ranks exact/high-weight title matches first', () {
      final matches = runSearch('flutter');
      expect(matches, isNotEmpty);
      expect(matches.first.item.id, 'srv-02');
    });
  });
}
