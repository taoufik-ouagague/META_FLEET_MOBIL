import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../controllers/auth_controller.dart';
import '../screens/demandes/demande_or_apercu_page.dart';
import '../screens/or/or_apercu_page.dart';
import '../screens/vidanges/vidange_apercu_page.dart';
import '../services/api_service.dart';
import 'apercu_kit.dart';
import 'filtre_pastille.dart';

/// Historique d'un vehicule : ses derniers OR et vidanges, filtrables par type,
/// chaque ligne ouvrant l'apercu correspondant. Partage par les fiches
/// vehicule, OR et vidange.
class HistoriqueVehicule extends StatefulWidget {
  final int vehiculeId;

  const HistoriqueVehicule({super.key, required this.vehiculeId});

  @override
  State<HistoriqueVehicule> createState() => _HistoriqueVehiculeState();
}

class _HistoriqueVehiculeState extends State<HistoriqueVehicule> {
  final _auth = Get.find<AuthController>();

  List<Map<String, dynamic>> _historique = const [];
  bool _chargement = true;

  final _filtreHistorique = TextEditingController();
  String _rechercheHistorique = '';

  /// null = tout, 'or' ou 'vidange' pour ne garder qu'un type.
  String? _typeHistorique;

  @override
  void initState() {
    super.initState();
    _chargerHistorique();
  }

  @override
  void dispose() {
    _filtreHistorique.dispose();
    super.dispose();
  }

  Future<void> _chargerHistorique() async {
    final id = widget.vehiculeId;
    Future<List<Map<String, dynamic>>> charger(String url, String type) async {
      try {
        final data = await _auth.makeRequest(
          url,
          method: 'POST',
          body: {'vehiculeId': id},
          showErrorSnackbar: false,
        );
        final contenu = data is Map ? (data['content'] ?? data['data']) : data;
        if (contenu is List) {
          return contenu.whereType<Map>().map((e) {
            final item = Map<String, dynamic>.from(e);
            item['_type'] = type;
            return item;
          }).toList();
        }
      } catch (_) {
        // Liste indisponible : on garde la fiche, sans l'historique.
      }
      return <Map<String, dynamic>>[];
    }

    final resultats = await Future.wait([
      charger(ApiService.listOr(page: 0, size: 15), 'or'),
      charger(ApiService.listVidanges(page: 0, size: 15), 'vidange'),
      charger(ApiService.listDemandesOR(page: 0, size: 15), 'demande'),
    ]);

    final historique = [...resultats[0], ...resultats[1], ...resultats[2]];

    // Dates ISO-8601 : l'ordre lexicographique suit l'ordre chronologique.
    // Les entrées sans date finissent en bas.
    historique.sort((a, b) {
      final da = _dateHistorique(a);
      final db = _dateHistorique(b);
      if (da.isEmpty && db.isEmpty) return 0;
      if (da.isEmpty) return 1;
      if (db.isEmpty) return -1;
      return db.compareTo(da);
    });

    if (!mounted) return;
    setState(() {
      _historique = historique;
      _chargement = false;
    });
  }

  /// Côté vidange le DTO expose dateDebut/dateFin (+ variantes « Prevu »),
  /// pas dateRealisation/datePrevue : date réelle si elle existe, sinon planifiée.

  String _dateHistorique(Map<String, dynamic> item) {
    final raw = item['_type'] == 'vidange'
        ? (item['dateFin'] ??
              item['dateDebut'] ??
              item['dateFinPrevu'] ??
              item['dateDebutPrevu'] ??
              item['dateCreation'])
        : (item['dateOrdreReparation'] ??
              item['dateDemande'] ??
              item['dateSouhaitee'] ??
              item['dateCreation']);
    return raw?.toString() ?? '';
  }

  /// Numero de l'OR ou de la vidange, selon la ligne d'historique.
  String _numeroHistorique(Map<String, dynamic> item) =>
      (item['numero'] ??
              item['numeroOrdreReparation'] ??
              item['numeroDemande'] ??
              '')
          .toString();

  @override
  Widget build(BuildContext context) {
    if (_chargement) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    final requete = _rechercheHistorique.trim().toLowerCase();
    final lignes = _historique.where((item) {
      if (_typeHistorique != null && item['_type'] != _typeHistorique) {
        return false;
      }
      if (requete.isEmpty) return true;
      return _numeroHistorique(item).toLowerCase().contains(requete);
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: TextField(
            controller: _filtreHistorique,
            onChanged: (v) => setState(() => _rechercheHistorique = v),
            style: GoogleFonts.poppins(fontSize: 12.5),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Numéro OR ou vidange...',
              hintStyle: GoogleFonts.poppins(
                fontSize: 12.5,
                color: const Color(0xFF94A3B8),
              ),
              prefixIcon: const Icon(
                LucideIcons.search,
                size: 16,
                color: Color(0xFF94A3B8),
              ),
              suffixIcon: _rechercheHistorique.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(LucideIcons.x, size: 15),
                      color: const Color(0xFF94A3B8),
                      onPressed: () {
                        _filtreHistorique.clear();
                        setState(() => _rechercheHistorique = '');
                      },
                    ),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.70),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.90),
                  width: 1.5,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.90),
                  width: 1.5,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: kApBleu, width: 1.5),
              ),
            ),
          ),
        ),
        _filtresHistorique(),
        Expanded(
          child: lignes.isEmpty
              ? apercuVide(
                  requete.isEmpty ? 'Aucun historique' : 'Aucun résultat',
                )
              : apercuScroll(
                  lignes.map(_carteHistorique).toList(),
                  cle: ValueKey('$requete|$_typeHistorique'),
                ),
        ),
      ],
    );
  }

  /// Carte d'historique compacte, calquee sur la liste des OR :
  /// deux lignes denses plutot que le tableau libelle/valeur.

  Widget _carteHistorique(Map<String, dynamic> item) {
    final vidange = item['_type'] == 'vidange';
    final demande = item['_type'] == 'demande';
    final statut = (item['workflowDORLibelle'] ?? item['status'] ?? '')
        .toString();
    final couleurStatut = apercuCouleurStatut(apercuLibelleStatut(statut));
    final couleurType = vidange ? kApViolet : (demande ? kApCyan : kApBleu);
    final icone = vidange
        ? LucideIcons.droplet
        : (demande ? LucideIcons.clipboardList : LucideIcons.wrench);

    final natures = <String>[];
    if (item['naturesAnomalies'] is List) {
      for (final n in item['naturesAnomalies']) {
        final lib = n is Map
            ? (n['libelle'] ?? n['nom'] ?? n['natureAnomalie'])?.toString()
            : n?.toString();
        if (lib != null && lib.trim().isNotEmpty && !natures.contains(lib)) {
          natures.add(lib.trim());
        }
      }
    }
    final nature = (item['natureAnomalieLibelle'] ?? '').toString().trim();
    if (natures.isEmpty && nature.isNotEmpty) natures.add(nature);

    final libelleType = vidange
        ? (item['typeVidangeLibelle'] ?? '').toString().trim()
        : (item['typeInterventionLibelle'] ??
                  item['typeDemandeORLibelle'] ??
                  '')
              .toString()
              .trim();
    final lieu = (item['lieuReparation'] ?? '').toString().trim();
    final chauffeur =
        (item['chauffeurNomComplet'] ??
                item['chauffeur'] ??
                item['chauffeurNom'] ??
                item['demandeurNomComplet'] ??
                '')
            .toString()
            .trim();
    final km = apercuKm(item['kilometrage']) ?? '—';

    final pastilles = <Widget>[
      if (natures.isNotEmpty)
        _badge(natures.first, LucideIcons.alertTriangle, kApRouge),
      if (natures.length > 1)
        _badge('+${natures.length - 1}', LucideIcons.plus, kApBleu),
      if (libelleType.isNotEmpty) _badge(libelleType, icone, couleurType),
      if (lieu.isNotEmpty) _badge(lieu, LucideIcons.truck, kApAmbre),
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.95)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1F3A5F).withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Get.to(
            () => vidange
                ? VidangeApercuPage(vidange: item)
                : (demande
                      ? DemandeOrApercuPage(demande: item)
                      : OrApercuPage(ordre: item)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icone, size: 13, color: couleurType),
                    const SizedBox(width: 6),
                    Text(
                      _numeroHistorique(item),
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      apercuDate(_dateHistorique(item)) ?? '—',
                      style: GoogleFonts.poppins(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                    const Spacer(),
                    if (statut.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2.5,
                        ),
                        decoration: BoxDecoration(
                          color: couleurStatut.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          apercuLibelleStatut(statut),
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: couleurStatut,
                          ),
                        ),
                      ),
                    const SizedBox(width: 6),
                    const Icon(
                      LucideIcons.chevronRight,
                      size: 15,
                      color: Color(0xFF94A3B8),
                    ),
                  ],
                ),
                if (pastilles.isNotEmpty) ...[
                  const SizedBox(height: 7),
                  Wrap(spacing: 5, runSpacing: 4, children: pastilles),
                ],
                const SizedBox(height: 7),
                Row(
                  children: [
                    const Icon(
                      LucideIcons.gauge,
                      size: 12,
                      color: Color(0xFF94A3B8),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      km,
                      style: GoogleFonts.poppins(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                    if (chauffeur.isNotEmpty) ...[
                      const SizedBox(width: 10),
                      const Icon(
                        LucideIcons.user,
                        size: 12,
                        color: Color(0xFF94A3B8),
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          chauffeur,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 10.5,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Deux filtres de type : OR et Vidanges, plus un retour a tout.

  Widget _filtresHistorique() {
    int compte(String type) =>
        _historique.where((e) => e['_type'] == type).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: SizedBox(
        height: 28,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            FiltrePastille(
              label: 'Tous (${_historique.length})',
              couleur: const Color(0xFF1F3A5F),
              actif: _typeHistorique == null,
              onTap: () => setState(() => _typeHistorique = null),
            ),
            const SizedBox(width: 6),
            FiltrePastille(
              label: 'OR (${compte('or')})',
              icone: LucideIcons.wrench,
              couleur: kApBleu,
              actif: _typeHistorique == 'or',
              onTap: () => setState(() => _typeHistorique = 'or'),
            ),
            const SizedBox(width: 6),
            FiltrePastille(
              label: 'Vidanges (${compte('vidange')})',
              icone: LucideIcons.droplet,
              couleur: kApViolet,
              actif: _typeHistorique == 'vidange',
              onTap: () => setState(() => _typeHistorique = 'vidange'),
            ),
            const SizedBox(width: 6),
            FiltrePastille(
              label: 'Demandes (${compte('demande')})',
              icone: LucideIcons.clipboardList,
              couleur: kApCyan,
              actif: _typeHistorique == 'demande',
              onTap: () => setState(() => _typeHistorique = 'demande'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(String texte, IconData icone, Color couleur) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: couleur.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 10, color: couleur),
          const SizedBox(width: 3),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 150),
            child: Text(
              texte,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: couleur,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
