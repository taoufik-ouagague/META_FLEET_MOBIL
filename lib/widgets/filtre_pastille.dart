import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Pastille de filtre commune aux listes (demandes, véhicules, vidanges, OR) :
/// coins à 9, fond plein dans la couleur du filtre quand elle est active,
/// teinte claire et bordure assortie sinon.
class FiltrePastille extends StatelessWidget {
  final String label;
  final Color couleur;
  final bool actif;
  final VoidCallback? onTap;

  /// Icône de tête, absente pour les pastilles de statut.
  final IconData? icone;

  /// Chevron de fin, pour les pastilles qui ouvrent une liste.
  final bool deroulante;

  /// Croix de fin, pour effacer un filtre déjà posé.
  final VoidCallback? onEffacer;

  const FiltrePastille({
    super.key,
    required this.label,
    required this.couleur,
    this.actif = false,
    this.onTap,
    this.icone,
    this.deroulante = false,
    this.onEffacer,
  });

  @override
  Widget build(BuildContext context) {
    final contenu = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: actif ? couleur : couleur.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: couleur.withValues(alpha: actif ? 1 : 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icone != null) ...[
            Icon(icone, size: 12, color: actif ? Colors.white : couleur),
            const SizedBox(width: 5),
          ],
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 170),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: actif ? Colors.white : couleur,
              ),
            ),
          ),
          if (onEffacer != null) ...[
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onEffacer,
              child: Icon(
                LucideIcons.x,
                size: 12,
                color: actif ? Colors.white : couleur,
              ),
            ),
          ] else if (deroulante) ...[
            const SizedBox(width: 3),
            Icon(
              LucideIcons.chevronDown,
              size: 12,
              color: actif ? Colors.white : couleur,
            ),
          ],
        ],
      ),
    );

    if (onTap == null) return contenu;

    return GestureDetector(onTap: onTap, child: contenu);
  }
}
