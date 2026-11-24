# ServiceEpic — Service Discovery & Request Management App

A client-side Flutter application for discovering services with an intelligent, typo-tolerant smart search engine, submitting structured service requirements, managing request lifecycles, and comparing/negotiating provider quotes.

## Key Features

- **Superb Smart Search Engine (`SmartSearchEngine`)**
  - **Damerau-Levenshtein Fuzzy Matching**: Handles typos and transpositions (e.g., `"plubming"` → Plumbing).
  - **Natural Language Query Parsing**: Extracts embedded constraints such as `"plumber under $120 4.5+ stars verified urgent"` into live budget, rating, verification, and response-time filters.
  - **Synonym & Intent Expansion**: Maps everyday terms (`"leak"`, `"pipe"` → Plumbing; `"website"`, `"app"` → Tech & Software; `"ac"` → HVAC).
  - **Multi-Field Weighted Scoring & Substring Highlighting**: Ranks results across Title, Category, Tags, Provider, and Description, highlighting matched terms directly in the UI.
  - **Search Everywhere**: Smart search is integrated across Service Discovery, Submitted Requests, and Provider Responses.
- **Service Discovery & Deep Service Details**
  - Category filtering, multi-facet filter sheet (price slider, min rating, verified pros, fast reply, sort order), featured carousel, saved favorites, and selectable service tiers/packages.
- **Requirement Submission & Validation**
  - Dynamic category-specific requirement fields, min/max budget cross-validation, date picker validation, contact email/phone validation, and inline error feedback.
- **Request Management & Provider Responses**
  - Track requests (`Open`, `Quotes Received`, `In Progress`, `Completed`, `Cancelled`), view chronological activity timelines, edit/cancel/reopen/complete requests, compare provider quotes against target budget, accept/decline quotes, and negotiate via inline messaging.
- **API Integration, Error Handling & Diagnostics**
  - `ServiceApiClient` powered by `package:http` with typed `AppException` / `Result<T>` error handling, JSON round-trip serialization, local-first persistence via `SharedPreferences`, and a **Settings → Simulate API Error** toggle to test retry flows.

## Architecture (MVVM + Repository Pattern)

```text
lib/
├── core/
│   ├── errors/          # AppException hierarchy & Result<T>
│   ├── theme/           # Material 3 light & dark themes
│   └── utils/           # SmartSearchEngine, Validators, Debouncer
├── data/
│   ├── repositories/    # ServiceRepository, RequestRepository
│   └── services/        # ServiceApiClient (REST + Mock Adapter), LocalStorageService, SeedData
├── domain/
│   └── models/          # Immutable ServiceItem, ServiceCategory, ServiceRequest, ProviderResponse
└── ui/
    ├── core/widgets/    # SmartSearchBar, HighlightedText, StatusBadge, ErrorRetryWidget, EmptyStateWidget
    └── features/
        ├── discovery/       # DiscoveryViewModel & DiscoveryScreen
        ├── service_detail/  # ServiceDetailScreen
        ├── submit_request/  # SubmitRequestViewModel & SubmitRequestScreen
        ├── requests/        # RequestsViewModel & RequestsScreen
        ├── request_detail/  # RequestDetailViewModel & RequestDetailScreen
        └── home_shell.dart  # NavigationShell & Settings/Diagnostics
```

## Build & Run

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```
