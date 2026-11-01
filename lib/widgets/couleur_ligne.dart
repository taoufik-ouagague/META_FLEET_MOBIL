import 'package:flutter/material.dart';

/// Mise en evidence d'une ligne de liste, reprise telle quelle des listes web :
/// une bande laterale de 4 px et un fond teinte.
class CouleurLigne {
  /// Bande laterale.
  final Color accent;

  /// Teinte posee sur le verre de la carte.
  final Color fond;

  const CouleurLigne(this.accent, this.fond);
}

const _rouge = Color(0xFFEA5455); // annule
const _vert = Color(0xFF22C55E); // cloture
const _bleu = Color(0xFF1D4ED8); // OR sans reparation
const _orange = Color(0xFFF59E0B); // demande non transformee

const _lignes = {
  'annule': CouleurLigne(_rouge, Color(0x17EA5455)), // 0.09
  'cloture': CouleurLigne(_vert, Color(0x1722C55E)), // 0.09
  'sansReparation': CouleurLigne(_bleu, Color(0x211D4ED8)), // 0.13
  'nonTransformee': CouleurLigne(_orange, Color(0x24F59E0B)), // 0.14
  // Alerte : bande et bordure rouges, mais le verre reste clair (fond
  // transparent) — c'est un signal, pas un etat de la ligne.
  'alerte': CouleurLigne(_rouge, Color(0x00EA5455)),
};

/// Minuscules sans accents : les statuts arrivent ecrits de plusieurs facons.
String _plat(dynamic valeur) {
  const accents = 'àáâãäçèéêëìíîïñòóôõöùúûüýÿ';
  const simples = 'aaaaaceeeeiiiinooooouuuuyy';
  final s = (valeur ?? '').toString().toLowerCase().trim();
  final tampon = StringBuffer();
  for (final c in s.split('')) {
    final i = accents.indexOf(c);
    tampon.write(i == -1 ? c : simples[i]);
  }
  return tampon.toString();
}

bool _annule(Map<String, dynamic> item) {
  final s = _plat(item['status']);
  return s.contains('annul') || item['statusCode']?.toString() == '-3';
}

/// Rejetee : meme mise en evidence rouge que l'annulation, comme sur le web.
bool _rejete(Map<String, dynamic> item) {
  final s = _plat(item['status']);
  return s.contains('rejet') || item['statusCode']?.toString() == '-4';
}

bool _cloture(Map<String, dynamic> item) {
  final s = _plat(item['status']);
  return s.contains('clot') || s.contains('clos');
}

/// Derniere etape active du workflow, comme la colonne « Étape » de la liste.
String _etapeCourante(Map<String, dynamic> item) {
  final etapes = item['listEtape'];
  if (etapes is! List) return '';
  final actives = etapes.where((e) => e is Map && e['active'] == 1).toList();
  return actives.isEmpty ? '' : _plat((actives.last as Map)['libelle']);
}

/// OR transforme mais dont la reparation n'a pas commence : ligne bleue.
bool _sansReparation(Map<String, dynamic> ordre) {
  if (_annule(ordre) || _cloture(ordre) || ordre['dateCloture'] != null) {
    return false;
  }

  final etapes = ordre['listEtape'];
  if (etapes is List && etapes.isNotEmpty) {
    for (final e in etapes) {
      if (e is! Map) continue;
      final libelle = _plat(e['libelle']);
      if (libelle.contains('repar') && !libelle.contains('ordre')) {
        return e['active'] != 1;
      }
    }
  }

  final courante = _etapeCourante(ordre);
  if (courante.isEmpty ||
      courante == '—' ||
      courante.contains('gener') ||
      courante.contains('achat')) {
    return true;
  }

  return ordre['dateReparation'] == null;
}

CouleurLigne? couleurLigneOr(Map<String, dynamic> ordre) {
  if (_annule(ordre)) return _lignes['annule'];
  if (_cloture(ordre)) return _lignes['cloture'];
  if (_sansReparation(ordre)) return _lignes['sansReparation'];
  return null;
}

/// Demande non encore transformee en OR : ligne orange.
bool _nonTransformee(Map<String, dynamic> demande) {
  if (_annule(demande)) return false;
  final s = (demande['status'] ?? '').toString();
  if (s.isEmpty) return true;
  return s != 'Transformée en OT' && s != 'Transformée en OR';
}

CouleurLigne? couleurLigneDemande(Map<String, dynamic> demande) {
  if (_annule(demande)) return _lignes['annule'];
  if (_nonTransformee(demande)) return _lignes['nonTransformee'];
  // Le DTO porte le drapeau quand l'OR issu de la demande n'a pas de reparation.
  if (demande['orSansReparation'] == true) return _lignes['sansReparation'];
  return null;
}

/// Pneu en alerte (potentiel depasse) : ligne rouge, comme une annulation.
CouleurLigne? couleurLignePneu(Map<String, dynamic> pneu) {
  final alerte = (pneu['messageAlert'] ?? '').toString().trim();

  return alerte.isEmpty ? null : _lignes['alerte'];
}

CouleurLigne? couleurLigneVidange(Map<String, dynamic> vidange) =>
    (_annule(vidange) || _rejete(vidange)) ? _lignes['annule'] : null;

/// Verre des cartes de liste, teinte selon la mise en evidence.
/// La bande laterale est posee par [avecBandeLigne] : un `Border` non uniforme
/// est incompatible avec un `borderRadius`, et la carte ne se peignait plus.
/// [degrade] reprend le verre en degrade des cartes demandes.
BoxDecoration decorationLigne(
  CouleurLigne? ligne, {
  double rayon = 18,
  bool ombre = true,
  bool degrade = false,
}) {
  final blanc = Colors.white.withValues(alpha: 0.85);
  final bord = ligne == null
      ? Colors.white.withValues(alpha: degrade ? 0.92 : 0.95)
      : ligne.accent.withValues(alpha: 0.45);
  final epaisseur = degrade ? 1.5 : 1.3;
  final fond = ligne == null ? blanc : Color.alphaBlend(ligne.fond, blanc);

  return BoxDecoration(
    color: degrade ? null : fond,
    gradient: degrade
        ? LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [fond, fond.withValues(alpha: 0.55)],
          )
        : null,
    borderRadius: BorderRadius.circular(rayon),
    border: Border.all(color: bord, width: epaisseur),
    boxShadow: ombre
        ? [
            BoxShadow(
              color: const Color(0xFF1F3A5F).withValues(alpha: 0.05),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ]
        : null,
  );
}

/// Bande laterale de 4 px, posee a l'interieur du ClipRRect de la carte.
Widget avecBandeLigne(CouleurLigne? ligne, Widget enfant) {
  if (ligne == null) return enfant;

  return Stack(
    children: [
      enfant,
      PositionedDirectional(
        start: 0,
        top: 0,
        bottom: 0,
        child: Container(width: 4, color: ligne.accent),
      ),
    ],
  );
}
