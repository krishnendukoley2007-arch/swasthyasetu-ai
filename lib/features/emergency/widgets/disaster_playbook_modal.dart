import 'package:flutter/material.dart';
import 'package:swasthyasetu_ai/core/theme/app_theme.dart';
import 'package:swasthyasetu_ai/core/theme/clinical_palette.dart';
import 'package:swasthyasetu_ai/domain/models/disaster_hazard.dart';
import 'package:url_launcher/url_launcher.dart';

// Localization guard: top-level constants
const _kModalTitle = 'All-Hazard Offline Survival Playbook';
const _kSubtitle =
    'Field-tested emergency protocols for frontline workers and families during severe climate hazards and cellular blackouts.';
const _kTabFlood = 'Floods & Water';
const _kTabHeat = 'Heatwaves';
const _kTabSmog = 'Toxic Smog';
const _kTabCyclone = 'Cyclones';
const _kTabHelplines = 'Helplines';
const _kDisclaimer =
    'Off-grid screening and first-aid protocol. Does not replace tertiary clinical care. Evacuate when directed by civil defense or NDRF authorities.';

class DisasterPlaybookModal extends StatefulWidget {
  final DisasterHazardType initialHazard;

  const DisasterPlaybookModal({
    super.key,
    this.initialHazard = DisasterHazardType.none,
  });

  static Future<void> show(
    BuildContext context, {
    DisasterHazardType initialHazard = DisasterHazardType.none,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DisasterPlaybookModal(initialHazard: initialHazard),
    );
  }

  @override
  State<DisasterPlaybookModal> createState() => _DisasterPlaybookModalState();
}

class _DisasterPlaybookModalState extends State<DisasterPlaybookModal> {
  late int _selectedTab;

  @override
  void initState() {
    super.initState();
    _selectedTab = switch (widget.initialHazard) {
      DisasterHazardType.flood => 0,
      DisasterHazardType.heatwave => 1,
      DisasterHazardType.severeAirPollution => 2,
      DisasterHazardType.cycloneStorm => 3,
      _ => 0,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (ctx, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppTheme.radiusLg),
            ),
          ),
          child: Column(
            children: [
              // Drag handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Modal Header
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingMd,
                  vertical: 4,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.menu_book_rounded,
                        color: theme.colorScheme.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _kModalTitle,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            _kSubtitle,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 11,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Hazard Category Filter Tabs
              Padding(
                padding: const EdgeInsets.all(AppTheme.spacingSm),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip(0, _kTabFlood, Icons.water_rounded),
                      const SizedBox(width: 6),
                      _buildFilterChip(1, _kTabHeat, Icons.wb_sunny_rounded),
                      const SizedBox(width: 6),
                      _buildFilterChip(2, _kTabSmog, Icons.air_rounded),
                      const SizedBox(width: 6),
                      _buildFilterChip(3, _kTabCyclone, Icons.cyclone_rounded),
                      const SizedBox(width: 6),
                      _buildFilterChip(4, _kTabHelplines, Icons.phone_rounded),
                    ],
                  ),
                ),
              ),

              // Scrollable Content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(AppTheme.spacingMd),
                  children: [
                    if (_selectedTab == 0) _buildFloodTab(theme),
                    if (_selectedTab == 1) _buildHeatTab(theme),
                    if (_selectedTab == 2) _buildSmogTab(theme),
                    if (_selectedTab == 3) _buildCycloneTab(theme),
                    if (_selectedTab == 4) _buildHelplinesTab(theme),
                    const SizedBox(height: 16),
                    _buildDisclaimerCard(theme),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterChip(int index, String label, IconData icon) {
    final isSelected = _selectedTab == index;
    final theme = Theme.of(context);

    return FilterChip(
      selected: isSelected,
      showCheckmark: false,
      avatar: Icon(
        icon,
        size: 16,
        color: isSelected ? Colors.white : theme.colorScheme.onSurfaceVariant,
      ),
      label: Text(label),
      labelStyle: TextStyle(
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        color: isSelected ? Colors.white : theme.colorScheme.onSurface,
        fontSize: 12,
      ),
      selectedColor: theme.colorScheme.primary,
      backgroundColor: theme.colorScheme.surfaceContainerHighest,
      onSelected: (_) => setState(() => _selectedTab = index),
    );
  }

  Widget _buildFloodTab(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionCard(
          theme,
          icon: Icons.water_drop_rounded,
          color: ClinicalPalette.teal,
          title: 'Drinking Water Decontamination',
          children: [
            _buildProtocolRow(
              theme,
              'Rolling Boil Method',
              'Bring water to a vigorous, rolling boil for at least 1 full minute (3 minutes at elevations above 2,000m). Destroys bacteria, viruses, and parasites.',
            ),
            const Divider(height: 16),
            _buildProtocolRow(
              theme,
              'Chlorine / Halazone Tablets',
              'Use 1 standard tablet per 20 Litres of clear water. Dissolve and wait 30 minutes before drinking. If water is turbid, pre-filter through clean cloth.',
            ),
            const Divider(height: 16),
            _buildProtocolRow(
              theme,
              'Solar Disinfection (SODIS)',
              'In absence of fuel or tablets, fill clean transparent PET bottles and lay horizontally on a metal roof in direct sunshine for at least 6 hours.',
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildSectionCard(
          theme,
          icon: Icons.local_hospital_rounded,
          color: AppTheme.riskGreen,
          title: 'WHO Home ORS Preparation',
          children: [
            _buildProtocolRow(
              theme,
              'Life-Saving Formulation',
              '1 Litre clean boiled/purified water + 6 level teaspoons sugar + 1/2 level teaspoon common salt. Mix until fully dissolved.',
            ),
            const Divider(height: 16),
            _buildProtocolRow(
              theme,
              'Administration Guidance',
              'Sip continuously, especially after loose stool. Discard any prepared ORS remaining after 24 hours. Do not add excess salt.',
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildSectionCard(
          theme,
          icon: Icons.healing_rounded,
          color: ClinicalPalette.coral,
          title: 'Leptospirosis & Flood Wounds',
          children: [
            _buildProtocolRow(
              theme,
              'Avoid Wading with Cuts',
              'Floodwater contaminated with animal urine carries Leptospira bacteria. Never walk barefoot in floodwaters.',
            ),
            const Divider(height: 16),
            _buildProtocolRow(
              theme,
              'Calf Pain & Fever Red Flag',
              'High fever accompanied by severe calf/muscle tenderness and yellowing of eyes requires immediate referral to medical relief camp for Doxycycline.',
            ),
            const Divider(height: 16),
            _buildProtocolRow(
              theme,
              'Snakebite & Submerged Hazards',
              'Do not reach into dark water or hollows. If bitten: keep bitten limb still and immobilized below heart level. Do NOT use tourniquets or incisions.',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHeatTab(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionCard(
          theme,
          icon: Icons.warning_amber_rounded,
          color: ClinicalPalette.coral,
          title: 'Heat Exhaustion vs Heatstroke',
          children: [
            _buildProtocolRow(
              theme,
              'Heat Exhaustion (Warning)',
              'Heavy sweating, cool pale skin, dizziness, nausea. Action: Move to shade, loosen clothing, sip cool water or ORS solution, rest 30+ mins.',
            ),
            const Divider(height: 16),
            _buildProtocolRow(
              theme,
              'Heatstroke (Medical Emergency!)',
              'Core temp > 40°C (104°F), hot red DRY skin, confusion, loss of consciousness. Action: Call 108 immediately! Pour cool water over body, place ice packs in groin/armpits/neck.',
            ),
            const Divider(height: 16),
            _buildProtocolRow(
              theme,
              'Medication Warning',
              'NEVER administer paracetamol or aspirin for environmental heatstroke; they impair renal and hepatic function during hyperthermia.',
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildSectionCard(
          theme,
          icon: Icons.timer_outlined,
          color: ClinicalPalette.amber,
          title: 'Work / Rest Ratios (Vidarbha / North India)',
          children: [
            _buildProtocolRow(
              theme,
              'Ambient 36°C - 40°C',
              '45 minutes work / 15 minutes shaded rest. Drink 250ml water every 20 minutes.',
            ),
            const Divider(height: 16),
            _buildProtocolRow(
              theme,
              'Ambient 40°C - 44°C',
              '30 minutes work / 30 minutes shaded rest. Wear damp bandana around neck.',
            ),
            const Divider(height: 16),
            _buildProtocolRow(
              theme,
              'Ambient > 44°C (Red Alert)',
              'Halt non-essential manual labor between 11:00 AM and 4:00 PM.',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSmogTab(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionCard(
          theme,
          icon: Icons.masks_rounded,
          color: ClinicalPalette.teal,
          title: 'Respiratory Defense & Smog Enclosure',
          children: [
            _buildProtocolRow(
              theme,
              'Certified Respirator Requirement',
              'Only N95 or FFP2 respirators trap microscopic PM2.5 particles. Surgical paper masks and single-layer cloth offer under 15% PM2.5 filtration.',
            ),
            const Divider(height: 16),
            _buildProtocolRow(
              theme,
              'Room Sealing Technique',
              'Keep windows tightly shut. Roll damp towels along door cracks to intercept infiltration. Avoid dry sweeping; always wet-mop.',
            ),
            const Divider(height: 16),
            _buildProtocolRow(
              theme,
              'Pursed-Lip Bronchodilation',
              'When feeling chest tightness, practice slow nasal inhalation for 4 seconds, followed by gentle exhalation through pursed lips for 6 seconds.',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCycloneTab(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionCard(
          theme,
          icon: Icons.shield_rounded,
          color: ClinicalPalette.amber,
          title: 'Cyclone Shelter & Structural Protocols',
          children: [
            _buildProtocolRow(
              theme,
              'Before Landfall',
              'Switch off main power breaker and LPG gas cylinder valve. Fasten loose outdoor objects. Move to designated concrete cyclone shelter.',
            ),
            const Divider(height: 16),
            _buildProtocolRow(
              theme,
              'During the Eye of the Storm',
              'Do NOT venture outside when winds suddenly stop. The calm "eye" is temporary and violent reverse winds will resume abruptly.',
            ),
            const Divider(height: 16),
            _buildProtocolRow(
              theme,
              'Emergency Offline Signaling',
              'If trapped, sound 3 short whistle blasts, pause 10 seconds, repeat. At night, flash a torch in Morse SOS pattern (... --- ...).',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHelplinesTab(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionCard(
          theme,
          icon: Icons.contact_phone_rounded,
          color: theme.colorScheme.primary,
          title: 'National Disaster & Medical Helplines',
          children: [
            _buildHelplineRow(
              theme,
              'NDRF National Disaster Helpline',
              '1078',
              'Flood evacuation, building collapse, cyclone rescue',
            ),
            const Divider(height: 16),
            _buildHelplineRow(
              theme,
              'Ambulance & Emergency Medical (EMRI)',
              '108',
              'Life-threatening trauma, acute respiratory failure, heatstroke',
            ),
            const Divider(height: 16),
            _buildHelplineRow(
              theme,
              'National Emergency Number',
              '112',
              'Unified police, fire, and all disaster services',
            ),
            const Divider(height: 16),
            _buildHelplineRow(
              theme,
              'Childline Helpline',
              '1098',
              'Separated minors and vulnerable children in relief camps',
            ),
            const Divider(height: 16),
            _buildHelplineRow(
              theme,
              'Women in Distress Helpline',
              '181',
              'Safety and protection in shelter facilities',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionCard(
    ThemeData theme, {
    required IconData icon,
    required Color color,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildProtocolRow(ThemeData theme, String title, String description) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          description,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildHelplineRow(
    ThemeData theme,
    String name,
    String number,
    String description,
  ) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                description,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        FilledButton.tonalIcon(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            visualDensity: VisualDensity.compact,
          ),
          onPressed: () {
            launchUrl(
              Uri.parse('tel:$number'),
              mode: LaunchMode.externalApplication,
            );
          },
          icon: const Icon(Icons.call_rounded, size: 14),
          label: Text(
            number,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
          ),
        ),
      ],
    );
  }

  Widget _buildDisclaimerCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingSm),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 14,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _kDisclaimer,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 10,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
