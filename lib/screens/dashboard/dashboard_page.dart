import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../controllers/dashboard_controller.dart';
import 'cards/alertes_vidange_page.dart';
import 'cards/erreurs_kilometrage_page.dart';
import 'cards/vidanges_retard_page.dart';
import 'cards/operations_retard_page.dart';
import 'cards/conflits_planification_page.dart';
import 'cards/demandes_achat_page.dart';
import 'cards/bons_sans_bc_page.dart';
import 'cards/articles_sans_ba_page.dart';
import 'cards/documents_expires_page.dart';
import 'cards/documents_planifier_page.dart';
import 'cards/vidanges_sous_3000_page.dart';
import 'cards/demandes_or_page.dart';
import 'cards/or_non_clotures_page.dart';

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
    return Container(
      height: height,
      color: Colors.transparent,
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: child,
      ),
    );
  }

  @override
  bool shouldRebuild(_StickyHeaderDelegate oldDelegate) {
    return child != oldDelegate.child || height != oldDelegate.height;
  }
}

class DashboardPage extends StatefulWidget {
  final Function(int targetIndex) onNavigateToTab;

  const DashboardPage({super.key, required this.onNavigateToTab});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final DashboardController _controller = Get.find<DashboardController>();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final appBarHeight = topPadding + kToolbarHeight;

    return Padding(
      padding: EdgeInsets.only(top: appBarHeight - 55),
      child: RefreshIndicator(
        displacement: 24,
        onRefresh: () => _controller.fetchDashboardData(showLoading: false),
        color: const Color(0xFF1F3A5F),
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ── 1. En-tête : Titre & Sous-titre ──
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 4),
              sliver: SliverToBoxAdapter(child: _buildTitleRow()),
            ),

            // ── 2. Barre de recherche Collante (Sticky Header façon hr-perfect) ──
            SliverPersistentHeader(
              pinned: true,
              delegate: _StickyHeaderDelegate(
                // 62 et non 56 : le champ fait ~50 pt (TextField non dense +
                // bordure) et le delegate n'en laissait que 48 une fois ses
                // 4 pt de marge retirés — le bas du champ était rogné.
                height: 62,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: _buildSearchBar(),
                ),
              ),
            ),

            // ── 3. Indicateur de chargement discret ──
            Obx(() {
              if (_controller.isLoading.value) {
                return const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(18, 4, 18, 8),
                    child: LinearProgressIndicator(
                      minHeight: 2.5,
                      backgroundColor: Color(0xFFE2E8F0),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFF2563EB),
                      ),
                    ),
                  ),
                );
              }
              return const SliverToBoxAdapter(child: SizedBox.shrink());
            }),

            // ── 4. Les 13 Cartes du Tableau de bord ──
            Obx(() {
              final query = _controller.searchQuery.value.trim().toLowerCase();
              final allCards = _buildCardDefinitions();
              final filtered = query.isEmpty
                  ? allCards
                  : allCards
                        .where((c) => c.title.toLowerCase().contains(query))
                        .toList();

              if (filtered.isEmpty) {
                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 20, 18, 110),
                  sliver: SliverToBoxAdapter(child: _buildEmptyState(query)),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 110),
                sliver: SliverList.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    return _buildGmaoCard(filtered[index]);
                  },
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildTitleRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tableau de bord',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                'Alertes et analytiques du parc',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: const Color(0xFF64748B),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        // Badge nombre de cartes
        Obx(() {
          final query = _controller.searchQuery.value.trim().toLowerCase();
          final allCards = _buildCardDefinitions();
          final visibleCount = query.isEmpty
              ? allCards.length
              : allCards
                    .where((c) => c.title.toLowerCase().contains(query))
                    .length;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF1F3A5F).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF1F3A5F).withValues(alpha: 0.15),
              ),
            ),
            child: Text(
              '$visibleCount / ${allCards.length} cartes',
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1F3A5F),
              ),
            ),
          );
        }),
      ],
    );
  }

  // ── Barre de recherche ──
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
            onChanged: (val) => _controller.searchQuery.value = val,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: const Color(0xFF0F172A),
            ),
            decoration: InputDecoration(
              hintText: 'Rechercher une carte…',
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
                  color: Color(0xFF1F3A5F),
                ),
              ),
              prefixIconConstraints: const BoxConstraints(
                minWidth: 0,
                minHeight: 0,
              ),
              suffixIcon: Obx(() {
                if (_controller.searchQuery.value.isNotEmpty) {
                  return IconButton(
                    icon: const Icon(
                      LucideIcons.x,
                      size: 16,
                      color: Color(0xFF94A3B8),
                    ),
                    onPressed: () {
                      _searchController.clear();
                      _controller.searchQuery.value = '';
                    },
                  );
                }
                return const SizedBox.shrink();
              }),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ),
    );
  }

  // ── Définition réactive des 13 cartes GMAO ──
  List<_CardModel> _buildCardDefinitions() {
    return [
      // 1. Alertes vidange
      _CardModel(
        title: 'Alertes vidange',
        icon: LucideIcons.alertTriangle,
        color: const Color(0xFFF59E0B),
        targetTab: 3,
        pills: [
          _PillModel(
            '${_controller.alertesVidangeDepasses.value} dépassés',
            'depasse',
          ),
          _PillModel(
            '${_controller.alertesVidangeImminents.value} imminentes',
            'imminent',
          ),
          _PillModel(
            '${_controller.alertesVidangeCount.value} alertes',
            'total',
          ),
        ],
      ),

      // 2. Erreurs de kilométrage
      _CardModel(
        title: 'Erreurs de kilométrage',
        icon: LucideIcons.gauge,
        color: const Color(0xFFDC2626),
        targetTab: 3,
        pills: [
          _PillModel(
            '${_controller.erreursKmCount.value} véhicules',
            _controller.erreursKmCount.value > 0 ? 'depasse' : 'total',
          ),
        ],
      ),

      // 3. Vidanges planifiées en retard
      _CardModel(
        title: 'Vidanges planifiées en retard',
        icon: LucideIcons.calendarX,
        color: const Color(0xFF7C3AED),
        targetTab: 3,
        pills: [
          _PillModel(
            '${_controller.vidangesEnRetardCount.value} vidanges',
            _controller.vidangesEnRetardCount.value > 0 ? 'depasse' : 'total',
          ),
        ],
      ),

      // 4. Opérations administratives en retard
      _CardModel(
        title: 'Opérations administratives en retard',
        icon: LucideIcons.clock,
        color: const Color(0xFF0891B2),
        targetTab: 1,
        pills: [
          _PillModel(
            '${_controller.operationsEnRetardCount.value} opérations',
            _controller.operationsEnRetardCount.value > 0 ? 'depasse' : 'total',
          ),
        ],
      ),

      // 5. Conflits de planification
      _CardModel(
        title: 'Conflits de planification',
        icon: LucideIcons.alertOctagon,
        color: const Color(0xFFDB2777),
        targetTab: 3,
        pills: [
          _PillModel(
            '${_controller.conflitsPlanifCount.value} conflits',
            _controller.conflitsPlanifCount.value > 0 ? 'depasse' : 'total',
          ),
        ],
      ),

      // 6. Demandes d'achat en cours
      _CardModel(
        title: 'Demandes d\'achat en cours',
        icon: LucideIcons.shoppingCart,
        color: const Color(0xFF0EA5E9),
        targetTab: 2,
        pills: [
          _PillModel('${_controller.demandesAchatCount.value} bons', 'total'),
        ],
      ),

      // 7. Bons d'achat validés sans B.C
      _CardModel(
        title: 'Bons d\'achat validés sans B.C',
        icon: LucideIcons.fileCheck,
        color: const Color(0xFFF97316),
        targetTab: 2,
        pills: [
          _PillModel('${_controller.bonsSansBcCount.value} bons', 'total'),
        ],
      ),

      // 8. Articles sans bon d'achat validé
      _CardModel(
        title: 'Articles sans bon d\'achat validé',
        icon: LucideIcons.receipt,
        color: const Color(0xFFE11D48),
        targetTab: 2,
        pills: [
          if (_controller.articlesSansBaSansBon.value > 0)
            _PillModel(
              '${_controller.articlesSansBaSansBon.value} sans bon',
              'depasse',
            ),
          _PillModel(
            '${_controller.articlesSansBaTotal.value} articles',
            'total',
          ),
        ],
      ),

      // 9. Documents expirés
      _CardModel(
        title: 'Documents expirés',
        icon: LucideIcons.fileWarning,
        color: const Color(0xFFEF4444),
        targetTab: 1,
        pills: [
          _PillModel(
            '${_controller.docsExpiresCount.value} documents',
            _controller.docsExpiresCount.value > 0 ? 'depasse' : 'total',
          ),
        ],
      ),

      // 10. Documents à planifier
      _CardModel(
        title: 'Documents à planifier',
        icon: LucideIcons.calendar,
        color: const Color(0xFFF59E0B),
        targetTab: 1,
        pills: [
          if (_controller.docsPlanifEscalade.value > 0)
            _PillModel(
              '${_controller.docsPlanifEscalade.value} à remonter',
              'depasse',
            ),
          _PillModel('${_controller.docsPlanifCount.value} sous 21 j', 'total'),
        ],
      ),

      // 11. Vidange sous 3 000 km
      _CardModel(
        title: 'Vidange sous 3 000 km',
        icon: LucideIcons.droplet,
        color: const Color(0xFFE11D48),
        targetTab: 3,
        pills: [
          _PillModel(
            '${_controller.vidangesSous3000Count.value} à remonter',
            _controller.vidangesSous3000Count.value > 0 ? 'depasse' : 'total',
          ),
        ],
      ),

      // 12. Demandes OR à traiter
      _CardModel(
        title: 'Demandes OR à traiter',
        icon: LucideIcons.clipboardList,
        color: const Color(0xFF3B82F6),
        targetTab: 2,
        pills: [
          _PillModel('${_controller.demandesOrCount.value} demandes', 'total'),
        ],
      ),

      // 13. OR non clôturés
      _CardModel(
        title: 'OR non clôturés',
        icon: LucideIcons.wrench,
        color: const Color(0xFF8B5CF6),
        targetTab: 2,
        pills: [
          _PillModel('${_controller.orNonCloturesCount.value} ordres', 'total'),
        ],
      ),
    ];
  }

  // ── Rendu d'une carte GMAO ──
  Widget _buildGmaoCard(_CardModel card) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.95),
          width: 1.3,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1F3A5F).withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
          BoxShadow(
            color: card.color.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => _navigateToCardPage(card),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    // Icône de la carte
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: card.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: card.color.withValues(alpha: 0.25),
                          width: 1,
                        ),
                      ),
                      child: Icon(card.icon, color: card.color, size: 20),
                    ),
                    const SizedBox(width: 12),

                    // Titre & Pastilles de métriques
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            card.title,
                            style: GoogleFonts.poppins(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: card.pills
                                .map((pill) => _buildPill(pill))
                                .toList(),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 6),

                    // Flèche droite
                    const Icon(
                      LucideIcons.chevronRight,
                      size: 16,
                      color: Color(0xFF94A3B8),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Pastille de statut ──
  Widget _buildPill(_PillModel pill) {
    Color bg;
    Color border;
    Color text;

    switch (pill.type) {
      case 'depasse':
        bg = const Color(0xFFEF4444).withValues(alpha: 0.12);
        border = const Color(0xFFEF4444).withValues(alpha: 0.35);
        text = const Color(0xFFDC2626);
        break;
      case 'imminent':
        bg = const Color(0xFFF59E0B).withValues(alpha: 0.12);
        border = const Color(0xFFF59E0B).withValues(alpha: 0.35);
        text = const Color(0xFFD97706);
        break;
      case 'total':
      default:
        bg = const Color(0xFF1F3A5F).withValues(alpha: 0.08);
        border = const Color(0xFF1F3A5F).withValues(alpha: 0.18);
        text = const Color(0xFF1F3A5F);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border, width: 0.8),
      ),
      child: Text(
        pill.label,
        style: GoogleFonts.poppins(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: text,
        ),
      ),
    );
  }

  // ── État vide si aucune carte ne correspond à la recherche ──
  Widget _buildEmptyState(String query) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      alignment: Alignment.center,
      child: Column(
        children: [
          const Icon(LucideIcons.searchX, size: 36, color: Color(0xFF94A3B8)),
          const SizedBox(height: 12),
          Text(
            'Aucune carte ne correspond à « $query »',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  // ── Navigation vers la page dédiée de chaque carte ──
  void _navigateToCardPage(_CardModel card) {
    Widget? page;
    switch (card.title) {
      case 'Alertes vidange':
        page = const AlertesVidangePage();
        break;
      case 'Erreurs de kilométrage':
        page = const ErreursKilometragePage();
        break;
      case 'Vidanges planifiées en retard':
        page = const VidangesRetardPage();
        break;
      case 'Opérations administratives en retard':
        page = const OperationsRetardPage();
        break;
      case 'Conflits de planification':
        page = const ConflitsPlanificationPage();
        break;
      case 'Demandes d\'achat en cours':
        page = const DemandesAchatPage();
        break;
      case 'Bons d\'achat validés sans B.C':
        page = const BonsSansBcPage();
        break;
      case 'Articles sans bon d\'achat validé':
        page = const ArticlesSansBaPage();
        break;
      case 'Documents expirés':
        page = const DocumentsExpiresPage();
        break;
      case 'Documents à planifier':
        page = const DocumentsPlanifierPage();
        break;
      case 'Vidange sous 3 000 km':
        page = const VidangesSous3000Page();
        break;
      case 'Demandes OR à traiter':
        page = const DemandesOrPage();
        break;
      case 'OR non clôturés':
        page = const OrNonCloturesPage();
        break;
    }
    if (page != null) {
      Get.to(
        () => page!,
        transition: Transition.fadeIn,
        duration: const Duration(milliseconds: 300),
      );
    }
  }
}

class _CardModel {
  final String title;
  final IconData icon;
  final Color color;
  final int targetTab;
  final List<_PillModel> pills;

  _CardModel({
    required this.title,
    required this.icon,
    required this.color,
    required this.targetTab,
    required this.pills,
  });
}

class _PillModel {
  final String label;
  final String type;

  _PillModel(this.label, this.type);
}
