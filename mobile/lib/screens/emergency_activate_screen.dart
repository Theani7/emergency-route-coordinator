import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/kathmandu.dart';
import '../providers/emergency_provider.dart';
import '../screens/location_pick_screen.dart';
import '../services/ai_service.dart';
import '../services/api_service.dart';
import '../services/geocoding_service.dart';
import '../widgets/skeleton_widgets.dart';
import '../widgets/auth_widgets.dart';
import '../widgets/emergency_button.dart';

class EmergencyActivateScreen extends StatefulWidget {
  const EmergencyActivateScreen({super.key});

  @override
  State<EmergencyActivateScreen> createState() =>
      _EmergencyActivateScreenState();
}

class _EmergencyActivateScreenState extends State<EmergencyActivateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _destCtrl = TextEditingController(
    text: 'Emergency incident',
  );
  final _latCtrl = TextEditingController(
    text: KathmanduLocation.centerLat.toString(),
  );
  final _lonCtrl = TextEditingController(
    text: KathmanduLocation.centerLon.toString(),
  );
  bool _useAi = true;
  bool _pinned = false;
  double? _pinnedLat;
  double? _pinnedLon;
  String _incidentType = 'general';
  String _routePreference = 'fastest';
  KathmanduHospital? _hospital = kathmanduHospitals.first;

  static const _incidentTypes = [
    'general',
    'accident',
    'cardiac',
    'fire',
    'respiratory',
    'trauma',
  ];

  String _incidentLabel(String type) {
    switch (type) {
      case 'accident':
        return 'Traffic accident';
      case 'cardiac':
        return 'Cardiac';
      case 'fire':
        return 'Fire';
      case 'respiratory':
        return 'Respiratory';
      case 'trauma':
        return 'Trauma';
      default:
        return 'General';
    }
  }

  @override
  void dispose() {
    _destCtrl.dispose();
    _latCtrl.dispose();
    _lonCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickOnMap(BuildContext context) async {
    final initialLat =
        double.tryParse(_latCtrl.text.trim()) ?? KathmanduLocation.centerLat;
    final initialLon =
        double.tryParse(_lonCtrl.text.trim()) ?? KathmanduLocation.centerLon;
    final picked = await Navigator.push<PickedLocation>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationPickScreen(
          initialLat: initialLat,
          initialLon: initialLon,
        ),
      ),
    );
    if (picked == null || !mounted) return;
    final coordText =
        '${picked.latitude.toStringAsFixed(6)}, ${picked.longitude.toStringAsFixed(6)}';
    setState(() {
      _pinned = true;
      _pinnedLat = picked.latitude;
      _pinnedLon = picked.longitude;
      _latCtrl.text = picked.latitude.toStringAsFixed(6);
      _lonCtrl.text = picked.longitude.toStringAsFixed(6);
      _destCtrl.text = coordText;
    });
  }

  void _showLocationSearch(BuildContext context) {
    final searchCtrl = TextEditingController();
    List<GeocodingResult>? results;
    bool loading = false;
    var open = true;
    final text = GoogleFonts.inter();

    Future<void> runSearch(StateSetter setDialogState) async {
      if (!open || searchCtrl.text.trim().length < 2) return;
      setDialogState(() => loading = true);
      try {
        final api = context.read<ApiService?>();
        if (api == null) return;
        final svc = GeocodingService(api);
        final r = await svc.search(
          searchCtrl.text.trim(),
          lat: 27.7172,
          lon: 85.3240,
        );
        if (!open) return;
        setDialogState(() {
          results = r;
          loading = false;
        });
      } catch (e) {
        if (!open) return;
        setDialogState(() => loading = false);
      }
    }

    OutlineInputBorder fieldBorder(Color color) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: color),
        );

    final dialogFuture = showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          backgroundColor: kAuthCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: kAuthBorder),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Search location',
                  style: text.copyWith(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: kAuthText,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: searchCtrl,
                  autofocus: true,
                  style: text.copyWith(fontSize: 15, color: kAuthText),
                  cursorColor: kAuthRed,
                  decoration: InputDecoration(
                    hintText: 'e.g. Teaching Hospital Kathmandu',
                    hintStyle: text.copyWith(fontSize: 14, color: kAuthFaint),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      size: 20,
                      color: kAuthIcon,
                    ),
                      suffixIcon: loading
                          ? const Padding(
                              padding: EdgeInsets.all(11),
                              child: SkeletonLoadingIndicator(size: 18),
                            )
                        : null,
                    border: fieldBorder(kAuthBorder),
                    enabledBorder: fieldBorder(kAuthBorder),
                    focusedBorder: fieldBorder(kAuthRed),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                  ),
                  onSubmitted: (_) => runSearch(setDialogState),
                ),
                const SizedBox(height: 12),
                if (!loading && results != null && results!.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text(
                        'No results found',
                        style: text.copyWith(fontSize: 13, color: kAuthFaint),
                      ),
                    ),
                  ),
                if (!loading && results != null && results!.isNotEmpty)
                  SizedBox(
                    height: 240,
                    width: double.maxFinite,
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: results!.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, color: kAuthBorder),
                      itemBuilder: (_, i) {
                        final r = results![i];
                        return InkWell(
                          onTap: () {
                            _destCtrl.text =
                                r.displayName.split(',').take(2).join(',');
                            _latCtrl.text = r.latitude.toStringAsFixed(6);
                            _lonCtrl.text = r.longitude.toStringAsFixed(6);
                            Navigator.pop(ctx);
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 10,
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.location_on_outlined,
                                  size: 18,
                                  color: kAuthRed,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        r.displayName
                                            .split(',')
                                            .take(2)
                                            .join(','),
                                        style: text.copyWith(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w500,
                                          color: kAuthText,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${r.latitude.toStringAsFixed(5)}, '
                                        '${r.longitude.toStringAsFixed(5)}',
                                        style: text.copyWith(
                                          fontSize: 11.5,
                                          color: kAuthFaint,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: TextButton.styleFrom(
                        foregroundColor: kAuthMuted,
                        minimumSize: const Size(0, 40),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                      ),
                      child: Text(
                        'Cancel',
                        style: text.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
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
    dialogFuture.whenComplete(() {
      open = false;
      searchCtrl.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    final emergency = context.watch<EmergencyProvider>();
    final prediction = emergency.lastPrediction;
    final text = GoogleFonts.inter();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: kAuthText,
        elevation: 0,
        scrolledUnderElevation: 0,
        flexibleSpace: const FrostedAppBarBackdrop(),
        shape: const Border(bottom: BorderSide(color: kAuthBorder)),
        title: Text(
          'Activate emergency',
          style: text.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: kAuthText,
          ),
        ),
      ),
      body: GlassBackdrop(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: kAuthRedBadgeBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kAuthRed.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.emergency_rounded,
                        size: 18, color: kAuthRed),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'On activation, dispatch and nearby traffic officers '
                        'are alerted to clear the route.',
                        style: text.copyWith(
                          fontSize: 12.5,
                          color: kAuthRedBadgeText,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _sectionLabel(text, 'Incident details'),
              const SizedBox(height: 8),
              AuthDropdownField(
                label: 'Incident type',
                icon: Icons.medical_information_outlined,
                value: _incidentType,
                items: _incidentTypes
                    .map((t) => DropdownMenuItem(
                          value: t,
                          child: Text(_incidentLabel(t)),
                        ))
                    .toList(),
                onChanged: (v) =>
                    setState(() => _incidentType = v ?? 'general'),
              ),
              const SizedBox(height: 12),
              AuthDropdownField(
                label: 'Route preference',
                icon: Icons.route_outlined,
                value: _routePreference,
                items: const [
                  DropdownMenuItem(
                      value: 'fastest', child: Text('Fastest (time)')),
                  DropdownMenuItem(
                    value: 'shortest',
                    child: Text('Shortest (distance)'),
                  ),
                ],
                onChanged: (v) =>
                    setState(() => _routePreference = v ?? 'fastest'),
              ),
              const SizedBox(height: 12),
              _KField(
                controller: _destCtrl,
                label: 'Destination / landmark',
                icon: Icons.location_on_outlined,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Enter a destination'
                    : null,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Search location',
                      padding: const EdgeInsets.all(7),
                      onPressed: () => _showLocationSearch(context),
                      icon: const Icon(
                        Icons.search_rounded,
                        size: 20,
                        color: kAuthIcon,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Pin on map',
                      padding: const EdgeInsets.all(7),
                      onPressed: () => _pickOnMap(context),
                      icon: const Icon(
                        Icons.map_outlined,
                        size: 20,
                        color: kAuthRedLink,
                      ),
                    ),
                  ],
                ),
              ),
              if (_pinned && _useAi) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.push_pin_outlined,
                        size: 14, color: kAuthRedLink),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Pinned location overrides the AI estimate for this activation.',
                        style: GoogleFonts.inter().copyWith(
                          color: kAuthRedLink,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              AuthDropdownField(
                label: 'Hospital (optional)',
                icon: Icons.local_hospital_outlined,
                value: _hospital?.name ?? '',
                items: [
                  const DropdownMenuItem(
                    value: '',
                    child: Text('Choose from Kathmandu hospitals'),
                  ),
                  ...kathmanduHospitals.map((h) =>
                      DropdownMenuItem(value: h.name, child: Text(h.name))),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() {
                    _hospital = v.isEmpty
                        ? null
                        : kathmanduHospitals.firstWhere((h) => h.name == v);
                    if (!_useAi && _hospital != null) {
                      _latCtrl.text = _hospital!.lat.toStringAsFixed(6);
                      _lonCtrl.text = _hospital!.lon.toStringAsFixed(6);
                    }
                  });
                },
              ),
              const SizedBox(height: 20),
              _sectionLabel(text, 'Prediction'),
              const SizedBox(height: 8),
              _aiToggleCard(text, emergency),
              const SizedBox(height: 12),
              if (_useAi) ...[
                _PreviewButton(
                  loading: emergency.loading,
                  onPressed: () async {
                    final pred = await emergency.previewAiPrediction(
                      incidentType: _incidentType,
                    );
                    if (pred != null && mounted) {
                      setState(() {
                        _pinned = false;
                        _latCtrl.text = pred.incidentLat.toStringAsFixed(6);
                        _lonCtrl.text = pred.incidentLon.toStringAsFixed(6);
                      });
                    }
                  },
                ),
                if (prediction != null) ...[
                  const SizedBox(height: 12),
                  _predictionCard(text, prediction),
                ],
              ] else ...[
                _KField(
                  controller: _latCtrl,
                  label: 'Incident latitude (manual)',
                  icon: Icons.near_me_outlined,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) {
                    final lat = double.tryParse(v?.trim() ?? '');
                    if (lat == null) return 'Enter a valid latitude';
                    if (lat < -90 || lat > 90) {
                      return 'Latitude must be -90 to 90';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                _KField(
                  controller: _lonCtrl,
                  label: 'Incident longitude (manual)',
                  icon: Icons.explore_outlined,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) {
                    final lon = double.tryParse(v?.trim() ?? '');
                    if (lon == null) return 'Enter a valid longitude';
                    if (lon < -180 || lon > 180) {
                      return 'Longitude must be -180 to 180';
                    }
                    return null;
                  },
                ),
              ],
              if (emergency.error != null) ...[
                const SizedBox(height: 16),
                AuthErrorBanner(message: emergency.error!),
              ],
              const SizedBox(height: 24),
              EmergencyButton(
                loading: emergency.loading,
                label: 'Start emergency',
                onPressed: () async {
                  if (!(_formKey.currentState!.validate())) return;
                  final ok = await emergency.activateEmergency(
                    destination: _destCtrl.text,
                    useAiPrediction: _useAi,
                    incidentType: _incidentType,
                    routePreference: _routePreference,
                    destLat: _pinned
                        ? _pinnedLat
                        : (_useAi ? null : double.tryParse(_latCtrl.text)),
                    destLon: _pinned
                        ? _pinnedLon
                        : (_useAi ? null : double.tryParse(_lonCtrl.text)),
                    hospitalName: _hospital?.name,
                    hospitalLatitude: _hospital?.lat,
                    hospitalLongitude: _hospital?.lon,
                  );
                  if (!ok) return;
                  if (!mounted) return;
                  Navigator.pop(this.context, true);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(TextStyle text, String label) {
    return Row(
      children: [
        Text(
          label,
          style: text.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: kAuthText,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(child: Divider(color: kAuthBorder, height: 1)),
      ],
    );
  }

  Widget _aiToggleCard(TextStyle text, EmergencyProvider emergency) {
    return GlassSurface(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _useAi ? _kBlueTint : _kNeutralTint,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.psychology_rounded,
              size: 19,
              color: _useAi ? _kBlue : kAuthMuted,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI incident prediction',
                  style: text.copyWith(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w500,
                    color: kAuthText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Forecasts the incident location, then routes around traffic',
                  style: text.copyWith(fontSize: 12, color: kAuthFaint),
                ),
              ],
            ),
          ),
          Switch(
            value: _useAi,
            onChanged: (v) {
              setState(() {
                _useAi = v;
                if (!v && emergency.lastPrediction != null) {
                  _latCtrl.text =
                      emergency.lastPrediction!.incidentLat.toStringAsFixed(6);
                  _lonCtrl.text =
                      emergency.lastPrediction!.incidentLon.toStringAsFixed(6);
                }
              });
            },
            activeThumbColor: Colors.white,
            activeTrackColor: kAuthRed,
            inactiveThumbColor: kAuthCard,
            inactiveTrackColor: const Color(0xFFE0DED6),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }

  Widget _predictionCard(TextStyle text, IncidentPrediction prediction) {
    return GlassSurface(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: _kBlueTint,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.psychology_rounded,
                  size: 18,
                  color: _kBlue,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Prediction result',
                style: text.copyWith(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: kAuthText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            prediction.incidentDescription,
            style: text.copyWith(
              fontSize: 12.5,
              color: kAuthMuted,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),
          _predictionRow(
            text,
            Icons.location_on_outlined,
            'Predicted location',
            '${prediction.incidentLat.toStringAsFixed(5)}, '
                '${prediction.incidentLon.toStringAsFixed(5)}',
          ),
          _predictionRow(
            text,
            Icons.analytics_outlined,
            'Confidence',
            '${(prediction.confidence * 100).toStringAsFixed(0)}% · '
                '${prediction.confidenceDescription}',
          ),
          _predictionRow(
            text,
            Icons.traffic_outlined,
            'Traffic condition',
            prediction.trafficLabel.isNotEmpty
                ? prediction.trafficLabel
                : 'Normal',
          ),
          _predictionRow(
            text,
            Icons.category_outlined,
            'Incident type',
            _incidentLabel(prediction.incidentType),
          ),
          _predictionRow(
            text,
            Icons.science_outlined,
            'Model version',
            prediction.modelVersion,
          ),
        ],
      ),
    );
  }

  Widget _predictionRow(
    TextStyle text,
    IconData icon,
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: kAuthIcon),
          const SizedBox(width: 8),
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: text.copyWith(fontSize: 12, color: kAuthFaint),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: text.copyWith(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: kAuthText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const _kBlue = Color(0xFF2E6FD8);
const _kBlueTint = Color(0xFFEAF1FC);
const _kNeutralTint = Color(0xFFF2F1ED);

class _KField extends StatefulWidget {
  const _KField({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.trailing,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final Widget? trailing;
  final String? Function(String?)? validator;

  @override
  State<_KField> createState() => _KFieldState();
}

class _KFieldState extends State<_KField> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChanged);
  }

  void _onFocusChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChanged);
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = GoogleFonts.inter();
    final focused = _focus.hasFocus;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: text.copyWith(fontSize: 13, color: kAuthMuted),
        ),
        const SizedBox(height: 6),
        AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          height: 44,
          decoration: BoxDecoration(
            color: kAuthCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: focused ? kAuthRed : kAuthBorder,
            ),
          ),
          child: Row(
            children: [
              const SizedBox(width: 12),
              Icon(widget.icon, size: 18, color: kAuthIcon),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: widget.controller,
                  focusNode: _focus,
                  keyboardType: widget.keyboardType,
                  validator: widget.validator,
                  style: text.copyWith(fontSize: 15, color: kAuthText),
                  cursorColor: kAuthRed,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    errorStyle: text.copyWith(
                      fontSize: 12,
                      color: kAuthRedDark,
                    ),
                    errorMaxLines: 2,
                  ),
                ),
              ),
              if (widget.trailing != null) widget.trailing!,
              const SizedBox(width: 5),
            ],
          ),
        ),
      ],
    );
  }
}

class _PreviewButton extends StatefulWidget {
  const _PreviewButton({required this.loading, required this.onPressed});

  final bool loading;
  final VoidCallback onPressed;

  @override
  State<_PreviewButton> createState() => _PreviewButtonState();
}

class _PreviewButtonState extends State<_PreviewButton> {
  bool _hover = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final text = GoogleFonts.inter();
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          height: 44,
          decoration: BoxDecoration(
            color: _hover || _pressed ? kAuthRedBadgeBg : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: kAuthRed.withValues(alpha: 0.6)),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.loading ? null : widget.onPressed,
              borderRadius: BorderRadius.circular(10),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.psychology_rounded,
                      size: 18,
                      color: kAuthRedLink,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Preview AI prediction',
                      style: text.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: kAuthRedLink,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
