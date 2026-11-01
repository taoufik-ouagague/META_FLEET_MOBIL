import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../controllers/journal_controller.dart';
import '../../controllers/or_controller.dart';
import '../../widgets/apercu_kit.dart';
import '../../widgets/couleur_ligne.dart';
import '../../widgets/filtre_pastille.dart';
import 'journal_apercu_page.dart';

/// Journal des operations, calque sur la table du web : operation, vehicule,
/// article, kilometrages et montants.
class JournalPage extends StatefulWidget {
  const JournalPage({super.key});

  @override
  State<JournalPage> createState() => _JournalPageState();
}

class _JournalPageState extends State<JournalPage> {
  static const Color _accent = Color(0xFF1F3A5F);

  late final JournalController _controller;
  final TextEditingController _searchController = TextEditingController();

  /// Champ du selecteur d'articles : porte par l'ecran, pas par la feuille, car
  /// le disposer a la fermeture detruit le TextField encore anime.
  final TextEditingController _articleChamp = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Controleur permanent (main.dart) : la liste est deja chargee quand on
    // ouvre la page, comme pour les OR, vehicules et vidanges.
    _controller = Get.isRegistered<JournalController>()
        ? Get.find<JournalController>()
        : Get.put(JournalController(), permanent: true);
    _searchController.text = _controller.searchQuery.value;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _articleChamp.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String _formatCount(int count) => _separerMilliers(count.toString());

  String _separerMilliers(String str) {
    final parts = <String>[];
    var i = str.length;
    while (i > 3) {
      parts.insert(0, str.substring(i - 3, i));
      i -= 3;
    }
    parts.insert(0, str.substring(0, i));

    return parts.join(' ');
  }

  String _formatKm(dynamic km) {
    if (km == null) return '—';
    final valeur = (km is num) ? km.toInt() : int.tryParse(km.toString());
    if (valeur == null) return '—';

    return '${_separerMilliers(valeur.toString())} km';
  }

  String _formatDate(dynamic raw) {
    final s = (raw ?? '').toString();
    if (s.length < 10) return '—';
    final d = s.substring(0, 10).split('-');

    return d.length == 3 ? '${d[2]}/${d[1]}/${d[0]}' : s.substring(0, 10);
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final appBarHeight = topPadding + kToolbarHeight;

    return Padding(
      padding: EdgeInsets.only(top: appBarHeight - 55),
      child: NotificationListener<ScrollNotification>(
        onNotification: (scrollInfo) {
          if (scrollInfo.metrics.pixels >=
              scrollInfo.metrics.maxScrollExtent - 300) {
            _controller.loadNextPage();
          }

          return false;
        },
        child: RefreshIndicator(
          displacement: 24,
          onRefresh: () => _controller.fetchJournal(showLoading: false),
          color: _accent,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 4),
                child: _buildTitleRow(),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildSearchBar(),
                      const SizedBox(height: 8),
                      _buildFilterPills(),
                      const SizedBox(height: 6),
                      _buildFiltresAvances(),
                      Obx(() {
                        if (!_controller.isLoading.value) {
                          return const SizedBox.shrink();
                        }

                        return const Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: LinearProgressIndicator(
                            minHeight: 2.5,
                            backgroundColor: Color(0xFFE2E8F0),
                            valueColor: AlwaysStoppedAnimation<Color>(_accent),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: CustomScrollView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    Obx(() {
                      final list = _controller.filteredLignes;
                      if (list.isEmpty && !_controller.isLoading.value) {
                        return SliverPadding(
                          padding: const EdgeInsets.fromLTRB(18, 20, 18, 110),
                          sliver: SliverToBoxAdapter(child: _buildEmptyState()),
                        );
                      }

                      return SliverPadding(
                        padding: const EdgeInsets.fromLTRB(18, 10, 18, 110),
                        sliver: SliverList.separated(
                          itemCount: list.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, index) =>
                              _buildLigneCard(list[index]),
                        ),
                      );
                    }),
                    Obx(() {
                      if (!_controller.isLoadingMore.value) {
                        return const SliverToBoxAdapter(
                          child: SizedBox.shrink(),
                        );
                      }

                      return const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.only(bottom: 120),
                          child: Center(
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  _accent,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTitleRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Journal',
                style: GoogleFonts.poppins(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                  letterSpacing: -0.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                'Opérations sur le parc',
                style: GoogleFonts.poppins(
                  fontSize: 11.5,
                  color: const Color(0xFF64748B),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Obx(() {
          final count = _controller.filteredLignes.length;
          final total = _controller.totalCount;
          final isFiltered =
              _controller.selectedTypeFilter.value != 'TOUS' ||
              _controller.searchQuery.value.isNotEmpty;
          final label = _controller.searchQuery.value.isNotEmpty
              ? '${_formatCount(count)} / ${_formatCount(total)}'
              : '${_formatCount(total)} éléments';

          return GestureDetector(
            onTap: isFiltered ? _controller.resetFilters : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _accent.withValues(alpha: 0.15)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _accent,
                    ),
                  ),
                  if (isFiltered) ...[
                    const SizedBox(width: 4),
                    const Icon(LucideIcons.x, size: 11, color: _accent),
                  ],
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  /// Filtres repris du journal web : nature d'anomalie et article.
  Widget _buildFiltresAvances() {
    return Obx(() {
      final nature = _controller.selectedNature.value;
      final article = _controller.articleFilter.value;

      return SizedBox(
        height: 32,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            FiltrePastille(
              label: nature == null
                  ? "Nature d'anomalie"
                  : (nature['libelle'] ?? nature['nom'] ?? '—').toString(),
              couleur: const Color(0xFFDC2626),
              icone: LucideIcons.alertTriangle,
              actif: nature != null,
              deroulante: true,
              onTap: _choisirNature,
            ),
            const SizedBox(width: 6),
            FiltrePastille(
              label: article.isEmpty ? 'Article' : article,
              couleur: const Color(0xFF7C3AED),
              icone: LucideIcons.package,
              actif: article.isNotEmpty,
              onTap: _saisirArticle,
            ),
          ],
        ),
      );
    });
  }

  /// Coquille en verre des feuilles de filtre, dans le ton des cartes.
  Widget _feuilleVerre({required Widget enfant, double hauteur = 0.75}) {
    // Pas de SafeArea ici : elle laissait une bande grise sous le verre, et la
    // liste continuait de defiler dedans. Le verre descend jusqu'au bord, la
    // marge basse est posee a l'interieur des listes.
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: MediaQuery.of(context).size.height * hauteur,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.86),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.95),
              width: 1.2,
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: Column(
            children: [
              // Poignee de glissement.
              Container(
                width: 42,
                height: 4,
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF94A3B8).withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(child: enfant),
            ],
          ),
        ),
      ),
    );
  }

  /// Marge basse d'une liste de feuille : au-dessus de la barre d'accueil.
  double get _margeBasse => MediaQuery.of(context).viewPadding.bottom + 16;

  Widget _titreFeuille(String texte, IconData icone, Color couleur) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 10),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: couleur.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icone, size: 16, color: couleur),
          ),
          const SizedBox(width: 10),
          Text(
            texte,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  /// Ligne de choix : carte en verre, comme les cartes de liste.
  Widget _ligneChoix({
    required String titre,
    String? sousTitre,
    required IconData icone,
    required Color couleur,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      child: Material(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFFE2E8F0).withValues(alpha: 0.9),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: couleur.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(icone, size: 15, color: couleur),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titre,
                        style: GoogleFonts.poppins(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF0F172A),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if ((sousTitre ?? '').isNotEmpty)
                        Text(
                          sousTitre!,
                          style: GoogleFonts.poppins(
                            fontSize: 10.5,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// La liste des natures est deja chargee par le controleur des OR.
  Future<void> _choisirNature() async {
    final natures = Get.isRegistered<OrController>()
        ? Get.find<OrController>().naturesAnomalies.toList()
        : <Map<String, dynamic>>[];

    if (natures.isEmpty) {
      _controller.updateNature(null);

      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      // On passe par le contexte de la feuille : fermer via le contexte de
      // l'ecran revient a chercher un ancetre deja desactive.
      builder: (contexte) => _feuilleVerre(
        hauteur: 0.6,
        enfant: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _titreFeuille(
              "Nature d'anomalie",
              LucideIcons.alertTriangle,
              const Color(0xFFDC2626),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.only(top: 2, bottom: _margeBasse),
                children: [
                  _ligneChoix(
                    titre: 'Toutes les natures',
                    icone: LucideIcons.x,
                    couleur: const Color(0xFF64748B),
                    onTap: () {
                      _controller.updateNature(null);
                      Navigator.of(contexte).pop();
                    },
                  ),
                  for (final n in natures)
                    _ligneChoix(
                      titre:
                          (n['libelle'] ??
                                  n['nom'] ??
                                  n['natureAnomalie'] ??
                                  '—')
                              .toString(),
                      icone: LucideIcons.alertTriangle,
                      couleur: const Color(0xFFDC2626),
                      onTap: () {
                        _controller.updateNature(n);
                        Navigator.of(contexte).pop();
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saisirArticle() async {
    // Catalogue pret avant d'ouvrir : la feuille n'a alors aucun etat reactif
    // a observer, et rien ne se reconstruit apres sa fermeture.
    await _controller.chargerArticles();
    if (!mounted) return;

    _articleChamp.text = _controller.articleFilter.value;
    final tous = _controller.articles.toList();
    var limite = 100;

    final choix = await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (contexte) => StatefulBuilder(
        builder: (contexte, majFeuille) {
          final requete = _articleChamp.text.trim().toLowerCase();
          final trouves = tous.where((a) {
            if (requete.isEmpty) return true;
            final libelle = (a['libelle'] ?? '').toString().toLowerCase();
            final code = (a['code'] ?? '').toString().toLowerCase();

            return libelle.contains(requete) || code.contains(requete);
          }).toList();
          final visibles = trouves.take(limite).toList();
          final restants = trouves.length - visibles.length;

          return _feuilleVerre(
            enfant: Column(
              children: [
                _titreFeuille(
                  'Article  ·  ${trouves.length}',
                  LucideIcons.package,
                  const Color(0xFF7C3AED),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.95),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFF1F3A5F,
                          ).withValues(alpha: 0.05),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _articleChamp,
                      autofocus: true,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: const Color(0xFF0F172A),
                      ),
                      onChanged: (_) => majFeuille(() => limite = 100),
                      decoration: InputDecoration(
                        hintText: 'Rechercher un article…',
                        hintStyle: GoogleFonts.poppins(
                          fontSize: 13,
                          color: const Color(0xFF94A3B8),
                        ),
                        prefixIcon: const Padding(
                          padding: EdgeInsets.only(left: 14, right: 8),
                          child: Icon(
                            LucideIcons.search,
                            size: 18,
                            color: Color(0xFF7C3AED),
                          ),
                        ),
                        prefixIconConstraints: const BoxConstraints(
                          minWidth: 0,
                          minHeight: 0,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: tous.isEmpty
                      ? Center(
                          child: Text(
                            'Aucun article disponible',
                            style: GoogleFonts.poppins(
                              fontSize: 12.5,
                              color: const Color(0xFF94A3B8),
                            ),
                          ),
                        )
                      : NotificationListener<ScrollNotification>(
                          onNotification: (scroll) {
                            if (restants > 0 &&
                                scroll.metrics.pixels >=
                                    scroll.metrics.maxScrollExtent - 200) {
                              majFeuille(() => limite += 100);
                            }

                            return false;
                          },
                          child: ListView.builder(
                            padding: EdgeInsets.only(bottom: _margeBasse),
                            itemCount: visibles.length + (restants > 0 ? 2 : 1),
                            itemBuilder: (_, i) {
                              if (i == 0) {
                                return _ligneChoix(
                                  titre: 'Tous les articles',
                                  icone: LucideIcons.x,
                                  couleur: const Color(0xFF64748B),
                                  onTap: () => Navigator.of(contexte).pop(''),
                                );
                              }

                              final index = i - 1;
                              if (index >= visibles.length) {
                                return Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Center(
                                    child: Text(
                                      '$restants article(s) de plus…',
                                      style: GoogleFonts.poppins(
                                        fontSize: 11.5,
                                        color: const Color(0xFF94A3B8),
                                      ),
                                    ),
                                  ),
                                );
                              }

                              final a = visibles[index];
                              final libelle = (a['libelle'] ?? '').toString();
                              final code = (a['code'] ?? '').toString();

                              return _ligneChoix(
                                titre: libelle.isEmpty ? code : libelle,
                                sousTitre: code,
                                icone: LucideIcons.package,
                                couleur: const Color(0xFF7C3AED),
                                onTap: () =>
                                    Navigator.of(contexte).pop(libelle),
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );

    if (choix != null) _controller.updateArticle(choix);
  }

  Widget _buildFilterPills() {
    return Obx(() {
      final statuses = _controller.availableTypes;
      final selected = _controller.selectedTypeFilter.value;

      return SizedBox(
        height: 32,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: statuses.length,
          separatorBuilder: (_, _) => const SizedBox(width: 6),
          itemBuilder: (_, i) {
            final s = statuses[i];

            final n = _controller.countForType(s);

            return FiltrePastille(
              label: n == null ? s : '$s (${_formatCount(n)})',
              couleur: s == 'TOUS'
                  ? const Color(0xFF1F3A5F)
                  : apercuCouleurStatut(apercuLibelleStatut(s)),
              actif: s.toLowerCase() == selected.toLowerCase(),
              onTap: () => _controller.updateTypeFilter(s),
            );
          },
        ),
      );
    });
  }

  Widget _buildSearchBar() {
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
            controller: _searchController,
            onChanged: _controller.updateSearchQuery,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: const Color(0xFF0F172A),
            ),
            decoration: InputDecoration(
              hintText: 'N° OR, vidange ou immatriculation…',
              hintStyle: GoogleFonts.poppins(
                fontSize: 13,
                color: const Color(0xFF94A3B8),
              ),
              // La boite du prefixe fait 48 dp par defaut : l'icone s'y centre et
              // laisse un vide avant le texte. On porte les marges sur l'icone.
              prefixIcon: const Padding(
                padding: EdgeInsets.only(left: 14, right: 8),
                child: Icon(LucideIcons.search, size: 18, color: _accent),
              ),
              prefixIconConstraints: const BoxConstraints(
                minWidth: 0,
                minHeight: 0,
              ),
              suffixIcon: Obx(() {
                if (_controller.searchQuery.value.isEmpty) {
                  return const SizedBox.shrink();
                }

                return IconButton(
                  icon: const Icon(
                    LucideIcons.x,
                    size: 16,
                    color: Color(0xFF94A3B8),
                  ),
                  onPressed: () {
                    _searchController.clear();
                    _controller.updateSearchQuery('');
                  },
                );
              }),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLigneCard(Map<String, dynamic> l) {
    final estVidange = (l['typeOperation'] ?? '')
        .toString()
        .toUpperCase()
        .contains('VIDANGE');
    final numero = (l['ordreReparationNumero'] ?? l['vidangeNumero'] ?? '—')
        .toString();
    final immat = (l['vehiculeImmatriculation'] ?? '').toString();
    final vehicule = [
      (l['vehiculeMarque'] ?? '').toString(),
      (l['vehiculeModele'] ?? '').toString(),
    ].where((e) => e.isNotEmpty && e != 'null').join(' · ');
    final article = (l['produitLibelle'] ?? l['description'] ?? '').toString();
    final statut = (l['statusOperation'] ?? '').toString();
    final couleurOp = estVidange
        ? const Color(0xFF0891B2)
        : const Color(0xFFD97706);

    return Container(
      decoration: decorationLigne(null),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: InkWell(
            onTap: () => Get.to(() => JournalApercuPage(ligne: l)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: couleurOp.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: couleurOp.withValues(alpha: 0.22),
                          ),
                        ),
                        child: Icon(
                          estVidange ? LucideIcons.droplet : LucideIcons.wrench,
                          size: 18,
                          color: couleurOp,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              numero,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (immat.isNotEmpty || vehicule.isNotEmpty)
                              Text(
                                [
                                  immat,
                                  vehicule,
                                ].where((e) => e.isNotEmpty).join('  —  '),
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF2563EB),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      if (statut.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: apercuCouleurStatut(
                              apercuLibelleStatut(statut),
                            ).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            apercuLibelleStatut(statut),
                            style: GoogleFonts.poppins(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: apercuCouleurStatut(
                                apercuLibelleStatut(statut),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (article.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      article,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF334155),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (l['dateOr'] != null)
                        _infoPill(
                          _formatDate(l['dateOr']),
                          LucideIcons.calendar,
                        ),
                      if (l['qte'] != null)
                        _infoPill('Qté ${l['qte']}', LucideIcons.hash),
                      if (l['km'] != null)
                        _infoPill(_formatKm(l['km']), LucideIcons.gauge),
                      if ((l['natureAnomalie'] ?? '').toString().isNotEmpty)
                        _infoPill(
                          l['natureAnomalie'].toString(),
                          LucideIcons.alertTriangle,
                        ),
                      if ((l['fournisseur'] ?? '').toString().isNotEmpty)
                        _infoPill(
                          l['fournisseur'].toString(),
                          LucideIcons.store,
                        ),
                      if (l['montantTtc'] != null)
                        _infoPill('${l['montantTtc']} TTC', LucideIcons.wallet),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoPill(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: const Color(0xFF64748B)),
          const SizedBox(width: 3),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF475569),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
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
              color: _accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(LucideIcons.circleDot, size: 30, color: _accent),
          ),
          const SizedBox(height: 14),
          Text(
            'Aucune ligne trouvée',
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Aucune opération ne correspond aux critères de recherche.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 12.5,
              color: const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: _controller.resetFilters,
            icon: const Icon(LucideIcons.rotateCcw, size: 14),
            label: const Text('Afficher tout le journal'),
          ),
        ],
      ),
    );
  }
}
