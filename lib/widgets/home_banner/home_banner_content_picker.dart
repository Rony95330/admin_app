import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/home_banner/home_banner_service.dart';

class HomeBannerContentChoice {
  const HomeBannerContentChoice({
    required this.value,
    required this.title,
    required this.subtitle,
  });

  final String value;
  final String title;
  final String subtitle;
}

class HomeBannerContentPicker extends StatefulWidget {
  const HomeBannerContentPicker({
    super.key,
    required this.actionType,
    required this.service,
  });

  final String actionType;
  final HomeBannerService service;

  @override
  State<HomeBannerContentPicker> createState() =>
      _HomeBannerContentPickerState();
}

class _HomeBannerContentPickerState extends State<HomeBannerContentPicker> {
  List<Map<String, dynamic>> _items = const <Map<String, dynamic>>[];
  bool _loading = true;
  String? _error;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await widget.service.fetchActionChoices(widget.actionType);
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  String _title(Map<String, dynamic> item) {
    final value = widget.actionType == 'press_review'
        ? item['titre']
        : item['title'];
    final title = value?.toString().trim() ?? '';
    return title.isEmpty ? 'Sans titre' : title;
  }

  String _subtitle(Map<String, dynamic> item) {
    final parts = <String>[];
    final cse = item['cse']?.toString().trim() ?? '';
    if (cse.isNotEmpty) parts.add(cse);

    final description = item['description']?.toString().trim() ?? '';
    final source = (item['source'] ?? item['journal'])?.toString().trim() ?? '';
    if (source.isNotEmpty) {
      parts.add(source);
    } else if (description.isNotEmpty) {
      parts.add(description.replaceAll(RegExp(r'\s+'), ' '));
    }

    final seconds = item['duration_seconds'];
    final duration = seconds is num ? seconds.toInt() : null;
    if (duration != null && duration > 0) {
      parts.add(
        '${duration ~/ 60}:${(duration % 60).toString().padLeft(2, '0')}',
      );
    }
    return parts.join(' • ');
  }

  IconData get _icon => switch (widget.actionType) {
    'tract' => Icons.article_outlined,
    'press_review' => Icons.newspaper_rounded,
    'podcast' => Icons.podcasts_rounded,
    _ => Icons.attach_file_rounded,
  };

  String get _dialogTitle => switch (widget.actionType) {
    'tract' => 'Choisir un tract',
    'press_review' => 'Choisir une revue de presse',
    'podcast' => 'Choisir un podcast',
    _ => 'Choisir un contenu',
  };

  @override
  Widget build(BuildContext context) {
    final query = _search.trim().toLowerCase();
    final filtered = query.isEmpty
        ? _items
        : _items
              .where((item) {
                return '${_title(item)} ${_subtitle(item)}'
                    .toLowerCase()
                    .contains(query);
              })
              .toList(growable: false);
    final media = MediaQuery.sizeOf(context);

    return AlertDialog(
      title: Text(_dialogTitle),
      content: SizedBox(
        width: math.min(620.0, media.width * .90),
        height: math.min(560.0, media.height * .70),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(
                child: Text(
                  'Chargement impossible.\n$_error',
                  textAlign: TextAlign.center,
                ),
              )
            : Column(
                children: [
                  TextField(
                    autofocus: true,
                    onChanged: (value) => setState(() => _search = value),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search_rounded),
                      hintText: 'Rechercher par titre, CSE ou description…',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: filtered.isEmpty
                        ? const Center(child: Text('Aucun contenu trouvé.'))
                        : Scrollbar(
                            thumbVisibility: true,
                            child: ListView.separated(
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final item = filtered[index];
                                final title = _title(item);
                                final subtitle = _subtitle(item);
                                return ListTile(
                                  leading: CircleAvatar(child: Icon(_icon)),
                                  title: Text(
                                    title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: subtitle.isEmpty
                                      ? null
                                      : Text(
                                          subtitle,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                  onTap: () => Navigator.pop(
                                    context,
                                    HomeBannerContentChoice(
                                      value: item['id'].toString(),
                                      title: title,
                                      subtitle: subtitle,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                  ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
      ],
    );
  }
}
