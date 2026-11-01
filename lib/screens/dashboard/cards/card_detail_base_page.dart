import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../widgets/ambient_background.dart';

class _StickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;

  _StickyHeaderDelegate({required this.child, required this.height});

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    // Fond transparent : le degrade ambiant de la page passe derriere la barre
    // de recherche. Un flou leger prend le relais quand la liste defile dessous.
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: overlapsContent ? 14 : 0,
          sigmaY: overlapsContent ? 14 : 0,
        ),
        child: Container(
          height: height,
          color: Colors.transparent,
          padding: const EdgeInsets.only(top: 4, bottom: 4),
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: child,
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_StickyHeaderDelegate oldDelegate) {
    return child != oldDelegate.child || height != oldDelegate.height;
  }
}

/// Filtre affiche en pastille cliquable sous le titre. `predicat` a null
/// signifie « tout », ce qui sert de filtre par defaut.
class CardFiltre {
  final String label;
  final Color couleur;
  final bool Function(Map item)? predicat;

  const CardFiltre({required this.label, required this.couleur, this.predicat});
}

/// Selecteur deroulant construit a partir des elements eux-memes : chaque
/// element expose ses valeurs (natures d'anomalies, services...), la page
/// propose la liste distincte et filtre dessus.
class CardSelecteur {
  final String label;
  final IconData icone;
  final Color couleur;
  final List<String> Function(Map item) valeurs;

  const CardSelecteur({
    required this.label,
    required this.icone,
    required this.couleur,
    required this.valeurs,
  });

  /// Selecteur « Nature d'anomalie », commun aux demandes d'OR et aux ordres :
  /// les deux DTO exposent la meme liste d'objets.
  factory CardSelecteur.naturesAnomalies() => CardSelecteur(
    label: 'Nature d\'anomalie',
    icone: LucideIcons.alertTriangle,
    couleur: const Color(0xFFDC2626),
    valeurs: (item) {
      final brut = item['naturesAnomalies'] ?? item['anomalies'];
      if (brut is! List) return const <String>[];

      return brut
          .map((e) {
            final libelle = e is Map
                ? (e['libelle'] ??
                      e['nom'] ??
                      e['natureAnomalieLibelle'] ??
                      e['naturesAnomaliesPrcLibelle'])
                : e;
            return libelle?.toString().trim() ?? '';
          })
          .where((e) => e.isNotEmpty && e != 'null')
          .toList();
    },
  );

  /// Selecteur « Type de document » : visite technique, assurance, vignette...
  factory CardSelecteur.typeDocument() => CardSelecteur(
    label: 'Type de document',
    icone: LucideIcons.fileText,
    couleur: const Color(0xFF2563EB),
    valeurs: (item) {
      final libelle = (item['document'] ?? item['typeDocLibelle'] ?? '')
          .toString()
          .trim();
      return libelle.isEmpty || libelle == 'null'
          ? const <String>[]
          : [libelle];
    },
  );
}

class CardDetailBasePage extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final List<dynamic> items;
  final Future<void> Function() onRefresh;
  final Widget Function(dynamic item)? customItemBuilder;
  final List<Widget>? headerPills;
  final List<CardFiltre>? filtres;
  final CardSelecteur? selecteur;

  /// Ouverture de la fiche correspondante au clic sur une ligne.
  final void Function(Map<String, dynamic> item)? onItemTap;

  const CardDetailBasePage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.items,
    required this.onRefresh,
    this.customItemBuilder,
    this.onItemTap,
    this.headerPills,
    this.filtres,
    this.selecteur,
  });

  @override
  State<CardDetailBasePage> createState() => _CardDetailBasePageState();
}

class _CardDetailBasePageState extends State<CardDetailBasePage> {
  /// Deux lignes de pastilles au plus : au-dela, la carte s'allonge trop.
  /// Le reste est dans la fiche, que la ligne ouvre au clic.
  static const _maxPastilles = 6;

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _searchQuery = '';

  /// Index du filtre actif ; par defaut celui qui ne filtre rien.
  int _filtreActif = -1;

  /// Valeur choisie dans le selecteur, null = toutes.
  String? _valeurSelecteur;

  @override
  void initState() {
    super.initState();
    final filtres = widget.filtres;
    if (filtres != null) {
      final tout = filtres.indexWhere((f) => f.predicat == null);
      _filtreActif = tout >= 0 ? tout : -1;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  List<dynamic> _filterItems() {
    var items = widget.items;

    final filtres = widget.filtres;
    if (filtres != null && _filtreActif >= 0 && _filtreActif < filtres.length) {
      final predicat = filtres[_filtreActif].predicat;
      if (predicat != null) {
        items = items.where((it) => it is Map && predicat(it)).toList();
      }
    }

    final selecteur = widget.selecteur;
    final valeur = _valeurSelecteur;
    if (selecteur != null && valeur != null) {
      items = items
          .where((it) => it is Map && selecteur.valeurs(it).contains(valeur))
          .toList();
    }

    if (_searchQuery.trim().isEmpty) return items;
    final q = _searchQuery.trim().toLowerCase();
    return items.where((it) {
      if (it is! Map) return it.toString().toLowerCase().contains(q);
      // Recherche sur la seule immatriculation, comme demande : les autres
      // champs (numeros, articles) ne sont pas pris en compte.
      final immat =
          (it['immatriculation'] ??
                  it['vehiculeImmatriculation'] ??
                  it['immat'] ??
                  it['numImmatriculation'] ??
                  '')
              .toString()
              .toLowerCase();

      return immat.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filterItems();
    final topPadding = MediaQuery.of(context).padding.top + kToolbarHeight;

    return Scaffold(
      extendBodyBehindAppBar: true,
      // Meme fond que la liste des vehicules : le degrade ambiant transparait
      // sous les cartes en verre, au lieu du gris plat.
      backgroundColor: Colors.transparent,
      appBar: _buildAppBar(context),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const AmbientBackground(),
          Padding(
            padding: EdgeInsets.only(top: topPadding + 6),
            child: RefreshIndicator(
              displacement: 24,
              onRefresh: widget.onRefresh,
              color: widget.accentColor,
              child: CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // ── 1. Sous-titre et Badges d'en-tête (dans sa place normale) ──
                  SliverPadding(
                    // Un peu d'air entre l'en-tete degrade et les filtres.
                    padding: const EdgeInsets.fromLTRB(18, 10, 18, 6),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Sous-titre facultatif : les pages qui exposent des
                          // filtres s'en passent, les pastilles suffisent.
                          if (widget.subtitle.isNotEmpty)
                            Text(
                              widget.subtitle,
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          if (widget.filtres != null &&
                              widget.filtres!.isNotEmpty) ...[
                            if (widget.subtitle.isNotEmpty)
                              const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                for (var i = 0; i < widget.filtres!.length; i++)
                                  _pastilleFiltre(i, widget.filtres![i]),
                                ?_selecteurAnomalies(),
                              ],
                            ),
                          ] else if (widget.headerPills != null &&
                              widget.headerPills!.isNotEmpty) ...[
                            if (widget.subtitle.isNotEmpty)
                              const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                ...widget.headerPills!,
                                ?_selecteurAnomalies(),
                              ],
                            ),
                          ] else if (widget.selecteur != null) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [?_selecteurAnomalies()],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // ── 2. Barre de recherche Collante (Sticky Header façon hr-perfect) ──
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _StickyHeaderDelegate(
                      // 56 rognait le champ : 48 de hauteur utile + 8 de marges.
                      height: 64,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        child: _buildSearchBar(filtered.length),
                      ),
                    ),
                  ),

                  // ── 3. Liste des éléments ou État vide ──
                  if (filtered.isEmpty)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(18, 20, 18, 40),
                      sliver: SliverToBoxAdapter(child: _buildEmptyState()),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(18, 10, 18, 40),
                      sliver: SliverList.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final element = filtered[index];
                          final carte = widget.customItemBuilder != null
                              ? widget.customItemBuilder!(element)
                              : _buildDefaultItemCard(element);
                          if (widget.onItemTap == null || element is! Map) {
                            return carte;
                          }

                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () => widget.onItemTap!(
                                Map<String, dynamic>.from(element),
                              ),
                              child: carte,
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── AppBar avec style dégradé et bouton retour ──
  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.16),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.35),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1F3A5F).withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const Icon(
            LucideIcons.arrowLeft,
            size: 18,
            color: Colors.white,
          ),
        ),
        onPressed: () => Get.back(),
      ),
      systemOverlayStyle: SystemUiOverlayStyle.light,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1F3A5F), Color(0xFF2563EB)],
          ),
        ),
      ),
      title: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
            ),
            child: Icon(widget.icon, color: Colors.white, size: 17),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Liste deroulante des valeurs portees par les elements (natures
  /// d'anomalies...). Rendue en pastille, comme les filtres.
  Widget? _selecteurAnomalies() {
    final selecteur = widget.selecteur;
    if (selecteur == null) return null;

    // Nombre d'elements par valeur : un element portant plusieurs natures
    // compte dans chacune d'elles.
    final comptes = <String, int>{};
    for (final it in widget.items) {
      if (it is! Map) continue;
      for (final v in selecteur.valeurs(it).toSet()) {
        comptes[v] = (comptes[v] ?? 0) + 1;
      }
    }
    if (comptes.isEmpty) return null;

    final triees = comptes.keys.toList()..sort();
    final actif = _valeurSelecteur != null;

    return PopupMenuButton<String>(
      tooltip: selecteur.label,
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
      onSelected: (v) =>
          setState(() => _valeurSelecteur = v.isEmpty ? null : v),
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          value: '',
          height: 42,
          child: _ligneSelecteur(
            'Toutes',
            widget.items.length,
            selectionnee: _valeurSelecteur == null,
            couleur: const Color(0xFF64748B),
          ),
        ),
        ...triees.map(
          (v) => PopupMenuItem<String>(
            value: v,
            height: 42,
            child: _ligneSelecteur(
              v,
              comptes[v] ?? 0,
              selectionnee: _valeurSelecteur == v,
              couleur: selecteur.couleur,
            ),
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: actif
              ? selecteur.couleur
              : selecteur.couleur.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: selecteur.couleur.withValues(alpha: actif ? 1 : 0.35),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selecteur.icone,
              size: 12,
              color: actif ? Colors.white : selecteur.couleur,
            ),
            const SizedBox(width: 5),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 170),
              child: Text(
                _valeurSelecteur ?? selecteur.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: actif ? Colors.white : selecteur.couleur,
                ),
              ),
            ),
            const SizedBox(width: 3),
            Icon(
              LucideIcons.chevronDown,
              size: 12,
              color: actif ? Colors.white : selecteur.couleur,
            ),
          ],
        ),
      ),
    );
  }

  /// Ligne du menu : libelle a gauche, nombre d'elements a droite.
  Widget _ligneSelecteur(
    String libelle,
    int compte, {
    required bool selectionnee,
    required Color couleur,
  }) {
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

  /// Pastille de filtre : pleine quand elle est active.
  Widget _pastilleFiltre(int index, CardFiltre filtre) {
    final actif = _filtreActif == index;

    return GestureDetector(
      onTap: () => setState(() => _filtreActif = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: actif
              ? filtre.couleur
              : filtre.couleur.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: filtre.couleur.withValues(alpha: actif ? 1 : 0.35),
          ),
        ),
        child: Text(
          filtre.label,
          style: GoogleFonts.poppins(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: actif ? Colors.white : filtre.couleur,
          ),
        ),
      ),
    );
  }

  // ── Barre de recherche ──
  Widget _buildSearchBar(int resultCount) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1F3A5F).withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: Colors.white.withValues(alpha: 0.85),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.92),
                width: 1.4,
              ),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v),
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: const Color(0xFF0F172A),
              ),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Filtrer par immatriculation…',
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
                suffixIcon: _searchQuery.isEmpty
                    ? null
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$resultCount',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(LucideIcons.x, size: 16),
                            color: const Color(0xFF94A3B8),
                            // Sans ces contraintes, le bouton impose 48 px de
                            // haut et le champ se fait rogner par le bandeau.
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          ),
                          const SizedBox(width: 6),
                        ],
                      ),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 0,
                  minHeight: 32,
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
      ),
    );
  }

  // ── Carte par defaut, calquee sur la liste des vehicules ──
  Widget _buildDefaultItemCard(dynamic item) {
    if (item is! Map) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(item.toString()),
      );
    }

    final immat =
        (item['immatriculation'] ??
                item['vehiculeImmatriculation'] ??
                item['immat'] ??
                item['numImmatriculation'] ??
                item['numero'] ??
                item['numeroDemande'] ??
                item['numeroOrdreReparation'] ??
                item['code'] ??
                'Véhicule')
            .toString();

    // Marque et modele sont deux champs distincts cote backend : on les affiche
    // ensemble plutot que de n'en garder qu'un.
    final modele = [
      (item['marque'] ?? item['vehiculeMarqueLibelle'] ?? '').toString().trim(),
      (item['modele'] ??
              item['vehiculeModeleLibelle'] ??
              item['libelle'] ??
              item['typeVidangeLibelle'] ??
              item['typeDocLibelle'] ??
              item['designation'] ??
              '')
          .toString()
          .trim(),
    ].where((e) => e.isNotEmpty && e != 'null').join(' ');

    // Deuxieme ligne : le document pour les cartes documents, sinon l'article
    // ou le numero du bon pour les cartes achat / OR.
    final document =
        (item['document'] ??
                item['typeDocLibelle'] ??
                item['designationProduit'] ??
                item['produitLibelle'] ??
                item['description'] ??
                '')
            .toString()
            .trim();
    final numeroDocument =
        (item['numeroDocument'] ??
                item['numeroDemandeAchat'] ??
                item['numeroBonApprovisionnement'] ??
                item['vidangeNumero'] ??
                item['numeroDemande'] ??
                item['numeroOrdreReparation'] ??
                '')
            .toString()
            .trim();
    final ligneDocument = [
      document,
      numeroDocument,
    ].where((e) => e.isNotEmpty && e != 'null').join(' - ');

    // Valeurs affichees en pastilles, uniquement celles que l'element porte.
    final details = <(IconData, String, Color)>[
      ?_detail(
        LucideIcons.wrench,
        item['numeroOrdreReparation'] ??
            item['ordreReparationNumero'] ??
            item['numeroOr'],
        const Color(0xFF7C3AED),
      ),
      ?_detail(
        LucideIcons.clipboardList,
        item['demandeORNumero'] ?? item['numeroDemandeStock'],
        const Color(0xFF2563EB),
      ),
      ?_detail(
        LucideIcons.user,
        item['demandeur'] ??
            item['demandeurNomComplet'] ??
            item['agentSaisieNomComplet'],
        const Color(0xFF059669),
      ),
      ?_detail(
        LucideIcons.alertTriangle,
        _liste(item['naturesAnomalies'] ?? item['anomalies']),
        const Color(0xFFDC2626),
      ),
      ?_detail(
        LucideIcons.fileText,
        item['descriptionProbleme'] ?? item['descriptionDiagnostic'],
        const Color(0xFF64748B),
      ),
      ?_detail(
        LucideIcons.tag,
        item['typeDemandeORLibelle'],
        const Color(0xFF0891B2),
      ),
      ?_detail(
        LucideIcons.flame,
        item['prioriteLibelle'],
        const Color(0xFFD97706),
      ),
      ?_detail(
        LucideIcons.wrench,
        item['servicesPrcLibelle'],
        const Color(0xFF7C3AED),
      ),
      ?_detail(
        LucideIcons.mapPin,
        item['localisationVehicule'],
        const Color(0xFFD97706),
      ),
      ?_detail(
        LucideIcons.gauge,
        item['kilometrage'],
        const Color(0xFF2563EB),
        suffixe: ' km',
      ),
      ?_detail(
        LucideIcons.activity,
        item['workflowDORLibelle'] ?? item['status'],
        const Color(0xFF059669),
      ),
      ?_detail(
        LucideIcons.briefcase,
        item['prestataireLibelle'] ?? item['fournisseurLibelle'],
        const Color(0xFFD97706),
      ),
      ?_detail(
        LucideIcons.calendar,
        _dateCourte(
          item['dateDemande'] ??
              item['dateOrdreReparation'] ??
              item['dateDemandeAchat'],
        ),
        const Color(0xFF7C3AED),
      ),
      ?_detail(
        LucideIcons.package,
        item['nbArticles'],
        const Color(0xFF2563EB),
        prefixe: 'Articles ',
      ),
      ?_detail(
        LucideIcons.fileWarning,
        item['nbArticlesSansBc'],
        const Color(0xFFDC2626),
        prefixe: 'Sans B.C ',
      ),
      ?_detail(
        LucideIcons.boxes,
        item['qte'],
        const Color(0xFF2563EB),
        prefixe: 'Qté ',
      ),
      ?_detail(
        LucideIcons.wallet,
        item['montantTtc'] ?? item['totalTtc'],
        const Color(0xFF059669),
        suffixe: ' MAD',
      ),
      ?_detail(
        LucideIcons.gauge,
        item['kmActuel'],
        const Color(0xFF2563EB),
        prefixe: 'Actuel ',
        suffixe: ' km',
      ),
      ?_detail(
        LucideIcons.droplet,
        item['kilometrageVidange'] ?? item['kmVidange'],
        const Color(0xFF0891B2),
        prefixe: 'Vidange ',
        suffixe: ' km',
      ),
      ?_detail(
        LucideIcons.repeat,
        item['cycleVidange'],
        const Color(0xFF64748B),
        prefixe: 'Cycle ',
        suffixe: ' km',
      ),
      ?_detail(
        LucideIcons.flag,
        item['prochainKmVidange'],
        const Color(0xFF059669),
        prefixe: 'Prochaine ',
        suffixe: ' km',
      ),
      ?_detail(
        LucideIcons.calendarCheck,
        _dateCourte(item['dateVidange'] ?? item['dateRealisation']),
        const Color(0xFF7C3AED),
      ),
      ?_detail(
        LucideIcons.userCheck,
        item['chauffeurNom'] ?? item['chaffeurNomComplet'] ?? item['chauffeur'],
        const Color(0xFF64748B),
      ),
      ?_detail(
        LucideIcons.mapPin,
        item['agenceLibelle'] ?? item['nomAgence'],
        const Color(0xFFD97706),
      ),
    ];

    // Numeros portes par l'en-tete : document (DA, vidange, doc administratif)
    // puis ordre de reparation, avant la plaque.
    final numeroOr =
        (item['numeroOrdreReparation'] ??
                item['ordreReparationNumero'] ??
                item['numeroOr'] ??
                '')
            .toString()
            .trim();

    // L'en-tete affiche deja l'immatriculation et le numero de document :
    // les repeter en pastille allongeait la carte pour rien.
    final dejaVu = {
      immat.toLowerCase(),
      numeroOr.toLowerCase(),
      modele.toLowerCase(),
      ...ligneDocument.toLowerCase().split(' - '),
    }..removeWhere((e) => e.isEmpty);
    details.removeWhere((d) => dejaVu.contains(d.$2.toLowerCase().trim()));

    String statusText = '';
    Color statusBg = const Color(0xFFF1F5F9);
    Color statusFg = const Color(0xFF64748B);

    final kmVidange = item['kilometrageVidange'];
    final kmActuel = item['kmActuel'];

    // Erreur de kilometrage : la derniere vidange est enregistree au-dessus du
    // compteur. Le meme DTO sert aux alertes, d'ou le test sur les deux valeurs.
    if (kmVidange is num && kmActuel is num && kmVidange > kmActuel) {
      statusText = 'Écart de ${_nombre(kmVidange - kmActuel)} km';
      statusBg = const Color(0xFFEF4444).withValues(alpha: 0.12);
      statusFg = const Color(0xFFDC2626);
    } else if (item['act'] is num) {
      final act = item['act'] as num;
      if (act <= 0) {
        statusText = 'Dépassé de ${_nombre(-act)} km';
        statusBg = const Color(0xFFEF4444).withValues(alpha: 0.12);
        statusFg = const Color(0xFFDC2626);
      } else if (act <= 500) {
        statusText = 'Dans ${_nombre(act)} km (Imminent)';
        statusBg = const Color(0xFFF59E0B).withValues(alpha: 0.12);
        statusFg = const Color(0xFFD97706);
      } else {
        statusText = 'Dans ${_nombre(act)} km';
        statusBg = const Color(0xFF2563EB).withValues(alpha: 0.10);
        statusFg = const Color(0xFF2563EB);
      }
    } else if (item['joursExpire'] is num) {
      final jours = (item['joursExpire'] as num).toInt();
      statusText = jours == 1
          ? 'Expire depuis 1 jour'
          : 'Expire depuis $jours jours';
      statusBg = const Color(0xFFEF4444).withValues(alpha: 0.12);
      statusFg = const Color(0xFFDC2626);
    } else if (item['joursRestants'] is num) {
      final jours = (item['joursRestants'] as num).toInt();
      statusText = jours <= 0
          ? 'Expire aujourd\'hui'
          : (jours == 1 ? 'Dans 1 jour' : 'Dans $jours jours');
      statusBg = const Color(0xFFF59E0B).withValues(alpha: 0.12);
      statusFg = const Color(0xFFD97706);
    } else if (item['dateExpiration'] != null) {
      statusText = 'Expire le : ${_dateCourte(item['dateExpiration'])}';
      statusBg = const Color(0xFFEF4444).withValues(alpha: 0.12);
      statusFg = const Color(0xFFDC2626);
    } else if (item['datePrevue'] != null) {
      statusText = 'Prévu le : ${_dateCourte(item['datePrevue'])}';
      statusBg = const Color(0xFF7C3AED).withValues(alpha: 0.12);
      statusFg = const Color(0xFF7C3AED);
    } else if (item['statut'] != null) {
      statusText = item['statut'].toString();
      statusBg = const Color(0xFF10B981).withValues(alpha: 0.12);
      statusFg = const Color(0xFF059669);
    }

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
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            // Meme gabarit que la liste des vehicules : compact, verre clair,
            // plaque noire puis pastilles de valeurs.
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.85),
                  Colors.white.withValues(alpha: 0.55),
                ],
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.92),
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Numeros, plaque et vehicule sur une ligne ; le Wrap les
                // renvoie a la ligne suivante plutot que de deborder quand un
                // libelle est long.
                Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 5,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (ligneDocument.isNotEmpty)
                            _pastille(
                              LucideIcons.fileText,
                              ligneDocument,
                              const Color(0xFF2563EB),
                              largeurMax: 120,
                            ),
                          if (numeroOr.isNotEmpty)
                            _pastille(
                              LucideIcons.wrench,
                              numeroOr,
                              const Color(0xFF7C3AED),
                              largeurMax: 100,
                            ),
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
                                Icon(
                                  widget.icon,
                                  size: 11,
                                  color: Colors.white70,
                                ),
                                const SizedBox(width: 5),
                                ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 120,
                                  ),
                                  child: Text(
                                    immat,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.9,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Marque et modele a la suite de la plaque ; « — »
                          // quand le vehicule n'en porte pas.
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 160),
                            child: Text(
                              modele.ifEmpty('—'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (widget.onItemTap != null) ...[
                      const SizedBox(width: 6),
                      const Icon(
                        LucideIcons.chevronRight,
                        size: 15,
                        color: Color(0xFF94A3B8),
                      ),
                    ],
                  ],
                ),
                if (details.isNotEmpty || statusText.isNotEmpty) ...[
                  const SizedBox(height: 7),
                  Wrap(
                    spacing: 5,
                    runSpacing: 4,
                    children: [
                      // Le statut ouvre la rangee : l'en-tete est pris par les
                      // numeros, la plaque et le vehicule.
                      if (statusText.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: statusBg,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            statusText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: statusFg,
                            ),
                          ),
                        ),
                      for (final d in details.take(_maxPastilles))
                        _pastille(d.$1, d.$2, d.$3),
                      if (details.length > _maxPastilles)
                        _pastille(
                          LucideIcons.plus,
                          '${details.length - _maxPastilles}',
                          const Color(0xFF64748B),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Pastille compacte « icone + valeur », calquee sur la liste des vehicules.
  Widget _pastille(
    IconData icone,
    String texte,
    Color couleur, {
    double largeurMax = 210,
  }) {
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
          // Plafond de largeur : une description de panne ne doit pas pousser
          // la pastille hors de la carte.
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: largeurMax),
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

  /// (icone, texte, couleur) pret a afficher, ou null si la donnee manque.
  (IconData, String, Color)? _detail(
    IconData icone,
    dynamic valeur,
    Color couleur, {
    String prefixe = '',
    String suffixe = '',
  }) {
    if (valeur == null) return null;
    var texte = valeur.toString().trim();
    if (texte.isEmpty || texte == 'null') return null;

    final nombre = num.tryParse(texte);
    if (nombre != null) texte = _nombre(nombre);

    return (icone, '$prefixe$texte$suffixe', couleur);
  }

  /// 310001.0 -> « 310 001 » : des milliers lisibles, sans decimale inutile.
  String _nombre(num valeur) {
    final entier = valeur % 1 == 0;
    final texte = entier
        ? valeur.toInt().abs().toString()
        : valeur.abs().toStringAsFixed(2);
    final partieEntiere = texte.split('.').first;
    final reste = texte.contains('.') ? ',${texte.split('.').last}' : '';

    final tampon = StringBuffer();
    for (var i = 0; i < partieEntiere.length; i++) {
      if (i > 0 && (partieEntiere.length - i) % 3 == 0) tampon.write('\u202F');
      tampon.write(partieEntiere[i]);
    }

    return '${valeur < 0 ? '-' : ''}$tampon$reste';
  }

  /// Liste d'objets du backend -> « Panne moteur, Freinage » ; null si vide.
  String? _liste(dynamic brut) {
    if (brut is! List || brut.isEmpty) return null;

    final libelles = <String>[];
    for (final e in brut) {
      final texte = e is Map
          ? (e['libelle'] ?? e['nom'] ?? e['natureAnomalieLibelle'] ?? '')
                .toString()
          : e.toString();
      final propre = texte.trim();
      if (propre.isNotEmpty && propre != 'null' && !libelles.contains(propre)) {
        libelles.add(propre);
      }
    }

    return libelles.isEmpty ? null : libelles.join(', ');
  }

  /// Dates ISO-8601 ramenees au jour : « 2026-09-29T14:51 » -> « 29/09/2026 ».
  String? _dateCourte(dynamic brut) {
    final texte = brut?.toString() ?? '';
    if (texte.length < 10) return texte.isEmpty ? null : texte;
    final parts = texte.substring(0, 10).split('-');
    if (parts.length != 3) return texte.substring(0, 10);
    return '${parts[2]}/${parts[1]}/${parts[0]}';
  }

  // ── État vide ──
  Widget _buildEmptyState() {
    final isSearching = _searchQuery.isNotEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.90)),
      ),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: isSearching
                  ? const Color(0xFF94A3B8).withValues(alpha: 0.12)
                  : const Color(0xFF10B981).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isSearching ? LucideIcons.searchX : LucideIcons.checkCircle2,
              size: 30,
              color: isSearching
                  ? const Color(0xFF64748B)
                  : const Color(0xFF10B981),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            isSearching ? 'Aucun résultat trouvé' : 'Aucune alerte en cours',
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isSearching
                ? 'Aucun élément ne correspond à « $_searchQuery ».'
                : 'Tous les éléments sont conformes pour « ${widget.title} ».\nAucune action requise.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 12.5,
              color: const Color(0xFF64748B),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

extension on String {
  /// Valeur de repli quand la chaine est vide.
  String ifEmpty(String repli) => isEmpty ? repli : this;
}
