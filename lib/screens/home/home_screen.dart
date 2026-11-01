import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/notification_controller.dart';
import '../../widgets/ambient_background.dart';
import '../agenda/agenda_page.dart';
import '../dashboard/dashboard_page.dart';
import '../demandes/demandes_or_liste_page.dart';
import '../../controllers/chat_controller.dart';
import '../chat/chat_page.dart';
import '../journal/journal_page.dart';
import '../or/or_page.dart';
import '../pneumatiques/pneumatiques_page.dart';
import '../profile/profile_page.dart';
import '../notifications/notifications_page.dart';
import '../search/global_search_page.dart';
import '../vehicules/vehicules_page.dart';
import '../vidanges/vidanges_page.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _cleScaffold = GlobalKey<ScaffoldState>();
  final TextEditingController _rechercheMenu = TextEditingController();
  String _filtreMenu = '';
  int _index = 0;
  final AuthController _authController = Get.find<AuthController>();

  static const LinearGradient _brandGradient = LinearGradient(
    colors: [Color(0xFF1F3A5F), Color(0xFF2563EB)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _authController.fetchEmployeProfile();
    });
  }

  @override
  void dispose() {
    _rechercheMenu.dispose();
    super.dispose();
  }

  /// Le champ du menu filtre les libelles des deux sections.
  bool _correspond(String label) =>
      _filtreMenu.isEmpty || label.toLowerCase().contains(_filtreMenu);

  /// Onglets du menu, dans l'ordre d'affichage. `droit` null = toujours
  /// visible ; sinon l'onglet n'apparait qu'avec l'autorisation correspondante,
  /// comme les pages du web.
  List<({IconData icone, String label, String? droit, Widget page, bool barre})>
  _ongletsVisibles() {
    final user = _authController.currentUser.value;
    bool autorise(String? droit) =>
        droit == null || (user?.hasAuthority(droit) ?? false);

    final onglets =
        <
          ({
            IconData icone,
            String label,
            String? droit,
            Widget page,
            bool barre,
          })
        >[
          (
            icone: LucideIcons.home,
            label: 'Accueil',
            droit: null,
            page: DashboardPage(
              onNavigateToTab: (target) => setState(() => _index = target),
            ),
            barre: true,
          ),
          (
            icone: LucideIcons.truck,
            label: 'Véhicules',
            droit: 'VEHICULES',
            page: const VehiculesPage(),
            barre: true,
          ),
          (
            icone: LucideIcons.clipboardList,
            label: 'Demandes',
            droit: 'DEMANDES_OR',
            page: const DemandesOrListePage(),
            barre: true,
          ),
          (
            icone: LucideIcons.wrench,
            label: 'OR',
            droit: 'ORDRE_REPARATION',
            page: const OrPage(),
            barre: true,
          ),
          (
            icone: LucideIcons.bookOpen,
            label: 'Journal',
            droit: 'JOURNAL',
            page: const JournalPage(),
            // Menu lateral seulement : la barre du bas est deja pleine.
            barre: false,
          ),
          (
            icone: LucideIcons.droplet,
            label: 'Vidanges',
            droit: 'VIDANGES',
            page: const VidangesPage(),
            barre: true,
          ),
          (
            icone: LucideIcons.calendarDays,
            label: 'Agenda',
            droit: null,
            page: const AgendaPage(),
            barre: true,
          ),
          (
            icone: LucideIcons.circleDot,
            label: 'Pneumatiques',
            droit: 'PNEUMATIQUES',
            page: const PneumatiquesPage(),
            // Menu lateral seulement : la barre du bas est deja pleine.
            barre: false,
          ),
        ];

    return onglets.where((o) => autorise(o.droit)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final onglets = _ongletsVisibles();
    // Un droit retire peut rendre l'index courant hors limites.
    if (_index >= onglets.length) _index = 0;
    final pages = onglets.map((o) => o.page).toList();

    return Scaffold(
      key: _cleScaffold,
      extendBody: true,
      extendBodyBehindAppBar: true,
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildAppBar(),
      drawer: _menuLateral(onglets),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const AmbientBackground(),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, animation) {
              final slide =
                  Tween<Offset>(
                    begin: const Offset(0, 0.04),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    ),
                  );
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(position: slide, child: child),
              );
            },
            child: KeyedSubtree(
              key: ValueKey<int>(_index),
              child: pages[_index],
            ),
          ),
        ],
      ),
      // Bouton de chat, pose juste au-dessus de la barre flottante.
      floatingActionButton: _boutonChat(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: Theme(
        data: ThemeData(canvasColor: Colors.transparent),
        child: _pillBottomBar(onglets),
      ),
    );
  }

  // ==================== APP BAR STYLE DÉGRADÉ (SANS LIGNE DE SÉPARATION) ====================
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      // 44 au lieu des 56 par défaut : le logo (36) et les boutons (40) tiennent,
      // et la barre ne laisse plus 20 pt de vide sous le logo — c'est ce vide qui
      // repoussait le titre de chaque page vers le bas.
      toolbarHeight: 44,
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      // Pas de BackdropFilter ici : le flou s'arrête net au bas de la barre et
      // ce bord net dessinait une ligne en travers de l'écran. Le seul dégradé
      // suffit à détacher le logo du contenu, et il s'éteint en transparent.
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white.withValues(alpha: 0.92),
              Colors.white.withValues(alpha: 0.65),
              Colors.white.withValues(alpha: 0.0),
            ],
            stops: const [0.0, 0.70, 1.0],
          ),
        ),
      ),
      // Le logo laisse la place au bouton de menu : le tiroir regroupe les
      // pages, le profil et la deconnexion. Sans automaticallyImplyLeading a
      // false, Flutter ajoute son propre bouton de tiroir et il y en a deux.
      automaticallyImplyLeading: false,
      titleSpacing: 4,
      title: Row(
        children: [
          IconButton(
            icon: const Icon(LucideIcons.menu, size: 22),
            color: const Color(0xFF1F3A5F),
            onPressed: () => _cleScaffold.currentState?.openDrawer(),
          ),
          const SizedBox(width: 2),
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0xFF1F3A5F), Color(0xFF00C6FF)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ).createShader(bounds),
            child: Text(
              'META FLEET',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
      actions: [
        // Bouton Recherche rapide
        _appBarGlassButton(
          icon: LucideIcons.search,
          onTap: () {
            Get.to(
              () => const GlobalSearchPage(),
              transition: Transition.fadeIn,
              duration: const Duration(milliseconds: 300),
            );
          },
        ),
        const SizedBox(width: 8),
        // Bouton Notifications
        Obx(() {
          final notifCtrl = Get.isRegistered<NotificationController>()
              ? Get.find<NotificationController>()
              : null;
          final hasUnread = (notifCtrl?.unreadCount.value ?? 0) > 0;
          return _appBarGlassButton(
            icon: LucideIcons.bell,
            hasBadge: hasUnread,
            onTap: () {
              Get.to(
                () => const NotificationsPage(),
                transition: Transition.fadeIn,
                duration: const Duration(milliseconds: 300),
              );
            },
          );
        }),
        const SizedBox(width: 8),
        // Profil : accessible depuis l'en-tete, l'onglet du menu sert
        // desormais aux demandes d'OR.
        _boutonProfil(),
        const SizedBox(width: 14),
      ],
    );
  }

  /// Bouton profil : la photo de l'utilisateur si elle existe, sinon l'icone.
  Widget _boutonProfil() {
    return Obx(() {
      final photo = _photoUtilisateur(_authController.currentUser.value?.photo);

      void ouvrir() => Get.to(
        () => const ProfileRoutePage(),
        transition: Transition.fadeIn,
        duration: const Duration(milliseconds: 300),
      );

      if (photo == null) {
        return _appBarGlassButton(icon: LucideIcons.user, onTap: ouvrir);
      }

      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1.6),
          image: DecorationImage(image: MemoryImage(photo), fit: BoxFit.cover),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1F3A5F).withValues(alpha: 0.12),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(customBorder: const CircleBorder(), onTap: ouvrir),
        ),
      );
    });
  }

  Widget _appBarGlassButton({
    required IconData icon,
    required VoidCallback onTap,
    bool hasBadge = false,
  }) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1F3A5F).withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Material(
            color: Colors.white.withValues(alpha: 0.65),
            shape: const CircleBorder(
              side: BorderSide(color: Colors.white, width: 1.2),
            ),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(icon, color: const Color(0xFF1F3A5F), size: 18),
                  if (hasBadge)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Color(0xFF2563EB),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==================== BARRE DE NAVIGATION FLOTTANTE (GLASSMORPHISM) ====================
  Widget _pillBottomBar(
    List<
      ({IconData icone, String label, String? droit, Widget page, bool barre})
    >
    onglets,
  ) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        14,
        0,
        14,
        bottomPadding > 0 ? bottomPadding + 6 : 14,
      ),
      child: Container(
        height: 74,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1F3A5F).withValues(alpha: 0.12),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: const Color(0xFF00C6FF).withValues(alpha: 0.08),
              blurRadius: 18,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.88),
                    Colors.white.withValues(alpha: 0.65),
                  ],
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.95),
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  for (var i = 0; i < onglets.length; i++)
                    if (onglets[i].barre)
                      _navItem(i, onglets[i].icone, onglets[i].label),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Menu lateral : raccourcis vers les pages autorisees, puis les actions
  /// de compte, a la maniere du menu d'une application sociale.
  Widget _menuLateral(
    List<
      ({IconData icone, String label, String? droit, Widget page, bool barre})
    >
    onglets,
  ) {
    return Drawer(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const AmbientBackground(),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
              children: [
                _enteteMenu(),
                const SizedBox(height: 14),
                _champRechercheMenu(),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.only(left: 6, bottom: 8),
                  child: Text(
                    'Raccourcis',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                ),
                for (var i = 0; i < onglets.length; i++)
                  if (_correspond(onglets[i].label))
                    _ligneMenu(
                      icone: onglets[i].icone,
                      label: onglets[i].label,
                      actif: _index == i,
                      onTap: () {
                        setState(() => _index = i);
                        Navigator.of(context).pop();
                      },
                    ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.only(left: 6, bottom: 8),
                  child: Text(
                    'Compte',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                ),
                if (_correspond('Profil'))
                  _ligneMenu(
                    icone: LucideIcons.user,
                    label: 'Profil',
                    onTap: () {
                      Navigator.of(context).pop();
                      Get.to(() => const ProfileRoutePage());
                    },
                  ),
                if (_correspond('Notifications'))
                  _ligneMenu(
                    icone: LucideIcons.bell,
                    label: 'Notifications',
                    onTap: () {
                      Navigator.of(context).pop();
                      Get.to(() => const NotificationsPage());
                    },
                  ),
                const SizedBox(height: 10),
                if (_correspond('Déconnexion'))
                  _ligneMenu(
                    icone: LucideIcons.logOut,
                    label: 'Déconnexion',
                    couleur: const Color(0xFFDC2626),
                    onTap: () {
                      Navigator.of(context).pop();
                      _authController.logout();
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Meme habillage que la barre de recherche du tableau de bord.
  /// Chat employe ↔ administration : pastille rouge si messages non lus.
  Widget _boutonChat() {
    // Le controleur est permanent (main.dart) : on ne le cree pas pendant la
    // construction, sinon son onInit touche des observables en pleine frame.
    if (!Get.isRegistered<ChatController>()) return const SizedBox.shrink();

    final chat = Get.find<ChatController>();

    return Padding(
      // Juste au-dessus de la barre flottante du bas.
      padding: const EdgeInsets.only(bottom: 46),
      child: Obx(() {
        final nonLus = chat.nonLus.value;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            GestureDetector(
              onTap: () async {
                await Get.to(
                  () => chat.peutRepondre
                      ? const ChatFilsPage()
                      : const ChatPage(titre: 'Administration'),
                );
                chat.rafraichirNonLus();
              },
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: _brandGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1F3A5F).withValues(alpha: 0.28),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(
                  LucideIcons.messageCircle,
                  size: 22,
                  color: Colors.white,
                ),
              ),
            ),
            if (nonLus > 0)
              Positioned(
                top: -2,
                right: -2,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: Text(
                    nonLus > 99 ? '99+' : '$nonLus',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        );
      }),
    );
  }

  Widget _champRechercheMenu() {
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
      // Pas de BackdropFilter ici : dans la ListView du tiroir, il echantillonne
      // ce qui a deja ete peint et laisse une copie decalee de la carte voisine.
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: TextField(
          controller: _rechercheMenu,
          onChanged: (val) =>
              setState(() => _filtreMenu = val.trim().toLowerCase()),
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: const Color(0xFF0F172A),
          ),
          decoration: InputDecoration(
            hintText: 'Rechercher dans le menu…',
            hintStyle: GoogleFonts.poppins(
              fontSize: 13,
              color: const Color(0xFF94A3B8),
            ),
            // Sans contraintes, la boite du prefixe fait 48 dp : l'icone se
            // centre dedans et un vide reste avant le texte.
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
            suffixIcon: _filtreMenu.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(
                      LucideIcons.x,
                      size: 16,
                      color: Color(0xFF94A3B8),
                    ),
                    onPressed: () {
                      _rechercheMenu.clear();
                      setState(() => _filtreMenu = '');
                    },
                  ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ),
    );
  }

  Widget _enteteMenu() {
    return Obx(() {
      final user = _authController.currentUser.value;
      final employe = _authController.employeProfile.value;
      final nom = employe?.displayName ?? user?.username ?? 'Utilisateur';
      final role = (user?.userRoles ?? []).isNotEmpty
          ? user!.userRoles.first
          : '';
      final photo = _photoUtilisateur(user?.photo);

      return Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          // L'en-tete ouvre la fiche profil, comme le bouton de la barre.
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            Navigator.of(context).pop();
            Get.to(() => const ProfileRoutePage());
          },
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.88),
                  Colors.white.withValues(alpha: 0.60),
                ],
              ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.92)),
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    gradient: photo == null ? _brandGradient : null,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.9),
                      width: 1.5,
                    ),
                    image: photo == null
                        ? null
                        : DecorationImage(
                            image: MemoryImage(photo),
                            fit: BoxFit.cover,
                          ),
                  ),
                  alignment: Alignment.center,
                  child: photo != null
                      ? null
                      : Text(
                          nom.isNotEmpty ? nom[0].toUpperCase() : '?',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nom,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      if (role.isNotEmpty)
                        Text(
                          role,
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
                const Icon(
                  LucideIcons.chevronRight,
                  size: 17,
                  color: Color(0xFF94A3B8),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  /// Photo de profil stockee en base64 (avec ou sans prefixe data:).
  Uint8List? _photoUtilisateur(String? brut) {
    if (brut == null || brut.trim().isEmpty) return null;
    try {
      var propre = brut.trim();
      if (propre.contains(',')) propre = propre.split(',').last;

      return base64Decode(propre);
    } catch (_) {
      return null;
    }
  }

  Widget _ligneMenu({
    required IconData icone,
    required String label,
    required VoidCallback onTap,
    bool actif = false,
    Color? couleur,
  }) {
    final teinte = couleur ?? const Color(0xFF1F3A5F);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: actif
            ? teinte.withValues(alpha: 0.10)
            : Colors.white.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(icone, size: 19, color: teinte),
                const SizedBox(width: 13),
                Expanded(
                  child: Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontSize: 13.5,
                      fontWeight: actif ? FontWeight.w700 : FontWeight.w600,
                      color: couleur ?? const Color(0xFF0F172A),
                    ),
                  ),
                ),
                if (actif)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: teinte,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(int idx, IconData icon, String label) {
    final active = _index == idx;
    return GestureDetector(
      onTap: () => setState(() => _index = idx),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: active ? 36 : 26,
              height: active ? 36 : 26,
              decoration: active
                  ? BoxDecoration(
                      gradient: _brandGradient,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFF1F3A5F,
                          ).withValues(alpha: 0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    )
                  : null,
              child: Icon(
                icon,
                color: active ? Colors.white : const Color(0xFF64748B),
                size: active ? 18 : 19,
              ),
            ),
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 220),
              style: GoogleFonts.poppins(
                fontSize: 9.5,
                height: 1.15,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: active
                    ? const Color(0xFF1F3A5F)
                    : const Color(0xFF94A3B8),
              ),
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}
