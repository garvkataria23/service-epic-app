import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/repositories/payment_repository.dart';
import '../../../domain/models/payment_transaction.dart';
import '../../../domain/models/provider_response.dart';
import '../../../domain/models/service_request.dart';
import '../../core/widgets/confirmation_banner.dart';
import '../../core/widgets/empty_state_widget.dart';
import '../../core/widgets/error_retry_widget.dart';
import '../../core/widgets/status_badge.dart';
import '../auth/auth_view_model.dart';
import '../compare/compare_screen.dart';
import '../payment/checkout_screen.dart';
import 'request_detail_view_model.dart';

class RequestDetailScreen extends StatefulWidget {
  const RequestDetailScreen({
    super.key,
    required this.onEditRequest,
    required this.onRequestChanged,
  });

  final Future<ServiceRequest?> Function(ServiceRequest request) onEditRequest;
  final VoidCallback onRequestChanged;

  @override
  State<RequestDetailScreen> createState() => _RequestDetailScreenState();
}

class _RequestDetailScreenState extends State<RequestDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _quoteSearchController = TextEditingController();
  ConfirmationBannerData? _banner;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _quoteSearchController.dispose();
    super.dispose();
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _openCompleteAndReviewDialog(
    RequestDetailViewModel vm,
    ServiceRequest req,
  ) async {
    var selectedRating = 5.0;
    final reviewController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Complete & Release Escrow'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Confirm that the service was delivered satisfactorily. Escrow funds will be released to the provider.',
              ),
              const SizedBox(height: 14),
              const Text(
                'Rate Provider:',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  final star = i + 1;
                  return IconButton(
                    onPressed: () =>
                        setDialogState(() => selectedRating = star.toDouble()),
                    icon: Icon(
                      star <= selectedRating
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      color: AppColors.accentAmber,
                      size: 30,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: reviewController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Write a short review (optional)',
                  hintText: 'Share your experience...',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Confirm & Release'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && mounted) {
      final paymentRepo = context.read<PaymentRepository>();
      await paymentRepo.releaseEscrowForRequest(req.id);
      final ok = await vm.completeWithReview(
        rating: selectedRating,
        review: reviewController.text,
      );
      if (ok && mounted) {
        widget.onRequestChanged();
        setState(() {
          _banner = ConfirmationBannerData(
            title: 'Job Completed & Escrow Released',
            badgeText: '${selectedRating.toStringAsFixed(1)} ★',
            subtitle:
                '${req.id} marked completed. Escrow funds released to provider and review saved.',
            tone: ConfirmationTone.success,
          );
        });
      }
    }
    reviewController.dispose();
  }

  Future<void> _openCancelInProgressDialog(
    RequestDetailViewModel vm,
    ServiceRequest req,
  ) async {
    final user = context.read<AuthViewModel>().currentUser;
    if (user == null) return;
    final reasons = [
      'Specialist unavailable / delayed',
      'Scope changed before work began',
      'Found an alternative provider',
    ];
    var selectedReason = reasons.first;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Cancel & Refund Escrow'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Escrow funds for this request will be refunded instantly to your Epic Wallet.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 10),
              ...reasons.map(
                (r) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    selectedReason == r
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_off_rounded,
                    size: 18,
                    color: selectedReason == r
                        ? Theme.of(ctx).colorScheme.primary
                        : null,
                  ),
                  title: Text(r, style: const TextStyle(fontSize: 13)),
                  onTap: () => setDialogState(() => selectedReason = r),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep Active'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Cancel & Refund'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && mounted) {
      final paymentRepo = context.read<PaymentRepository>();
      final currency = context.read<CurrencyController>();
      final refunded = await paymentRepo.refundEscrowForReference(
        req.id,
        user: user,
        reason: selectedReason,
      );
      final ok = await vm.cancelInProgressWithReason(selectedReason);
      if (ok && mounted) {
        context.read<AuthViewModel>().refreshUserFromStorage();
        widget.onRequestChanged();
        setState(() {
          _banner = ConfirmationBannerData(
            title: 'Request Cancelled & Escrow Refunded',
            badgeText: refunded > 0
                ? '+${currency.formatExact(refunded)} WALLET'
                : 'CANCELLED',
            subtitle: refunded > 0
                ? '${req.id} cancelled and ${currency.formatExact(refunded)} refunded to your Epic Wallet.'
                : '${req.id} has been cancelled.',
            tone: ConfirmationTone.warning,
            icon: Icons.cancel_rounded,
          );
        });
      }
    }
  }

  Future<void> _openNegotiationDialog(
    RequestDetailViewModel vm,
    ProviderResponse quote,
  ) async {
    final msgController = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            4,
            16,
            MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.62,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Messages with ${quote.providerName}',
                  style: Theme.of(ctx)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  'Quote: \$${quote.quotedPrice.toStringAsFixed(0)} • ${quote.estimatedDuration}',
                  style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                        color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                      ),
                ),
                const Divider(height: 20),
                Expanded(
                  child: quote.messages.isEmpty
                      ? const Center(
                          child: Text(
                            'No messages yet. Ask a question or propose a counter-offer.',
                          ),
                        )
                      : ListView.builder(
                          itemCount: quote.messages.length,
                          itemBuilder: (_, idx) {
                            final m = quote.messages[idx];
                            final align = m.senderIsClient
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment.start;
                            final bg = m.senderIsClient
                                ? Theme.of(ctx).colorScheme.primaryContainer
                                : Theme.of(ctx)
                                    .colorScheme
                                    .surfaceContainerHighest;
                            return Column(
                              crossAxisAlignment: align,
                              children: [
                                Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  constraints:
                                      const BoxConstraints(maxWidth: 280),
                                  decoration: BoxDecoration(
                                    color: bg,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        m.senderName,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(m.text),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      'Can you offer 10% discount?',
                      'Available tomorrow?',
                      'Share past work & warranty',
                    ].map((preset) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ActionChip(
                          label: Text(
                            preset,
                            style: const TextStyle(fontSize: 11),
                          ),
                          visualDensity: VisualDensity.compact,
                          onPressed: () {
                            msgController.text = preset;
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: msgController,
                        decoration: const InputDecoration(
                          hintText: 'Write a message or counter-offer...',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: () async {
                        final text = msgController.text.trim();
                        if (text.isEmpty) return;
                        Navigator.pop(ctx);
                        final ok = await vm.sendMessage(quote, text);
                        if (ok && mounted) {
                          widget.onRequestChanged();
                          _showSnack('Message sent to ${quote.providerName}');
                        }
                      },
                      icon: const Icon(Icons.send_rounded),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    msgController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<RequestDetailViewModel>();
    final req = vm.request;
    final quotes = vm.filteredResponses;
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(req.id),
        actions: [
          if (req.status == RequestStatus.open ||
              req.status == RequestStatus.quoted)
            IconButton(
              tooltip: 'Edit Requirement',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () async {
                final updated = await widget.onEditRequest(req);
                if (updated != null) {
                  vm.applyUpdatedRequest(updated);
                  widget.onRequestChanged();
                }
              },
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Responses (${quotes.length})'),
            const Tab(text: 'Details & Timeline'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // TAB 1: Provider Responses
          RefreshIndicator(
            onRefresh: vm.loadResponses,
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _quoteSearchController,
                            onChanged: vm.updateQuoteSearch,
                            decoration: const InputDecoration(
                              hintText: 'Search quotes or providers...',
                              prefixIcon: Icon(Icons.search_rounded),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        if (quotes.length >= 2)
                          IconButton(
                            tooltip: 'Compare Quotes Side-by-Side',
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => CompareScreen.quotes(
                                    quotes: quotes.take(3).toList(),
                                    clientMaxBudget: req.budgetMax,
                                    onAcceptQuote: (q) async {
                                      final txn = await Navigator.of(context)
                                          .push<PaymentTransaction>(
                                        MaterialPageRoute(
                                          builder: (_) => CheckoutScreen(
                                            request: req,
                                            quote: q,
                                          ),
                                        ),
                                      );
                                      if (txn == null || !mounted) return;
                                      final ok = await vm.acceptQuote(q);
                                      if (ok && mounted) {
                                        widget.onRequestChanged();
                                        setState(() {
                                          _banner = ConfirmationBannerData(
                                            title:
                                                'Quote Accepted & Escrow Locked',
                                            badgeText: q.providerName,
                                            subtitle:
                                                '${req.id} awarded to ${q.providerName}. Funds are protected in Escrow.',
                                            tone: ConfirmationTone.success,
                                          );
                                        });
                                      }
                                    },
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.compare_arrows_rounded),
                          ),
                        PopupMenuButton<QuoteSortOption>(
                          initialValue: vm.sortOption,
                          onSelected: vm.setSortOption,
                          icon: const Icon(Icons.sort_rounded),
                          itemBuilder: (_) => QuoteSortOption.values
                              .map(
                                (o) => PopupMenuItem(
                                  value: o,
                                  child: Text(o.label),
                                ),
                              )
                              .toList(),
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
                      onRetry: vm.loadResponses,
                    ),
                  )
                else if (quotes.isEmpty)
                  SliverFillRemaining(
                    child: EmptyStateWidget(
                      icon: Icons.mark_chat_unread_outlined,
                      title: 'No matching quotes yet',
                      subtitle:
                          'Providers are reviewing your brief. You can also request an additional quote now.',
                      actionLabel: 'Request Quote Now',
                      onAction: () async {
                        final ok = await vm.requestFreshQuote();
                        if (ok && mounted) {
                          widget.onRequestChanged();
                          _showSnack('New provider quote received!');
                        }
                      },
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                    sliver: SliverList.separated(
                      itemCount: quotes.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, idx) {
                        final quote = quotes[idx];
                        return _QuoteCard(
                          quote: quote,
                          clientMaxBudget: req.budgetMax,
                          isBusy: vm.isActionBusy,
                          canDecide: req.status == RequestStatus.open ||
                              req.status == RequestStatus.quoted,
                          onAccept: () async {
                            final txn =
                                await Navigator.of(context).push<PaymentTransaction>(
                              MaterialPageRoute(
                                builder: (_) => CheckoutScreen(
                                  request: req,
                                  quote: quote,
                                ),
                              ),
                            );
                            if (txn == null || !mounted) return;
                            final ok = await vm.acceptQuote(quote);
                            if (ok && mounted) {
                              widget.onRequestChanged();
                              _showSnack(
                                'Paid \$${txn.totalAmount.toStringAsFixed(2)} in Escrow & started with ${quote.providerName}!',
                              );
                            }
                          },
                          onDecline: () async {
                            final ok = await vm.declineQuote(quote);
                            if (ok && mounted) {
                              widget.onRequestChanged();
                              _showSnack('Quote declined.');
                            }
                          },
                          onMessage: () => _openNegotiationDialog(vm, quote),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),

          // TAB 2: Request Overview, Lifecycle Actions & Timeline
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
            children: [
              if (_banner != null)
                ConfirmationBanner(
                  data: _banner!,
                  onDismiss: () => setState(() => _banner = null),
                ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          StatusBadge.fromRequestStatus(req.status),
                          const Spacer(),
                          Text(
                            req.urgency.label,
                            style: textTheme.labelSmall?.copyWith(
                              color: colors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        req.title,
                        style: textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        req.description,
                        style: textTheme.bodyMedium?.copyWith(height: 1.45),
                      ),
                      const Divider(height: 24),
                      _DetailRow(
                        icon: Icons.payments_outlined,
                        label: 'Target Budget',
                        value:
                            '\$${req.budgetMin.toStringAsFixed(0)} – \$${req.budgetMax.toStringAsFixed(0)}',
                      ),
                      _DetailRow(
                        icon: Icons.calendar_today_outlined,
                        label: 'Preferred Date',
                        value: DateFormat.yMMMEd().format(req.preferredDate),
                      ),
                      _DetailRow(
                        icon: Icons.location_on_outlined,
                        label: 'Location',
                        value: req.location,
                      ),
                      _DetailRow(
                        icon: Icons.email_outlined,
                        label: 'Contact',
                        value: '${req.contactEmail} • ${req.contactPhone}',
                      ),
                      if (req.customAnswers.isNotEmpty) ...[
                        const Divider(height: 20),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: req.customAnswers.entries
                              .map(
                                (e) => Chip(
                                  label: Text('${e.key}: ${e.value}'),
                                  visualDensity: VisualDensity.compact,
                                ),
                              )
                              .toList(),
                        ),
                      ],
                      if (req.attachmentLabels.isNotEmpty) ...[
                        const Divider(height: 20),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: req.attachmentLabels
                              .map(
                                (a) => Chip(
                                  avatar: const Icon(
                                    Icons.attach_file_rounded,
                                    size: 14,
                                  ),
                                  label: Text(a),
                                  visualDensity: VisualDensity.compact,
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Lifecycle Actions
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  if (req.status == RequestStatus.open ||
                      req.status == RequestStatus.quoted)
                    OutlinedButton.icon(
                      onPressed: vm.isActionBusy
                          ? null
                          : () async {
                              final ok = await vm.requestFreshQuote();
                              if (ok && mounted) {
                                widget.onRequestChanged();
                                _showSnack('New provider quote received!');
                              }
                            },
                      icon: const Icon(Icons.auto_awesome_rounded),
                      label: const Text('Get More Quotes'),
                    ),
                  if (req.status == RequestStatus.inProgress) ...[
                    FilledButton.icon(
                      onPressed: vm.isActionBusy
                          ? null
                          : () => _openCompleteAndReviewDialog(vm, req),
                      icon: const Icon(Icons.check_circle_rounded),
                      label: const Text('Mark Completed & Release Escrow'),
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                      ),
                      onPressed: vm.isActionBusy
                          ? null
                          : () => _openCancelInProgressDialog(vm, req),
                      icon: const Icon(Icons.cancel_outlined),
                      label: const Text('Cancel & Refund Escrow'),
                    ),
                  ],
                  if (req.status == RequestStatus.open ||
                      req.status == RequestStatus.quoted)
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                      ),
                      onPressed: vm.isActionBusy
                          ? null
                          : () async {
                              final ok = await vm.cancelRequest();
                              if (ok && mounted) {
                                widget.onRequestChanged();
                                setState(() {
                                  _banner = ConfirmationBannerData(
                                    title: 'Request Cancelled',
                                    badgeText: req.id,
                                    subtitle:
                                        'Your service request ${req.id} has been cancelled. You can reopen it anytime.',
                                    tone: ConfirmationTone.warning,
                                    icon: Icons.cancel_rounded,
                                  );
                                });
                              }
                            },
                      icon: const Icon(Icons.cancel_outlined),
                      label: const Text('Cancel Request'),
                    ),
                  if (req.status == RequestStatus.cancelled)
                    FilledButton.tonalIcon(
                      onPressed: vm.isActionBusy
                          ? null
                          : () async {
                              final ok = await vm.reopenRequest();
                              if (ok && mounted) {
                                widget.onRequestChanged();
                                setState(() {
                                  _banner = ConfirmationBannerData(
                                    title: 'Request Reopened',
                                    badgeText: req.id,
                                    subtitle:
                                        '${req.id} is active again and visible to providers.',
                                    tone: ConfirmationTone.info,
                                  );
                                });
                              }
                            },
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Reopen Request'),
                    ),
                ],
              ),

              const SizedBox(height: 22),
              Text(
                'Activity Timeline',
                style:
                    textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              ...req.timeline.reversed.map(
                (event) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: colors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              event.title,
                              style: textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              event.subtitle,
                              style: textTheme.bodySmall?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                            Text(
                              DateFormat.MMMd().add_jm().format(event.timestamp),
                              style: textTheme.labelSmall?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: colors.primary),
          const SizedBox(width: 8),
          SizedBox(
            width: 105,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuoteCard extends StatelessWidget {
  const _QuoteCard({
    required this.quote,
    required this.clientMaxBudget,
    required this.isBusy,
    required this.canDecide,
    required this.onAccept,
    required this.onDecline,
    required this.onMessage,
  });

  final ProviderResponse quote;
  final double clientMaxBudget;
  final bool isBusy;
  final bool canDecide;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback onMessage;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final withinBudget = quote.quotedPrice <= clientMaxBudget;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: colors.primaryContainer,
                  child: Text(
                    quote.providerName.substring(0, 1),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: colors.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              quote.providerName,
                              style: textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (quote.isVerified) ...[
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.verified_rounded,
                              size: 15,
                              color: AppColors.info,
                            ),
                          ],
                        ],
                      ),
                      Text(
                        '${quote.rating.toStringAsFixed(1)} ★ • ${quote.completedJobs} jobs',
                        style: textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                StatusBadge.fromQuoteStatus(quote.status),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  context.watch<CurrencyController>().format(quote.quotedPrice),
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colors.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (withinBudget ? AppColors.success : AppColors.warning)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    withinBudget ? 'Within Budget' : 'Above Max Budget',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: withinBudget
                          ? AppColors.success
                          : AppColors.warning,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  quote.estimatedDuration,
                  style: textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              quote.message,
              style: textTheme.bodyMedium?.copyWith(height: 1.4),
            ),
            if (quote.deliverables.isNotEmpty) ...[
              const SizedBox(height: 10),
              ...quote.deliverables.map(
                (d) => Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_rounded,
                        size: 15,
                        color: AppColors.success,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(d, style: textTheme.bodySmall),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: isBusy ? null : onMessage,
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                  label: Text('Chat (${quote.messages.length})'),
                ),
                const Spacer(),
                if (canDecide &&
                    (quote.status == QuoteStatus.pending ||
                        quote.status == QuoteStatus.negotiating)) ...[
                  TextButton(
                    onPressed: isBusy ? null : onDecline,
                    child: const Text('Decline'),
                  ),
                  const SizedBox(width: 6),
                  FilledButton(
                    onPressed: isBusy ? null : onAccept,
                    child: const Text('Accept Quote'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
