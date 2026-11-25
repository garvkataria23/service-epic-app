import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../domain/models/service_item.dart';
import '../discovery/discovery_view_model.dart';

class ProviderProfileScreen extends StatelessWidget {
  const ProviderProfileScreen({
    super.key,
    required this.providerName,
    required this.providerTitle,
    required this.isVerified,
    required this.rating,
    required this.completedJobs,
    required this.onSelectService,
  });

  final String providerName;
  final String providerTitle;
  final bool isVerified;
  final double rating;
  final int completedJobs;
  final ValueChanged<ServiceItem> onSelectService;

  @override
  Widget build(BuildContext context) {
    final discoveryVm = context.watch<DiscoveryViewModel>();
    final providerServices = discoveryVm.results
        .map((m) => m.item)
        .where((s) => s.providerName == providerName)
        .toList();
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Provider Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.secondary],
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: Colors.white.withValues(alpha: 0.22),
                      child: Text(
                        providerName.isNotEmpty
                            ? providerName[0].toUpperCase()
                            : 'P',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  providerName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              if (isVerified) ...[
                                const SizedBox(width: 6),
                                const Icon(
                                  Icons.verified_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ],
                            ],
                          ),
                          Text(
                            providerTitle,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 6,
                  children: [
                    _ProviderStat('${rating.toStringAsFixed(1)} ★ Rating'),
                    _ProviderStat('$completedJobs+ Jobs Completed'),
                    if (isVerified) const _ProviderStat('Background Verified'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Services by $providerName (${providerServices.length})',
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          ...providerServices.map(
            (srv) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  onTap: () => onSelectService(srv),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: srv.category.color.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(srv.category.icon, color: srv.category.color),
                  ),
                  title: Text(
                    srv.title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    '${srv.rating.toStringAsFixed(1)} ★ • From \$${srv.basePrice.toStringAsFixed(0)} / ${srv.priceUnit}',
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProviderStat extends StatelessWidget {
  const _ProviderStat(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
