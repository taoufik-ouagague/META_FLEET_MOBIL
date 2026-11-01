import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../or/or_apercu_page.dart';
import '../pneumatiques/pneumatique_apercu_page.dart';
import '../vehicules/vehicule_apercu_page.dart';
import '../vidanges/vidange_apercu_page.dart';
import '../../widgets/ambient_background.dart';
import '../../widgets/filtre_pastille.dart';

import '../../widgets/page_entrance_animation.dart';
import '../../controllers/search_controller.dart' as ctrl;

class GlobalSearchPage extends StatefulWidget {
  const GlobalSearchPage({super.key});

  @override
  State<GlobalSearchPage> createState() => _GlobalSearchPageState();
}

class _GlobalSearchPageState extends State<GlobalSearchPage> {
  late final ctrl.SearchController _controller;
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  /// Section affichee sous le selecteur, et filtre de statut de chacune.
  String _section = 'VIDANGES';
  String _statutVidange = 'TOUS';
  String _statutOr = 'TOUS';
  String _statutPneu = 'TOUS';

  List<String> _statuts(List<Map<String, dynamic>> items) {
    final vus = <String>{'TOUS'};
    for (final item in items) {
      final s = (item['status'] ?? '').toString().trim();
      if (s.isNotEmpty) vus.add(s);
    }

    return vus.toList();
  }

  List<Map<String, dynamic>> _parStatut(
    List<Map<String, dynamic>> items,
    String statut,
  ) {
    if (statut == 'TOUS') return items;
    final cible = statut.toLowerCase();

    return items
        .where(
          (e) => (e['status'] ?? '').toString().trim().toLowerCase() == cible,
        )
        .toList();
  }

  /// Pastilles de statut d'une section.
  Widget _filtresStatut({
    required List<Map<String, dynamic>> items,
    required String selection,
    required Color couleur,
    required ValueChanged<String> onChange,
  }) {
    final statuts = _statuts(items);
    if (statuts.length <= 2) return const SizedBox.shrink();

    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: statuts.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final st = statuts[i];
          final n = _parStatut(items, st).length;

          return FiltrePastille(
            label: '$st ($n)',
            couleur: st == 'TOUS' ? const Color(0xFF1F3A5F) : couleur,
            actif: st.toLowerCase() == selection.toLowerCase(),
            onTap: () => onChange(st == selection ? 'TOUS' : st),
          );
        },
      ),
    );
  }

  /// Selecteur Vidanges / OR : une seule liste affichee a la fois.
  Widget _selecteurSection() {
    final sections = <(String, String, IconData, Color, int)>[
      (
        'VIDANGES',
        'Vidanges',
        LucideIcons.droplet,
        const Color(0xFF0891B2),
        _controller.vidanges.length,
      ),
      (
        'OR',
        'OR',
        LucideIcons.wrench,
        const Color(0xFFD97706),
        _controller.ordres.length,
      ),
      (
        'PNEUS',
        'Pneumatiques',
        LucideIcons.circleDot,
        const Color(0xFF0EA5E9),
        _controller.pneumatiques.length,
      ),
      (
        'DOCS',
        'Documents',
        LucideIcons.fileText,
        const Color(0xFF7C3AED),
        _controller.documents.length,
      ),
    ].where((e) => e.$5 > 0).toList();

    if (sections.isEmpty) return const SizedBox.shrink();

    // La section ouverte par defaut est la premiere qui a des resultats.
    if (!sections.any((e) => e.$1 == _section)) _section = sections.first.$1;

    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: sections.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final (cle, libelle, icone, couleur, n) = sections[i];

          return FiltrePastille(
            label: '$libelle ($n)',
            couleur: couleur,
            icone: icone,
            actif: _section == cle,
            onTap: () => setState(() => _section = cle),
          );
        },
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _controller = Get.put(ctrl.SearchController());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearch() {
    final q = _textController.text.trim();
    if (q.isNotEmpty) {
      _focusNode.unfocus();
      _controller.searchByMatricule(q);
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const AmbientBackground(),
          Column(
            children: [
              // Glassmorphism header bar with back + search input
              ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Container(
                    padding: EdgeInsets.fromLTRB(12, topPadding + 8, 12, 12),
                    decoration: const BoxDecoration(
                      // Meme degrade que la barre de l'accueil et des apercus.
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF1F3A5F), Color(0xFF2563EB)],
                      ),
                    ),
                    child: Row(
                      children: [
                        // Back button
                        GestureDetector(
                          onTap: () => Get.back(),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.35),
                                width: 1,
                              ),
                            ),
                            child: const Icon(
                              LucideIcons.arrowLeft,
                              size: 18,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Search input
                        Expanded(
                          child: Container(
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.95),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.6),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF0F172A,
                                  ).withValues(alpha: 0.04),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                const SizedBox(width: 12),
                                const Icon(
                                  LucideIcons.search,
                                  size: 18,
                                  color: Color(0xFF94A3B8),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: _textController,
                                    focusNode: _focusNode,
                                    textInputAction: TextInputAction.search,
                                    onSubmitted: (_) => _onSearch(),
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: const Color(0xFF0F172A),
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'Immatriculation, marque...',
                                      hintStyle: GoogleFonts.poppins(
                                        fontSize: 13,
                                        color: const Color(0xFF94A3B8),
                                      ),
                                      border: InputBorder.none,
                                      isDense: true,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            vertical: 10,
                                          ),
                                    ),
                                  ),
                                ),
                                // Search action button
                                GestureDetector(
                                  onTap: _onSearch,
                                  child: Container(
                                    margin: const EdgeInsets.only(right: 4),
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFF2563EB),
                                          Color(0xFF1D4ED8),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      LucideIcons.arrowRight,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Results
              Expanded(
                child: Obx(() {
                  if (_controller.isLoading.value) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF2563EB),
                      ),
                    );
                  }

                  if (!_controller.hasSearched.value) {
                    return PageEntranceAnimation(
                      key: const ValueKey('recherche-initiale'),
                      duration: const Duration(milliseconds: 400),
                      slideOffset: 18,
                      child: _buildEmptyState(
                        icon: LucideIcons.search,
                        title: 'Recherche par matricule',
                        subtitle:
                            'Entrez une immatriculation pour voir\ntous les éléments associés',
                      ),
                    );
                  }

                  if (_controller.totalResults == 0 &&
                      _controller.vehicule.value == null) {
                    return PageEntranceAnimation(
                      key: const ValueKey('recherche-vide'),
                      duration: const Duration(milliseconds: 400),
                      slideOffset: 18,
                      child: _buildEmptyState(
                        icon: LucideIcons.searchX,
                        title: 'Aucun résultat',
                        subtitle:
                            'Aucun élément trouvé pour\n"${_controller.searchQuery.value}"',
                      ),
                    );
                  }

                  // La cle change avec la requete : l'animation rejoue a
                  // chaque nouvelle recherche.
                  return PageEntranceAnimation(
                    key: ValueKey('res-${_controller.searchQuery.value}'),
                    duration: const Duration(milliseconds: 420),
                    slideOffset: 20,
                    child: _buildResults(),
                  );
                }),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF2563EB).withValues(alpha: 0.08),
            ),
            child: Icon(icon, size: 32, color: const Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: const Color(0xFF94A3B8),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResults() {
    final veh = _controller.vehicule.value;
    final aDesSections =
        _controller.vidanges.isNotEmpty ||
        _controller.ordres.isNotEmpty ||
        _controller.pneumatiques.isNotEmpty ||
        _controller.documents.isNotEmpty;

    // Selecteur et pastilles fixes, seule la liste defile : meme principe que
    // la liste des demandes d'OR.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Fiche vehicule et filtres restent visibles ; seule la liste defile.
        if (veh != null) ...[
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildVehiculeCard(veh),
          ),
          const SizedBox(height: 12),
        ],
        if (aDesSections) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _selecteurSection(),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _barreStatuts(),
          ),
          const SizedBox(height: 10),
        ],
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              ..._cartesSection(),
              if (_controller.operations.isNotEmpty) ...[
                const SizedBox(height: 12),
                _sectionTitle(
                  LucideIcons.fileText,
                  'Opérations Adm. (${_controller.operations.length})',
                  const Color(0xFF7C3AED),
                ),
                const SizedBox(height: 8),
                for (final op in _controller.operations)
                  _buildOperationCard(op),
              ],
              const SizedBox(height: 30),
            ],
          ),
        ),
      ],
    );
  }

  /// Pastilles de statut de la section ouverte (les documents n'en ont pas).
  Widget _barreStatuts() {
    switch (_section) {
      case 'VIDANGES':
        return _filtresStatut(
          items: _controller.vidanges,
          selection: _statutVidange,
          couleur: const Color(0xFF0891B2),
          onChange: (st) => setState(() => _statutVidange = st),
        );
      case 'OR':
        return _filtresStatut(
          items: _controller.ordres,
          selection: _statutOr,
          couleur: const Color(0xFFD97706),
          onChange: (st) => setState(() => _statutOr = st),
        );
      case 'PNEUS':
        return _filtresStatut(
          items: _controller.pneumatiques,
          selection: _statutPneu,
          couleur: const Color(0xFF0EA5E9),
          onChange: (st) => setState(() => _statutPneu = st),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  List<Widget> _cartesSection() {
    switch (_section) {
      case 'VIDANGES':
        return [
          for (final v in _parStatut(_controller.vidanges, _statutVidange))
            _buildVidangeCard(v),
        ];
      case 'OR':
        return [
          for (final o in _parStatut(_controller.ordres, _statutOr))
            _buildOrCard(o),
        ];
      case 'PNEUS':
        return [
          for (final p in _parStatut(_controller.pneumatiques, _statutPneu))
            _buildPneuCard(p),
        ];
      case 'DOCS':
        return [for (final d in _controller.documents) _buildDocumentCard(d)];
      default:
        return const [];
    }
  }

  Widget _sectionTitle(IconData icon, String text, Color color) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 15, color: color),
        ),
        const SizedBox(width: 10),
        Text(
          text,
          style: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }

  /// Ouvre la fiche du vehicule trouve, sur l'onglet demande.
  void _ouvrirVehicule({int onglet = 0}) {
    final veh = _controller.vehicule.value;
    if (veh == null) return;

    Get.to(() => VehiculeApercuPage(vehicule: veh, ongletInitial: onglet));
  }

  Widget _buildVehiculeCard(dynamic veh) {
    return GestureDetector(
      onTap: () => _ouvrirVehicule(),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Vehicle icon
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF2563EB).withValues(alpha: 0.12),
                            const Color(0xFF2563EB).withValues(alpha: 0.06),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        LucideIcons.truck,
                        size: 17,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            veh.displayName,
                            style: GoogleFonts.poppins(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0F172A),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 1),
                          Text(
                            veh.immatriculation ?? veh.immatriculationWw ?? '-',
                            style: GoogleFonts.poppins(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF2563EB),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Status badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: veh.isActif
                            ? const Color(0xFF059669).withValues(alpha: 0.10)
                            : const Color(0xFFDC2626).withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        veh.isActif ? 'Actif' : 'Inactif',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: veh.isActif
                              ? const Color(0xFF059669)
                              : const Color(0xFFDC2626),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Memes valeurs que la carte de la liste Vehicules.
                Wrap(
                  spacing: 5,
                  runSpacing: 4,
                  children: [
                    if ((veh.marqueLibelle ?? '').trim().isNotEmpty)
                      _infoChip(
                        LucideIcons.factory,
                        veh.marqueLibelle!,
                        const Color(0xFF2563EB),
                      ),
                    if ((veh.modeleLibelle ?? '').trim().isNotEmpty)
                      _infoChip(
                        LucideIcons.car,
                        veh.modeleLibelle!,
                        const Color(0xFF2563EB),
                      ),
                    if ((veh.codeInterne ?? '').trim().isNotEmpty)
                      _infoChip(
                        LucideIcons.hash,
                        veh.codeInterne!,
                        const Color(0xFF64748B),
                      ),
                    _infoChip(
                      LucideIcons.gauge,
                      veh.formattedKm,
                      const Color(0xFF2563EB),
                    ),
                    if ((veh.typeCarburantLibelle ?? '').trim().isNotEmpty)
                      _infoChip(
                        LucideIcons.fuel,
                        veh.typeCarburantLibelle!,
                        const Color(0xFFD97706),
                      ),
                    if (veh.annee != null)
                      _infoChip(
                        LucideIcons.calendar,
                        '${veh.annee}',
                        const Color(0xFF64748B),
                      ),
                    if ((veh.typeVehiculeLibelle ?? '').trim().isNotEmpty)
                      _infoChip(
                        LucideIcons.truck,
                        veh.typeVehiculeLibelle!,
                        const Color(0xFF0891B2),
                      ),
                    if (veh.categorieDisplay.isNotEmpty)
                      _infoChip(
                        LucideIcons.tag,
                        veh.categorieDisplay,
                        const Color(0xFF7C3AED),
                      ),
                    if (veh.puissanceFiscale != null)
                      _infoChip(
                        LucideIcons.zap,
                        '${veh.puissanceFiscale} CV',
                        const Color(0xFF64748B),
                      ),
                    if ((veh.couleur ?? '').trim().isNotEmpty)
                      _infoChip(
                        LucideIcons.droplet,
                        veh.couleur!,
                        const Color(0xFF64748B),
                      ),
                    if ((veh.statutVehiculeLibelle ?? '').trim().isNotEmpty)
                      _infoChip(
                        LucideIcons.activity,
                        veh.statutVehiculeLibelle!,
                        const Color(0xFF059669),
                      ),
                    if ((veh.organismeLibelle ?? '').trim().isNotEmpty)
                      _infoChip(
                        LucideIcons.building2,
                        veh.organismeLibelle!,
                        const Color(0xFF64748B),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  /// Gabarit commun aux resultats : numero, ligne vehicule, pastilles d'infos
  /// et statut — les memes champs que les listes Vidanges et OR.
  Widget _carteResultat({
    required IconData icone,
    required Color couleur,
    required String titre,
    required String sousTitre,
    required List<String> infos,
    required String statut,
    required Color couleurStatut,
    VoidCallback? onTap,
  }) {
    final pills = infos.where((e) => e.trim().isNotEmpty).toList();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
                        titre.isEmpty ? '—' : titre,
                        style: GoogleFonts.poppins(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (sousTitre.isNotEmpty) ...[
                        const SizedBox(height: 1),
                        Text(
                          sousTitre,
                          style: GoogleFonts.poppins(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF2563EB),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: couleurStatut.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    statut.isEmpty ? '—' : statut,
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: couleurStatut,
                    ),
                  ),
                ),
              ],
            ),
            if (pills.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 5,
                runSpacing: 5,
                children: [for (final info in pills) _pillInfo(info)],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _pillInfo(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 9.5,
          fontWeight: FontWeight.w500,
          color: const Color(0xFF475569),
        ),
      ),
    );
  }

  String _texte(dynamic v) {
    final s = (v ?? '').toString().trim();

    return (s.isEmpty || s == 'null') ? '' : s;
  }

  /// Immatriculation + marque/modele, comme la 1re ligne des cartes de liste.
  String _ligneVehicule(Map<String, dynamic> m) {
    final immat = _texte(
      m['vehiculeImmatriculation'] ??
          m['immatriculation'] ??
          m['immatriculationWw'],
    );
    final marque = _texte(m['vehiculeMarqueLibelle'] ?? m['marqueLibelle']);
    final modele = _texte(m['vehiculeModeleLibelle'] ?? m['modeleLibelle']);
    final vehicule = [marque, modele].where((e) => e.isNotEmpty).join(' · ');

    return [immat, vehicule].where((e) => e.isNotEmpty).join('  —  ');
  }

  Widget _buildVidangeCard(Map<String, dynamic> v) {
    final status = _texte(v['status']);
    final km = _texte(
      v['kilometrage'] ?? v['vehiculeKmActuel'] ?? v['kmActuel'],
    );
    final date = _texte(
      v['dateDebutPrevu'] ?? v['datePrevue'] ?? v['dateDebut'],
    );

    return _carteResultat(
      icone: LucideIcons.droplet,
      couleur: const Color(0xFF0891B2),
      titre: _texte(v['numero']),
      sousTitre: _ligneVehicule(v),
      statut: status,
      couleurStatut: _vidangeStatusColor(status),
      onTap: () => Get.to(() => VidangeApercuPage(vidange: v)),
      infos: [
        if (date.isNotEmpty) _formatDate(date),
        _texte(v['servicesPrcLibelle'] ?? v['serviceLibelle']),
        _texte(v['chauffeurNom'] ?? v['chauffeurNomComplet'] ?? v['chauffeur']),
        _texte(
          v['agenceLibelle'] ?? v['vehiculeAgenceLibelle'] ?? v['nomAgence'],
        ),
        if (km.isNotEmpty) 'Km $km',
        if (_texte(v['vehiculeKmActuel']).isNotEmpty)
          'Véh. ${_texte(v['vehiculeKmActuel'])} km',
        if (_texte(v['resteKmVidange']).isNotEmpty)
          'Reste ${_texte(v['resteKmVidange'])} km',
        if (_texte(v['nbReplanification']) != '' &&
            _texte(v['nbReplanification']) != '0')
          'Replanif. ${_texte(v['nbReplanification'])}',
        _texte(v['observation']),
      ],
    );
  }

  Widget _buildOrCard(Map<String, dynamic> o) {
    final status = _texte(o['status'] ?? o['statutLibelle']);
    final date = _texte(
      o['dateOrdreReparation'] ?? o['dateDemande'] ?? o['dateCreation'],
    );

    // Les natures d'anomalie arrivent soit en libelle, soit en liste d'objets.
    final natures = <String>[];
    final brut = o['naturesAnomalies'];
    if (brut is List) {
      for (final item in brut) {
        final lib = item is Map
            ? _texte(item['libelle'] ?? item['nom'] ?? item['natureAnomalie'])
            : _texte(item);
        if (lib.isNotEmpty && !natures.contains(lib)) natures.add(lib);
      }
    }
    if (natures.isEmpty) {
      final seule = _texte(o['natureAnomalieLibelle']);
      if (seule.isNotEmpty) natures.add(seule);
    }

    return _carteResultat(
      icone: LucideIcons.wrench,
      couleur: const Color(0xFFD97706),
      titre: _texte(o['numero'] ?? o['numeroOrdreReparation']),
      sousTitre: _ligneVehicule(o),
      statut: status,
      couleurStatut: status.toLowerCase().contains('actif')
          ? const Color(0xFF059669)
          : const Color(0xFF64748B),
      onTap: () => Get.to(() => OrApercuPage(ordre: o)),
      infos: [
        if (date.isNotEmpty) _formatDate(date),
        _texte(o['chauffeur'] ?? o['chauffeurNom'] ?? o['demandeurNomComplet']),
        _texte(o['typeInterventionLibelle'] ?? o['typeIntervention']),
        _texte(o['prestataireLibelle'] ?? o['fournisseurLibelle']),
        if (_texte(o['kilometrage']).isNotEmpty)
          'Km ${_texte(o['kilometrage'])}',
        _texte(o['numeroDemande']),
        ...natures,
      ],
    );
  }

  Widget _buildPneuCard(Map<String, dynamic> p) {
    final statut = _texte(p['status']);
    final km = _texte(p['kilometrageMontage']);
    final alerte = _texte(p['messageAlert'])
        .replaceAll(
          RegExp(r'[\u2190-\u2BFF\uFE0F\u{1F000}-\u{1FAFF}]', unicode: true),
          '',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    return _carteResultat(
      icone: LucideIcons.circleDot,
      couleur: const Color(0xFF0EA5E9),
      titre: _texte(p['pneuNumSerie'] ?? p['numSerie']),
      sousTitre: _ligneVehicule(p),
      statut: statut,
      couleurStatut: alerte.isEmpty
          ? const Color(0xFF059669)
          : const Color(0xFFDC2626),
      onTap: () => Get.to(() => PneumatiqueApercuPage(pneu: p)),
      infos: [
        _texte(p['positionLibelle']),
        _texte(p['marqueLibelle']),
        if (km.isNotEmpty) 'Montage $km km',
        if (_texte(p['dateMontage']).isNotEmpty)
          _formatDate(_texte(p['dateMontage'])),
        _texte(p['numeroOrMontage']),
        alerte,
      ],
    );
  }

  Widget _buildDocumentCard(Map<String, dynamic> d) {
    final fin = _texte(d['dateFinValidite']);
    final valide = d['valide'] == true;

    return _carteResultat(
      icone: LucideIcons.fileText,
      couleur: const Color(0xFF7C3AED),
      titre: _texte(d['docAdmPrcLibelle']),
      sousTitre: _ligneVehicule(d),
      statut: valide ? 'Valide' : 'Expiré',
      couleurStatut: valide ? const Color(0xFF059669) : const Color(0xFFDC2626),
      // Pas de fiche document : on ouvre le vehicule sur son onglet Documents.
      onTap: () => _ouvrirVehicule(onglet: 1),
      infos: [
        _texte(d['numeroDocument'] ?? d['reference']),
        _texte(d['organismeDocsPrcLibelle']),
        if (_texte(d['dateEmission']).isNotEmpty)
          'Émis ${_formatDate(_texte(d['dateEmission']))}',
        if (fin.isNotEmpty) 'Fin ${_formatDate(fin)}',
        _texte(d['resultatVisite']),
      ],
    );
  }

  Widget _buildOperationCard(Map<String, dynamic> op) {
    final status = _texte(op['status']);
    final date = _texte(
      op['datePlanifiee'] ?? op['dateDebut'] ?? op['dateOperation'],
    );

    return _carteResultat(
      icone: LucideIcons.fileText,
      couleur: const Color(0xFF7C3AED),
      titre: _texte(
        op['typeOperationLibelle'] ??
            op['typeLibelle'] ??
            op['docAdmPrcLibelle'],
      ),
      sousTitre: _ligneVehicule(op),
      statut: status,
      couleurStatut: const Color(0xFF64748B),
      infos: [
        if (date.isNotEmpty) _formatDate(date),
        _texte(op['numeroDocument'] ?? op['reference']),
      ],
    );
  }

  Color _vidangeStatusColor(String status) {
    final s = status.toLowerCase();
    if (s.contains('planifi')) return const Color(0xFF2563EB);
    if (s.contains('cours')) return const Color(0xFFD97706);
    if (s.contains('valid')) return const Color(0xFF059669);
    if (s.contains('retard') || s.contains('alerte')) {
      return const Color(0xFFDC2626);
    }
    return const Color(0xFF64748B);
  }

  String _formatDate(String raw) {
    if (raw == '-' || raw.isEmpty) return '-';
    try {
      final dt = DateTime.parse(raw);
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return raw.length > 10 ? raw.substring(0, 10) : raw;
    }
  }
}
