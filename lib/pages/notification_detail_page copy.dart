// lib/pages/notifications/notification_detail_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// Détail d’une notification + réactions ❤️ / 👎
/// Requiert côté SQL :
///  - vue  user_notifications_view (has_reacted, likes, dislikes)
///  - RPC  api_notification_react_privacy(uuid, text)
class NotificationDetailPage extends StatefulWidget {
  final String notificationId;

  const NotificationDetailPage({super.key, required this.notificationId});

  @override
  State<NotificationDetailPage> createState() => _NotificationDetailPageState();
}

class _NotificationDetailPageState extends State<NotificationDetailPage> {
  final supa = Supabase.instance.client;

  bool _loading = true;
  String? _error;

  String _title = '';
  String _message = '';
  String? _attachmentUrl;
  DateTime? _createdAt;

  bool _hasReacted = false;
  int _likes = 0;
  int _dislikes = 0;

  @override
  void initState() {
    super.initState();
    _markReadSilently();
    _loadOne();
  }

  Future<void> _markReadSilently() async {
    try {
      final uid = supa.auth.currentUser?.id;
      if (uid == null) return;

      // On marque simplement comme lu (suppression de PostgrestMap increment)
      await supa.from('user_notifications').update({'is_read': true}).match({
        'user_id': uid,
        'notification_id': widget.notificationId,
      });
    } catch (_) {
      // Non bloquant
    }
  }

  Future<void> _loadOne() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final row = await supa
          .from('user_notifications_view')
          .select(
            'type,message,attachment_url,outbox_created_at,has_reacted,likes,dislikes',
          )
          .eq('notification_id', widget.notificationId)
          .single();

      setState(() {
        _title = (row['type'] as String?)?.trim() ?? 'Notification';
        _message = (row['message'] as String?)?.trim() ?? '';
        _attachmentUrl = (row['attachment_url'] as String?)?.trim();
        _createdAt = DateTime.tryParse(
          row['outbox_created_at']?.toString() ?? '',
        );
        _hasReacted = (row['has_reacted'] as bool?) ?? false;
        _likes = (row['likes'] as int?) ?? 0;
        _dislikes = (row['dislikes'] as int?) ?? 0;
      });
    } catch (e) {
      setState(() => _error = 'Erreur de chargement : $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool get _hasAttachment =>
      _attachmentUrl != null && _attachmentUrl!.trim().isNotEmpty;

  bool get _isImageAttachment {
    if (!_hasAttachment) return false;
    final u = _attachmentUrl!.toLowerCase();
    return u.endsWith('.png') ||
        u.endsWith('.jpg') ||
        u.endsWith('.jpeg') ||
        u.endsWith('.gif') ||
        u.endsWith('.webp');
  }

  Future<void> _openAttachment() async {
    if (!_hasAttachment) return;
    final url = Uri.parse(_attachmentUrl!);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible d’ouvrir la pièce jointe.')),
      );
    }
  }

  Future<void> _react(String kind) async {
    if (_hasReacted) return;
    try {
      final res = await supa.rpc(
        'api_notification_react_privacy',
        params: {
          'p_outbox': widget.notificationId,
          'p_reaction': kind, // 'like' ou 'dislike'
        },
      );

      if (mounted) {
        final msg = (res == 'exists')
            ? 'Vous avez déjà noté cette notification.'
            : 'Merci pour votre avis !';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
      }
      await _loadOne(); // rafraîchir has_reacted/compteurs
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur lors du vote : $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Détail de la notification')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: cs.error),
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadOne,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Titre
                  Text(
                    _title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (_createdAt != null)
                    Text(
                      _formatDate(_createdAt!),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurface.withOpacity(.6),
                      ),
                    ),

                  const SizedBox(height: 16),

                  // Message
                  if (_message.isNotEmpty)
                    SelectableText(
                      _message,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),

                  const SizedBox(height: 16),

                  // Pièce jointe
                  if (_hasAttachment) ...[
                    _isImageAttachment
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              _attachmentUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _AttachmentTile(
                                onTap: _openAttachment,
                                subtitle: 'Voir la pièce jointe',
                              ),
                            ),
                          )
                        : _AttachmentTile(
                            onTap: _openAttachment,
                            subtitle: 'Ouvrir la pièce jointe',
                          ),
                    const SizedBox(height: 16),
                  ],

                  // Compteurs
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      const Icon(Icons.favorite, size: 18),
                      const SizedBox(width: 6),
                      Text('$_likes'),
                      const SizedBox(width: 16),
                      const Icon(Icons.thumb_down_alt_rounded, size: 18),
                      const SizedBox(width: 6),
                      Text('$_dislikes'),
                      if (_hasReacted) ...[
                        const SizedBox(width: 16),
                        Icon(Icons.verified, size: 18, color: cs.primary),
                        const SizedBox(width: 4),
                        Text('Déjà notée', style: TextStyle(color: cs.primary)),
                      ],
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Boutons de réaction
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _hasReacted ? null : () => _react('like'),
                          icon: const Icon(Icons.favorite),
                          label: Text("J'aime ($_likes)"),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _hasReacted
                              ? null
                              : () => _react('dislike'),
                          icon: const Icon(Icons.thumb_down_alt_rounded),
                          label: Text("J'aime pas ($_dislikes)"),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  String _formatDate(DateTime dt) {
    final d = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
  }
}

class _AttachmentTile extends StatelessWidget {
  final VoidCallback onTap;
  final String subtitle;

  const _AttachmentTile({required this.onTap, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      onTap: onTap,
      tileColor: cs.surfaceVariant.withOpacity(.4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      leading: const Icon(Icons.attach_file),
      title: const Text('Pièce jointe'),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.open_in_new),
    );
  }
}
