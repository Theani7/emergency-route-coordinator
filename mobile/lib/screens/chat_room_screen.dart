

import 'package:flutter/material.dart';
import 'package:flutter_map_cache/flutter_map_cache.dart';
import '../core/map_cache.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/chat_models.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../services/gps_service.dart';
import '../widgets/skeleton_widgets.dart';
import '../widgets/auth_widgets.dart';
import 'location_pick_screen.dart';

class ChatRoomScreen extends StatefulWidget {
  const ChatRoomScreen({super.key, required this.session});

  final ChatSessionSummary session;

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final _composer = TextEditingController();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ChatProvider>().loadMessages(widget.session.emergencySessionId);
    });
  }

  @override
  void dispose() {
    _composer.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send(ChatProvider chat) {
    final msg = _composer.text.trim();
    if (msg.isEmpty || chat.sending) return;
    _composer.clear();
    _sendMessage(chat, msg);
  }

  void _sendMessage(ChatProvider chat, String message,
      {double? latitude, double? longitude}) {
    chat
        .sendMessage(
          widget.session.emergencySessionId,
          message,
          latitude: latitude,
          longitude: longitude,
        )
        .catchError((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send message')),
        );
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    if (!_scroll.hasClients) return;
    if (!mounted) return;
    _scroll.animateTo(
      _scroll.position.maxScrollExtent,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  String _timeLabel(DateTime dt) => DateFormat('HH:mm').format(dt.toLocal());

  void _showAttachSheet(ChatProvider chat) {
    final text = GoogleFonts.inter();
    showModalBottomSheet(
      context: context,
      backgroundColor: kAuthCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Text(
                    'Share',
                    style: text.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: kAuthText,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: kAuthFaint, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: kAuthRed.withValues(alpha: 0.12),
                child: const Icon(Icons.my_location, color: kAuthRed, size: 20),
              ),
              title: Text(
                'Send current location',
                style: text.copyWith(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              subtitle: Text(
                'Your live position right now',
                style: text.copyWith(fontSize: 12, color: kAuthFaint),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _sendCurrentLocation(chat);
              },
            ),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: kAuthGreen.withValues(alpha: 0.12),
                child:
                    const Icon(Icons.map_outlined, color: kAuthGreen, size: 20),
              ),
              title: Text(
                'Send any location',
                style: text.copyWith(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              subtitle: Text(
                'Pick a spot on the map',
                style: text.copyWith(fontSize: 12, color: kAuthFaint),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndSendLocation();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _sendCurrentLocation(ChatProvider chat) async {
    Position? position;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Enable location permission to share your position')),
          );
        }
        return;
      }
    } catch (e) {
      debugPrint(e.toString());
    }

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Center(
        child: GlassSurface(
          radius: 16,
          blur: 10,
          tint: kGlassTint,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: SkeletonLoadingIndicator(size: 20),
              ),
              SizedBox(width: 14),
              Text(
                'Getting your location…',
                style: TextStyle(color: kAuthText, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );

    position = await GpsTrackingService.bestPosition();
    if (!mounted) return;
    Navigator.of(context).pop();

    if (position == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not get your location — try again')),
        );
      }
      return;
    }
    _sendMessage(
      chat,
      'Shared current location',
      latitude: position.latitude,
      longitude: position.longitude,
    );
  }

  Future<void> _pickAndSendLocation() async {
    double lat = 27.7172;
    double lon = 85.3240;
    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) {
        lat = last.latitude;
        lon = last.longitude;
      }
    } catch (e) {
      debugPrint(e.toString());
    }
    if (!mounted) return;
    final picked = await Navigator.of(context).push<PickedLocation>(
      MaterialPageRoute(
        builder: (_) => LocationPickScreen(initialLat: lat, initialLon: lon),
      ),
    );
    if (picked == null || !mounted) return;
    final chat = context.read<ChatProvider>();
    _sendMessage(
      chat,
      picked.label == null || picked.label!.trim().isEmpty
          ? 'Shared location'
          : 'Shared location · ${picked.label}',
      latitude: picked.latitude,
      longitude: picked.longitude,
    );
  }

  Future<void> _openLocation(ChatMessageModel m) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${m.latitude},${m.longitude}',
    );
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open maps')),
      );
    }
  }

  void _showParticipants(BuildContext context) {
    final text = GoogleFonts.inter();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kAuthCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Participants',
          style: text.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: kAuthText,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: buildParticipantRows(widget.session, text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Close', style: text.copyWith(color: kAuthMuted)),
          ),
        ],
      ),
    );
  }

  List<Widget> buildParticipantRows(ChatSessionSummary s, TextStyle text) {
    final rows = <Widget>[];
    for (final p in s.participants) {
      final isDriver = p.isDriver;
      rows.add(ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(
          backgroundColor: isDriver ? kAuthGreen : kAuthRed,
          child: Text(
            p.initials,
            style: text.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
        title: Text(
          p.name,
          style: text.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          isDriver ? 'Driver' : 'Traffic officer',
          style: text.copyWith(
            fontSize: 12,
            color: isDriver ? kAuthGreen : kAuthRed,
            fontWeight: FontWeight.w600,
          ),
        ),
      ));
    }
    if (rows.isEmpty) {
      rows.add(Text('No participants yet', style: text.copyWith(color: kAuthFaint)));
    }
    return rows;
  }

  Widget _locationPreview(ChatMessageModel m) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 230,
        height: 120,
        child: Stack(
          children: [
            FlutterMap(
              options: MapOptions(
                initialCenter: LatLng(m.latitude!, m.longitude!),
                initialZoom: 15,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.none,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.ambulance_coordination',
                  tileProvider: CachedTileProvider(store: mapCacheStore),
                ),
              ],
            ),
            const Center(
              child: Icon(Icons.location_on, color: kAuthRed, size: 34,
                  shadows: [
                    Shadow(color: Colors.white, blurRadius: 8),
                    Shadow(color: Colors.black26, blurRadius: 3),
                  ]),
            ),
            Positioned(
              left: 6,
              bottom: 6,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${m.latitude!.toStringAsFixed(5)}, ${m.longitude!.toStringAsFixed(5)}',
                  style: GoogleFonts.inter(
                    fontSize: 9.5,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatProvider>();
    final auth = context.watch<AuthProvider>();
    final myId = auth.user?.id;
    final messages = chat.messagesFor(widget.session.emergencySessionId);
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
        title: InkWell(
          onTap: () => _showParticipants(context),
          borderRadius: BorderRadius.circular(8),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: kAuthRed,
                child: Text(
                  widget.session.drivers.isEmpty
                      ? 'AMB'
                      : widget.session.drivers.first.initials,
                  style: text.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.session.vehicleNumber,
                    style: text.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: kAuthText,
                    ),
                  ),
                  Text(
                    '${widget.session.officers.length} officer(s) · tap for details',
                    style: text.copyWith(fontSize: 11, color: kAuthMuted),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      body: GlassBackdrop(
        child: Column(
          children: [
            Expanded(
              child: messages.isEmpty
                  ? Center(
                      child: Text(
                        'No messages yet — say hello!',
                        style: text.copyWith(fontSize: 14, color: kAuthFaint),
                      ),
                    )
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 12),
                      itemCount: messages.length,
                      itemBuilder: (_, i) {
                        final m = messages[i];
                        final mine = m.senderUserId == myId;
                        return _bubble(context, m, mine, text);
                      },
                    ),
            ),
            _composerBar(context, chat, text),
          ],
        ),
      ),
    );
  }

  Widget _bubble(
    BuildContext context,
    ChatMessageModel m,
    bool mine,
    TextStyle text,
  ) {
    return Column(
      crossAxisAlignment:
          mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        if (!mine) ...[
          Padding(
            padding: const EdgeInsets.only(left: 6, top: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: m.isFromDriver ? kAuthGreen : kAuthRed,
                  child: Text(
                    m.initials,
                    style: text.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  m.senderName,
                  style: text.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: kAuthText,
                  ),
                ),
                const SizedBox(width: 5),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: (m.isFromDriver ? kAuthGreen : kAuthRed)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    m.isFromDriver ? 'Driver' : 'Officer',
                    style: text.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: m.isFromDriver ? kAuthGreen : kAuthRed,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        Align(
          alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: m.isLocation
                ? const EdgeInsets.all(8)
                : const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            constraints: const BoxConstraints(maxWidth: 310),
            decoration: BoxDecoration(
              color: mine ? kAuthRedBadgeBg : Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(14),
                topRight: const Radius.circular(14),
                bottomLeft: Radius.circular(mine ? 14 : 4),
                bottomRight: Radius.circular(mine ? 4 : 14),
              ),
              border: mine ? null : Border.all(color: kAuthBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment:
                  mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (m.isLocation) ...[
                  InkWell(
                    onTap: () => _openLocation(m),
                    borderRadius: BorderRadius.circular(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _locationPreview(m),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, 8, 4, 2),
                          child: Row(
                            children: [
                              const Icon(Icons.location_on,
                                  color: kAuthRed, size: 16),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  m.message.isEmpty
                                      ? 'Location'
                                      : m.message,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: text.copyWith(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: kAuthText,
                                  ),
                                ),
                              ),
                              Text(
                                'View map',
                                style: text.copyWith(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: kAuthRedLink,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else
                  Text(
                    m.message,
                    style: text.copyWith(
                      fontSize: 16,
                      color: kAuthText,
                      height: 1.35,
                    ),
                  ),
                const SizedBox(height: 3),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _timeLabel(m.createdAt),
                      style: text.copyWith(
                        fontSize: 11,
                        color: kAuthFaint,
                      ),
                    ),
                    if (mine) ...[
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.done_all_rounded,
                        size: 14,
                        color: kAuthGreen,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _composerBar(
    BuildContext context,
    ChatProvider chat,
    TextStyle text,
  ) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 8, 10, 10),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: kGlassBorder)),
        ),
        child: Row(
          children: [
            IconButton(
              onPressed: chat.sending ? null : () => _showAttachSheet(chat),
              icon: const Icon(Icons.add_circle_outline_rounded,
                  color: kAuthRed, size: 26),
              tooltip: 'Share location',
            ),
            Expanded(
              child: TextField(
                controller: _composer,
                minLines: 1,
                maxLines: 4,
                style: text.copyWith(fontSize: 14, color: kAuthText),
                cursorColor: kAuthRed,
                decoration: InputDecoration(
                  hintText: 'Message',
                  hintStyle: text.copyWith(fontSize: 14, color: kAuthFaint),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(color: kAuthBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(color: kAuthBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(color: kAuthRed, width: 1.4),
                  ),
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(chat),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: kAuthRed,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: chat.sending ? null : () => _send(chat),
                icon: chat.sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: SkeletonLoadingIndicator(size: 18),
                      )
                    : const Icon(Icons.send_rounded, size: 20, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}