import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../controllers/or_controller.dart';
import '../../widgets/couleur_ligne.dart';
import '../../widgets/filtre_pastille.dart';
import 'or_apercu_page.dart';

import '../../widgets/apercu_kit.dart';

class OrPage extends StatefulWidget {
  const OrPage({super.key});

  @override
  State<OrPage> createState() => _OrPageState();
}

class _OrPageState extends State<OrPage> {
  late final OrController _controller;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller = Get.isRegistered<OrController>()
        ? Get.find<OrController>()
        : Get.put(OrController());
    if (_controller.ordres.isEmpty && !_controller.isLoading.value) {
      _controller.fetchOrdres();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String _formatCount(int count) {
    final str = count.toString();
    final parts = <String>[];
    int i = str.length;
    while (i > 3) {
      parts.insert(0, str.substring(i - 3, i));
      i -= 3;
    }
    parts.insert(0, str.substring(0, i));
    return parts.join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final appBarHeight = topPadding + kToolbarHeight;

    return Padding(
      padding: EdgeInsets.only(top: appBarHeight - 55),
      child: NotificationListener<ScrollNotification>(
        onNotification: (ScrollNotification scrollInfo) {
          if (scrollInfo.metrics.pixels >=
              scrollInfo.metrics.maxScrollExtent - 300) {
            _controller.loadNextPage();
          }
          return false;
        },
        child: RefreshIndicator(
          displacement: 24,
          onRefresh: () => _controller.fetchOrdres(showLoading: false),
          color: const Color(0xFF1F3A5F),
          // Titre, recherche et filtres fixes : seule la liste defile, comme
          // sur la liste des demandes.
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
                      _buildFilterBar(context),
                      Obx(() {
                        if (_controller.isLoading.value) {
                          return const Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: LinearProgressIndicator(
                              minHeight: 2.5,
                              backgroundColor: Color(0xFFE2E8F0),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFF2563EB),
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
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
                    // ── 3. Liste virtualisée des OR (29828 éléments avec pagination) ──
                    Obx(() {
                      final list = _controller.filteredOrdres;
                      if (list.isEmpty && !_controller.isLoading.value) {
                        return SliverPadding(
                          padding: const EdgeInsets.fromLTRB(18, 20, 18, 110),
                          sliver: SliverToBoxAdapter(child: _buildEmptyState()),
                        );
                      }

                      return SliverPadding(
                        padding: const EdgeInsets.fromLTRB(18, 10, 18, 16),
                        sliver: SliverList.separated(
                          itemCount: list.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            return _buildOrCard(list[index]);
                          },
                        ),
                      );
                    }),

                    // ── Indicateur de chargement de la page suivante ──
                    Obx(() {
                      if (_controller.isLoadingMore.value) {
                        return const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Color(0xFF2563EB),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }
                      return const SliverToBoxAdapter(
                        child: SizedBox(height: 110),
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
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ordres de Réparation',
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
                'Suivi des interventions atelier',
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
          final total = _controller.totalCount;
          final isFiltered = _controller.hasActiveFilter;
          final label = '${_formatCount(total)} éléments';

          return GestureDetector(
            onTap: isFiltered ? () => _controller.resetFilters() : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1D4ED8),
                    ),
                  ),
                  if (isFiltered) ...[
                    const SizedBox(width: 4),
                    const Icon(
                      LucideIcons.x,
                      size: 11,
                      color: Color(0xFF1D4ED8),
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
      ],
    );
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
            onChanged: (val) => _controller.updateSearchQuery(val),
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: const Color(0xFF0F172A),
            ),
            decoration: InputDecoration(
              hintText: 'Rechercher un OR, immatriculation…',
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
                      _controller.updateSearchQuery('');
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

  Widget _buildOrCard(Map<String, dynamic> ordre) {
    final numero =
        ordre['numero']?.toString() ??
        ordre['numeroOrdreReparation']?.toString() ??
        '—';
    final immat =
        ordre['immatriculation']?.toString() ??
        ordre['vehiculeImmatriculation']?.toString() ??
        '';
    final dateOr =
        ordre['dateOrdreReparation']?.toString() ??
        ordre['dateDemande']?.toString() ??
        '';
    final chauffeur =
        ordre['chauffeur']?.toString() ??
        ordre['chauffeurNom']?.toString() ??
        ordre['demandeurNomComplet']?.toString() ??
        '';
    final nature = ordre['natureAnomalieLibelle']?.toString() ?? '';
    final natures = <String>[];
    if (ordre['naturesAnomalies'] is List) {
      for (final item in ordre['naturesAnomalies']) {
        if (item is Map) {
          final lib = (item['libelle'] ?? item['nom'] ?? item['natureAnomalie'])
              ?.toString()
              .trim();
          if (lib != null && lib.isNotEmpty && !natures.contains(lib)) {
            natures.add(lib);
          }
        } else if (item is String &&
            item.trim().isNotEmpty &&
            !natures.contains(item.trim())) {
          natures.add(item.trim());
        }
      }
    }
    if (natures.isEmpty && nature.isNotEmpty) {
      natures.add(nature);
    }
    final typeIntervention = ordre['typeInterventionLibelle']?.toString() ?? '';
    final status = ordre['status']?.toString() ?? 'Actif';
    final lieu = ordre['lieuReparation']?.toString() ?? '';
    final categorie =
        ordre['vehiculeCategorieLibelle']?.toString() ??
        ordre['categorieVehicule']?.toString() ??
        '';
    final marque =
        ordre['vehiculeMarqueLibelle']?.toString() ??
        ordre['marque']?.toString() ??
        '';
    final genre =
        ordre['vehiculeGenreLibelle']?.toString() ??
        ordre['genre']?.toString() ??
        '';
    final km =
        ordre['kilometrage'] != null &&
            ordre['kilometrage'].toString().isNotEmpty
        ? '${ordre['kilometrage']} km'
        : '';
    final etape = _controller.currentEtape(ordre);
    final isCloture = _controller.isCloture(ordre);

    // Status colors
    Color statusBg, statusFg;
    if (isCloture) {
      statusBg = const Color(0xFF64748B).withValues(alpha: 0.12);
      statusFg = const Color(0xFF475569);
    } else if (status.toLowerCase().contains('actif')) {
      statusBg = const Color(0xFF10B981).withValues(alpha: 0.12);
      statusFg = const Color(0xFF059669);
    } else {
      statusBg = const Color(0xFFF59E0B).withValues(alpha: 0.12);
      statusFg = const Color(0xFFD97706);
    }

    // Etape colors
    Color etapeBg, etapeFg;
    final etapeLower = etape.toLowerCase();
    if (etapeLower.contains('clôture') || etapeLower.contains('cloture')) {
      etapeBg = const Color(0xFF10B981).withValues(alpha: 0.12);
      etapeFg = const Color(0xFF059669);
    } else if (etapeLower.contains('répar') ||
        etapeLower.contains('repar') ||
        etapeLower.contains('technique') ||
        etapeLower.contains('financ')) {
      etapeBg = const Color(0xFFF59E0B).withValues(alpha: 0.12);
      etapeFg = const Color(0xFFD97706);
    } else if (etapeLower.contains('achat')) {
      etapeBg = const Color(0xFF2563EB).withValues(alpha: 0.12);
      etapeFg = const Color(0xFF2563EB);
    } else {
      etapeBg = const Color(0xFF6366F1).withValues(alpha: 0.12);
      etapeFg = const Color(0xFF6366F1);
    }

    // Vehicle description line (Catégorie • Marque • Genre)
    final vehicleDetails = [
      categorie,
      marque,
      genre,
    ].where((s) => s.isNotEmpty).join(' • ');

    // Formatted date
    String formattedDate = '';
    if (dateOr.isNotEmpty) {
      if (dateOr.length >= 10) {
        final raw = dateOr.substring(0, 10);
        final parts = raw.split('-');
        if (parts.length == 3) {
          formattedDate = '${parts[2]}/${parts[1]}/${parts[0]}';
        } else {
          formattedDate = raw;
        }
      } else {
        formattedDate = dateOr;
      }
    }

    return Container(
      decoration: decorationLigne(couleurLigneOr(ordre)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: avecBandeLigne(
          couleurLigneOr(ordre),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => Get.to(() => OrApercuPage(ordre: ordre)),
                borderRadius: BorderRadius.circular(18),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Row 1: Numéro OR (Vert comme version web) + Date + Matricule + Statut ──
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text(
                                numero,
                                style: GoogleFonts.poppins(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                  color: isCloture
                                      ? const Color(0xFF64748B)
                                      : const Color(0xFF16A34A),
                                ),
                              ),
                              if (formattedDate.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Text(
                                  formattedDate,
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: const Color(0xFF94A3B8),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          Row(
                            children: [
                              if (immat.isNotEmpty) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: const Color(0xFFBFDBFE),
                                    ),
                                  ),
                                  child: Text(
                                    immat,
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF1D4ED8),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                              ],
                              if (status.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 2.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: statusBg,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    status,
                                    style: GoogleFonts.poppins(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                      color: statusFg,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      // ── Row 2: Natures d'anomalies (avec badge +N comme version web) + Lieu ──
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (natures.isNotEmpty) ...[
                            _infoPill(
                              natures[0],
                              LucideIcons.alertTriangle,
                              isAnomaly: true,
                            ),
                            if (natures.length > 1)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: const Color(0xFFBFDBFE),
                                  ),
                                ),
                                child: Text(
                                  '+${natures.length - 1}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF2563EB),
                                  ),
                                ),
                              ),
                          ],
                          if (typeIntervention.isNotEmpty)
                            _infoPill(typeIntervention, LucideIcons.wrench),
                          if (lieu.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFFBEB),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: const Color(0xFFFDE68A),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    LucideIcons.truck,
                                    size: 11,
                                    color: Color(0xFFD97706),
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    lieu,
                                    style: GoogleFonts.poppins(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFFD97706),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),

                      if (vehicleDetails.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          vehicleDetails,
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],

                      const SizedBox(height: 8),

                      // ── Row 3: Étape workflow + KM + Chauffeur ──
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: etapeBg,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  LucideIcons.workflow,
                                  size: 12,
                                  color: etapeFg,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  etape,
                                  style: GoogleFonts.poppins(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: etapeFg,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            children: [
                              if (chauffeur.isNotEmpty) ...[
                                Icon(
                                  LucideIcons.user,
                                  size: 12,
                                  color: const Color(0xFF94A3B8),
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  chauffeur.length > 15
                                      ? '${chauffeur.substring(0, 15)}…'
                                      : chauffeur,
                                  style: GoogleFonts.poppins(
                                    fontSize: 10.5,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              if (km.isNotEmpty) ...[
                                Icon(
                                  LucideIcons.gauge,
                                  size: 12,
                                  color: const Color(0xFF94A3B8),
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
                              ],
                            ],
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

  // ── Barre de Filtres Réactifs (Statuts + Sélecteur Nature Anomalie) ──
  Widget _buildFilterBar(BuildContext context) {
    return Obx(() {
      final selectedStatus = _controller.selectedStatusFilter.value;
      final selectedNature = _controller.selectedNatureAnomalie.value;
      final selectedNatureLib =
          (selectedNature?['libelle'] ??
                  selectedNature?['nom'] ??
                  selectedNature?['natureAnomalie'] ??
                  '')
              .toString();
      final natures = _controller.availableNatures;

      return SizedBox(
        height: 34,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            // 1. Bouton TOUS
            Builder(
              builder: (_) {
                final isTousActive =
                    selectedStatus.toLowerCase() == 'tous' &&
                    selectedNature == null;

                return FiltrePastille(
                  label: 'TOUS',
                  couleur: const Color(0xFF1F3A5F),
                  actif: isTousActive,
                  onTap: () => _controller.resetFilters(),
                );
              },
            ),
            const SizedBox(width: 8),

            // 2. Select NATURE D'ANOMALIE (ouvert au clic avec liste complète et recherche)
            _buildFilterPill(
              label: selectedNatureLib.isEmpty
                  ? 'Nature anomalie'
                  : selectedNatureLib,
              isSelected: selectedNature != null,
              hasValue: selectedNature != null,
              onTap: () => _openFilterSelector(
                context: context,
                title: 'Nature des anomalies',
                items: natures,
                selectedItem: selectedNature,
                onSelect: (val) => _controller.updateNatureAnomalieFilter(val),
                countProvider: _controller.countForNature,
              ),
              couleur: kApRouge,
              icone: LucideIcons.alertTriangle,
              onClear: selectedNature != null
                  ? () => _controller.updateNatureAnomalieFilter(null)
                  : null,
            ),
            const SizedBox(width: 8),

            // 3. Filtres par Statut : Actif et Clôturé
            for (final s in ['Actif', 'Clôturé']) ...[
              Builder(
                builder: (_) {
                  final count = _controller.countForStatus(s);
                  final label = count != null && count > 0
                      ? '$s (${_formatCount(count)})'
                      : s;
                  final isActive =
                      s.toLowerCase() == selectedStatus.toLowerCase();

                  return FiltrePastille(
                    label: label,
                    icone: s == 'Actif'
                        ? LucideIcons.activity
                        : LucideIcons.checkCircle,
                    couleur: apercuCouleurStatut(s),
                    actif: isActive,
                    onTap: () => _controller.updateStatusFilter(s),
                  );
                },
              ),
              const SizedBox(width: 8),
            ],
          ],
        ),
      );
    });
  }

  void _openFilterSelector({
    required BuildContext context,
    required String title,
    required List<Map<String, dynamic>> items,
    required Map<String, dynamic>? selectedItem,
    required Function(Map<String, dynamic>?) onSelect,
    int Function(Map<String, dynamic>)? countProvider,
    bool enableSearch = true,
  }) {
    String libelleDe(Map<String, dynamic> m) =>
        (m['libelle'] ?? m['nom'] ?? m['natureAnomalie'] ?? '').toString();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final searchNotifier = ValueNotifier<String>('');
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.70,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 10, bottom: 8),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        if (selectedItem != null)
                          GestureDetector(
                            onTap: () {
                              onSelect(null);
                              Navigator.pop(ctx);
                            },
                            child: Text(
                              'Réinitialiser',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFFEF4444),
                              ),
                            ),
                          )
                        else
                          IconButton(
                            icon: const Icon(
                              LucideIcons.x,
                              size: 20,
                              color: Color(0xFF64748B),
                            ),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                      ],
                    ),
                  ),

                  // Search bar inside bottom sheet
                  if (enableSearch && items.length > 5) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      child: Container(
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: TextField(
                          onChanged: (val) {
                            searchNotifier.value = val;
                            setModalState(() {});
                          },
                          style: GoogleFonts.poppins(fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'Rechercher...',
                            hintStyle: GoogleFonts.poppins(
                              fontSize: 12.5,
                              color: const Color(0xFF94A3B8),
                            ),
                            // La boite du prefixe fait 48 dp par defaut : l'icone s'y centre et
                            // laisse un vide avant le texte. On porte les marges sur l'icone.
                            prefixIcon: const Padding(
                              padding: EdgeInsets.only(left: 14, right: 8),
                              child: Icon(
                                LucideIcons.search,
                                size: 16,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            prefixIconConstraints: const BoxConstraints(
                              minWidth: 0,
                              minHeight: 0,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 10,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],

                  const Divider(height: 1, color: Color(0xFFE2E8F0)),

                  // List of items
                  Expanded(
                    child: ValueListenableBuilder<String>(
                      valueListenable: searchNotifier,
                      builder: (context, query, _) {
                        final filtered = items.where((it) {
                          if (query.trim().isEmpty) return true;
                          return libelleDe(
                            it,
                          ).toLowerCase().contains(query.trim().toLowerCase());
                        }).toList();

                        if (filtered.isEmpty) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                'Aucun résultat trouvé',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: const Color(0xFF94A3B8),
                                ),
                              ),
                            ),
                          );
                        }

                        return ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: filtered.length,
                          separatorBuilder: (_, _) => const Divider(
                            height: 1,
                            indent: 20,
                            endIndent: 20,
                            color: Color(0xFFF1F5F9),
                          ),
                          itemBuilder: (context, index) {
                            final item = filtered[index];
                            final isSelected =
                                selectedItem != null &&
                                libelleDe(item).toLowerCase() ==
                                    libelleDe(selectedItem).toLowerCase();
                            final count = countProvider != null
                                ? countProvider(item)
                                : null;

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 2,
                              ),
                              title: Text(
                                libelleDe(item),
                                style: GoogleFonts.poppins(
                                  fontSize: 13.5,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? const Color(0xFF1F3A5F)
                                      : const Color(0xFF0F172A),
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (count != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? const Color(
                                                0xFF1F3A5F,
                                              ).withValues(alpha: 0.10)
                                            : const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        '$count',
                                        style: GoogleFonts.poppins(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: isSelected
                                              ? const Color(0xFF1F3A5F)
                                              : const Color(0xFF64748B),
                                        ),
                                      ),
                                    ),
                                  if (isSelected) ...[
                                    const SizedBox(width: 8),
                                    const Icon(
                                      LucideIcons.check,
                                      size: 16,
                                      color: Color(0xFF1F3A5F),
                                    ),
                                  ],
                                ],
                              ),
                              onTap: () {
                                onSelect(item);
                                Navigator.pop(ctx);
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFilterPill({
    required String label,
    required bool isSelected,
    required bool hasValue,
    required VoidCallback onTap,
    VoidCallback? onClear,
    Color couleur = const Color(0xFF1F3A5F),
    IconData? icone,
  }) {
    return FiltrePastille(
      label: label,
      icone: icone,
      couleur: couleur,
      actif: isSelected,
      onTap: onTap,
      deroulante: !hasValue,
      onEffacer: hasValue ? onClear : null,
    );
  }

  Widget _infoPill(
    String label,
    IconData icon, {
    bool isAlert = false,
    bool isAnomaly = false,
  }) {
    Color bg = const Color(0xFFF1F5F9);
    Color border = const Color(0xFFE2E8F0);
    Color fg = const Color(0xFF475569);
    Color iconColor = const Color(0xFF64748B);

    if (isAlert) {
      bg = const Color(0xFFFEF2F2);
      border = const Color(0xFFFECACA);
      fg = const Color(0xFFB91C1C);
      iconColor = const Color(0xFFDC2626);
    } else if (isAnomaly) {
      bg = const Color(0xFFF8FAFC);
      border = const Color(0xFFE2E8F0);
      fg = const Color(0xFF334155);
      iconColor = const Color(0xFF64748B);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: iconColor),
          const SizedBox(width: 3),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: fg,
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
              color: const Color(0xFF10B981).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              LucideIcons.checkCircle2,
              size: 30,
              color: Color(0xFF10B981),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Aucun ordre de réparation',
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Aucun OR ne correspond aux critères de recherche.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 12.5,
              color: const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () => _controller.resetFilters(),
            icon: const Icon(LucideIcons.rotateCcw, size: 14),
            label: const Text('Afficher tous les OR'),
          ),
        ],
      ),
    );
  }
}
