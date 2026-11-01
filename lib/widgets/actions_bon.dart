import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../controllers/auth_controller.dart';
import 'apercu_kit.dart';

/// Menu d'actions d'un bon d'achat ou d'approvisionnement : valider, rejeter,
/// supprimer. Les regles et les droits sont ceux de la fiche web ; seules les
/// routes changent d'un module a l'autre, d'ou [url].
class MenuActionsBon extends StatefulWidget {
  final Map<String, dynamic> bon;

  /// true pour un bon d'approvisionnement, false pour un bon d'achat.
  final bool appro;

  /// Document clos ou annule : plus de suppression possible.
  final bool verrouille;

  /// Commentaire joint a la validation ou au rejet. Il appartient a la page :
  /// un controleur cree par dialogue etait utilise apres son dispose.
  final TextEditingController commentaire;

  /// Route a appeler pour (action, appro, id du bon).
  final String Function(String action, bool appro, int id) url;

  /// Rechargement de la fiche apres une action reussie.
  final Future<void> Function() onTermine;

  const MenuActionsBon({
    super.key,
    required this.bon,
    required this.appro,
    required this.commentaire,
    required this.url,
    required this.onTermine,
    this.verrouille = false,
  });

  @override
  State<MenuActionsBon> createState() => _MenuActionsBonState();
}

class _MenuActionsBonState extends State<MenuActionsBon> {
  bool _enCours = false;

  @override
  Widget build(BuildContext context) {
    final d = widget.bon;
    final appro = widget.appro;
    final id = d['id'];
    if (id is! int) return const SizedBox.shrink();

    final user = Get.find<AuthController>().currentUser.value;
    final suffixe = appro ? 'BON_APPRO' : 'BON_ACHAT';

    // Mêmes règles que la fiche web : valider / rejeter seulement sur un bon
    // « en cours » (7) ; supprimer sur un bon en cours, validé (1) ou rejeté
    // (-4), tant que l'ordre n'est pas clôturé ou annulé.
    final statut = (d['statusCode'] ?? d['status'] ?? '').toString().trim();
    final enCours = statut == '7';
    final supprimable = const ['7', '1', '-4'].contains(statut);

    final peutValider =
        enCours && (user?.hasAuthority('${suffixe}_VALIDER') ?? false);
    final peutRejeter =
        enCours && (user?.hasAuthority('${suffixe}_REJETER') ?? false);
    final peutSupprimer =
        supprimable &&
        !widget.verrouille &&
        (user?.hasAuthority('${suffixe}_SUPPRIMER') ?? false);

    if (!peutValider && !peutRejeter && !peutSupprimer) {
      return const SizedBox.shrink();
    }

    if (_enCours) {
      return const Padding(
        padding: EdgeInsets.only(left: 8),
        child: SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 1.8),
        ),
      );
    }

    return PopupMenuButton<String>(
      padding: EdgeInsets.zero,
      tooltip: 'Actions',
      offset: const Offset(0, 34),
      color: Colors.white,
      elevation: 10,
      shadowColor: const Color(0xFF1F3A5F).withValues(alpha: 0.22),
      surfaceTintColor: Colors.transparent,
      constraints: const BoxConstraints(minWidth: 208),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: const Color(0xFF1F3A5F).withValues(alpha: 0.07),
        ),
      ),
      // Même pastille que le bouton « Imprimer » : la cible de tap reste
      // visible sans alourdir l'en-tête de la carte.
      icon: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: const Color(0xFF64748B).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: const Color(0xFF64748B).withValues(alpha: 0.18),
          ),
        ),
        child: const Icon(
          LucideIcons.moreVertical,
          size: 14,
          color: Color(0xFF64748B),
        ),
      ),
      onSelected: (action) => _agir(d, appro, action),
      itemBuilder: (context) => [
        if (peutValider)
          _itemMenu('valider', 'Valider', LucideIcons.checkCircle2, kApVert),
        if (peutRejeter)
          _itemMenu(
            'rejeter',
            'Rejeter',
            LucideIcons.xCircle,
            kApRouge,
            destructif: true,
          ),
        // La suppression est séparée du reste : elle ne se répare pas.
        if (peutSupprimer && (peutValider || peutRejeter))
          const PopupMenuDivider(height: 9),
        if (peutSupprimer)
          _itemMenu(
            'supprimer',
            'Supprimer',
            LucideIcons.trash2,
            kApRouge,
            destructif: true,
          ),
      ],
    );
  }

  PopupMenuItem<String> _itemMenu(
    String valeur,
    String label,
    IconData icone,
    Color couleur, {
    bool destructif = false,
  }) {
    return PopupMenuItem<String>(
      value: valeur,
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: couleur.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: couleur.withValues(alpha: 0.22)),
            ),
            child: Icon(icone, size: 15, color: couleur),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.1,
              color: destructif ? couleur : const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _agir(Map<String, dynamic> d, bool appro, String action) async {
    final id = d['id'];
    if (id is! int) return;

    final numero = (d['numeroDemande'] ?? d['numeroDemandeStock'] ?? '')
        .toString();
    final suppression = action == 'supprimer';

    // Valider / rejeter acceptent un commentaire ; la suppression se contente
    // d'une confirmation.
    widget.commentaire.clear();

    final couleur = switch (action) {
      'valider' => kApVert,
      _ => kApRouge,
    };
    final icone = switch (action) {
      'valider' => LucideIcons.checkCircle2,
      'rejeter' => LucideIcons.xCircle,
      _ => LucideIcons.trash2,
    };
    final titre = switch (action) {
      'valider' => 'Valider le bon',
      'rejeter' => 'Rejeter le bon',
      _ => 'Supprimer le bon',
    };

    final confirme = await Get.dialog<bool>(
      apercuDialogueAction(
        titre: titre,
        numero: numero,
        message: suppression
            ? 'Cette suppression est définitive.'
            : 'Un commentaire peut être joint à la décision.',
        libelleAction: suppression ? 'Supprimer' : 'Confirmer',
        couleur: couleur,
        icone: icone,
        commentaire: suppression ? null : widget.commentaire,
      ),
      barrierColor: const Color(0xFF0F172A).withValues(alpha: 0.35),
    );

    if (confirme != true) return;

    final texte = widget.commentaire.text.trim();

    final url = widget.url(action, appro, id);

    setState(() => _enCours = true);
    try {
      final reponse = await Get.find<AuthController>().makeRequest(
        url,
        method: 'POST',
        body: suppression ? null : {'commentaire': texte},
      );

      final message = reponse is Map
          ? (reponse['message']?.toString() ?? 'Opération effectuée')
          : 'Opération effectuée';
      Get.snackbar(
        'Bon $numero',
        message,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFFF0FDF4),
        colorText: const Color(0xFF166534),
        borderRadius: 14,
        margin: const EdgeInsets.all(16),
      );

      await widget.onTermine();
    } catch (_) {
      // makeRequest a déjà affiché l'erreur.
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }
}
