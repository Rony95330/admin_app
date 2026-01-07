import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 🔹 Couleurs de ta charte (tu peux les remplacer par AppColors)
const kMarine = Color(0xFF213A8F);
const kVert = Color(0xFF5FB670);
const kRouge = Color(0xFFE42313);

class NonVotantsListPage extends StatelessWidget {
  final String cse;
  final String college;

  const NonVotantsListPage({
    super.key,
    required this.cse,
    required this.college,
  });

  Future<List<Map<String, dynamic>>> _loadNonVotants() async {
    final supabase = Supabase.instance.client;

    final raw = await supabase
        .from('votants')
        .select('matricule, nom, prenom, etablissement, telephone, mail')
        .eq('cse_lib', cse)
        .eq('college', college)
        .eq('a_vote', false)
        .order('nom');

    final List<dynamic> rowsDynamic = raw as List<dynamic>;
    return rowsDynamic.cast<Map<String, dynamic>>();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme);

    return Theme(
      data: Theme.of(context).copyWith(textTheme: textTheme),
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: kMarine,
          title: Text(
            'Non-votants',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(40),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '$cse\n$college',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ),
            ),
          ),
        ),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: _loadNonVotants(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Erreur de chargement : ${snapshot.error}',
                  style: GoogleFonts.poppins(color: kRouge),
                  textAlign: TextAlign.center,
                ),
              );
            }

            final data = snapshot.data ?? [];
            if (data.isEmpty) {
              return Center(
                child: Text(
                  'Tous les inscrits de ce collège ont voté 🎉',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w500,
                    color: kVert,
                  ),
                  textAlign: TextAlign.center,
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: data.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final row = data[index];
                final nom = (row['nom'] ?? '').toString();
                final prenom = (row['prenom'] ?? '').toString();
                final matricule = (row['matricule'] ?? '').toString();
                final etablissement = (row['etablissement'] ?? '').toString();
                final tel = (row['telephone'] ?? '').toString();
                final mail = (row['mail'] ?? '').toString();

                return Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(12),
                    title: Text(
                      '$nom $prenom',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          'Matricule : $matricule',
                          style: GoogleFonts.poppins(fontSize: 12),
                        ),
                        if (etablissement.isNotEmpty)
                          Text(
                            etablissement,
                            style: GoogleFonts.poppins(fontSize: 12),
                          ),
                        const SizedBox(height: 4),
                        if (tel.isNotEmpty)
                          Text(
                            '📞 $tel',
                            style: GoogleFonts.poppins(fontSize: 12),
                          ),
                        if (mail.isNotEmpty)
                          Text(
                            '✉️ $mail',
                            style: GoogleFonts.poppins(fontSize: 12),
                          ),
                      ],
                    ),
                    onTap: () {
                      // 🔜 Plus tard : ouvrir une fiche détaillée + relances
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
