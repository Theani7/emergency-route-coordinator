import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/chat_models.dart';
import '../providers/chat_provider.dart';
import '../widgets/skeleton_widgets.dart';
import '../widgets/auth_widgets.dart';
import 'chat_room_screen.dart';



class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<ChatProvider>().loadSessions();
    });
  }

  String _timeLabel(DateTime? dt) {
    if (dt == null) return '';
    final now = DateTime.now();
    final sameDay = dt.year == now.year &&
        dt.month == now.month &&
        dt.day == now.day;
    if (sameDay) return DateFormat('HH:mm').format(dt.toLocal());
    return DateFormat('MMM d').format(dt.toLocal());
  }

  String _chatTitle(ChatSessionSummary s) {
    if (s.officers.isNotEmpty) {
      final names = s.officers.map((o) => o.name).toList();
      if (names.length > 1) {
        return '${s.vehicleNumber} · ${names.length} officers';
      }
      return '${s.vehicleNumber} · ${names.first.split(' ').first}';
    }
    return s.vehicleNumber;
  }

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatProvider>();
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
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                color: kAuthRed,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.chat_rounded, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Text(
              'Chat',
              style: text.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
                color: kAuthText,
              ),
            ),
          ],
        ),
      ),
      body: GlassBackdrop(
        child: chat.loading && chat.sessions.isEmpty
            ? const SkeletonList(itemCount: 5)
            : chat.sessions.isEmpty
                ? RefreshIndicator(
                    onRefresh: chat.loadSessions,
                    child: const AuthEmptyState(
                      icon: Icons.forum_outlined,
                      title: 'No conversations yet',
                      hint: 'Chat with drivers and officers for each emergency '
                          'trip will appear here.',
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: chat.loadSessions,
                    child: ListView.separated(
                      padding: const EdgeInsets.only(top: 6, bottom: 110),
                      itemCount: chat.sessions.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        indent: 72,
                        color: kAuthBorder.withValues(alpha: 0.6),
                      ),
                      itemBuilder: (_, i) {
                        final s = chat.sessions[i];
                        return _sessionTile(context, chat, s, text);
                      },
                    ),
                  ),
      ),
    );
  }

  Widget _sessionTile(
    BuildContext context,
    ChatProvider chat,
    ChatSessionSummary s,
    TextStyle text,
  ) {
    final driver = s.drivers.isEmpty ? null : s.drivers.first;
    final preview = s.lastMessage ?? 'No messages yet — say hello!';
    final hasUnread = s.unreadCount > 0;

    return InkWell(
      onTap: () {
        chat.openSession(s.emergencySessionId);
        Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => ChatRoomScreen(session: s)))
            .then((_) {
          if (mounted) chat.loadSessions();
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            _avatar(s.emergencySessionId, driver?.initials, true, 46),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _chatTitle(s),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 14.5,
                            color: kAuthText,
                          ),
                        ),
                      ),
                      Text(
                        _timeLabel(s.lastMessageAt),
                        style: text.copyWith(
                          fontSize: 11,
                          color: hasUnread ? kAuthRed : kAuthFaint,
                          fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  if (driver != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 3),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: kAuthGreen.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${driver.name} · Driver',
                        style: text.copyWith(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: kAuthGreen,
                        ),
                      ),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          preview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.copyWith(
                            fontSize: 13,
                            color: s.lastMessage == null ? kAuthFaint : kAuthMuted,
                            fontWeight: hasUnread
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ),
                      if (hasUnread) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: const BoxDecoration(
                            color: kAuthRed,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${s.unreadCount}',
                            style: text.copyWith(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatar(int seed, String? initials, bool circle, double size) {
    final Color bg = kAuthRed;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle ? null : BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          initials ?? 'AMB',
          style: GoogleFonts.inter(
            fontSize: size * 0.36,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}