import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GoodiesAddPage extends StatefulWidget {
  /// null => création, non-null => édition du goodie existant
  final String? goodieId;

  const GoodiesAddPage({super.key, this.goodieId});

  @override
  State<GoodiesAddPage> createState() => _GoodiesAddPageState();
}

class _GoodiesAddPageState extends State<GoodiesAddPage> {
  final supa = Supabase.instance.client;

  final _formKey = GlobalKey<FormState>();

  // Champs texte
  final _codeController = TextEditingController();
  final _libelleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _stockController = TextEditingController();
  final _photoUrlController = TextEditingController();

  // Multi-sélection population & niveau (enum[])
  final Set<String> _selectedPopulations = {}; // goodie_population[]
  final Set<String> _selectedNiveaux = {}; // goodie_niveau[]

  // CSE ciblés
  bool _tousCse = true;
  final Set<String> _selectedCseCodes = {}; // cse_codes[]

  // Actif ou non
  bool _actif = true;

  // Image (on garde seulement les bytes pour l’upload)
  Uint8List? _pickedImageBytes;

  bool _loading = false;
  bool _initialLoading = true;
  String? _error;

  // 🔹 ENUM goodie_population (valeurs exactes côté SQL)
  static const List<_EnumOption> populationOptions = [
    _EnumOption('tous', 'Tous'),
    _EnumOption('adherents', 'Adhérents'),
    _EnumOption('militants', 'Militants'),
  ];

  // 🔹 ENUM goodie_niveau (cohérent avec la fonction SQL)
  static const List<_EnumOption> niveauOptions = [
    _EnumOption('tous', 'Tous'),
    _EnumOption('cadres', 'Cadres'),
    _EnumOption('non_cadres', 'Non cadres'),
  ];

  // 🔹 CSE (complète selon ton CSV si besoin)
  static const List<String> cseOptions = [
    'CSE EXPLOITATION COURT COURRIER',
    "CSE SYSTEMES D'INFORMATION",
    'CSE INDUSTRIEL',
    'CSE EXPLOITATION HUB',
    'CSE PILOTAGE ECONOMIQUE',
    'CSE AIR FRANCE CARGO',
    'CSE EXPLOITATION AERIENNE',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.goodieId != null) {
      _loadExistingGoodie();
    } else {
      // Par défaut pour un nouveau goodie : tous
      _selectedPopulations.add('tous');
      _selectedNiveaux.add('tous');
      _initialLoading = false;
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _libelleController.dispose();
    _descriptionController.dispose();
    _stockController.dispose();
    _photoUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingGoodie() async {
    setState(() {
      _initialLoading = true;
      _error = null;
    });

    try {
      final res = await supa
          .from('goodies')
          .select()
          .eq('id', widget.goodieId!) // ✅ goodieId non null ici
          .maybeSingle();

      if (res == null) {
        setState(() {
          _error = "Goodie introuvable.";
          _initialLoading = false;
        });
        return;
      }

      _codeController.text = res['code'] ?? '';
      _libelleController.text = res['libelle'] ?? '';
      _descriptionController.text = res['description'] ?? '';
      _photoUrlController.text = res['photo_url'] ?? '';

      // population_cible : enum[] => List<dynamic>
      final rawPop = res['population_cible'];
      List<String> pops;
      if (rawPop is List) {
        pops = rawPop.whereType<String>().toList();
      } else if (rawPop is String) {
        pops = [rawPop];
      } else {
        pops = [];
      }
      if (pops.isEmpty) pops = ['tous'];
      _selectedPopulations
        ..clear()
        ..addAll(pops);

      // niveau_cible : enum[] => List<dynamic>
      final rawNiv = res['niveau_cible'];
      List<String> nivs;
      if (rawNiv is List) {
        nivs = rawNiv.whereType<String>().toList();
      } else if (rawNiv is String) {
        nivs = [rawNiv];
      } else {
        nivs = [];
      }
      if (nivs.isEmpty) nivs = ['tous'];
      _selectedNiveaux
        ..clear()
        ..addAll(nivs);

      _tousCse = (res['tous_cse'] ?? true) as bool;
      _actif = (res['actif'] ?? true) as bool;

      final List<dynamic>? cseCodesDyn = res['cse_codes'] as List<dynamic>?;
      _selectedCseCodes
        ..clear()
        ..addAll((cseCodesDyn ?? []).whereType<String>());

      setState(() {
        _initialLoading = false;
      });
    } on PostgrestException catch (e) {
      setState(() {
        _error = "Erreur Supabase: ${e.message}";
        _initialLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = "Erreur inattendue: $e";
        _initialLoading = false;
      });
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      setState(() {
        _pickedImageBytes = bytes;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la sélection de l’image: $e')),
      );
    }
  }

  Future<String?> _uploadImageIfNeeded() async {
    // Si pas de nouvelle image → on garde l’URL saisie
    if (_pickedImageBytes == null) {
      final existing = _photoUrlController.text.trim();
      return existing.isEmpty ? null : existing;
    }

    final filename = 'goodies_${DateTime.now().millisecondsSinceEpoch}.jpg';

    try {
      await supa.storage
          .from('goodies')
          .uploadBinary(
            filename,
            _pickedImageBytes!,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );

      final publicUrl = supa.storage.from('goodies').getPublicUrl(filename);
      return publicUrl;
    } on StorageException catch (e) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur upload image: ${e.message}")),
      );
      return null;
    } catch (e) {
      if (!mounted) return null;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Erreur upload image: $e")));
      return null;
    }
  }

  Future<void> _saveGoodie() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedPopulations.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choisir au moins une population cible.')),
      );
      return;
    }
    if (_selectedNiveaux.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choisir au moins un niveau cible.')),
      );
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final photoUrl = await _uploadImageIfNeeded();

      int? stock;
      if (_stockController.text.trim().isNotEmpty) {
        stock = int.tryParse(_stockController.text.trim());
      }

      final List<String> cseCodes = _tousCse
          ? <String>[]
          : _selectedCseCodes.toList();

      final Map<String, dynamic> data = {
        'code': _codeController.text.trim(),
        'libelle': _libelleController.text.trim(),
        'description': _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        'photo_url': photoUrl,
        'population_cible': _selectedPopulations.toList(),
        'niveau_cible': _selectedNiveaux.toList(),
        'tous_cse': _tousCse,
        'cse_codes': cseCodes,
        'actif': _actif,
        'stock_theorique': stock,
      };

      if (widget.goodieId == null) {
        final userId = supa.auth.currentUser?.id;
        if (userId != null) {
          data['created_by'] = userId;
        }
        await supa.from('goodies').insert(data);
      } else {
        await supa
            .from('goodies')
            .update(data)
            .eq('id', widget.goodieId!); // ✅ non null ici aussi
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.goodieId == null
                ? 'Goodie créé avec succès'
                : 'Goodie mis à jour avec succès',
          ),
        ),
      );
      Navigator.of(context).pop(true);
    } on PostgrestException catch (e) {
      setState(() {
        _error = "Erreur Supabase: ${e.message}";
      });
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur Supabase: ${e.message}')));
    } catch (e) {
      setState(() {
        _error = "Erreur inattendue: $e";
      });
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  // Gestion spéciale du chip "tous" pour la population
  void _togglePopulation(String value) {
    setState(() {
      if (value == 'tous') {
        if (_selectedPopulations.contains('tous')) {
          _selectedPopulations.remove('tous');
        } else {
          _selectedPopulations
            ..clear()
            ..add('tous');
        }
      } else {
        _selectedPopulations.remove('tous');
        if (_selectedPopulations.contains(value)) {
          _selectedPopulations.remove(value);
        } else {
          _selectedPopulations.add(value);
        }
        if (_selectedPopulations.isEmpty) {
          _selectedPopulations.add('tous');
        }
      }
    });
  }

  // Gestion spéciale du chip "tous" pour le niveau
  void _toggleNiveau(String value) {
    setState(() {
      if (value == 'tous') {
        if (_selectedNiveaux.contains('tous')) {
          _selectedNiveaux.remove('tous');
        } else {
          _selectedNiveaux
            ..clear()
            ..add('tous');
        }
      } else {
        _selectedNiveaux.remove('tous');
        if (_selectedNiveaux.contains(value)) {
          _selectedNiveaux.remove(value);
        } else {
          _selectedNiveaux.add(value);
        }
        if (_selectedNiveaux.isEmpty) {
          _selectedNiveaux.add('tous');
        }
      }
    });
  }

  Widget _buildImagePreview() {
    Widget content;

    if (_pickedImageBytes != null) {
      content = Image.memory(_pickedImageBytes!, fit: BoxFit.cover);
    } else if (_photoUrlController.text.trim().isNotEmpty) {
      content = Image.network(
        _photoUrlController.text.trim(),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            const Center(child: Text('Impossible de charger la photo')),
      );
    } else {
      content = const Center(child: Text('Aucune image sélectionnée'));
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 180,
        width: double.infinity,
        color: Colors.grey.shade200,
        child: content,
      ),
    );
  }

  Widget _buildCseMultiSelect() {
    if (_tousCse) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CSE ciblés',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: cseOptions.map((cse) {
            final selected = _selectedCseCodes.contains(cse);
            return FilterChip(
              label: Text(cse, style: GoogleFonts.poppins(fontSize: 12)),
              selected: selected,
              onSelected: (value) {
                setState(() {
                  if (value) {
                    _selectedCseCodes.add(cse);
                  } else {
                    _selectedCseCodes.remove(cse);
                  }
                });
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildPopulationChips() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Populations cibles',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: populationOptions.map((opt) {
            final selected = _selectedPopulations.contains(opt.value);
            return FilterChip(
              label: Text(opt.label),
              selected: selected,
              onSelected: (_) => _togglePopulation(opt.value),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildNiveauChips() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Niveaux cibles',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: niveauOptions.map((opt) {
            final selected = _selectedNiveaux.contains(opt.value);
            return FilterChip(
              label: Text(opt.label),
              selected: selected,
              onSelected: (_) => _toggleNiveau(opt.value),
            );
          }).toList(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.goodieId == null
        ? 'Ajouter un goodie'
        : 'Modifier un goodie';
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          title,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
      ),
      body: _initialLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_error != null) ...[
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _error!,
                            style: TextStyle(color: Colors.red.shade800),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Code
                      TextFormField(
                        controller: _codeController,
                        decoration: const InputDecoration(
                          labelText: 'Code',
                          hintText: 'ex: USB_LAMP_001',
                          border: OutlineInputBorder(),
                        ),
                        textInputAction: TextInputAction.next,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Le code est obligatoire';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      // Libellé
                      TextFormField(
                        controller: _libelleController,
                        decoration: const InputDecoration(
                          labelText: 'Libellé',
                          hintText: 'ex: Lampe USB CFECGC',
                          border: OutlineInputBorder(),
                        ),
                        textInputAction: TextInputAction.next,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Le libellé est obligatoire';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      // Description
                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 16),

                      // Photo
                      Text(
                        'Photo du goodie',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),

                      _buildImagePreview(),
                      const SizedBox(height: 8),

                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _pickImage(ImageSource.camera),
                              icon: const Icon(Icons.photo_camera),
                              label: const Text('Prendre une photo'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _pickImage(ImageSource.gallery),
                              icon: const Icon(Icons.photo),
                              label: const Text('Depuis la galerie'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      TextFormField(
                        controller: _photoUrlController,
                        decoration: const InputDecoration(
                          labelText: 'URL de la photo (optionnel)',
                          border: OutlineInputBorder(),
                          helperText:
                              'Laisser vide si vous utilisez uniquement la photo uploadée',
                        ),
                      ),
                      const SizedBox(height: 16),

                      _buildPopulationChips(),
                      const SizedBox(height: 16),
                      _buildNiveauChips(),
                      const SizedBox(height: 16),

                      // Tous CSE + CSE ciblés
                      SwitchListTile(
                        title: const Text('Goodie visible pour tous les CSE'),
                        value: _tousCse,
                        onChanged: (value) {
                          setState(() {
                            _tousCse = value;
                          });
                        },
                      ),
                      const SizedBox(height: 8),
                      _buildCseMultiSelect(),

                      // Actif ?
                      SwitchListTile(
                        title: const Text('Goodie actif'),
                        subtitle: const Text(
                          "Si inactif, il n'apparaîtra pas pour la distribution",
                        ),
                        value: _actif,
                        onChanged: (value) {
                          setState(() {
                            _actif = value;
                          });
                        },
                      ),
                      const SizedBox(height: 8),

                      // Stock
                      TextFormField(
                        controller: _stockController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Stock théorique (optionnel)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Bouton Enregistrer
                      SizedBox(
                        height: 48,
                        child: ElevatedButton.icon(
                          icon: _loading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Icon(Icons.save),
                          label: Text(
                            _loading ? 'Enregistrement...' : 'Enregistrer',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          onPressed: _loading ? null : _saveGoodie,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: theme.colorScheme.onPrimary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

class _EnumOption {
  final String value;
  final String label;
  const _EnumOption(this.value, this.label);
}
