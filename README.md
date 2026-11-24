# ServiceEpic — Service Discovery, Request Management & Escrow Payment App

A full-featured client-side Flutter application covering **Authentication → Smart Service Discovery → Requirement Submission → Request & Quote Management → Escrow Payment Gateway → Post-Completion Reviews**.

## Key Features

- **Authentication & Client Account (`AuthScreen`, `AuthRepository`)**
  - Email/Password Sign In, Sign Up with validation, Forgot Password flow, and One-Tap Demo Client Login (`garv.client@example.com`).
  - Persistent session, editable profile, saved cards & addresses, dark mode, and Sign Out.
- **Superb Smart Search Engine (`SmartSearchEngine`)**
  - **Damerau-Levenshtein Fuzzy Matching**: Handles typos and transpositions (e.g., `"plubming"` → Plumbing).
  - **Natural Language Query Parsing**: Extracts embedded constraints (`"plumber under $120 4.5+ stars verified urgent"`) into live budget, rating, verification, and response-time filters.
  - **Synonym & Intent Expansion**: Maps everyday terms (`"leak"`, `"pipe"`, `"ac"`, `"website"`, `"app"`) to relevant services.
  - **Multi-Field Weighted Scoring & Substring Highlighting**: Ranks across Title, Category, Tags, Provider, and Description, highlighting matched terms directly in the UI.
- **Service Discovery & Deep Service Details**
  - Category chips, multi-facet filter sheet (price slider, min rating, verified pros, fast reply, sort order), featured carousel, saved favorites, selectable service tiers/packages, and an interactive **Notifications Center**.
- **Requirement Submission & Request Management**
  - Dynamic category-specific fields, min/max budget cross-validation, date picker validation, contact validation, and auto-filled client details.
  - Status tracking (`Open`, `Quotes Received`, `In Progress`, `Completed`, `Cancelled`), chronological activity timeline, quote comparison, and inline provider messaging.
- **Secure Escrow Payment Gateway & Wallet (`CheckoutScreen`, `TransactionsScreen`)**
  - Multi-method checkout: **Credit/Debit Card** (Luhn checksum, brand detection, expiry/CVV validation, save card), **UPI / Instant Bank**, and **ServiceEpic Wallet** (with instant top-up).
  - Promo code engine (`EPIC10`, `WELCOME15`, `PRO20`), 3% Escrow Protection Fee breakdown, **3D-Secure OTP Verification** (demo OTP `1234`), and itemized **Payment Receipt**.
  - **Escrow Lifecycle**: Funds are held securely in Escrow on quote acceptance and automatically released to the provider when the client marks the job completed with a **5-Star Rating & Review**.
- **API Integration, Error Handling & Diagnostics**
  - `ServiceApiClient` (`package:http`) with typed `AppException` / `Result<T>` error handling, JSON serialization, local-first persistence (`SharedPreferences`), and a **Profile → Simulate API / Network Error** toggle to test failure & retry flows.

## Architecture (MVVM + Repository Pattern)

```text
lib/
├── core/
│   ├── errors/          # AppException hierarchy & Result<T>
│   ├── theme/           # Material 3 light & dark themes
│   └── utils/           # SmartSearchEngine, Validators, Debouncer
├── data/
│   ├── repositories/    # AuthRepository, ServiceRepository, RequestRepository, PaymentRepository
│   └── services/        # ServiceApiClient (REST + Mock Adapter), LocalStorageService, SeedData
├── domain/
│   └── models/          # UserProfile, ServiceItem, ServiceCategory, ServiceRequest, ProviderResponse, PaymentTransaction, AppNotification
└── ui/
    ├── core/widgets/    # SmartSearchBar, HighlightedText, StatusBadge, ErrorRetryWidget, EmptyStateWidget
    └── features/
        ├── auth/            # AuthViewModel & AuthScreen
        ├── discovery/       # DiscoveryViewModel & DiscoveryScreen
        ├── service_detail/  # ServiceDetailScreen
        ├── submit_request/  # SubmitRequestViewModel & SubmitRequestScreen
        ├── requests/        # RequestsViewModel & RequestsScreen
        ├── request_detail/  # RequestDetailViewModel & RequestDetailScreen
        ├── payment/         # CheckoutScreen & TransactionsScreen
        └── home_shell.dart  # NavigationShell, Notifications & Profile/Settings
```

## Build & Run

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```
