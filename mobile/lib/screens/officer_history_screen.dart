import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/junction_provider.dart';
import '../widgets/skeleton_widgets.dart';
import '../widgets/auth_widgets.dart';

class OfficerHistoryScreen extends StatefulWidget {
  const OfficerHistoryScreen({super.key});

  @override
  State<OfficerHistoryScreen> createState() => _OfficerHistoryScreenState();
}

class _OfficerHistoryScreenState extends State<OfficerHistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<JunctionProvider>().loadClearanceHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    final junctions = context.watch<JunctionProvider>();
    final text = GoogleFonts.inter();
    final history = junctions.clearanceHistory;
    final now = DateTime.now();
    bool isToday(DateTime dt) =>
        dt.year == now.year && dt.month == now.month && dt.day == now.day;
    final todayCount = history.where((h) {
      final t = DateTime.tryParse(h.clearedAt);
      return t != null && isToday(t);
    }).length;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        flexibleSpace: const FrostedAppBarBackdrop(),
        shape: const Border(bottom: BorderSide(color: kAuthBorder)),
        title: Text(
          'Junction clearances',
          style: text.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
            color: kAuthText,
          ),
        ),
      ),
      body: GlassBackdrop(
        child: junctions.loading
            ? const SkeletonList(itemCount: 5)
            : history.isEmpty
                ? const AuthEmptyState(
                    icon: Icons.traffic_rounded,
                    title: 'No clearances yet',
                    hint:
                        'Mark junctions cleared from the Live map tab and they '
                        'will show up here with timestamps.',
                  )
                : RefreshIndicator(
                    onRefresh: junctions.loadClearanceHistory,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: kAuthCard,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: kAuthBorder),
                            boxShadow: kCardShadow,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: kAuthGreenBg,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.traffic_rounded,
                                  size: 20,
                                  color: kAuthGreen,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Clearance history',
                                      style: text.copyWith(
                                        fontSize: 12.5,
                                        color: kAuthFaint,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '$todayCount today • '
                                      '${history.length} total',
                                      style: text.copyWith(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w600,
                                        color: kAuthGreenText,
                                        fontFeatures: const [
                                          FontFeature.tabularFigures(),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...history.map(
                          (h) => Card(
                            margin: const EdgeInsets.only(bottom: 6),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 4),
                              leading: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: kAuthGreenBg,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.traffic_rounded,
                                  size: 18,
                                  color: kAuthGreen,
                                ),
                              ),
                              title: Text(
                                h.junctionName,
                                style: text.copyWith(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: kAuthText,
                                ),
                              ),
                              subtitle: Text(
                                h.clearedAt.isNotEmpty
                                    ? 'Cleared: ${_formatClearedAt(h.clearedAt)}'
                                    : 'Cleared',
                                style: text.copyWith(
                                  fontSize: 13,
                                  color: kAuthMuted,
                                ),
                              ),
                              trailing: const Icon(
                                Icons.check_circle_rounded,
                                color: kAuthGreen,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }

  String _formatClearedAt(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final hm = '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}, $hm';
  }
}
