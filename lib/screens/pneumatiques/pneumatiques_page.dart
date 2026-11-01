import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../controllers/pneumatique_controller.dart';
import '../../widgets/apercu_kit.dart';
import '../../widgets/couleur_ligne.dart';
import '../../widgets/filtre_pastille.dart';
import 'pneumatique_apercu_page.dart';

/// Liste des pneumatiques, calquee sur la liste web (N° serie, vehicule,
/// position, km et date de montage, statut).
class PneumatiquesPage extends StatefulWidget {
  const PneumatiquesPage({super.key});

  @override
  State<PneumatiquesPage> createState() => _PneumatiquesPageState();
}

class _PneumatiquesPageState extends State<PneumatiquesPage> {
  static const Color _accent = Color(0xFF0EA5E9);

  late final PneumatiqueController _controller;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Controleur permanent (main.dart) : la liste est deja chargee quand on
    // ouvre la page, comme pour les OR, vehicules et vidanges.
    _controller = Get.isRegistered<PneumatiqueController>()
        ? Get.find<PneumatiqueController>()
        : Get.put(PneumatiqueController(), permanent: true);
    _searchController.text = _controller.searchQuery.value;
  }

  @override
  void dispose() {
    _searchController.dispose();
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

  /// Le backend prefixe l'alerte d'un pictogramme (« ⚠ Alerte : … ») que la
  /// police de l'app ne sait pas dessiner : il s'affiche en carre vide a cote
  /// de l'icone de la carte. On ne garde que le texte.
  String _texteAlerte(dynamic raw) {
    final brut = (raw ?? '').toString();
    if (brut.isEmpty) return '';

    return brut
        .replaceAll(
          RegExp(r'[\u2190-\u2BFF\uFE0F\u{1F000}-\u{1FAFF}]', unicode: true),
          '',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
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
          onRefresh: () => _controller.fetchPneumatiques(showLoading: false),
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
                      final list = _controller.filteredPneumatiques;
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
                              _buildPneuCard(list[index]),
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
                'Liste des pneumatiques',
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
                'Montage et suivi des pneus du parc',
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
          final count = _controller.filteredPneumatiques.length;
          final total = _controller.totalCount;
          final isFiltered =
              _controller.selectedStatusFilter.value != 'TOUS' ||
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

  Widget _buildFilterPills() {
    return Obx(() {
      final statuses = _controller.availableStatuses;
      final selected = _controller.selectedStatusFilter.value;

      return SizedBox(
        height: 32,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: statuses.length,
          separatorBuilder: (_, _) => const SizedBox(width: 6),
          itemBuilder: (_, i) {
            final s = statuses[i];

            return FiltrePastille(
              label: '$s (${_formatCount(_controller.countForStatus(s))})',
              couleur: s == 'TOUS'
                  ? const Color(0xFF1F3A5F)
                  : apercuCouleurStatut(apercuLibelleStatut(s)),
              actif: s.toLowerCase() == selected.toLowerCase(),
              onTap: () => _controller.updateStatusFilter(s),
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
              hintText: 'Rechercher un pneu, véhicule, position…',
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

  Widget _buildPneuCard(Map<String, dynamic> pneu) {
    final numSerie = (pneu['pneuNumSerie'] ?? pneu['numSerie'] ?? '—')
        .toString();
    final vehicule = (pneu['vehiculeLibelle'] ?? '').toString();
    final position = (pneu['positionLibelle'] ?? '').toString();
    final marque = (pneu['marqueLibelle'] ?? '').toString();
    final status = (pneu['status'] ?? '').toString();
    final alerte = _texteAlerte(pneu['messageAlert']);

    final statutLibelle = apercuLibelleStatut(status);
    final statutCouleur = apercuCouleurStatut(statutLibelle);

    // Pneu en alerte : bande et fond rouges, comme une ligne annulee.
    final ligne = couleurLignePneu(pneu);

    return Container(
      decoration: decorationLigne(ligne),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: avecBandeLigne(
          ligne,
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: InkWell(
              onTap: () => Get.to(() => PneumatiqueApercuPage(pneu: pneu)),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Ligne 1 : N° série + statut ──
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: _accent.withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: _accent.withValues(alpha: 0.22),
                                  ),
                                ),
                                child: const Icon(
                                  LucideIcons.circleDot,
                                  size: 18,
                                  color: _accent,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      numSerie,
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF0F172A),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (marque.isNotEmpty)
                                      Text(
                                        marque,
                                        style: GoogleFonts.poppins(
                                          fontSize: 11,
                                          color: const Color(0xFF64748B),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (status.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: statutCouleur.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: statutCouleur.withValues(alpha: 0.25),
                              ),
                            ),
                            child: Text(
                              statutLibelle,
                              style: GoogleFonts.poppins(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: statutCouleur,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // ── Ligne 2 : véhicule, position, km et date de montage ──
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (vehicule.isNotEmpty)
                          _infoPill(vehicule, LucideIcons.truck),
                        if (position.isNotEmpty)
                          _infoPill(position, LucideIcons.mapPin),
                        if (pneu['kilometrageMontage'] != null)
                          _infoPill(
                            _formatKm(pneu['kilometrageMontage']),
                            LucideIcons.gauge,
                          ),
                        if (pneu['dateMontage'] != null)
                          _infoPill(
                            _formatDate(pneu['dateMontage']),
                            LucideIcons.calendar,
                          ),
                      ],
                    ),

                    if (alerte.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            LucideIcons.alertTriangle,
                            size: 13,
                            color: Color(0xFFDC2626),
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              alerte,
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: const Color(0xFFDC2626),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
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
            'Aucun pneumatique trouvé',
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Aucun pneumatique ne correspond aux critères de recherche.',
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
            label: const Text('Afficher tous les pneumatiques'),
          ),
        ],
      ),
    );
  }
}
