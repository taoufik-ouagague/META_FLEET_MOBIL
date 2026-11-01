import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../controllers/notification_controller.dart';
import '../../models/notification_item_model.dart';
import '../../services/fcm_service.dart';
import '../../widgets/ambient_background.dart';
import '../../widgets/page_entrance_animation.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.isRegistered<NotificationController>()
        ? Get.find<NotificationController>()
        : Get.put(NotificationController());

    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.fetchNotifications(
        showLoading: controller.notifications.isEmpty,
      );
    });

    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const AmbientBackground(),
          Column(
            children: [
              // Barre glassmorphism identique a celle de la recherche globale.
              ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Container(
                    padding: EdgeInsets.fromLTRB(12, topPadding + 8, 12, 12),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF1F3A5F), Color(0xFF2563EB)],
                      ),
                    ),
                    child: Row(
                      children: [
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
                        Flexible(
                          child: Text(
                            'Notifications',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Obx(() {
                          final actif = controller.nonLuesSeulement.value;

                          return GestureDetector(
                            onTap: () => controller.nonLuesSeulement.toggle(),
                            child: Container(
                              height: 36,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(
                                  alpha: actif ? 0.95 : 0.18,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.35),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    actif
                                        ? LucideIcons.mailOpen
                                        : LucideIcons.mail,
                                    size: 15,
                                    color: actif
                                        ? const Color(0xFF1F3A5F)
                                        : Colors.white,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    controller.unreadCount.value > 0
                                        ? 'Non lues (${controller.unreadCount.value})'
                                        : 'Non lues',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: actif
                                          ? const Color(0xFF1F3A5F)
                                          : Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Obx(() {
                  if (controller.isLoading.value &&
                      controller.notifications.isEmpty) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF2563EB),
                        strokeWidth: 2.5,
                      ),
                    );
                  }

                  final liste = controller.listeAffichee;
                  if (liste.isEmpty) {
                    return Center(
                      child: PageEntranceAnimation(
                        duration: const Duration(milliseconds: 420),
                        slideOffset: 20,
                        child: _buildEmptyState(
                          controller.nonLuesSeulement.value,
                        ),
                      ),
                    );
                  }

                  return RefreshIndicator(
                    color: const Color(0xFF2563EB),
                    backgroundColor: Colors.white,
                    onRefresh: () =>
                        controller.fetchNotifications(showLoading: false),
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
                      itemCount: liste.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final item = liste[index];
                        return _buildNotificationCard(
                          context,
                          controller,
                          item,
                          index,
                        );
                      },
                    ),
                  );
                }),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool filtreNonLues) {
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
            child: const Icon(
              LucideIcons.bellOff,
              size: 32,
              color: Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            filtreNonLues
                ? 'Aucune notification non lue'
                : 'Aucune notification',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            filtreNonLues
                ? 'Tout est lu.\nTouchez « Non lues » pour revoir la liste.'
                : 'Vous n\'avez aucune notification\npour le moment.',
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

  Widget _buildNotificationCard(
    BuildContext context,
    NotificationController controller,
    NotificationItemModel item,
    int index,
  ) {
    final isUnread = !item.isRead;
    final iconData = _getIconForType(item.type, item.titre);
    final iconColor = _getColorForType(item.type, item.titre);
    final demandeur = _champ(item.corps, const ['demandeur']);
    final vehicule = _champ(item.corps, const [
      'véhicule',
      'vehicule',
      'matricule',
      'immatriculation',
    ]);

    return PageEntranceAnimation(
      duration: Duration(milliseconds: 250 + (index * 40).clamp(0, 400)),
      slideOffset: 16,
      // Glisser vers la gauche decouvre le bouton Supprimer et s'arrete la.
      child: _CarteGlissante(
        key: ValueKey('notif-${item.id}'),
        onSupprimer: () => controller.supprimer(item.id),
        child: GestureDetector(
          onTap: () {
            if (isUnread) {
              controller.markAsRead(item.id);
            }
            ouvrirRouteNotification(item.route);
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: isUnread
                      ? const Color(0xFFEFF6FF).withValues(alpha: 0.96)
                      : Colors.white.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _bordure(isUnread), width: 1.1),
                  boxShadow: [
                    BoxShadow(
                      color: isUnread
                          ? const Color(0xFF2563EB).withValues(alpha: 0.1)
                          : const Color(0xFF0F172A).withValues(alpha: 0.04),
                      blurRadius: isUnread ? 14 : 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        width: 3.5,
                        color: isUnread
                            ? const Color(0xFF2563EB)
                            : const Color(0xFFCBD5E1),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(9, 9, 10, 9),
                          child: Row(
                            children: [
                              Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      iconColor.withValues(
                                        alpha: isUnread ? 0.2 : 0.09,
                                      ),
                                      iconColor.withValues(
                                        alpha: isUnread ? 0.1 : 0.04,
                                      ),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  iconData,
                                  size: 15,
                                  color: isUnread
                                      ? iconColor
                                      : iconColor.withValues(alpha: 0.55),
                                ),
                              ),
                              const SizedBox(width: 9),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            _titreCourt(item.titre),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.poppins(
                                              fontSize: 12,
                                              fontWeight: isUnread
                                                  ? FontWeight.w700
                                                  : FontWeight.w500,
                                              color: isUnread
                                                  ? const Color(0xFF0F172A)
                                                  : const Color(0xFF64748B),
                                            ),
                                          ),
                                        ),
                                        if (item.type == 'DEMANDE_ACHAT') ...[
                                          const SizedBox(width: 6),
                                          _pastille(
                                            'En cours',
                                            const Color(0xFFF59E0B),
                                          ),
                                        ],
                                        if (isUnread) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            width: 7,
                                            height: 7,
                                            decoration: const BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: Color(0xFF2563EB),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 5),
                                    Row(
                                      children: [
                                        if (demandeur != null)
                                          Flexible(
                                            child: _pastille(
                                              demandeur,
                                              const Color(0xFF6366F1),
                                            ),
                                          ),
                                        if (demandeur != null &&
                                            vehicule != null)
                                          const SizedBox(width: 6),
                                        if (vehicule != null)
                                          _pastille(
                                            vehicule,
                                            const Color(0xFF0D9488),
                                          ),
                                        const Spacer(),
                                        Text(
                                          _formatDate(item.dateCreation),
                                          style: GoogleFonts.poppins(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w500,
                                            color: const Color(0xFF94A3B8),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
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
          ),
        ),
      ),
    );
  }

  /// Bordure de la carte  /// Bordure de la carte : bleue tant que la notification n'est pas lue.
  static Color _bordure(bool isUnread) => isUnread
      ? const Color(0xFF2563EB).withValues(alpha: 0.35)
      : const Color(0xFFE2E8F0);

  /// Pastille coloree compacte (statut, demandeur, vehicule).
  Widget _pastille(String texte, Color couleur) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        texte,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.poppins(
          fontSize: 9.5,
          fontWeight: FontWeight.w600,
          color: couleur,
        ),
      ),
    );
  }

  /// Emojis retires (l'icone les remplace).
  static final RegExp _emojis = RegExp(
    r'[\u{1F000}-\u{1FAFF}\u{2300}-\u{23FF}\u{2600}-\u{27BF}\u{2B00}-\u{2BFF}\u{FE0F}\u{200D}]',
    unicode: true,
  );

  /// « ⏰ [Rappel] Bon d'approvisionnement N° DAP0009 à valider » → « B. d'appro DAP0009 ».
  /// Les autres notifications gardent leur titre, emojis et crochets en moins.
  String _titreCourt(String titre) {
    final propre = titre
        .replaceAll(_emojis, '')
        .replaceAll(RegExp(r'\[[^\]]*\]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    final bas = propre.toLowerCase();
    if (!bas.contains('approvisionnement') && !bas.contains('achat')) {
      return propre;
    }

    // Le « N° » doit suivre un debut de mot, sinon le « no » de « renouveler » matche.
    final numero = RegExp(
      r'(?:^|\s)N[°o]\s*([\w\-/]+)',
    ).firstMatch(propre)?.group(1);
    final libelle = bas.contains('approvisionnement')
        ? "B. d'appro"
        : "B. d'achat";

    return numero != null ? '$libelle $numero' : libelle;
  }

  /// Valeur d'une ligne « Cle : valeur » du corps, pour la premiere cle trouvee.
  String? _champ(String corps, List<String> cles) {
    for (final ligne
        in corps.replaceAll(_emojis, '').split(RegExp(r'[\r\n]+'))) {
      final t = ligne.trim();
      final i = t.indexOf(':');
      if (i <= 0) continue;

      final cle = t.substring(0, i).trim().toLowerCase();
      if (cles.any(cle.startsWith)) {
        final valeur = t.substring(i + 1).trim();
        if (valeur.isNotEmpty) return valeur;
      }
    }

    return null;
  }

  IconData _getIconForType(String? type, String title) {
    if (title.contains('⏰') || title.toLowerCase().contains('rappel')) {
      return LucideIcons.alarmClock;
    }
    final t = (type ?? '').toUpperCase();
    if (t.contains('ACHAT') || title.contains('📋')) {
      return LucideIcons.clipboardList;
    }
    if (t.contains('APPRO') || title.contains('📦')) {
      return LucideIcons.package;
    }
    if (t.contains('VIDANGE')) {
      return LucideIcons.droplets;
    }
    if (t.contains('DOC')) {
      return LucideIcons.fileText;
    }
    return LucideIcons.bell;
  }

  Color _getColorForType(String? type, String title) {
    if (title.contains('⏰') || title.toLowerCase().contains('rappel')) {
      return const Color(0xFFF59E0B);
    }
    final t = (type ?? '').toUpperCase();
    if (t.contains('ACHAT')) {
      return const Color(0xFF2563EB);
    }
    if (t.contains('APPRO')) {
      return const Color(0xFF0D9488);
    }
    if (t.contains('VIDANGE')) {
      return const Color(0xFFEA580C);
    }
    return const Color(0xFF4F46E5);
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '';
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inSeconds < 60) {
      return 'À l\'instant';
    } else if (diff.inMinutes < 60) {
      return 'Il y a ${diff.inMinutes} min';
    } else if (diff.inHours < 24 && dt.day == now.day) {
      final hour = dt.hour.toString().padLeft(2, '0');
      final min = dt.minute.toString().padLeft(2, '0');
      return 'Aujourd\'hui à $hour:$min';
    } else if (diff.inDays == 1 ||
        (diff.inHours < 48 && dt.day == now.day - 1)) {
      final hour = dt.hour.toString().padLeft(2, '0');
      final min = dt.minute.toString().padLeft(2, '0');
      return 'Hier à $hour:$min';
    } else {
      final day = dt.day.toString().padLeft(2, '0');
      final month = dt.month.toString().padLeft(2, '0');
      final hour = dt.hour.toString().padLeft(2, '0');
      final min = dt.minute.toString().padLeft(2, '0');
      return '$day/$month/${dt.year} à $hour:$min';
    }
  }
}

/// Glissement vers la gauche : la carte s'arrete sur le bouton Supprimer et
/// la suppression ne part qu'au clic sur ce bouton.
class _CarteGlissante extends StatefulWidget {
  const _CarteGlissante({
    super.key,
    required this.onSupprimer,
    required this.child,
  });

  final VoidCallback onSupprimer;
  final Widget child;

  @override
  State<_CarteGlissante> createState() => _CarteGlissanteState();
}

class _CarteGlissanteState extends State<_CarteGlissante> {
  static const double _largeurAction = 62;

  double _decalage = 0;
  bool _enCours = false;

  void _placer(double valeur) =>
      setState(() => _decalage = valeur.clamp(-_largeurAction, 0.0));

  @override
  Widget build(BuildContext context) {
    final ouvert = _decalage != 0;

    return GestureDetector(
      onHorizontalDragStart: (_) => setState(() => _enCours = true),
      onHorizontalDragUpdate: (d) => _placer(_decalage + d.delta.dx),
      onHorizontalDragEnd: (_) {
        setState(() => _enCours = false);
        _placer(_decalage < -_largeurAction / 2 ? -_largeurAction : 0);
      },
      child: Stack(
        children: [
          Positioned.fill(
            child: Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: widget.onSupprimer,
                child: Container(
                  width: _largeurAction,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    LucideIcons.trash2,
                    size: 20,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          AnimatedContainer(
            duration: _enCours
                ? Duration.zero
                : const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            transform: Matrix4.translationValues(_decalage, 0, 0),
            child: widget.child,
          ),
          // Carte ouverte : un tap ailleurs la referme au lieu d'ouvrir la fiche.
          if (ouvert)
            Positioned.fill(
              right: _largeurAction,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _placer(0),
              ),
            ),
        ],
      ),
    );
  }
}
