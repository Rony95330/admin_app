import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'non_votants_list_page.dart';

/// 🔹 Couleurs de ta charte (au cas où tu n'importes pas AppColors)
const kMarine = Color(0xFF213A8F);
const kVert = Color(0xFF5FB670);
const kCie = Color(0xFFB0DEF1);
const kRouge = Color(0xFFE42313);

/// Petit helper pour compter inscrits / votants par cellule CSE+collège
class _CellCounts {
  int total = 0;
  int voted = 0;

  double get participation =>
      total == 0 ? 0.0 : (voted * 100.0) / total.toDouble();
}

/// Structure globale renvoyée par le chargement
class _RecapData {
  final List<String> cseList;
  final List<String> collegeList;
  final Map<String, Map<String, _CellCounts>> byCse;
  final int totalInscrits;
  final int totalVotants;

  _RecapData({
    required this.cseList,
    required this.collegeList,
    required this.byCse,
    required this.totalInscrits,
    required this.totalVotants,
  });

  double get participationGlobale =>
      totalInscrits == 0 ? 0.0 : (totalVotants * 100.0) / totalInscrits;
}

/// 🧮 Page principale : tableau récap CSE × Collège
class ElectionDashboardPage extends StatefulWidget {
  const ElectionDashboardPage({super.key});

  @override
  State<ElectionDashboardPage> createState() => _ElectionDashboardPageState();
}

class _ElectionDashboardPageState extends State<ElectionDashboardPage> {
  final _supabase = Supabase.instance.client;
  late Future<_RecapData> _futureRecap;

  @override
  void initState() {
    super.initState();
    _futureRecap = _loadRecap();
  }

  Future<_RecapData> _loadRecap() async {
    // 🟦 Charge tous les votants pour l'élection en cours
    // 👉 adapte la requête si tu filtres par "election_id" ou autre
    final raw = await _supabase
        .from('votants')
        .select('matricule, nom, prenom, cse_lib, college, a_vote');

    final List<dynamic> rowsDynamic = raw as List<dynamic>;
    final rows = rowsDynamic.cast<Map<String, dynamic>>();

    final allColleges = <String>{};
    final Map<String, Map<String, _CellCounts>> byCse = {};
    int totalInscrits = 0;
    int totalVotants = 0;

    for (final r in rows) {
      final cse = (r['cse_lib'] ?? 'CSE inconnu').toString();
      final college = (r['college'] ?? 'Collège inconnu').toString();
      final bool aVote = (r['a_vote'] ?? false) as bool;

      allColleges.add(college);
      totalInscrits++;
      if (aVote) totalVotants++;

      final cseMap = byCse.putIfAbsent(cse, () => {});
      final cell = cseMap.putIfAbsent(college, () => _CellCounts());
      cell.total++;
      if (aVote) cell.voted++;
    }

    final cseList = byCse.keys.toList()..sort();
    final collegeList = allColleges.toList()..sort();

    return _RecapData(
      cseList: cseList,
      collegeList: collegeList,
      byCse: byCse,
      totalInscrits: totalInscrits,
      totalVotants: totalVotants,
    );
  }

  void _openNonVotants(BuildContext context, String cse, String college) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NonVotantsListPage(
          cse: cse,
          college: college,
        ),
      ),
    );
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
            'Suivi des élections',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          centerTitle: false,
        ),
        body: FutureBuilder<_RecapData>(
          future: _futureRecap,
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
            final recap = snapshot.data!;
            if (recap.totalInscrits == 0) {
              return Center(
                child: Text(
                  'Aucun inscrit trouvé pour cette élection.',
                  style: GoogleFonts.poppins(),
                ),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 🔹 Bandeau global en haut
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  color: kCie,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Inscrits : ${recap.totalInscrits}   •   Votants : ${recap.totalVotants}',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          color: kMarine,
                        ),
                      ),
                      Text(
                        'Participation globale : ${recap.participationGlobale.toStringAsFixed(1)} %',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700,
                          color: kVert,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // 🔹 Tableau scrollable
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SingleChildScrollView(
                      child: DataTable(
                        headingRowColor:
                            WidgetStateProperty.all(kMarine.withOpacity(0.9)),
                        headingTextStyle: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                        dataRowHeight: 60,
                        columns: [
                          const DataColumn(label: Text('CSE')),
                          ...recap.collegeList
                              .map(
                                (c) => DataColumn(
                                  label: Text(
                                    c,
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              )
                              .toList(),
                          const DataColumn(label: Text('Total CSE')),
                        ],
                        rows: recap.cseList.map((cse) {
                          final cseMap = recap.byCse[cse] ?? {};

                          // Calcul du total CSE
                          int cseInscrits = 0;
                          int cseVotants = 0;
                          for (final cell in cseMap.values) {
                            cseInscrits += cell.total;
                            cseVotants += cell.voted;
                          }
                          final csePct = cseInscrits == 0
                              ? 0.0
                              : (cseVotants * 100.0) / cseInscrits;

                          return DataRow(
                            cells: [
                              DataCell(
                                Text(
                                  cse,
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              ...recap.collegeList.map((college) {
                                final cell = cseMap[college];
                                if (cell == null || cell.total == 0) {
                                  return const DataCell(
                                    Center(child: Text('-')),
                                  );
                                }

                                final pct = cell.participation;
                                final text =
                                    '${pct.toStringAsFixed(1)} %\n${cell.voted}/${cell.total}';

                                // teinte verte si bonne participation, rouge si faible
                                Color pctColor;
                                if (pct >= 70) {
                                  pctColor = kVert;
                                } else if (pct >= 40) {
                                  pctColor = Colors.orange;
                                } else {
                                  pctColor = kRouge;
                                }

                                return DataCell(
                                  InkWell(
                                    onTap: () {
                                      if (cell.total > cell.voted) {
                                        _openNonVotants(
                                            context, cse, college);
                                      }
                                    },
                                    child: Center(
                                      child: Text(
                                        text,
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w500,
                                          color: pctColor,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }),
                              DataCell(
                                Center(
                                  child: Text(
                                    '${csePct.toStringAsFixed(1)} %\n$cseVotants/$cseInscrits',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600,
                                      color: kMarine,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
