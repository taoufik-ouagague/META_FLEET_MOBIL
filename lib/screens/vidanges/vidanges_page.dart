import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../controllers/vidange_controller.dart';
import '../../widgets/couleur_ligne.dart';
import '../../widgets/filtre_pastille.dart';
import '../../widgets/apercu_kit.dart';
import 'vidange_apercu_page.dart';

class VidangesPage extends StatefulWidget {
  const VidangesPage({super.key});

  @override
  State<VidangesPage> createState() => _VidangesPageState();
}

class _VidangesPageState extends State<VidangesPage> {
  late final VidangeController _controller;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller = Get.isRegistered<VidangeController>()
        ? Get.find<VidangeController>()
        : Get.put(VidangeController());
    // Réinitialise par défaut sur 'TOUS' pour afficher la liste complète des 416 vidanges
    _controller.selectedStatusFilter.value = 'TOUS';
    _controller.searchQuery.value = '';
    _controller.applyFilters();
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
      child: RefreshIndicator(
        displacement: 24,
        onRefresh: () => _controller.fetchVidanges(showLoading: false),
        color: const Color(0xFF7C3AED),
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
                    _buildFilterPills(),
                    Obx(() {
                      if (_controller.isLoading.value) {
                        return const Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: LinearProgressIndicator(
                            minHeight: 2.5,
                            backgroundColor: Color(0xFFE2E8F0),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Color(0xFF7C3AED),
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
                  // ── 3. Liste virtualisée des Vidanges (416 éléments) ──
                  Obx(() {
                    final list = _controller.filteredVidanges;
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
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          return _buildVidangeCard(list[index]);
                        },
                      ),
                    );
                  }),
                ],
              ),
            ),
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
                'Vidanges & Entretiens',
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
                'Planification et suivi du parc',
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
          final count = _controller.filteredVidanges.length;
          final total = _controller.totalCount;
          final isFiltered =
              _controller.selectedStatusFilter.value != 'TOUS' ||
              _controller.searchQuery.value.isNotEmpty;
          final label = _controller.searchQuery.value.isNotEmpty
              ? '${_formatCount(count)} / ${_formatCount(total)}'
              : '${_formatCount(total)} éléments';

          return GestureDetector(
            onTap: isFiltered ? () => _controller.resetFilters() : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF7C3AED).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.15),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF7C3AED),
                    ),
                  ),
                  if (isFiltered) ...[
                    const SizedBox(width: 4),
                    const Icon(
                      LucideIcons.x,
                      size: 11,
                      color: Color(0xFF7C3AED),
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
            final count = _controller.countForStatus(s);
            final isActive = s.toLowerCase() == selected.toLowerCase();
            return FiltrePastille(
              label: '$s (${_formatCount(count)})',
              couleur: s == 'TOUS'
                  ? const Color(0xFF1F3A5F)
                  : apercuCouleurStatut(apercuLibelleStatut(s)),
              actif: isActive,
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
            onChanged: (val) => _controller.updateSearchQuery(val),
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: const Color(0xFF0F172A),
            ),
            decoration: InputDecoration(
              hintText: 'Rechercher une vidange, immatriculation…',
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
                  color: Color(0xFF7C3AED),
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

  Widget _buildVidangeCard(Map<String, dynamic> vidange) {
    final numero = vidange['numero']?.toString() ?? '';
    final immat =
        vidange['vehiculeImmatriculation']?.toString() ??
        vidange['immatriculation']?.toString() ??
        '—';
    final marque =
        vidange['vehiculeMarqueLibelle']?.toString() ??
        vidange['marqueLibelle']?.toString() ??
        '';
    final modele =
        vidange['vehiculeModeleLibelle']?.toString() ??
        vidange['modeleLibelle']?.toString() ??
        '';
    final displayName = [marque, modele].where((s) => s.isNotEmpty).join(' · ');

    final service =
        vidange['servicesPrcLibelle']?.toString() ??
        vidange['serviceLibelle']?.toString() ??
        vidange['serviceNom']?.toString() ??
        vidange['typeVidangeLibelle']?.toString() ??
        '';

    final chauffeur =
        vidange['chauffeurNom']?.toString() ??
        vidange['chauffeurNomComplet']?.toString() ??
        vidange['chaffeurNomComplet']?.toString() ??
        vidange['chauffeur']?.toString() ??
        '';

    final agence =
        vidange['agenceLibelle']?.toString() ??
        vidange['vehiculeAgenceLibelle']?.toString() ??
        vidange['nomAgence']?.toString() ??
        vidange['agence']?.toString() ??
        '';

    final datePrevue = vidange['datePrevue']?.toString() ?? '';
    final dateRealisation = vidange['dateRealisation']?.toString() ?? '';
    final dateDebut = vidange['dateDebut']?.toString() ?? '';
    final dateFin = vidange['dateFin']?.toString() ?? '';
    final dateCreation = vidange['dateCreation']?.toString() ?? '';

    final status = vidange['status']?.toString() ?? '';
    final kmActuel = vidange['vehiculeKmActuel'] ?? vidange['kmActuel'];
    final kmVidange = vidange['kilometrage'] ?? vidange['kmPrevue'];
    final resteKm = vidange['resteKmVidange'];

    // Calcul de l'écart km
    num? ecartKm;
    if (vidange['ecartKm'] != null && vidange['ecartKm'] is num) {
      ecartKm = vidange['ecartKm'] as num;
    } else if (kmActuel is num && kmVidange is num) {
      ecartKm = kmActuel - kmVidange;
    }

    // Status colors
    Color statusBg, statusFg;
    final statusLower = status.toLowerCase();
    if (statusLower.contains('réalisée') ||
        statusLower.contains('realisee') ||
        statusLower.contains('clôtur') ||
        statusLower.contains('clos')) {
      statusBg = const Color(0xFF10B981).withValues(alpha: 0.12);
      statusFg = const Color(0xFF059669);
    } else if (statusLower.contains('retard') ||
        statusLower.contains('annul') ||
        statusLower.contains('rejet')) {
      statusBg = const Color(0xFFEF4444).withValues(alpha: 0.12);
      statusFg = const Color(0xFFDC2626);
    } else if (statusLower.contains('cours')) {
      statusBg = const Color(0xFFF59E0B).withValues(alpha: 0.12);
      statusFg = const Color(0xFFD97706);
    } else {
      statusBg = const Color(0xFF7C3AED).withValues(alpha: 0.12);
      statusFg = const Color(0xFF7C3AED);
    }

    // Km progress string
    String kmInfo = '';
    Color kmColor = const Color(0xFF64748B);
    if (resteKm != null && resteKm is num) {
      if (resteKm <= 0) {
        kmInfo = 'Dépassé de ${(-resteKm).toInt()} km';
        kmColor = const Color(0xFFDC2626);
      } else if (resteKm < 3000) {
        kmInfo = 'Reste ${resteKm.toInt()} km';
        kmColor = const Color(0xFFD97706);
      } else {
        kmInfo = 'Reste ${resteKm.toInt()} km';
        kmColor = const Color(0xFF059669);
      }
    } else if (ecartKm != null) {
      if (ecartKm > 0) {
        kmInfo = '+${_formatKm(ecartKm)} km';
        kmColor = const Color(0xFFD97706);
      } else {
        kmInfo = '${_formatKm(ecartKm)} km';
        kmColor = const Color(0xFF2563EB);
      }
    }

    return Container(
      decoration: decorationLigne(couleurLigneVidange(vidange)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: avecBandeLigne(
          couleurLigneVidange(vidange),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: InkWell(
              onTap: () => Get.to(() => VidangeApercuPage(vidange: vidange)),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Ligne 1 : Numéro / Immat + Statut ──
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF7C3AED,
                                ).withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: const Color(
                                    0xFF7C3AED,
                                  ).withValues(alpha: 0.22),
                                ),
                              ),
                              child: const Icon(
                                LucideIcons.droplet,
                                size: 18,
                                color: Color(0xFF7C3AED),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      immat,
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF0F172A),
                                      ),
                                    ),
                                    if (numero.isNotEmpty) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 1.5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(
                                            0xFF1F3A5F,
                                          ).withValues(alpha: 0.08),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Text(
                                          numero,
                                          style: GoogleFonts.poppins(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF1F3A5F),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                if (displayName.isNotEmpty)
                                  Text(
                                    displayName.length > 26
                                        ? '${displayName.substring(0, 26)}…'
                                        : displayName,
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      color: const Color(0xFF64748B),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // ── Ligne 2 : Badges info (Service, Km, Agence, Chauffeur) ──
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (service.isNotEmpty)
                          _infoPill(service, LucideIcons.wrench),
                        if (kmInfo.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: kmColor.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: kmColor.withValues(alpha: 0.30),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  LucideIcons.gauge,
                                  size: 11,
                                  color: kmColor,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  kmInfo,
                                  style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: kmColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (kmActuel != null)
                          _infoPill(
                            '${_formatKm(kmActuel)} km actuels',
                            LucideIcons.milestone,
                          ),
                        if (chauffeur.isNotEmpty)
                          _infoPill(chauffeur, LucideIcons.user),
                        if (agence.isNotEmpty)
                          _infoPill(agence, LucideIcons.mapPin),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // ── Ligne 3 : Dates et statut ──
                    Wrap(
                      spacing: 12,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (datePrevue.isNotEmpty)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                LucideIcons.calendar,
                                size: 12,
                                color: Color(0xFF94A3B8),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                'Prévue : ${_formatDate(datePrevue)}',
                                style: GoogleFonts.poppins(
                                  fontSize: 10.5,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          )
                        else if (dateDebut.isNotEmpty)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                LucideIcons.calendar,
                                size: 12,
                                color: Color(0xFF94A3B8),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                'Début : ${_formatDate(dateDebut)}',
                                style: GoogleFonts.poppins(
                                  fontSize: 10.5,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          )
                        else if (dateCreation.isNotEmpty)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                LucideIcons.calendar,
                                size: 12,
                                color: Color(0xFF94A3B8),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                'Création : ${_formatDate(dateCreation)}',
                                style: GoogleFonts.poppins(
                                  fontSize: 10.5,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        if (dateRealisation.isNotEmpty)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                LucideIcons.calendarCheck,
                                size: 12,
                                color: Color(0xFF059669),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                'Réalisée : ${_formatDate(dateRealisation)}',
                                style: GoogleFonts.poppins(
                                  fontSize: 10.5,
                                  color: const Color(0xFF059669),
                                ),
                              ),
                            ],
                          )
                        else if (dateFin.isNotEmpty)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                LucideIcons.calendarCheck,
                                size: 12,
                                color: Color(0xFF059669),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                'Fin : ${_formatDate(dateFin)}',
                                style: GoogleFonts.poppins(
                                  fontSize: 10.5,
                                  color: const Color(0xFF059669),
                                ),
                              ),
                            ],
                          ),
                        if (status.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: statusBg,
                              borderRadius: BorderRadius.circular(8),
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

  String _formatDate(String raw) {
    if (raw.length >= 10) return raw.substring(0, 10);
    return raw;
  }

  String _formatKm(dynamic km) {
    if (km == null) return '—';
    final intKm = (km is num) ? km.toInt() : int.tryParse(km.toString()) ?? 0;
    final parts = <String>[];
    String str = intKm.toString();
    while (str.length > 3) {
      parts.insert(0, str.substring(str.length - 3));
      str = str.substring(0, str.length - 3);
    }
    parts.insert(0, str);
    return parts.join(' ');
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
            'Aucune vidange trouvée',
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Aucune vidange ne correspond aux critères de recherche.',
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
            label: const Text('Afficher toutes les vidanges'),
          ),
        ],
      ),
    );
  }
}
