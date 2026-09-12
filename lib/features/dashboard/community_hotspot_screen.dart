import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:swasthyasetu_ai/core/providers/providers.dart';
import 'package:swasthyasetu_ai/core/services/community_sync_service.dart';
import 'package:swasthyasetu_ai/core/theme/app_theme.dart';
import 'package:swasthyasetu_ai/core/widgets/index.dart';

const _kScreenTitle = 'Community Early-Warning Map';
const _kDemoBannerText = 'DEMO CLUSTERS (Mandate 2.1 Isolated)';
const _kPrivacyBannerTitle = 'Privacy-Preserving Regional Telemetry';
const _kPrivacyBannerBody =
    'Zero raw vitals, zero patient IDs, and zero exact GPS coordinates. '
    'Aggregated into 5 km geohashes and 1-hour time buckets.';
const _kFilterAll = 'All';
const _kFilterHeat = 'Heat';
const _kFilterRespiratory = 'Respiratory';
const _kFilterCardiac = 'Cardiac';
const _kEmptyClustersTitle = 'No hotspots matching filter';
const _kEmptyClustersBody =
    'No regional alert clusters recorded in this category.';

/// Displays regional early-warning health clusters on an offline tile map.
///
/// Under the privacy mandate (NEXT_PHASE_GUIDELINES.md), no raw vitals,
/// no patient identities, and no exact GPS coordinates are ever exposed.
class CommunityHotspotScreen extends ConsumerStatefulWidget {
  const CommunityHotspotScreen({super.key});

  @override
  ConsumerState<CommunityHotspotScreen> createState() =>
      _CommunityHotspotScreenState();
}

class _CommunityHotspotScreenState
    extends ConsumerState<CommunityHotspotScreen> {
  String _selectedCategory = _kFilterAll;
  List<CommunityHotspotCluster> _clusters = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadClusters();
  }

  Future<void> _loadClusters() async {
    setState(() => _isLoading = true);
    final service = ref.read(communitySyncServiceProvider);
    final clusters = await service.getRecentHotspots(
      includeDemo: true,
      categoryFilter: _selectedCategory == _kFilterAll
          ? null
          : _selectedCategory.toLowerCase(),
    );
    if (mounted) {
      setState(() {
        _clusters = clusters;
        _isLoading = false;
      });
    }
  }

  void _onCategorySelected(String category) {
    if (_selectedCategory == category) return;
    setState(() => _selectedCategory = category);
    _loadClusters();
  }

  Color _riskColor(String riskBand) {
    switch (riskBand.toUpperCase()) {
      case 'RED':
        return AppTheme.riskRed;
      case 'ORANGE':
        return AppTheme.tertiaryAmber;
      case 'YELLOW':
        return AppTheme.riskYellow;
      default:
        return AppTheme.riskGreen;
    }
  }

  IconData _categoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'heat':
        return Icons.wb_sunny_rounded;
      case 'respiratory':
        return Icons.air_rounded;
      case 'cardiac':
        return Icons.favorite_rounded;
      default:
        return Icons.public_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasDemo = _clusters.any((c) => c.isDemo);

    final markers = _clusters
        .map(
          (c) => MapMarker(
            latitude: c.latitude,
            longitude: c.longitude,
            color: _riskColor(c.primaryRiskBand),
          ),
        )
        .toList();

    return AppPageScaffold(
      appBar: AppBar(
        title: const Text(_kScreenTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadClusters,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingMd,
                vertical: AppTheme.spacingSm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (hasDemo) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacingMd,
                        vertical: AppTheme.spacingSm,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.science_outlined,
                            size: 18,
                            color: theme.colorScheme.onSecondaryContainer,
                          ),
                          const SizedBox(width: AppTheme.spacingSm),
                          Expanded(
                            child: Text(
                              _kDemoBannerText,
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.onSecondaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingSm),
                  ],

                  // Filter chips
                  Wrap(
                    spacing: AppTheme.spacingSm,
                    runSpacing: AppTheme.spacingXs,
                    children:
                        [
                          _kFilterAll,
                          _kFilterHeat,
                          _kFilterRespiratory,
                          _kFilterCardiac,
                        ].map((cat) {
                          final selected = _selectedCategory == cat;
                          return ChoiceChip(
                            label: Text(cat),
                            selected: selected,
                            onSelected: (_) => _onCategorySelected(cat),
                          );
                        }).toList(),
                  ),
                  const SizedBox(height: AppTheme.spacingMd),

                  // Map Container
                  Container(
                    height: 240,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant,
                      ),
                    ),
                    child: OfflineTileMap(markers: markers),
                  ),
                  const SizedBox(height: AppTheme.spacingMd),

                  // Privacy banner
                  AppCard(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.5,
                    ),
                    padding: const EdgeInsets.all(AppTheme.spacingMd),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.verified_user_outlined,
                          color: theme.colorScheme.primary,
                          size: 20,
                        ),
                        const SizedBox(width: AppTheme.spacingSm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _kPrivacyBannerTitle,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _kPrivacyBannerBody,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingMd),

                  // Clusters list
                  if (_clusters.isEmpty) ...[
                    const AppEmptyState(
                      icon: Icons.filter_alt_off_rounded,
                      title: _kEmptyClustersTitle,
                      subtitle: _kEmptyClustersBody,
                    ),
                  ] else ...[
                    ..._clusters.map((c) => _buildClusterCard(theme, c)),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildClusterCard(ThemeData theme, CommunityHotspotCluster cluster) {
    final riskColor = _riskColor(cluster.primaryRiskBand);
    final categoryIcon = _categoryIcon(cluster.dominantCategory);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingSm),
      child: AppElevatedCard(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(categoryIcon, color: riskColor, size: 20),
                const SizedBox(width: AppTheme.spacingSm),
                Expanded(
                  child: Text(
                    cluster.locationLabel,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingSm,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: riskColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    border: Border.all(color: riskColor, width: 1),
                  ),
                  child: Text(
                    cluster.primaryRiskBand,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: riskColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingSm),
            Wrap(
              spacing: AppTheme.spacingSm,
              runSpacing: AppTheme.spacingXs,
              children: [
                if (cluster.redCount > 0)
                  _buildCountChip('${cluster.redCount} Red', AppTheme.riskRed),
                if (cluster.orangeCount > 0)
                  _buildCountChip(
                    '${cluster.orangeCount} Orange',
                    AppTheme.tertiaryAmber,
                  ),
                if (cluster.yellowCount > 0)
                  _buildCountChip(
                    '${cluster.yellowCount} Yellow',
                    AppTheme.riskYellow,
                  ),
                if (cluster.greenCount > 0)
                  _buildCountChip(
                    '${cluster.greenCount} Green',
                    AppTheme.riskGreen,
                  ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingXs),
            Text(
              'Geohash: ${cluster.geohash} (~5km area) • ${cluster.totalScreenings} aggregated screenings',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCountChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingSm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
