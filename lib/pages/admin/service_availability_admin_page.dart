import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/service_availability_admin_service.dart';

class ServiceAvailabilityAdminPage extends StatefulWidget {
  const ServiceAvailabilityAdminPage({super.key});

  @override
  State<ServiceAvailabilityAdminPage> createState() =>
      _ServiceAvailabilityAdminPageState();
}

class _ServiceAvailabilityAdminPageState
    extends State<ServiceAvailabilityAdminPage> {
  final ServiceAvailabilityAdminService _service =
      ServiceAvailabilityAdminService();

  final Map<String, TextEditingController> _messageControllers =
      <String, TextEditingController>{
        'mobile': TextEditingController(),
        'admin': TextEditingController(),
      };

  bool _loading = true;
  bool _allowed = false;
  String? _error;

  List<ServiceAvailabilityStatus> _statuses =
      const <ServiceAvailabilityStatus>[];

  List<ServiceAvailabilityAuditItem> _audit =
      const <ServiceAvailabilityAuditItem>[];

  final Set<String> _busyTargets = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final controller in _messageControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final allowed = await _service.isSuperuser();

      if (!allowed) {
        if (!mounted) return;
        setState(() {
          _allowed = false;
          _loading = false;
        });
        return;
      }

      final statuses = await _service.getAllStatuses();
      final audit = await _service.getAudit();

      for (final status in statuses) {
        _messageControllers[status.target]?.text =
            status.publicMessage ?? _defaultMessage(status.mode);
      }

      if (!mounted) return;

      setState(() {
        _allowed = true;
        _statuses = statuses;
        _audit = audit;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String _defaultMessage(String mode) {
    switch (mode) {
      case 'maintenance':
        return 'Une opération de maintenance est en cours.';
      case 'suspended':
        return 'L’accès à l’application est temporairement suspendu.';
      default:
        return '';
    }
  }

  String _targetLabel(String target) {
    return target == 'mobile' ? 'Application mobile' : 'Console admin';
  }

  String _modeLabel(String? mode) {
    switch (mode) {
      case 'maintenance':
        return 'Maintenance';
      case 'suspended':
        return 'Suspendu';
      case 'active':
        return 'Actif';
      default:
        return '—';
    }
  }

  IconData _modeIcon(String mode) {
    switch (mode) {
      case 'maintenance':
        return Icons.build_circle_outlined;
      case 'suspended':
        return Icons.pause_circle_outline;
      default:
        return Icons.check_circle_outline;
    }
  }

  Color _modeColor(BuildContext context, String mode) {
    switch (mode) {
      case 'maintenance':
        return Colors.orange.shade700;
      case 'suspended':
        return Theme.of(context).colorScheme.error;
      default:
        return Colors.green.shade700;
    }
  }

  Future<void> _requestChange(
    ServiceAvailabilityStatus status,
    String newMode,
  ) async {
    if (status.mode == newMode) return;

    final targetLabel = _targetLabel(status.target);
    final modeLabel = _modeLabel(newMode);

    String confirmation =
        'Voulez-vous passer $targetLabel en mode « $modeLabel » ?';

    if (status.target == 'admin' && newMode != 'active') {
      confirmation =
          '$confirmation\n\n'
          'Attention : la console admin sera elle-même bloquée. '
          'Pour la réactiver, il faudra utiliser un accès externe '
          'à Supabase ou le contrôle administrateur hors console.';
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Confirmer le changement'),
          content: Text(confirmation),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Confirmer'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() => _busyTargets.add(status.target));

    try {
      String? message;

      if (newMode != 'active') {
        final typed = _messageControllers[status.target]?.text.trim() ?? '';
        message = typed.isEmpty ? _defaultMessage(newMode) : typed;
      }

      await _service.setStatus(
        target: status.target,
        mode: newMode,
        publicMessage: message,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$targetLabel : ${_modeLabel(newMode)}')),
      );

      await _load();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur : $e')));
    } finally {
      if (mounted) {
        setState(() => _busyTargets.remove(status.target));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_allowed) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Cette page est réservée au super-administrateur.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: <Widget>[
          Row(
            children: <Widget>[
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Disponibilité du service',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text('Contrôle centralisé de l’accès aux applications.'),
                  ],
                ),
              ),
              IconButton.filledTonal(
                tooltip: 'Actualiser',
                onPressed: _load,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ..._statuses.map(_buildTargetCard),
          const SizedBox(height: 28),
          const Text(
            'Historique récent',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          _buildAudit(),
        ],
      ),
    );
  }

  Widget _buildTargetCard(ServiceAvailabilityStatus status) {
    final busy = _busyTargets.contains(status.target);
    final color = _modeColor(context, status.mode);

    return Card(
      margin: const EdgeInsets.only(bottom: 18),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  status.target == 'mobile'
                      ? Icons.smartphone_outlined
                      : Icons.admin_panel_settings_outlined,
                  size: 30,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _targetLabel(status.target),
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(_modeIcon(status.mode), size: 18, color: color),
                      const SizedBox(width: 6),
                      Text(
                        _modeLabel(status.mode),
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _messageControllers[status.target],
              enabled: !busy,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Message affiché aux utilisateurs',
                hintText:
                    'Message visible pendant la maintenance ou la suspension',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            if (status.target == 'admin') ...<Widget>[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(Icons.lock_outline, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Protection anti-verrouillage : la console admin '
                        'ne peut pas être placée en maintenance ou suspendue '
                        'depuis cette page. Une modification exceptionnelle '
                        'reste possible depuis Supabase.',
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),
            ],
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                _modeButton(status, 'active', busy),
                _modeButton(status, 'maintenance', busy),
                _modeButton(status, 'suspended', busy),
              ],
            ),
            if (status.updatedAt != null) ...<Widget>[
              const SizedBox(height: 14),
              Text(
                'Dernière modification : '
                '${DateFormat('dd/MM/yyyy à HH:mm').format(status.updatedAt!.toLocal())}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _modeButton(ServiceAvailabilityStatus status, String mode, bool busy) {
    final selected = status.mode == mode;
    final color = _modeColor(context, mode);
    final selfLockBlocked = status.target == 'admin' && mode != 'active';

    return OutlinedButton.icon(
      onPressed: busy || selected || selfLockBlocked
          ? null
          : () => _requestChange(status, mode),
      icon: busy && !selected ? const SizedBox.shrink() : Icon(_modeIcon(mode)),
      label: Text(_modeLabel(mode)),
      style: OutlinedButton.styleFrom(
        foregroundColor: selected ? Colors.white : color,
        backgroundColor: selected ? color : null,
      ),
    );
  }

  Widget _buildAudit() {
    if (_audit.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text('Aucun changement enregistré.'),
        ),
      );
    }

    return Card(
      child: Column(
        children: _audit.map((item) {
          final date = item.changedAt == null
              ? 'Date inconnue'
              : DateFormat(
                  'dd/MM/yyyy HH:mm',
                ).format(item.changedAt!.toLocal());

          return ListTile(
            leading: Icon(
              item.target == 'mobile'
                  ? Icons.smartphone_outlined
                  : Icons.admin_panel_settings_outlined,
            ),
            title: Text(
              '${_targetLabel(item.target)} : '
              '${_modeLabel(item.oldMode)} → ${_modeLabel(item.newMode)}',
            ),
            subtitle: Text(date),
          );
        }).toList(),
      ),
    );
  }
}
