import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../controllers/auth_controller.dart';
import '../../services/api_service.dart';
import '../../widgets/apercu_kit.dart';
import '../dashboard/cards/navigation_fiches.dart';
import '../../widgets/filtre_pastille.dart';

/// Apercu d'une ligne de journal : operation, vehicule, article et montants.
/// Les donnees viennent de la liste, pas d'appel au serveur.
class JournalApercuPage extends StatefulWidget {
  final Map<String, dynamic> ligne;

  const JournalApercuPage({super.key, required this.ligne});

  @override
  State<JournalApercuPage> createState() => _JournalApercuPageState();
}

class _JournalApercuPageState extends State<JournalApercuPage> {
  final _auth = Get.find<AuthController>();

  Map<String, dynamic> get ligne => widget.ligne;

  /// Pieces de l'operation portant la ligne (BL, facture, BC, devis).
  List<Map<String, dynamic>> _pieces = const [];
  bool _chargement = true;

  /// Filtre par type de piece de l'onglet « Pieces ».
  String _typePiece = 'TOUS';

  @override
  void initState() {
    super.initState();
    _chargerPieces();
  }

  Future<void> _chargerPieces() async {
    final id = _estVidange ? ligne['vidangeId'] : ligne['ordreReparationId'];
    if (id is! int) {
      setState(() => _chargement = false);

      return;
    }

    try {
      final data = await _auth.makeRequest(
        _estVidange
            ? ApiService.getPiecesByVidange(id)
            : ApiService.getPiecesByOr(id),
        method: 'GET',
        showErrorSnackbar: false,
      );
      final contenu = data is Map ? (data['content'] ?? data['data']) : data;
      if (contenu is List && mounted) {
        setState(() {
          _pieces = contenu
              .whereType<Map>()
              .map(Map<String, dynamic>.from)
              .toList();
        });
      }
    } catch (_) {
      // Pieces indisponibles : l'onglet reste vide, le reste de la fiche tient.
    } finally {
      if (mounted) setState(() => _chargement = false);
    }
  }

  /// Pieces citees par la ligne ; a defaut d'identifiants, celles de
  /// l'operation entiere.
  List<Map<String, dynamic>> get _piecesDeLaLigne {
    final ids = <int>{
      for (final cle in ['devisId', 'bcId', 'blId', 'factureId'])
        if (ligne[cle] is int) ligne[cle] as int,
    };
    if (ids.isEmpty) return _pieces;

    final liees = _pieces.where((p) => ids.contains(p['id'])).toList();

    return liees.isEmpty ? _pieces : liees;
  }

  /// Identifiant de l'operation portee par la ligne, s'il est exploitable.
  bool get _aOperation =>
      (_estVidange ? ligne['vidangeId'] : ligne['ordreReparationId']) is int;

  /// Fiche de l'operation : vidange ou ordre de reparation.
  void _ouvrirOperation() {
    if (_estVidange) {
      ouvrirFicheVidange({'vidangeId': ligne['vidangeId']});
    } else {
      ouvrirFicheOr({'ordreReparationId': ligne['ordreReparationId']});
    }
  }

  void _ouvrirVehicule() => ouvrirFicheVehicule({
    'vehiculeId': ligne['vehiculeId'],
    'immatriculation': ligne['vehiculeImmatriculation'],
    'marque': ligne['vehiculeMarque'],
    'modele': ligne['vehiculeModele'],
  });

  /// Rend une carte cliquable quand la fiche cible est atteignable.
  static Widget _ouvrable(
    Widget carte,
    VoidCallback onTap, {
    bool actif = true,
  }) {
    if (!actif) return carte;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: carte,
    );
  }

  bool get _estVidange => (ligne['typeOperation'] ?? '')
      .toString()
      .toUpperCase()
      .contains('VIDANGE');

  String get _numero =>
      (ligne['ordreReparationNumero'] ?? ligne['vidangeNumero'] ?? '—')
          .toString();

  /// Ecart entre le compteur du vehicule et celui de l'operation.
  String? get _ecartKm {
    final actuel = ligne['kmActuel'];
    final km = ligne['km'];
    if (actuel is! num || km is! num) return null;

    return apercuKm(actuel - km);
  }

  @override
  Widget build(BuildContext context) {
    final consommables = ligne['consommables'];

    return ApercuScaffold(
      titre: _numero,
      sousTitre: _estVidange ? 'Vidange' : 'Ordre de réparation',
      chargement: _chargement,
      onglets: const ['Informations'],
      contenus: [
        ApercuSlider(
          pages: [
            ApercuSliderPage(
              label: 'Opération',
              icone: _estVidange ? LucideIcons.droplet : LucideIcons.wrench,
              contenu: apercuScroll([
                _ouvrable(
                  apercuCarte(
                    titre: _numero,
                    icone: _estVidange
                        ? LucideIcons.droplet
                        : LucideIcons.wrench,
                    couleur: _estVidange ? kApCyan : kApAmbre,
                    etiquette: ligne['typeOperation']?.toString(),
                    action: _aOperation
                        ? const Icon(
                            LucideIcons.chevronRight,
                            size: 16,
                            color: Color(0xFF94A3B8),
                          )
                        : null,
                    lignes: [
                      apercuLigneStatut(
                        'Statut',
                        ligne['statusOperation'],
                        avecIcone: true,
                      ),
                      apercuLigne(
                        'Date',
                        apercuDate(ligne['dateOr']),
                        LucideIcons.calendar,
                        kApBleu,
                      ),
                      apercuLigne(
                        "Type d'intervention",
                        ligne['typeIntervention'],
                        LucideIcons.settings2,
                        kApArdoise,
                      ),
                      apercuLigne(
                        "Nature d'anomalie",
                        ligne['natureAnomalie'],
                        LucideIcons.alertTriangle,
                        kApRouge,
                      ),
                      apercuLigne(
                        'Fournisseur',
                        ligne['fournisseur'],
                        LucideIcons.store,
                        kApArdoise,
                      ),
                      apercuLigne(
                        'Intervenants',
                        ligne['intervenants'],
                        LucideIcons.users,
                        kApArdoise,
                      ),
                    ],
                  ),
                  _ouvrirOperation,
                  actif: _aOperation,
                ),
                _ouvrable(
                  apercuSection(
                    'Véhicule',
                    [
                      apercuLigne(
                        'Immatriculation',
                        ligne['vehiculeImmatriculation'],
                        LucideIcons.truck,
                        kApBleu,
                      ),
                      apercuLigne(
                        'Marque',
                        ligne['vehiculeMarque'],
                        LucideIcons.factory,
                        kApBleu,
                      ),
                      apercuLigne(
                        'Modèle',
                        ligne['vehiculeModele'],
                        LucideIcons.car,
                        kApBleu,
                      ),
                      apercuLigne(
                        'Type de véhicule',
                        ligne['typeVehicule'],
                        LucideIcons.layers,
                        kApArdoise,
                      ),
                      apercuLigne(
                        'Km actuel',
                        apercuKm(ligne['kmActuel']),
                        LucideIcons.gauge,
                        kApBleu,
                      ),
                      apercuLigne(
                        'Km opération',
                        apercuKm(ligne['km']),
                        LucideIcons.gauge,
                        kApVert,
                      ),
                      apercuLigne(
                        'Écart km',
                        _ecartKm,
                        LucideIcons.activity,
                        kApAmbre,
                      ),
                    ],
                    action: ligne['vehiculeId'] is int
                        ? const Icon(
                            LucideIcons.chevronRight,
                            size: 16,
                            color: Color(0xFF94A3B8),
                          )
                        : null,
                  ),
                  _ouvrirVehicule,
                  actif: ligne['vehiculeId'] is int,
                ),
              ], cle: const ValueKey('journal-operation')),
            ),
            ApercuSliderPage(
              label: 'Article',
              icone: LucideIcons.package,
              contenu: apercuScroll([
                apercuCarte(
                  titre: ligne['produitLibelle'] ?? ligne['description'],
                  icone: LucideIcons.package,
                  couleur: kApViolet,
                  etiquette: ligne['produitCode']?.toString(),
                  lignes: [
                    apercuLigne(
                      'Quantité',
                      ligne['qte'],
                      LucideIcons.hash,
                      kApArdoise,
                    ),
                    apercuLigne(
                      'Service',
                      ligne['service'] == null
                          ? null
                          : (ligne['service'] == true ? 'Oui' : 'Non'),
                      LucideIcons.wrench,
                      kApArdoise,
                    ),
                    apercuLigne(
                      'Description',
                      ligne['description'],
                      LucideIcons.fileText,
                      kApArdoise,
                    ),
                    if (consommables is List && consommables.isNotEmpty)
                      apercuLigne(
                        'Consommables',
                        consommables.join(', '),
                        LucideIcons.boxes,
                        kApArdoise,
                      ),
                  ],
                ),
                apercuSection('Montants', [
                  apercuLigne(
                    'Prix unitaire',
                    apercuMontant(ligne['prixUnit']),
                    LucideIcons.tag,
                    kApArdoise,
                  ),
                  apercuLigne(
                    'Remise',
                    ligne['tauxRemise'] == null
                        ? null
                        : '${ligne['tauxRemise']} %',
                    LucideIcons.percent,
                    kApArdoise,
                  ),
                  apercuLigne(
                    'TVA',
                    ligne['tauxTva'] == null ? null : '${ligne['tauxTva']} %',
                    LucideIcons.percent,
                    kApArdoise,
                  ),
                  apercuLigne(
                    'Montant HT',
                    apercuMontant(ligne['montantHt']),
                    LucideIcons.wallet,
                    kApVert,
                  ),
                  apercuLigne(
                    'Montant TVA',
                    apercuMontant(ligne['montantTva']),
                    LucideIcons.wallet,
                    kApArdoise,
                  ),
                  apercuLigne(
                    'Total TTC',
                    apercuMontant(ligne['montantTtc']),
                    LucideIcons.wallet,
                    kApVert,
                  ),
                ]),
              ], cle: const ValueKey('journal-article')),
            ),
            ApercuSliderPage(
              label: 'Pièces',
              icone: LucideIcons.receipt,
              contenu: _ongletPieces(),
            ),
          ],
        ),
      ],
    );
  }

  /// Devis, bon de commande, BL et facture de la ligne, chacun avec ses dates
  /// et ses montants — comme la reception financiere de l'apercu OR.
  /// Ordre de lecture : devis, bon de commande, BL, facture.
  static const _typesPiece = ['DEVIS', 'COMMANDE', 'BL', 'FACTURE'];

  static const _libellesPiece = {
    'DEVIS': 'Devis',
    'COMMANDE': 'B. commande',
    'BL': 'BL',
    'FACTURE': 'Facture',
  };

  bool _estDuType(Map<String, dynamic> p, String motif) =>
      (p['typePiece'] ?? '').toString().toUpperCase().contains(motif);

  int _rangDe(Map<String, dynamic> p) {
    for (var i = 0; i < _typesPiece.length; i++) {
      if (_estDuType(p, _typesPiece[i])) return i;
    }

    return 9;
  }

  Widget _ongletPieces() {
    final pieces = _piecesDeLaLigne;
    if (pieces.isEmpty) {
      return apercuVide(
        _chargement ? 'Chargement…' : 'Aucune pièce rattachée à cette ligne',
      );
    }

    final triees = [...pieces]
      ..sort((a, b) => _rangDe(a).compareTo(_rangDe(b)));
    final visibles = _typePiece == 'TOUS'
        ? triees
        : triees.where((p) => _estDuType(p, _typePiece)).toList();

    // Seuls les types reellement presents sont proposes.
    final presents = _typesPiece
        .where((t) => triees.any((p) => _estDuType(p, t)))
        .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: SizedBox(
            height: 32,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                FiltrePastille(
                  label: 'Tous (${triees.length})',
                  couleur: const Color(0xFF1F3A5F),
                  actif: _typePiece == 'TOUS',
                  onTap: () => setState(() => _typePiece = 'TOUS'),
                ),
                for (final t in presents) ...[
                  const SizedBox(width: 6),
                  FiltrePastille(
                    label:
                        '${_libellesPiece[t]} '
                        '(${triees.where((p) => _estDuType(p, t)).length})',
                    couleur: _couleurType(t),
                    icone: _iconeType(t),
                    actif: _typePiece == t,
                    onTap: () => setState(
                      () => _typePiece = _typePiece == t ? 'TOUS' : t,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        Expanded(
          child: visibles.isEmpty
              ? apercuVide('Aucune pièce de ce type')
              : apercuScroll([
                  for (final p in visibles) _cartePiece(p),
                ], cle: ValueKey('journal-pieces-$_typePiece')),
        ),
      ],
    );
  }

  Color _couleurType(String type) => switch (type) {
    'FACTURE' => kApViolet,
    'COMMANDE' => kApBleu,
    'BL' => kApVert,
    _ => kApArdoise,
  };

  IconData _iconeType(String type) => switch (type) {
    'FACTURE' => LucideIcons.receipt,
    'COMMANDE' => LucideIcons.shoppingCart,
    'BL' => LucideIcons.truck,
    _ => LucideIcons.fileText,
  };

  Widget _cartePiece(Map<String, dynamic> p) {
    final type = _typesPiece.firstWhere(
      (t) => _estDuType(p, t),
      orElse: () => '',
    );

    return apercuCarte(
      titre: p['numPiece'],
      icone: _iconeType(type),
      couleur: _couleurType(type),
      etiquette: p['typePiece']?.toString(),
      lignes: [
        apercuLigne(
          'Prestataire',
          p['prestataireLibelle'],
          LucideIcons.building2,
          kApAmbre,
        ),
        apercuLigne(
          'Date pièce',
          apercuDate(p['datePiece']),
          LucideIcons.calendar,
          kApViolet,
        ),
        apercuLigne(
          'Date réception',
          apercuDate(p['dateReception']),
          LucideIcons.calendarCheck,
          kApCyan,
        ),
        apercuLigne(
          'Règlement',
          p['typeReglementLibelle'],
          LucideIcons.creditCard,
          kApArdoise,
        ),
        apercuLigne(
          'Montant HT',
          apercuMontant(p['mntHt']),
          LucideIcons.receipt,
          kApBleu,
        ),
        apercuLigne(
          'Montant TVA',
          apercuMontant(p['mntTva']),
          LucideIcons.hash,
          kApAmbre,
        ),
        apercuLigne(
          'Montant TTC',
          apercuMontant(p['mntTtc']),
          LucideIcons.creditCard,
          kApVert,
        ),
        apercuLigne('BL liés', p['blsNumeros'], LucideIcons.truck, kApVert),
        apercuLigne(
          'Factures liées',
          p['facturesNumeros'],
          LucideIcons.receipt,
          kApViolet,
        ),
        apercuLigne(
          'Bon de commande',
          p['bonCommandePieceNumero'],
          LucideIcons.shoppingCart,
          kApBleu,
        ),
      ],
    );
  }
}
