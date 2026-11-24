import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/smart_search_engine.dart';
import '../../../domain/models/service_category.dart';
import '../../../domain/models/service_item.dart';
import '../../core/widgets/empty_state_widget.dart';
import '../../core/widgets/error_retry_widget.dart';
import '../../core/widgets/highlighted_text.dart';
import '../../core/widgets/smart_search_bar.dart';
import '../service_detail/service_detail_screen.dart';
import 'discovery_view_model.dart';

class DiscoveryScreen extends StatefulWidget {
  const DiscoveryScreen({
    super.key,
    required this.onRequestService,
    required this.onPostCustomRequest,
    this.unreadNotifications = 0,
    this.onNotificationsTap,
  });

  final void Function(ServiceItem service, ServicePackage? selectedPackage)
      onRequestService;
  final VoidCallback onPostCustomRequest;
  final int unreadNotifications;
  final VoidCallback? onNotificationsTap;

  @override
  State<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends State<DiscoveryScreen> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  bool _showSuggestions = false;

  @override
  void initState() {
    super.initState();
    _searchFocus.addListener(() {
      if (mounted) {
        setState(() => _showSuggestions = _searchFocus.hasFocus);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _applyQuery(DiscoveryViewModel vm, String q) {
    _searchController.text = q;
    _searchController.selection = TextSelection.collapsed(offset: q.length);
    vm.submitSearch(q);
    _searchFocus.unfocus();
  }

  void _openFilterSheet(DiscoveryViewModel vm) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _FilterBottomSheet(vm: vm),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<DiscoveryViewModel>();
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => vm.loadServices(forceRefresh: true),
          child: CustomScrollView(
            slivers: [
              // Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Discover Services',
                              style: textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Smart search by skill, budget, rating or intent',
                              style: textTheme.bodySmall?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (widget.onNotificationsTap != null)
                        Badge(
                          isLabelVisible: widget.unreadNotifications > 0,
                          label: Text('${widget.unreadNotifications}'),
                          child: IconButton(
                            tooltip: 'Notifications',
                            onPressed: widget.onNotificationsTap,
                            icon: const Icon(Icons.notifications_outlined),
                          ),
                        ),
                      const SizedBox(width: 4),
                      FilledButton.tonalIcon(
                        onPressed: widget.onPostCustomRequest,
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Post Brief'),
                      ),
                    ],
                  ),
                ),
              ),

              // Smart Search Bar
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                  child: SmartSearchBar(
                    controller: _searchController,
                    focusNode: _searchFocus,
                    hintText: 'Try "plumber under \$120" or "urgent flutter"',
                    onChanged: vm.updateQuery,
                    onSubmitted: (val) {
                      vm.submitSearch(val);
                      _searchFocus.unfocus();
                    },
                    onClear: () {
                      _searchController.clear();
                      vm.updateQuery('');
                    },
                    onFilterTap: () => _openFilterSheet(vm),
                    activeFilterCount: vm.activeFilterCount,
                  ),
                ),
              ),

              // Focus-aware Smart Suggestions Panel
              if (_showSuggestions)
                SliverToBoxAdapter(
                  child: _SuggestionsPanel(
                    vm: vm,
                    onSelectQuery: (q) => _applyQuery(vm, q),
                  ),
                ),

              // Natural Language Extracted Filters Banner
              if (vm.parsedQuery.hasExtractedFilters)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                    child: _NaturalLanguageBanner(parsed: vm.parsedQuery),
                  ),
                ),

              // Category Horizontal Strip
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 46,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: const Text('All'),
                          selected: vm.selectedCategory == null,
                          onSelected: (_) => vm.selectCategory(null),
                        ),
                      ),
                      ...ServiceCategory.values.map(
                        (cat) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            avatar: Icon(
                              cat.icon,
                              size: 16,
                              color: vm.selectedCategory == cat
                                  ? colors.onPrimaryContainer
                                  : cat.color,
                            ),
                            label: Text(cat.label),
                            selected: vm.selectedCategory == cat,
                            onSelected: (_) => vm.selectCategory(cat),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Quick Filter Pills
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                    children: [
                      _QuickPill(
                        label: 'Verified Pros',
                        icon: Icons.verified_rounded,
                        selected: vm.verifiedOnly,
                        onTap: () => vm.setFilters(
                          verifiedOnly: !vm.verifiedOnly,
                        ),
                      ),
                      _QuickPill(
                        label: '4.8+ ★',
                        icon: Icons.star_rounded,
                        selected: vm.minRatingFilter == 4.8,
                        onTap: () => vm.setFilters(
                          minRating: vm.minRatingFilter == 4.8 ? null : 4.8,
                          clearMinRating: vm.minRatingFilter == 4.8,
                        ),
                      ),
                      _QuickPill(
                        label: 'Fast Reply (≤30m)',
                        icon: Icons.bolt_rounded,
                        selected: vm.fastResponseOnly,
                        onTap: () => vm.setFilters(
                          fastResponseOnly: !vm.fastResponseOnly,
                        ),
                      ),
                      _QuickPill(
                        label: 'Saved (${vm.favoriteIds.length})',
                        icon: Icons.favorite_rounded,
                        selected: vm.favoritesOnly,
                        onTap: () => vm.setFilters(
                          favoritesOnly: !vm.favoritesOnly,
                        ),
                      ),
                      if (vm.hasActiveSearchOrFilters)
                        TextButton.icon(
                          onPressed: () {
                            _searchController.clear();
                            vm.resetAll();
                          },
                          icon: const Icon(Icons.clear_all_rounded, size: 18),
                          label: const Text('Reset'),
                        ),
                    ],
                  ),
                ),
              ),

              // Body States
              if (vm.isLoading)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (vm.errorMessage != null)
                SliverFillRemaining(
                  child: ErrorRetryWidget(
                    message: vm.errorMessage!,
                    onRetry: () => vm.loadServices(forceRefresh: true),
                  ),
                )
              else if (vm.results.isEmpty)
                SliverFillRemaining(
                  child: EmptyStateWidget(
                    icon: Icons.search_off_rounded,
                    title: 'No matching services found',
                    subtitle:
                        'Try broadening your budget, clearing filters, or searching with fewer keywords.',
                    actionLabel: 'Clear All Filters',
                    onAction: () {
                      _searchController.clear();
                      vm.resetAll();
                    },
                  ),
                )
              else ...[
                // Featured Carousel when browsing cleanly
                if (!vm.hasActiveSearchOrFilters &&
                    vm.featuredServices.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                          child: Text(
                            'Featured Top Providers',
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        SizedBox(
                          height: 158,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: vm.featuredServices.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 12),
                            itemBuilder: (context, idx) {
                              final item = vm.featuredServices[idx];
                              return _FeaturedServiceCard(
                                service: item,
                                onTap: () => _openDetail(vm, item),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                // Results Header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Row(
                      children: [
                        Text(
                          vm.hasActiveSearchOrFilters
                              ? '${vm.results.length} Smart Matches'
                              : 'All Services (${vm.results.length})',
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          vm.sortOption.label,
                          style: textTheme.bodySmall?.copyWith(
                            color: colors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Service Cards List
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  sliver: SliverList.separated(
                    itemCount: vm.results.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final match = vm.results[index];
                      return _ServiceCard(
                        match: match,
                        isFavorite: vm.favoriteIds.contains(match.item.id),
                        onToggleFavorite: () =>
                            vm.toggleFavorite(match.item.id),
                        onTap: () => _openDetail(vm, match.item),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _openDetail(DiscoveryViewModel vm, ServiceItem service) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChangeNotifierProvider.value(
          value: vm,
          child: Builder(
            builder: (ctx) {
              final currentVm = ctx.watch<DiscoveryViewModel>();
              return ServiceDetailScreen(
                service: service,
                isFavorite: currentVm.favoriteIds.contains(service.id),
                onToggleFavorite: () => currentVm.toggleFavorite(service.id),
                onRequestService: (srv, pkg) {
                  Navigator.of(ctx).pop();
                  widget.onRequestService(srv, pkg);
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SuggestionsPanel extends StatelessWidget {
  const _SuggestionsPanel({
    required this.vm,
    required this.onSelectQuery,
  });

  final DiscoveryViewModel vm;
  final ValueChanged<String> onSelectQuery;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final suggestions = vm.smartSuggestions;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 2, 16, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (vm.recentSearches.isNotEmpty && vm.rawQuery.isEmpty) ...[
            Row(
              children: [
                Text(
                  'Recent Searches',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colors.onSurfaceVariant,
                      ),
                ),
                const Spacer(),
                InkWell(
                  onTap: vm.clearRecentSearches,
                  child: Text(
                    'Clear',
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: vm.recentSearches
                  .map(
                    (q) => InputChip(
                      label: Text(q, style: const TextStyle(fontSize: 12)),
                      onPressed: () => onSelectQuery(q),
                      onDeleted: () => vm.removeRecentSearch(q),
                      visualDensity: VisualDensity.compact,
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 10),
          ],
          Text(
            vm.rawQuery.isEmpty ? 'Try Smart Queries' : 'Smart Suggestions',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colors.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: suggestions
                .map(
                  (s) => ActionChip(
                    avatar: Icon(
                      Icons.auto_awesome_rounded,
                      size: 14,
                      color: colors.primary,
                    ),
                    label: Text(s, style: const TextStyle(fontSize: 12)),
                    onPressed: () => onSelectQuery(s),
                    visualDensity: VisualDensity.compact,
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _NaturalLanguageBanner extends StatelessWidget {
  const _NaturalLanguageBanner({required this.parsed});

  final ParsedSearchQuery parsed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final pills = <String>[];
    if (parsed.maxPrice != null) {
      pills.add('Max \$${parsed.maxPrice!.toStringAsFixed(0)}');
    }
    if (parsed.minPrice != null) {
      pills.add('Min \$${parsed.minPrice!.toStringAsFixed(0)}');
    }
    if (parsed.minRating != null) {
      pills.add('${parsed.minRating!.toStringAsFixed(1)}+ ★');
    }
    if (parsed.verifiedOnly) pills.add('Verified Only');
    if (parsed.fastResponseOnly) pills.add('Fast Reply');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colors.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.psychology_rounded, size: 18, color: colors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Smart filters:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: colors.onPrimaryContainer,
                  ),
                ),
                ...pills.map(
                  (p) => Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      p,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: colors.primary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickPill extends StatelessWidget {
  const _QuickPill({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        avatar: Icon(icon, size: 15),
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: selected,
        onSelected: (_) => onTap(),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class _FeaturedServiceCard extends StatelessWidget {
  const _FeaturedServiceCard({
    required this.service,
    required this.onTap,
  });

  final ServiceItem service;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      width: 245,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: service.category.color.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        service.category.icon,
                        size: 18,
                        color: service.category.color,
                      ),
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.star_rounded,
                      size: 16,
                      color: AppColors.accentAmber,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      service.rating.toStringAsFixed(1),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  service.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    height: 1.25,
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        service.providerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Text(
                      'From \$${service.basePrice.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: colors.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({
    required this.match,
    required this.isFavorite,
    required this.onToggleFavorite,
    required this.onTap,
  });

  final SmartSearchMatch<ServiceItem> match;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final service = match.item;
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: service.category.color.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      service.category.icon,
                      color: service.category.color,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: HighlightedText(
                                text: service.title,
                                tokens: match.matchedTokens,
                                maxLines: 2,
                                style: textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  height: 1.25,
                                ),
                              ),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              onPressed: onToggleFavorite,
                              icon: Icon(
                                isFavorite
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_border_rounded,
                                size: 20,
                                color: isFavorite
                                    ? AppColors.error
                                    : colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Flexible(
                              child: HighlightedText(
                                text: service.providerName,
                                tokens: match.matchedTokens,
                                style: textTheme.bodySmall?.copyWith(
                                  color: colors.onSurfaceVariant,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            if (service.isVerifiedProvider) ...[
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.verified_rounded,
                                size: 14,
                                color: AppColors.info,
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              HighlightedText(
                text: service.description,
                tokens: match.matchedTokens,
                maxLines: 2,
                style: textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              if (match.matchReason.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: colors.secondaryContainer.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.auto_awesome_rounded,
                        size: 12,
                        color: colors.onSecondaryContainer,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        match.matchReason,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: colors.onSecondaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    Icons.star_rounded,
                    size: 16,
                    color: AppColors.accentAmber,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '${service.rating.toStringAsFixed(1)} (${service.reviewCount})',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    Icons.bolt_rounded,
                    size: 15,
                    color: colors.primary,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    service.formattedResponseTime,
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'From \$${service.basePrice.toStringAsFixed(0)}',
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: colors.primary,
                    ),
                  ),
                  Text(
                    ' / ${service.priceUnit}',
                    style: textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterBottomSheet extends StatefulWidget {
  const _FilterBottomSheet({required this.vm});

  final DiscoveryViewModel vm;

  @override
  State<_FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<_FilterBottomSheet> {
  late double _maxPrice;
  late bool _hasMaxPrice;
  late double? _minRating;
  late bool _verifiedOnly;
  late bool _fastResponseOnly;
  late DiscoverySortOption _sortOption;

  @override
  void initState() {
    super.initState();
    _hasMaxPrice = widget.vm.maxPriceFilter != null;
    _maxPrice = widget.vm.maxPriceFilter ?? 500;
    _minRating = widget.vm.minRatingFilter;
    _verifiedOnly = widget.vm.verifiedOnly;
    _fastResponseOnly = widget.vm.fastResponseOnly;
    _sortOption = widget.vm.sortOption;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Filters & Sorting',
                style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  widget.vm.resetAll();
                  Navigator.pop(context);
                },
                child: const Text('Reset All'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('Sort By', style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: DiscoverySortOption.values
                .map(
                  (opt) => ChoiceChip(
                    label: Text(opt.label),
                    selected: _sortOption == opt,
                    onSelected: (_) => setState(() => _sortOption = opt),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                'Maximum Starting Price',
                style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Switch(
                value: _hasMaxPrice,
                onChanged: (v) => setState(() => _hasMaxPrice = v),
              ),
            ],
          ),
          if (_hasMaxPrice)
            Slider(
              value: _maxPrice,
              min: 50,
              max: 600,
              divisions: 11,
              label: '\$${_maxPrice.toStringAsFixed(0)}',
              onChanged: (v) => setState(() => _maxPrice = v),
            ),
          const SizedBox(height: 8),
          Text(
            'Minimum Rating',
            style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [null, 4.0, 4.5, 4.8]
                .map(
                  (r) => ChoiceChip(
                    label: Text(r == null ? 'Any' : '$r+ ★'),
                    selected: _minRating == r,
                    onSelected: (_) => setState(() => _minRating = r),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Verified Providers Only'),
            value: _verifiedOnly,
            onChanged: (v) => setState(() => _verifiedOnly = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Fast Response (≤ 30 mins)'),
            value: _fastResponseOnly,
            onChanged: (v) => setState(() => _fastResponseOnly = v),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                widget.vm.setFilters(
                  maxPrice: _hasMaxPrice ? _maxPrice : null,
                  clearMaxPrice: !_hasMaxPrice,
                  minRating: _minRating,
                  clearMinRating: _minRating == null,
                  verifiedOnly: _verifiedOnly,
                  fastResponseOnly: _fastResponseOnly,
                  sortOption: _sortOption,
                );
                Navigator.pop(context);
              },
              child: const Text('Apply Filters'),
            ),
          ),
        ],
      ),
    );
  }
}
