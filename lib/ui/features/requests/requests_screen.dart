import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/smart_search_engine.dart';
import '../../../domain/models/service_request.dart';
import '../../core/widgets/empty_state_widget.dart';
import '../../core/widgets/error_retry_widget.dart';
import '../../core/widgets/highlighted_text.dart';
import '../../core/widgets/smart_search_bar.dart';
import '../../core/widgets/status_badge.dart';
import 'requests_view_model.dart';

class RequestsScreen extends StatefulWidget {
  const RequestsScreen({
    super.key,
    required this.onOpenRequestDetail,
    required this.onCreateRequest,
  });

  final ValueChanged<ServiceRequest> onOpenRequestDetail;
  final VoidCallback onCreateRequest;

  @override
  State<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<RequestsViewModel>();
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: vm.loadRequests,
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
                              'My Requests',
                              style: textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              'Track requirements & compare provider quotes',
                              style: textTheme.bodySmall?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: widget.onCreateRequest,
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('New'),
                      ),
                    ],
                  ),
                ),
              ),

              // Summary KPI Row
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _KpiCard(
                          label: 'Active',
                          value: '${vm.activeCount}',
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 10),
                        _KpiCard(
                          label: 'Open Quotes',
                          value: '${vm.pendingQuotesCount}',
                          color: AppColors.accentAmber,
                        ),
                        const SizedBox(width: 10),
                        _KpiCard(
                          label: 'Completed',
                          value: '${vm.completedCount}',
                          color: AppColors.success,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Smart Search Bar
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
                  child: SmartSearchBar(
                    controller: _searchController,
                    focusNode: _searchFocus,
                    hintText: 'Search by title, REQ ID, provider, or location...',
                    onChanged: vm.updateSearch,
                    onSubmitted: (q) {
                      vm.updateSearch(q);
                      _searchFocus.unfocus();
                    },
                    onClear: () {
                      _searchController.clear();
                      vm.updateSearch('');
                    },
                  ),
                ),
              ),

              // Status Filter Chips
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text('All (${vm.allRequests.length})'),
                          selected: vm.selectedStatus == null,
                          onSelected: (_) => vm.selectStatus(null),
                        ),
                      ),
                      ...RequestStatus.values.map(
                        (status) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(status.label),
                            selected: vm.selectedStatus == status,
                            onSelected: (_) => vm.selectStatus(status),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              if (vm.isLoading)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (vm.errorMessage != null)
                SliverFillRemaining(
                  child: ErrorRetryWidget(
                    message: vm.errorMessage!,
                    onRetry: vm.loadRequests,
                  ),
                )
              else if (vm.filteredRequests.isEmpty)
                SliverFillRemaining(
                  child: EmptyStateWidget(
                    icon: Icons.assignment_outlined,
                    title: 'No requests found',
                    subtitle: vm.searchQuery.isNotEmpty ||
                            vm.selectedStatus != null
                        ? 'No submitted requests match your current search or filter.'
                        : 'Submit your first requirement to start receiving provider quotes.',
                    actionLabel: vm.searchQuery.isNotEmpty ||
                            vm.selectedStatus != null
                        ? 'Clear Filters'
                        : 'Submit Requirement',
                    onAction: () {
                      if (vm.searchQuery.isNotEmpty ||
                          vm.selectedStatus != null) {
                        _searchController.clear();
                        vm.clearFilters();
                      } else {
                        widget.onCreateRequest();
                      }
                    },
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                  sliver: SliverList.separated(
                    itemCount: vm.filteredRequests.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final match = vm.filteredRequests[index];
                      final req = match.item;
                      final quotes = vm.responsesFor(req.id);
                      return _RequestCard(
                        match: match,
                        quoteCount: quotes.length,
                        onTap: () => widget.onOpenRequestDetail(req),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.match,
    required this.quoteCount,
    required this.onTap,
  });

  final SmartSearchMatch<ServiceRequest> match;
  final int quoteCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final req = match.item;
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
                children: [
                  Expanded(
                    flex: 3,
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: colors.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: HighlightedText(
                            text: req.id,
                            tokens: match.matchedTokens,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              req.category.icon,
                              size: 15,
                              color: req.category.color,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                req.category.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: textTheme.bodySmall?.copyWith(
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    flex: 2,
                    child: StatusBadge.fromRequestStatus(req.status),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              HighlightedText(
                text: req.title,
                tokens: match.matchedTokens,
                maxLines: 2,
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              HighlightedText(
                text: req.description,
                tokens: match.matchedTokens,
                maxLines: 2,
                style: textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.payments_outlined,
                              size: 15,
                              color: colors.primary,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Consumer<CurrencyController>(
                                builder: (_, currency, _) => Text(
                                  '${currency.format(req.budgetMin)}–${currency.format(req.budgetMax)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: colors.primary,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.calendar_today_outlined,
                              size: 14,
                              color: colors.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              DateFormat.MMMd().format(req.preferredDate),
                              style: TextStyle(
                                fontSize: 12,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: colors.primaryContainer.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$quoteCount ${quoteCount == 1 ? 'Quote' : 'Quotes'}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: colors.onPrimaryContainer,
                      ),
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
