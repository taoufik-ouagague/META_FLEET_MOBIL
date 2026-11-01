import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../controllers/agenda_controller.dart';
import '../../widgets/apercu_kit.dart';
import '../../widgets/filtre_pastille.dart';

class AgendaPage extends StatefulWidget {
  const AgendaPage({super.key});

  @override
  State<AgendaPage> createState() => _AgendaPageState();
}

class _AgendaPageState extends State<AgendaPage> {
  late final AgendaController _controller;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  static const List<String> _monthsFr = [
    'Janvier',
    'Février',
    'Mars',
    'Avril',
    'Mai',
    'Juin',
    'Juillet',
    'Août',
    'Septembre',
    'Octobre',
    'Novembre',
    'Décembre',
  ];

  static const List<String> _daysOfWeekFr = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

  @override
  void initState() {
    super.initState();
    _controller = Get.isRegistered<AgendaController>()
        ? Get.find<AgendaController>()
        : Get.put(AgendaController());
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

  String _formatKm(double? km) {
    if (km == null || km == 0) return '—';
    return '${_formatCount(km.toInt())} km';
  }

  Color _getStatusColor(String status) {
    final s = status.trim().toLowerCase();
    switch (s) {
      case 'planifié':
        return const Color(0xFF2563EB); // Bleu
      case 'replanifié':
        return const Color(0xFFF59E0B); // Ambre / Orange
      case 'en cours':
      case 'en cours de planification':
        return const Color(0xFFD97706); // Orange foncé
      case 'validé':
      case 'clôturé':
      case 'termine':
      case 'terminé':
        return const Color(0xFF10B981); // Vert
      case 'actif':
        return const Color(0xFF0284C7); // Cyan
      case 'annulé':
      case 'rejeté':
        return const Color(0xFFEF4444); // Rouge
      default:
        return const Color(0xFF64748B); // Gris
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final appBarHeight = topPadding + kToolbarHeight;

    return Padding(
      padding: EdgeInsets.only(top: appBarHeight - 55),
      child: RefreshIndicator(
        displacement: 24,
        onRefresh: () => _controller.fetchAllAgendaData(showLoading: false),
        color: const Color(0xFF2563EB),
        // Titre, onglets, recherche et filtres fixes : seul le contenu defile,
        // comme sur la liste des demandes.
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 6),
              child: _buildTitleRow(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
              child: _buildTabSelector(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildSearchBar(),
                  const SizedBox(height: 6),
                  _buildFilterRow(),
                ],
              ),
            ),
            Expanded(
              child: CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // ── 4. Contenu selon le mode sélectionné ──
                  Obx(() {
                    if (_controller.isLoading.value) {
                      return const SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF2563EB),
                          ),
                        ),
                      );
                    }

                    switch (_controller.selectedTab.value) {
                      case AgendaTabMode.agenda:
                        return _buildAgendaSlivers();
                      case AgendaTabMode.aPlanifier:
                        return _buildAPlanifierSlivers();
                      case AgendaTabMode.conflits:
                        return _buildConflitsSlivers();
                    }
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Titre principal & Compteur ──
  Widget _buildTitleRow() {
    return Obx(() {
      final total = _controller.allEvents.length;
      final conflitsCount = _controller.conflitsSemaine.length;

      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Planification',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Agenda',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF2563EB),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Calendrier des vidanges & documents',
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF1F3A5F).withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF1F3A5F).withValues(alpha: 0.12),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  LucideIcons.calendar,
                  size: 13,
                  color: const Color(0xFF1F3A5F),
                ),
                const SizedBox(width: 5),
                Text(
                  '${_formatCount(total)} planif.',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1F3A5F),
                  ),
                ),
                if (conflitsCount > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEF4444),
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      );
    });
  }

  // ── Sélecteur d'onglets (Agenda / À planifier / Conflits) ──
  Widget _buildTabSelector() {
    return Obx(() {
      final tab = _controller.selectedTab.value;
      final eventsCount = _controller.allEvents.length;
      final aPlanifierCount =
          _controller.alertesVidange.length + _controller.docsEnAlerte.length;
      final conflitsCount = _controller.conflitsSemaine.length;

      return Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.80),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        ),
        child: Row(
          children: [
            _buildTabButton(
              title: 'Agenda',
              count: eventsCount,
              icon: LucideIcons.calendarDays,
              active: tab == AgendaTabMode.agenda,
              activeColor: const Color(0xFF2563EB),
              onTap: () => _controller.selectedTab.value = AgendaTabMode.agenda,
            ),
            const SizedBox(width: 4),
            _buildTabButton(
              title: 'À planifier',
              count: aPlanifierCount,
              icon: LucideIcons.alertTriangle,
              active: tab == AgendaTabMode.aPlanifier,
              activeColor: const Color(0xFFF59E0B),
              onTap: () =>
                  _controller.selectedTab.value = AgendaTabMode.aPlanifier,
            ),
            const SizedBox(width: 4),
            _buildTabButton(
              title: 'Conflits',
              count: conflitsCount,
              icon: LucideIcons.alertOctagon,
              active: tab == AgendaTabMode.conflits,
              activeColor: const Color(0xFFEF4444),
              isAlert: conflitsCount > 0,
              onTap: () =>
                  _controller.selectedTab.value = AgendaTabMode.conflits,
            ),
          ],
        ),
      );
    });
  }

  Widget _buildTabButton({
    required String title,
    required int count,
    required IconData icon,
    required bool active,
    required Color activeColor,
    bool isAlert = false,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active ? activeColor : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: activeColor.withValues(alpha: 0.28),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 13,
                color: active ? Colors.white : const Color(0xFF64748B),
              ),
              const SizedBox(width: 5),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                  color: active ? Colors.white : const Color(0xFF475569),
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: active
                        ? Colors.white.withValues(alpha: 0.25)
                        : (isAlert
                              ? const Color(0xFFEF4444).withValues(alpha: 0.12)
                              : const Color(0xFFE2E8F0)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$count',
                    style: GoogleFonts.poppins(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: active
                          ? Colors.white
                          : (isAlert
                                ? const Color(0xFFEF4444)
                                : const Color(0xFF64748B)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
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
              fontSize: 12.5,
              color: const Color(0xFF0F172A),
            ),
            decoration: InputDecoration(
              hintText:
                  'Rechercher par immatriculation, marque, prestataire...',
              hintStyle: GoogleFonts.poppins(
                fontSize: 11.5,
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
              suffixIcon: Obx(() {
                if (_controller.searchQuery.value.isNotEmpty) {
                  return IconButton(
                    icon: const Icon(
                      LucideIcons.x,
                      size: 14,
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

  // ── Ligne de filtres selon le mode ──
  Widget _buildFilterRow() {
    return Obx(() {
      final tab = _controller.selectedTab.value;

      if (tab == AgendaTabMode.agenda) {
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

              return FiltrePastille(
                label: '$s (${_formatCount(count)})',
                couleur: s.toUpperCase() == 'TOUS'
                    ? const Color(0xFF1F3A5F)
                    : apercuCouleurStatut(apercuLibelleStatut(s)),
                actif: s.toLowerCase() == selected.toLowerCase(),
                onTap: () => _controller.selectedStatusFilter.value = s,
              );
            },
          ),
        );
      }

      if (tab == AgendaTabMode.aPlanifier) {
        final source = _controller.planifierSource.value;

        return SizedBox(
          height: 32,
          child: ListView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            children: [
              FiltrePastille(
                label: 'Vidanges dues (${_controller.alertesVidange.length})',
                icone: LucideIcons.droplet,
                couleur: kApAmbre,
                actif: source == PlanifierSource.vidanges,
                onTap: () => _controller.planifierSource.value =
                    PlanifierSource.vidanges,
              ),
              const SizedBox(width: 6),
              FiltrePastille(
                label:
                    'Documents à renouveler (${_controller.docsEnAlerte.length})',
                icone: LucideIcons.fileText,
                couleur: kApViolet,
                actif: source == PlanifierSource.documents,
                onTap: () => _controller.planifierSource.value =
                    PlanifierSource.documents,
              ),
            ],
          ),
        );
      }

      // Conflits : simple compteur, rien a filtrer.
      return SizedBox(
        height: 32,
        child: Align(
          alignment: Alignment.centerLeft,
          child: FiltrePastille(
            label:
                '${_controller.conflitsSemaine.length} conflit(s) détecté(s)',
            icone: LucideIcons.alertOctagon,
            couleur: kApRouge,
          ),
        ),
      );
    });
  }

  // ==================== MODE 1 : AGENDA (CALENDRIER + ÉVÉNEMENTS) ====================
  Widget _buildAgendaSlivers() {
    final events = _controller.filteredEvents;

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 110),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          // Calendrier Mensuel
          _buildMonthlyCalendar(),
          const SizedBox(height: 14),

          // Légende des pastilles
          _buildLegend(),
          const SizedBox(height: 12),

          // En-tête des résultats
          _buildEventsHeader(events.length),
          const SizedBox(height: 8),

          // Liste des cartes d'événements
          if (events.isEmpty)
            _buildEmptyState('Aucune intervention planifiée trouvée')
          else
            for (int i = 0; i < events.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              _buildEventCard(events[i]),
            ],
        ]),
      ),
    );
  }

  Widget _buildMonthlyCalendar() {
    return Obx(() {
      final cursor = _controller.cursorMonth.value;
      final selected = _controller.selectedDate.value;
      final eventsMap = _controller.eventsByDateMap;

      final monthStr = '${_monthsFr[cursor.month - 1]} ${cursor.year}';

      // Calcul des cases du calendrier (façon planifiervidange/index.vue)
      final firstDow = DateTime(
        cursor.year,
        cursor.month,
        1,
      ).weekday; // 1 = Lun, 7 = Dim
      final offset = firstDow - 1;
      final daysInMonth = DateTime(cursor.year, cursor.month + 1, 0).day;
      final prevMonthDays = DateTime(cursor.year, cursor.month, 0).day;

      final List<Map<String, dynamic>> cells = [];
      // Jours mois précédent
      for (int i = 0; i < offset; i++) {
        final d = prevMonthDays - offset + 1 + i;
        final dt = DateTime(cursor.year, cursor.month - 1, d);
        cells.add({'day': d, 'other': true, 'date': dt});
      }
      // Jours mois courant
      for (int d = 1; d <= daysInMonth; d++) {
        final dt = DateTime(cursor.year, cursor.month, d);
        cells.add({'day': d, 'other': false, 'date': dt});
      }
      // Reste pour compléter la semaine
      final rem = (7 - cells.length % 7) % 7;
      for (int d = 1; d <= rem; d++) {
        final dt = DateTime(cursor.year, cursor.month + 1, d);
        cells.add({'day': d, 'other': true, 'date': dt});
      }

      final now = DateTime.now();

      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.1),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1F3A5F).withValues(alpha: 0.05),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            // Entête du mois : Navigation < Mois > + Aujourd'hui
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(LucideIcons.chevronLeft, size: 18),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        color: const Color(0xFF1F3A5F),
                        onPressed: () => _controller.changeMonth(-1),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          monthStr,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(LucideIcons.chevronRight, size: 18),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        color: const Color(0xFF1F3A5F),
                        onPressed: () => _controller.changeMonth(1),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (selected != null)
                      GestureDetector(
                        onTap: () => _controller.selectDay(null),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          margin: const EdgeInsets.only(right: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Tout le mois',
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF475569),
                            ),
                          ),
                        ),
                      ),
                    GestureDetector(
                      onTap: () {
                        _controller.cursorMonth.value = DateTime(
                          now.year,
                          now.month,
                          1,
                        );
                        _controller.selectDay(now);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF2563EB,
                          ).withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(
                              0xFF2563EB,
                            ).withValues(alpha: 0.20),
                          ),
                        ),
                        child: Text(
                          "Aujourd'hui",
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF2563EB),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Noms des jours (L M M J V S D)
            Row(
              children: [
                for (int i = 0; i < 7; i++)
                  Expanded(
                    child: Center(
                      child: Text(
                        _daysOfWeekFr[i],
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: i == 6
                              ? const Color(0xFFEF4444)
                              : const Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // Grille des jours (par lignes de 7 pour éliminer tout espace blanc parasite)
            for (int r = 0; r < cells.length; r += 7) ...[
              if (r > 0) const SizedBox(height: 4),
              Row(
                children: [
                  for (int c = 0; c < 7; c++)
                    Expanded(
                      child: (r + c < cells.length)
                          ? _buildDayCell(
                              cells[r + c],
                              now,
                              selected,
                              eventsMap,
                            )
                          : const SizedBox.shrink(),
                    ),
                ],
              ),
            ],
          ],
        ),
      );
    });
  }

  Widget _buildDayCell(
    Map<String, dynamic> cell,
    DateTime now,
    DateTime? selected,
    Map<String, List<AgendaEventItem>> eventsMap,
  ) {
    final day = cell['day'] as int;
    final isOther = cell['other'] as bool;
    final dt = cell['date'] as DateTime;
    final dtStr =
        "${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";

    final isToday =
        dt.year == now.year && dt.month == now.month && dt.day == now.day;
    final isSel =
        selected != null &&
        selected.year == dt.year &&
        selected.month == dt.month &&
        selected.day == dt.day;

    final dayEvents = eventsMap[dtStr] ?? [];
    final hasVidange = dayEvents.any((e) => e.type == AgendaEventType.vidange);
    final hasDoc = dayEvents.any((e) => e.type == AgendaEventType.document);
    final hasConflict = dayEvents.any((e) => e.isConflict);

    return GestureDetector(
      onTap: () => _controller.selectDay(dt),
      child: Container(
        height: 38,
        margin: const EdgeInsets.symmetric(horizontal: 1.5),
        decoration: BoxDecoration(
          color: isSel
              ? const Color(0xFF2563EB)
              : (isToday
                    ? const Color(0xFF2563EB).withValues(alpha: 0.08)
                    : Colors.transparent),
          borderRadius: BorderRadius.circular(8),
          border: isSel
              ? null
              : (isToday
                    ? Border.all(color: const Color(0xFF2563EB), width: 1.2)
                    : (hasConflict
                          ? Border.all(
                              color: const Color(
                                0xFFEF4444,
                              ).withValues(alpha: 0.6),
                              width: 1.2,
                            )
                          : null)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$day',
              style: GoogleFonts.poppins(
                fontSize: 11.5,
                fontWeight: (isSel || isToday)
                    ? FontWeight.w700
                    : FontWeight.w500,
                color: isSel
                    ? Colors.white
                    : (isOther
                          ? const Color(0xFFCBD5E1)
                          : (isToday
                                ? const Color(0xFF2563EB)
                                : const Color(0xFF1E293B))),
              ),
            ),
            if (dayEvents.isNotEmpty) ...[
              const SizedBox(height: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (hasVidange)
                    Container(
                      width: 4,
                      height: 4,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(
                        color: isSel ? Colors.white : const Color(0xFF2563EB),
                        shape: BoxShape.circle,
                      ),
                    ),
                  if (hasDoc)
                    Container(
                      width: 4,
                      height: 4,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(
                        color: isSel ? Colors.white : const Color(0xFF7C3AED),
                        shape: BoxShape.circle,
                      ),
                    ),
                  if (hasConflict)
                    Container(
                      width: 4,
                      height: 4,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(
                        color: isSel ? Colors.white : const Color(0xFFEF4444),
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _legendItem(const Color(0xFF2563EB), LucideIcons.droplet, 'Vidange'),
        const SizedBox(width: 14),
        _legendItem(const Color(0xFF7C3AED), LucideIcons.fileText, 'Document'),
        const SizedBox(width: 14),
        _legendItem(
          const Color(0xFFEF4444),
          LucideIcons.alertOctagon,
          'Conflit',
        ),
      ],
    );
  }

  Widget _legendItem(Color color, IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  Widget _buildEventsHeader(int count) {
    return Obx(() {
      final sel = _controller.selectedDate.value;
      final title = sel != null
          ? 'Interventions du ${sel.day.toString().padLeft(2, '0')}/${sel.month.toString().padLeft(2, '0')}/${sel.year}'
          : 'Toutes les interventions du mois';

      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count élément(s)',
              style: GoogleFonts.poppins(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF2563EB),
              ),
            ),
          ),
        ],
      );
    });
  }

  Widget _buildEventCard(AgendaEventItem item) {
    final statusColor = _getStatusColor(item.status);
    final isVidange = item.type == AgendaEventType.vidange;

    return GestureDetector(
      onTap: () => _showEventDetailSheet(item),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: item.isConflict
                ? const Color(0xFFEF4444).withValues(alpha: 0.50)
                : const Color(0xFFE2E8F0),
            width: item.isConflict ? 1.5 : 1.1,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1F3A5F).withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Ligne 1 : Type tag + Immatriculation + Statut ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: isVidange
                              ? const Color(0xFF2563EB).withValues(alpha: 0.10)
                              : const Color(0xFF7C3AED).withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isVidange
                                  ? LucideIcons.droplet
                                  : LucideIcons.fileText,
                              size: 11,
                              color: isVidange
                                  ? const Color(0xFF2563EB)
                                  : const Color(0xFF7C3AED),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isVidange
                                  ? 'Vidange'
                                  : (item.docLibelle ?? 'Document'),
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: isVidange
                                    ? const Color(0xFF2563EB)
                                    : const Color(0xFF7C3AED),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.immatriculation,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
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
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.30),
                    ),
                  ),
                  child: Text(
                    item.status,
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // ── Ligne 2 : Marque & Modèle + Date & Heure ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    [
                      item.marque,
                      item.modele,
                    ].where((s) => s.isNotEmpty).join(' '),
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF475569),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      LucideIcons.clock,
                      size: 11,
                      color: Color(0xFF64748B),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      item.timeStr != null
                          ? '${item.dateStr} à ${item.timeStr}'
                          : item.dateStr,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),

            // ── Ligne 3 : Métriques (Prestataire / Kilométrage) ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (item.prestataire != null && item.prestataire!.isNotEmpty)
                  Expanded(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          LucideIcons.wrench,
                          size: 11,
                          color: Color(0xFF94A3B8),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            item.prestataire!,
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: const Color(0xFF64748B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  const SizedBox.shrink(),
                if (item.kilometrage != null) ...[
                  const SizedBox(width: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        LucideIcons.gauge,
                        size: 11,
                        color: Color(0xFF94A3B8),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatKm(item.kilometrage),
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF334155),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),

            // ── Conflit détecté ? ──
            if (item.isConflict) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.20),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      LucideIcons.alertOctagon,
                      size: 12,
                      color: Color(0xFFEF4444),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Attention : Conflit de planification détecté pour ce véhicule dans la même semaine',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFDC2626),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ==================== MODE 2 : À PLANIFIER (ALERTES) ====================
  Widget _buildAPlanifierSlivers() {
    final source = _controller.planifierSource.value;

    if (source == PlanifierSource.vidanges) {
      final list = _controller.filteredAlertesVidange;
      return SliverPadding(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 110),
        sliver: SliverList(
          delegate: SliverChildListDelegate([
            _buildSectionInfoBanner(
              icon: LucideIcons.droplet,
              color: const Color(0xFFD97706),
              title: 'Véhicules à vidanger (${list.length})',
              subtitle:
                  'Véhicules ayant atteint ou dépassé leur seuil d\'entretien périodique.',
            ),
            const SizedBox(height: 10),
            if (list.isEmpty)
              _buildEmptyState('Aucun véhicule à vidanger')
            else
              for (int i = 0; i < list.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                _buildAlerteVidangeCard(list[i]),
              ],
          ]),
        ),
      );
    } else {
      final list = _controller.filteredDocsEnAlerte;
      return SliverPadding(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 110),
        sliver: SliverList(
          delegate: SliverChildListDelegate([
            _buildSectionInfoBanner(
              icon: LucideIcons.fileText,
              color: const Color(0xFF7C3AED),
              title: 'Documents à renouveler (${list.length})',
              subtitle:
                  'Documents véhicules expirés ou arrivant bientôt à échéance.',
            ),
            const SizedBox(height: 10),
            if (list.isEmpty)
              _buildEmptyState('Aucun document à renouveler')
            else
              for (int i = 0; i < list.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                _buildDocEnAlerteCard(list[i]),
              ],
          ]),
        ),
      );
    }
  }

  Widget _buildSectionInfoBanner({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlerteVidangeCard(Map<String, dynamic> a) {
    final immat = a['immatriculation']?.toString() ?? '—';
    final modele = a['modele']?.toString() ?? '';
    final kmActuel = (a['kmActuel'] is num)
        ? (a['kmActuel'] as num).toDouble()
        : null;
    final act = (a['act'] is num) ? (a['act'] as num).toDouble() : null;

    String retardText = '';
    Color retardColor = const Color(0xFF10B981);
    if (act != null) {
      if (act < 0) {
        retardText = 'Dépassé de ${_formatKm(act.abs())}';
        retardColor = const Color(0xFFEF4444);
      } else if (act == 0) {
        retardText = 'À faire maintenant';
        retardColor = const Color(0xFFF59E0B);
      } else {
        retardText = 'Dans ${_formatKm(act)}';
        retardColor = const Color(0xFF0284C7);
      }
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1F3A5F).withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  immat,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (retardText.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: retardColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: retardColor.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Text(
                    retardText,
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: retardColor,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  modele,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: const Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (kmActuel != null) ...[
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      LucideIcons.gauge,
                      size: 11,
                      color: Color(0xFF94A3B8),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatKm(kmActuel),
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF334155),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDocEnAlerteCard(Map<String, dynamic> d) {
    final immat = d['immatriculation']?.toString() ?? '—';
    final docNom =
        d['document']?.toString() ?? d['libelle']?.toString() ?? 'Document';
    final dateFin = d['dateFinValidite']?.toString();
    final joursExpire = (d['joursExpire'] is num)
        ? (d['joursExpire'] as num).toInt()
        : 0;

    String expLabel = '';
    Color expColor = const Color(0xFF10B981);
    if (joursExpire > 0) {
      expLabel = 'Expiré depuis $joursExpire j';
      expColor = const Color(0xFFEF4444);
    } else if (joursExpire == 0) {
      expLabel = "Expire aujourd'hui";
      expColor = const Color(0xFFF59E0B);
    } else {
      expLabel = 'Expire dans ${joursExpire.abs()} j';
      expColor = const Color(0xFF0284C7);
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1F3A5F).withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  immat,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: expColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: expColor.withValues(alpha: 0.25)),
                ),
                child: Text(
                  expLabel,
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: expColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  docNom,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF7C3AED),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (dateFin != null) ...[
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      LucideIcons.calendar,
                      size: 11,
                      color: Color(0xFF94A3B8),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      dateFin.length >= 10 ? dateFin.substring(0, 10) : dateFin,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ==================== MODE 3 : CONFLITS DE PLANIFICATION ====================
  Widget _buildConflitsSlivers() {
    final conflits = _controller.conflitsSemaine;

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 110),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          _buildSectionInfoBanner(
            icon: LucideIcons.alertOctagon,
            color: const Color(0xFFEF4444),
            title: '${conflits.length} Conflit(s) de planification',
            subtitle:
                'Même véhicule prévu pour au moins deux actions dans la même semaine de travail (Lundi → Samedi).',
          ),
          const SizedBox(height: 12),
          if (conflits.isEmpty)
            _buildEmptyState('Aucun conflit de planification détecté 🎉')
          else
            for (int i = 0; i < conflits.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              _buildConflitCard(conflits[i]),
            ],
        ]),
      ),
    );
  }

  Widget _buildConflitCard(ConflitSemaineItem item) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFEF4444).withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFEF4444).withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    LucideIcons.truck,
                    size: 16,
                    color: Color(0xFF1F3A5F),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    item.immatriculation,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${item.actions.length} interventions',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFEF4444),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Semaine du lundi ${item.lundi}',
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 8),
          Column(
            children: [
              for (final a in item.actions)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Icon(
                        a.type == 'vidange'
                            ? LucideIcons.droplet
                            : LucideIcons.fileText,
                        size: 13,
                        color: a.type == 'vidange'
                            ? const Color(0xFF2563EB)
                            : const Color(0xFF7C3AED),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          a.libelle,
                          style: GoogleFonts.poppins(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF334155),
                          ),
                        ),
                      ),
                      Text(
                        'le ${a.date}',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Détail d'un événement (Bottom Sheet) ──
  void _showEventDetailSheet(AgendaEventItem item) {
    final statusColor = _getStatusColor(item.status);
    final isVidange = item.type == AgendaEventType.vidange;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 34),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Poignée
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Entête
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color:
                              (isVidange
                                      ? const Color(0xFF2563EB)
                                      : const Color(0xFF7C3AED))
                                  .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          isVidange
                              ? LucideIcons.droplet
                              : LucideIcons.fileText,
                          color: isVidange
                              ? const Color(0xFF2563EB)
                              : const Color(0xFF7C3AED),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.immatriculation,
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            isVidange
                                ? 'Intervention Vidange'
                                : (item.docLibelle ??
                                      'Opération Administrative'),
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: statusColor.withValues(alpha: 0.30),
                      ),
                    ),
                    child: Text(
                      item.status,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              const SizedBox(height: 14),

              // Détails
              _detailRow(
                LucideIcons.car,
                'Véhicule',
                [item.marque, item.modele].where((s) => s.isNotEmpty).join(' '),
              ),
              _detailRow(
                LucideIcons.calendar,
                'Date prévue',
                item.timeStr != null
                    ? '${item.dateStr} à ${item.timeStr}'
                    : item.dateStr,
              ),
              if (item.prestataire != null && item.prestataire!.isNotEmpty)
                _detailRow(
                  LucideIcons.wrench,
                  'Prestataire',
                  item.prestataire!,
                ),
              if (item.kilometrage != null)
                _detailRow(
                  LucideIcons.gauge,
                  'Kilométrage',
                  _formatKm(item.kilometrage),
                ),
              if (item.docNumero != null && item.docNumero!.isNotEmpty)
                _detailRow(LucideIcons.hash, 'N° Document', item.docNumero!),
              if (item.observation != null && item.observation!.isNotEmpty)
                _detailRow(
                  LucideIcons.fileText,
                  'Observation',
                  item.observation!,
                ),

              if (item.isConflict) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        LucideIcons.alertOctagon,
                        size: 16,
                        color: Color(0xFFEF4444),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Conflit de planification détecté pour ce véhicule dans la même semaine',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFDC2626),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1F3A5F),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(
                    'Fermer',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF64748B)),
          const SizedBox(width: 8),
          SizedBox(
            width: 95,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 11.5,
                color: const Color(0xFF64748B),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── État vide ──
  Widget _buildEmptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 36),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB).withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                LucideIcons.calendarX,
                size: 32,
                color: Color(0xFF2563EB),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: GoogleFonts.poppins(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF64748B),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
