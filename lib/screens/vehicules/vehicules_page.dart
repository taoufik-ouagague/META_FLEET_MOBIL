import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../controllers/vehicule_controller.dart';
import '../../models/vehicule_model.dart';
import '../../widgets/filtre_pastille.dart';
import 'vehicule_apercu_page.dart';

import '../../widgets/apercu_kit.dart';

class VehiculesPage extends StatefulWidget {
  const VehiculesPage({super.key});

  @override
  State<VehiculesPage> createState() => _VehiculesPageState();
}

class _VehiculesPageState extends State<VehiculesPage> {
  late final VehiculeController _vehiculeController;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _vehiculeController = Get.isRegistered<VehiculeController>()
        ? Get.find<VehiculeController>()
        : Get.put(VehiculeController());
  }

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
        onRefresh: () =>
            _vehiculeController.fetchActiveVehicules(showLoading: false),
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
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildSearchBar(),
                  const SizedBox(height: 8),
                  _buildFilterBar(context),
                ],
              ),
            ),
            Expanded(
              child: CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // ── 3. Liste virtualisée des Véhicules Actifs ──
                  Obx(() {
                    if (_vehiculeController.isLoading.value &&
                        _vehiculeController.vehicules.isEmpty) {
                      return const SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }

                    final list = _vehiculeController.filteredVehicules;

                    if (list.isEmpty) {
                      return SliverPadding(
                        padding: const EdgeInsets.fromLTRB(18, 20, 18, 110),
                        sliver: SliverToBoxAdapter(
                          child: _buildEmptyVehiculesView(),
                        ),
                      );
                    }

                    return SliverPadding(
                      padding: const EdgeInsets.fromLTRB(18, 10, 18, 110),
                      sliver: SliverList.separated(
                        itemCount: list.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          return _buildVehiculeCard(list[index]);
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
                'Parc Automobile',
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
                'Véhicules actuellement actifs en service',
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
          final count = _vehiculeController.totalActiveCount;
          final hasFilter = _vehiculeController.hasActiveFilter;
          final filteredCount = _vehiculeController.filteredVehicules.length;
          final label = hasFilter
              ? '$filteredCount / $count actifs'
              : '$count actif${count > 1 ? 's' : ''}';

          return GestureDetector(
            onTap: hasFilter
                ? () => _vehiculeController.resetAllFilters()
                : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF047857),
                    ),
                  ),
                  if (hasFilter) ...[
                    const SizedBox(width: 4),
                    const Icon(
                      LucideIcons.x,
                      size: 11,
                      color: Color(0xFF047857),
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
            onChanged: _vehiculeController.updateSearchQuery,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: const Color(0xFF0F172A),
            ),
            decoration: InputDecoration(
              hintText: 'Rechercher immatriculation, marque, modèle...',
              hintStyle: GoogleFonts.poppins(
                fontSize: 12,
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
                if (_vehiculeController.searchQuery.value.isEmpty) {
                  return const SizedBox.shrink();
                }
                return IconButton(
                  icon: const Icon(
                    Icons.clear,
                    size: 16,
                    color: Color(0xFF64748B),
                  ),
                  onPressed: () {
                    _searchController.clear();
                    _vehiculeController.updateSearchQuery('');
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

  Widget _buildVehiculeCard(VehiculeModel v) {
    final actif = v.isActif;
    final statusBg = actif ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2);
    final statusBorder = actif
        ? const Color(0xFFA7F3D0)
        : const Color(0xFFFECACA);
    final statusFg = actif ? const Color(0xFF047857) : const Color(0xFFB91C1C);
    final statusDot = actif ? const Color(0xFF10B981) : const Color(0xFFEF4444);

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
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => Get.to(() => VehiculeApercuPage(vehicule: v)),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
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
                    // En-tête : Plaque + Code interne + Badge Statut réel
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
                                v.immatriculation ?? 'SANS IMMAT',
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
                        if (v.codeInterne != null &&
                            v.codeInterne!.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(
                                color: const Color(0xFFBFDBFE),
                              ),
                            ),
                            child: Text(
                              v.codeInterne!,
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF1E40AF),
                              ),
                            ),
                          ),
                        ],
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: statusBg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: statusBorder),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(
                                  color: statusDot,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                v.statusLabel,
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: statusFg,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Nom du véhicule (Marque & Modèle) + chevron
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            v.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        const Icon(
                          LucideIcons.chevronRight,
                          size: 15,
                          color: Color(0xFF94A3B8),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),

                    // Valeurs détaillées, façon carte vidange / OR
                    Wrap(
                      spacing: 5,
                      runSpacing: 4,
                      children: [
                        _vehiculeMetricPill(
                          icon: LucideIcons.gauge,
                          label: v.formattedKm,
                          color: const Color(0xFF2563EB),
                        ),
                        if (v.typeCarburantLibelle != null &&
                            v.typeCarburantLibelle!.isNotEmpty)
                          _vehiculeMetricPill(
                            icon: LucideIcons.fuel,
                            label: v.typeCarburantLibelle!,
                            color: const Color(0xFFD97706),
                          ),
                        if (v.annee != null)
                          _vehiculeMetricPill(
                            icon: LucideIcons.calendar,
                            label: '${v.annee}',
                            color: const Color(0xFF64748B),
                          ),
                        if (v.typeVehiculeLibelle != null &&
                            v.typeVehiculeLibelle!.isNotEmpty)
                          _vehiculeMetricPill(
                            icon: LucideIcons.truck,
                            label: v.typeVehiculeLibelle!,
                            color: const Color(0xFF0891B2),
                          ),
                        _vehiculeMetricPill(
                          icon: LucideIcons.tag,
                          label: v.categorieDisplay,
                          color: const Color(0xFF7C3AED),
                        ),
                        if (v.puissanceFiscale != null)
                          _vehiculeMetricPill(
                            icon: LucideIcons.hash,
                            label: '${v.puissanceFiscale} CV',
                            color: const Color(0xFF64748B),
                          ),
                        if (v.couleur != null && v.couleur!.isNotEmpty)
                          _vehiculeMetricPill(
                            icon: LucideIcons.droplet,
                            label: v.couleur!,
                            color: const Color(0xFF64748B),
                          ),
                        if (v.organismeLibelle != null &&
                            v.organismeLibelle!.isNotEmpty)
                          _vehiculeMetricPill(
                            icon: LucideIcons.building2,
                            label: v.organismeLibelle!,
                            color: const Color(0xFF64748B),
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

  Widget _vehiculeMetricPill({
    required IconData icon,
    required String label,
    required Color color,
  }) {
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
            label,
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

  Widget _buildFilterBar(BuildContext context) {
    return Obx(() {
      final hasFilters = _vehiculeController.hasActiveFilter;
      final selectedMarque = _vehiculeController.selectedMarque.value;
      final selectedModele = _vehiculeController.selectedModele.value;
      final selectedCategorie = _vehiculeController.selectedCategorie.value;

      final marques = _vehiculeController.availableMarques;
      final modeles = _vehiculeController.availableModeles;
      final categories = _vehiculeController.availableCategories;

      return SizedBox(
        height: 34,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            // 1. Bouton TOUS
            _buildFilterPill(
              label: 'TOUS',
              isSelected: !hasFilters,
              hasValue: false,
              onTap: () => _vehiculeController.resetAllFilters(),
            ),
            const SizedBox(width: 8),

            // 2. Select MARQUE
            _buildFilterPill(
              label: selectedMarque.isEmpty ? 'Marque' : selectedMarque,
              isSelected: selectedMarque.isNotEmpty,
              hasValue: selectedMarque.isNotEmpty,
              onTap: () => _openFilterSelector(
                context: context,
                title: 'Filtrer par Marque',
                items: marques,
                selectedItem: selectedMarque,
                onSelect: (val) => _vehiculeController.updateMarqueFilter(val),
                countProvider: (m) => _vehiculeController.countForMarque(m),
              ),
              couleur: kApBleu,
              icone: LucideIcons.tag,
              onClear: selectedMarque.isNotEmpty
                  ? () => _vehiculeController.updateMarqueFilter(selectedMarque)
                  : null,
            ),
            const SizedBox(width: 8),

            // 3. Select MODÈLE
            _buildFilterPill(
              label: selectedModele.isEmpty ? 'Modèle' : selectedModele,
              isSelected: selectedModele.isNotEmpty,
              hasValue: selectedModele.isNotEmpty,
              onTap: () => _openFilterSelector(
                context: context,
                title: selectedMarque.isNotEmpty
                    ? 'Modèles $selectedMarque'
                    : 'Filtrer par Modèle',
                items: modeles,
                selectedItem: selectedModele,
                onSelect: (val) => _vehiculeController.updateModeleFilter(val),
                countProvider: (mod) => _vehiculeController.countForModele(mod),
              ),
              couleur: kApViolet,
              icone: LucideIcons.car,
              onClear: selectedModele.isNotEmpty
                  ? () => _vehiculeController.updateModeleFilter(selectedModele)
                  : null,
            ),
            const SizedBox(width: 8),

            // 4. Select CATÉGORIE VÉHICULE
            _buildFilterPill(
              label: selectedCategorie.isEmpty
                  ? 'Catégorie'
                  : selectedCategorie,
              isSelected: selectedCategorie.isNotEmpty,
              hasValue: selectedCategorie.isNotEmpty,
              onTap: () => _openFilterSelector(
                context: context,
                title: 'Catégorie de véhicule',
                items: categories,
                selectedItem: selectedCategorie,
                onSelect: (val) =>
                    _vehiculeController.updateCategorieFilter(val),
                countProvider: (cat) =>
                    _vehiculeController.countForCategorie(cat),
                enableSearch: false,
              ),
              couleur: kApCyan,
              icone: LucideIcons.layers,
              onClear: selectedCategorie.isNotEmpty
                  ? () => _vehiculeController.updateCategorieFilter(
                      selectedCategorie,
                    )
                  : null,
            ),
          ],
        ),
      );
    });
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
      deroulante: !hasValue && label != 'TOUS',
      onEffacer: hasValue ? onClear : null,
    );
  }

  void _openFilterSelector({
    required BuildContext context,
    required String title,
    required List<String> items,
    required String selectedItem,
    required Function(String) onSelect,
    int Function(String)? countProvider,
    bool enableSearch = true,
  }) {
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
                        if (selectedItem.isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              onSelect('');
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
                          return it.toLowerCase().contains(
                            query.trim().toLowerCase(),
                          );
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
                                item.toLowerCase() ==
                                selectedItem.toLowerCase();
                            final count = countProvider != null
                                ? countProvider(item)
                                : null;

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 2,
                              ),
                              title: Text(
                                item,
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

  Widget _buildEmptyVehiculesView() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withValues(alpha: 0.70),
        border: Border.all(color: Colors.white.withValues(alpha: 0.90)),
      ),
      child: Column(
        children: [
          const Icon(LucideIcons.searchX, size: 36, color: Color(0xFF94A3B8)),
          const SizedBox(height: 12),
          Text(
            'Aucun véhicule actif trouvé',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Essayez de modifier votre terme de recherche ou le filtre de catégorie.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}
