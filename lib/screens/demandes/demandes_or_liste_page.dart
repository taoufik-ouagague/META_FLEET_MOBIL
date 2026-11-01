import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../widgets/couleur_ligne.dart';
import '../../widgets/filtre_pastille.dart';

import '../../controllers/demande_or_controller.dart';
import '../../widgets/apercu_kit.dart';
import 'demande_or_apercu_page.dart';

/// Liste des demandes d'ordre de réparation, avec recherche et accès à l'aperçu.
class DemandesOrListePage extends StatefulWidget {
  const DemandesOrListePage({super.key});

  @override
  State<DemandesOrListePage> createState() => _DemandesOrListePageState();
}

class _DemandesOrListePageState extends State<DemandesOrListePage> {
  final _controller = Get.find<DemandeOrController>();
  final _recherche = TextEditingController();
  final _defilement = ScrollController();

  String _requete = '';
  String? _nature;
  String? _statut;
  String? _chauffeur;

  @override
  void initState() {
    super.initState();
    // Les donnees sont deja en memoire : on se contente d'un rafraichissement
    // silencieux en arriere-plan, la liste s'affiche immediatement.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _controller.fetchDemandes(showLoading: false),
    );

    // Pagination : la page suivante part avant d'arriver tout en bas.
    _defilement.addListener(() {
      if (_defilement.position.pixels >=
          _defilement.position.maxScrollExtent - 400) {
        _controller.chargerPageSuivante();
      }
    });
  }

  @override
  void dispose() {
    _recherche.dispose();
    _defilement.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Meme calage que les autres onglets : l'en-tete META FLEET flotte
      // au-dessus, -55 supprime le vide qui restait sous le logo.
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + kToolbarHeight - 55,
      ),
      child: RefreshIndicator(
        displacement: 24,
        onRefresh: () => _controller.fetchDemandes(showLoading: false),
        color: const Color(0xFF1F3A5F),
        child: Obx(() {
          final liste = _controller.filtrees(
            _requete,
            nature: _nature,
            statut: _statut,
            chauffeur: _chauffeur,
          );
          final erreur = _controller.errorMessage.value;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 8),
                child: _titre(),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
                child: _champRecherche(liste.length),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
                child: Row(
                  spacing: 6,
                  children: [
                    ?_selecteur(
                      label: 'Nature d\'anomalie',
                      icone: LucideIcons.alertTriangle,
                      couleur: kApRouge,
                      valeur: _nature,
                      comptes: _controller.comptes(_controller.naturesDe),
                      onChange: (v) => setState(() => _nature = v),
                    ),
                    ?_selecteur(
                      label: 'Statut',
                      icone: LucideIcons.activity,
                      couleur: kApVert,
                      valeur: _statut,
                      comptes: _controller.comptes(
                        (d) => [_controller.statutDe(d)],
                      ),
                      onChange: (v) => setState(() => _statut = v),
                    ),
                    ?_selecteur(
                      label: 'Chauffeur',
                      icone: LucideIcons.user,
                      couleur: kApBleu,
                      valeur: _chauffeur,
                      comptes: _controller.comptes(
                        (d) => [_controller.chauffeurDe(d)],
                      ),
                      onChange: (v) => setState(() => _chauffeur = v),
                    ),
                  ],
                ),
              ),
              if (_controller.isLoading.value && _controller.demandes.isEmpty)
                const Expanded(
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else if (erreur.isNotEmpty && _controller.demandes.isEmpty)
                Expanded(child: _messageErreur(erreur))
              else if (liste.isEmpty)
                Expanded(child: apercuVide('Aucune demande'))
              else
                Expanded(
                  child: ListView.separated(
                    controller: _defilement,
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 110),
                    itemCount: liste.length + 1,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      if (index == liste.length) return _pied();
                      return _carte(liste[index]);
                    },
                  ),
                ),
            ],
          );
        }),
      ),
    );
  }

  /// 2401 -> « 2 401 », meme presentation que la liste des OR.
  String _formatNombre(int valeur) {
    final texte = valeur.toString();
    final tampon = StringBuffer();
    for (var i = 0; i < texte.length; i++) {
      if (i > 0 && (texte.length - i) % 3 == 0) tampon.write('\u202F');
      tampon.write(texte[i]);
    }

    return tampon.toString();
  }

  /// Pied de liste : avancement du chargement des pages suivantes.
  Widget _pied() {
    return Obx(() {
      if (!_controller.aPlusDePages) return const SizedBox(height: 4);

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 1.8),
              ),
              const SizedBox(width: 9),
              Text(
                'Chargement… ${_formatNombre(_controller.demandes.length)} / ${_formatNombre(_controller.totalElements.value)}',
                style: GoogleFonts.poppins(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _titre() {
    final chargees = _controller.demandes.length;
    final total = _controller.totalElements.value > 0
        ? _controller.totalElements.value
        : chargees;
    final filtre =
        _requete.isNotEmpty ||
        _nature != null ||
        _statut != null ||
        _chauffeur != null;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Demandes d\'OR',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Demandes d\'ordre de réparation du parc',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 11.5,
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: filtre
              ? () => setState(() {
                  _requete = '';
                  _recherche.clear();
                  _nature = null;
                  _statut = null;
                  _chauffeur = null;
                })
              : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: kApBleu.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: kApBleu.withValues(alpha: 0.15)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (filtre) ...[
                  const Icon(LucideIcons.x, size: 11, color: kApBleu),
                  const SizedBox(width: 4),
                ],
                Text(
                  '${_formatNombre(total)} éléments',
                  style: GoogleFonts.poppins(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: kApBleu,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Pastille deroulante : valeurs distinctes + nombre de demandes.
  Widget? _selecteur({
    required String label,
    required IconData icone,
    required Color couleur,
    required String? valeur,
    required Map<String, int> comptes,
    required void Function(String?) onChange,
  }) {
    if (comptes.isEmpty) return null;

    final triees = comptes.keys.toList()..sort();
    final actif = valeur != null;

    return PopupMenuButton<String>(
      tooltip: label,
      position: PopupMenuPosition.under,
      color: Colors.white,
      elevation: 10,
      shadowColor: const Color(0xFF1F3A5F).withValues(alpha: 0.22),
      surfaceTintColor: Colors.transparent,
      constraints: const BoxConstraints(minWidth: 220, maxHeight: 360),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: const Color(0xFF1F3A5F).withValues(alpha: 0.07),
        ),
      ),
      onSelected: (v) => onChange(v.isEmpty ? null : v),
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          value: '',
          height: 42,
          child: _ligneMenu(
            'Toutes',
            _controller.demandes.length,
            valeur == null,
            couleur,
          ),
        ),
        ...triees.map(
          (v) => PopupMenuItem<String>(
            value: v,
            height: 42,
            child: _ligneMenu(v, comptes[v] ?? 0, valeur == v, couleur),
          ),
        ),
      ],
      child: FiltrePastille(
        label: valeur ?? label,
        couleur: couleur,
        actif: actif,
        icone: icone,
        deroulante: true,
      ),
    );
  }

  Widget _ligneMenu(
    String libelle,
    int compte,
    bool selectionnee,
    Color couleur,
  ) {
    return Row(
      children: [
        Expanded(
          child: Text(
            libelle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 12.5,
              fontWeight: selectionnee ? FontWeight.w700 : FontWeight.w500,
              color: selectionnee ? couleur : const Color(0xFF0F172A),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: couleur.withValues(alpha: selectionnee ? 0.18 : 0.08),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            '$compte',
            style: GoogleFonts.poppins(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: couleur,
            ),
          ),
        ),
      ],
    );
  }

  Widget _messageErreur(String erreur) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              LucideIcons.alertTriangle,
              size: 32,
              color: Color(0xFFDC2626),
            ),
            const SizedBox(height: 10),
            Text(
              erreur,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 12.5,
                color: const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.tonalIcon(
              onPressed: () => _controller.fetchDemandes(),
              icon: const Icon(LucideIcons.refreshCw, size: 15),
              label: Text(
                'Réessayer',
                style: GoogleFonts.poppins(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _champRecherche(int resultats) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.95),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1F3A5F).withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: TextField(
            controller: _recherche,
            onChanged: (v) => setState(() => _requete = v),
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: const Color(0xFF0F172A),
            ),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Filtrer par immatriculation ou n° demande…',
              hintStyle: GoogleFonts.poppins(
                fontSize: 13,
                color: const Color(0xFF94A3B8),
              ),
              // La boite du prefixe fait 48 dp par defaut : l'icone s'y centre et
              // laisse un vide avant le texte. On porte les marges sur l'icone.
              prefixIcon: const Padding(
                padding: EdgeInsets.only(left: 14, right: 8),
                child: Icon(
                  LucideIcons.search,
                  size: 18,
                  color: Color(0xFF94A3B8),
                ),
              ),
              prefixIconConstraints: const BoxConstraints(
                minWidth: 0,
                minHeight: 32,
              ),
              suffixIcon: _requete.isEmpty
                  ? null
                  : Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: Text(
                        '$resultats',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ),
              suffixIconConstraints: const BoxConstraints(
                minWidth: 32,
                minHeight: 32,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 13),
            ),
          ),
        ),
      ),
    );
  }

  Widget _carte(Map<String, dynamic> d) {
    final vehicule = [
      (d['vehiculeMarqueLibelle'] ?? '').toString().trim(),
      (d['vehiculeModeleLibelle'] ?? '').toString().trim(),
    ].where((e) => e.isNotEmpty && e != 'null').join(' ');

    final statut = (d['workflowDORLibelle'] ?? d['status'] ?? '').toString();
    final couleurStatut = apercuCouleurStatut(apercuLibelleStatut(statut));

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1F3A5F).withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: avecBandeLigne(
          couleurLigneDemande(d),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => Get.to(() => DemandeOrApercuPage(demande: d)),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: decorationLigne(
                    couleurLigneDemande(d),
                    rayon: 16,
                    ombre: false,
                    degrade: true,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  LucideIcons.truck,
                                  size: 11,
                                  color: Colors.white70,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  (d['vehiculeImmatriculation'] ?? '—')
                                      .toString(),
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.9,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          // Expanded + alignement a gauche : avec un Flexible, la
                          // place non utilisee par une pastille courte restait
                          // vide et le chevron n'arrivait pas au bord.
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: statut.isEmpty
                                  ? const SizedBox.shrink()
                                  : Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: couleurStatut.withValues(
                                          alpha: 0.12,
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        apercuLibelleStatut(statut),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.poppins(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: couleurStatut,
                                        ),
                                      ),
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
                      const SizedBox(height: 7),
                      Text(
                        [
                          vehicule,
                          (d['numeroDemande'] ?? '').toString(),
                        ].where((e) => e.isNotEmpty).join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 7),
                      Wrap(
                        spacing: 5,
                        runSpacing: 4,
                        children: [
                          ?_pastille(
                            LucideIcons.calendar,
                            apercuDate(d['dateDemande']),
                            kApViolet,
                          ),
                          ?_pastille(
                            LucideIcons.user,
                            d['demandeurNomComplet'],
                            kApVert,
                          ),
                          ?_pastille(
                            LucideIcons.gauge,
                            apercuKm(d['kilometrage']),
                            kApBleu,
                          ),
                          ?_pastille(
                            LucideIcons.flame,
                            d['prioriteLibelle'],
                            kApAmbre,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget? _pastille(IconData icone, dynamic valeur, Color couleur) {
    final texte = valeur?.toString().trim() ?? '';
    if (texte.isEmpty || texte == 'null') return null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: couleur.withValues(alpha: 0.20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 11, color: couleur),
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 190),
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
