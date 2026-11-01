import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../controllers/auth_controller.dart';
import '../../services/api_service.dart';
import '../../widgets/actions_bon.dart';
import '../../widgets/apercu_kit.dart';
import '../../widgets/filtre_pastille.dart';

/// Aperçu d'une vidange, en consultation seule. Même présentation que la fiche
/// OR : page à onglets, cartes en verre sur le fond ambiant.
class VidangeApercuPage extends StatefulWidget {
  final Map<String, dynamic> vidange;

  const VidangeApercuPage({super.key, required this.vidange});

  @override
  State<VidangeApercuPage> createState() => _VidangeApercuPageState();
}

class _VidangeApercuPageState extends State<VidangeApercuPage> {
  final _auth = Get.find<AuthController>();

  List<Map<String, dynamic>> _pieces = const [];
  List<Map<String, dynamic>> _articles = const [];
  List<Map<String, dynamic>> _bons = const [];
  bool _chargement = true;

  /// Type de piece affiche dans la reception financiere.
  String? _typePiece;

  /// Code de reglement retenu, null = tous.
  String? _codeReglement;

  // Un seul controleur pour la page : en creer un par dialogue le faisait
  // utiliser apres dispose() pendant l'animation de fermeture.
  final _commentaireBon = TextEditingController();

  @override
  void dispose() {
    _commentaireBon.dispose();
    super.dispose();
  }

  /// Vidange close ou annulee : plus de suppression de bon.
  bool get _vidangeVerrouillee {
    final statut = (_v('status') ?? '').toString().toUpperCase();
    return statut.contains('CLOTUR') ||
        statut.contains('CLÔTUR') ||
        statut.contains('ANNUL');
  }

  /// Routes des actions sur un bon, cote vidanges.
  String _urlActionBon(String action, bool appro, int id) => switch (action) {
    'valider' =>
      appro
          ? ApiService.validerBonApproVidange(id)
          : ApiService.validerBonAchatVidange(id),
    'rejeter' =>
      appro
          ? ApiService.rejeterBonApproVidange(id)
          : ApiService.rejeterBonAchatVidange(id),
    _ =>
      appro
          ? ApiService.supprimerBonApproVidange(id)
          : ApiService.supprimerBonAchatVidange(id),
  };

  dynamic _v(String cle) => widget.vidange[cle];

  @override
  void initState() {
    super.initState();
    _chargerTout();
  }

  /// Articles consommes, bons d'approvisionnement et pieces justificatives.
  /// Chaque liste est independante : un echec laisse les autres onglets utiles.
  Future<void> _chargerTout() async {
    final id = (_v('id') as num?)?.toInt();
    if (id == null) {
      if (mounted) setState(() => _chargement = false);
      return;
    }

    Future<List<Map<String, dynamic>>> charger(String url) async {
      try {
        final data = await _auth.makeRequest(
          url,
          method: 'GET',
          showErrorSnackbar: false,
        );
        final contenu = data is Map ? (data['content'] ?? data['data']) : data;
        if (contenu is List) {
          return contenu
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      } catch (_) {
        // Liste indisponible : l'onglet reste vide.
      }
      return <Map<String, dynamic>>[];
    }

    final resultats = await Future.wait([
      charger(ApiService.getArticlesByVidange(id)),
      charger(ApiService.getDemandesAchatsByVidange(id)),
      charger(ApiService.getPiecesByVidange(id)),
    ]);

    if (!mounted) return;
    setState(() {
      _articles = resultats[0];
      _bons = resultats[1];
      _pieces = resultats[2];
      _chargement = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final numero = _v('numero')?.toString() ?? 'Vidange';

    return ApercuScaffold(
      titre: numero,
      sousTitre: 'Consultation',
      chargement: _chargement,
      onglets: const [
        'Informations',
        'Planification',
        'Articles consommés',
        'Approvisionnement',
        'Réception financière',
        'Prestataires',
      ],
      contenus: [
        // Fiche et vehicule dans le meme onglet, en slider.
        ApercuSlider(
          pages: [
            ApercuSliderPage(
              label: 'Informations',
              icone: LucideIcons.droplet,
              contenu: _ongletInformations(),
            ),
            ApercuSliderPage(
              label: 'Véhicule',
              icone: LucideIcons.truck,
              contenu: _ongletVehicule(),
            ),
          ],
        ),
        _ongletPlanification(),
        _ongletArticles(),
        _ongletApprovisionnement(),
        _ongletReceptionFinanciere(),
        _ongletPrestataires(),
      ],
    );
  }

  /// Articles consommes par la vidange, avec leur bon d'origine.
  Widget _ongletArticles() {
    if (_articles.isEmpty) return apercuVide('Aucun article consommé');

    return apercuScroll(
      _articles.map((a) {
        final bon = (a['numeroDemandeAchat'] ?? '').toString().trim();
        final appro = (a['typeDemandeAchat'] ?? '')
            .toString()
            .toUpperCase()
            .contains('APPRO');

        return apercuCarte(
          titre: a['produitLibelle'] ?? a['designationProduit'] ?? a['libelle'],
          icone: LucideIcons.package,
          couleur: kApAmbre,
          etiquette: bon.isEmpty
              ? null
              : (appro ? "Bon d'appro $bon" : "Bon d'achat $bon"),
          lignes: [
            apercuLigne(
              'Référence',
              a['produitCode'] ?? a['reference'],
              LucideIcons.hash,
              kApArdoise,
            ),
            apercuLigne(
              'Quantité',
              [a['qte'], (a['unite'] ?? '').toString()]
                  .where((e) => e != null && e.toString().trim().isNotEmpty)
                  .join(' '),
              LucideIcons.boxes,
              kApBleu,
            ),
            apercuLigne(
              'Prix unitaire',
              apercuMontant(a['prixUnit']),
              LucideIcons.tag,
              kApCyan,
            ),
            apercuLigne(
              'Remise',
              a['tauxRemise'] == null ? null : '${a['tauxRemise']} %',
              LucideIcons.percent,
              kApViolet,
            ),
            apercuLigne(
              'TVA',
              a['tauxTva'] == null ? null : '${a['tauxTva']} %',
              LucideIcons.percent,
              kApAmbre,
            ),
            apercuLigne(
              'Montant HT',
              apercuMontant(a['mntHt']),
              LucideIcons.receipt,
              kApBleu,
            ),
            apercuLigne(
              'Montant TTC',
              apercuMontant(a['mntTtc']),
              LucideIcons.wallet,
              kApVert,
            ),
            apercuLigne(
              'Observation',
              a['description'],
              LucideIcons.fileText,
              kApArdoise,
            ),
            apercuLigneStatut('Statut du bon', a['statutDemandeAchat']),
          ],
        );
      }).toList(),
    );
  }

  /// Bons d'achat et d'approvisionnement de la vidange.
  Widget _ongletApprovisionnement() {
    if (_bons.isEmpty) return apercuVide('Aucun bon');

    return apercuScroll(
      _bons.map((d) {
        final appro = (d['type'] ?? '').toString().toUpperCase().contains(
          'APPRO',
        );

        return apercuCarte(
          titre: d['numeroDemande'] ?? d['numeroDemandeStock'],
          icone: appro ? LucideIcons.truck : LucideIcons.shoppingCart,
          couleur: appro ? kApCyan : kApBleu,
          etiquette: appro ? "Bon d'approvisionnement" : "Bon d'achat",
          action: MenuActionsBon(
            bon: d,
            appro: appro,
            verrouille: _vidangeVerrouillee,
            commentaire: _commentaireBon,
            url: _urlActionBon,
            onTermine: _chargerTout,
          ),
          lignes: [
            apercuLigne(
              'Prestataire',
              d['prestataireLibelle'],
              LucideIcons.briefcase,
              kApAmbre,
            ),
            apercuLigne('Demandeur', d['demandeur'], LucideIcons.user, kApVert),
            apercuLigne(
              'Date demande',
              apercuDate(d['dateDemande']),
              LucideIcons.calendar,
              kApViolet,
            ),
            apercuLigne(
              'N° demande stock',
              d['numeroDemandeStock'],
              LucideIcons.hash,
              kApArdoise,
            ),
            apercuLigne(
              'Articles',
              d['nbArticles'],
              LucideIcons.package,
              kApBleu,
            ),
            apercuLigne(
              'Articles sans B.C',
              d['nbArticlesSansBc'],
              LucideIcons.fileWarning,
              kApRouge,
            ),
            apercuLigneStatut('Statut', d['status'], avecIcone: true),
            apercuLigne(
              'Approuvé par',
              d['approuvePar'],
              LucideIcons.userCheck,
              kApVert,
            ),
            apercuLigne(
              'Date validation',
              apercuDate(d['dateValidation']),
              LucideIcons.calendarCheck,
              kApVert,
            ),
            apercuLigne(
              'Rejeté par',
              d['rejetePar'],
              LucideIcons.userX,
              kApRouge,
            ),
            apercuLigne(
              'Date rejet',
              apercuDate(d['dateRejet']),
              LucideIcons.calendarX,
              kApRouge,
            ),
            apercuLigne(
              'Description',
              d['description'],
              LucideIcons.fileText,
              kApArdoise,
            ),
          ],
        );
      }).toList(),
    );
  }

  /// Couleur d'un type de piece, comme sur la fiche web : BL vert,
  /// facture ambre, les autres types se partagent le reste de la palette.
  static const _palettePieces = [kApBleu, kApViolet, kApCyan, kApRouge];

  Color _couleurTypePiece(String type, List<String> autres) {
    final t = type.toUpperCase();
    if (t == 'BL') return kApVert;
    if (t == 'FACTURE') return kApAmbre;
    final rang = autres.indexOf(type);
    return _palettePieces[(rang < 0 ? 0 : rang) % _palettePieces.length];
  }

  IconData _iconeTypePiece(String type) {
    final t = type.toUpperCase();
    if (t == 'BL') return LucideIcons.truck;
    if (t == 'FACTURE') return LucideIcons.receipt;
    if (t.contains('COMMANDE')) return LucideIcons.shoppingCart;
    return LucideIcons.fileText;
  }

  String _typeDe(Map<String, dynamic> piece) =>
      (piece['typePiece'] ?? '—').toString().trim();

  String _typeDeReglement(Map<String, dynamic> piece) =>
      (piece['typeReglementCode'] ?? piece['typeReglementLibelle'] ?? '')
          .toString()
          .trim();

  /// Pieces justificatives : un filtre par code de reglement, puis un filtre
  /// par type de piece, comme sur la fiche OR.
  Widget _ongletReceptionFinanciere() {
    if (_pieces.isEmpty) return apercuVide('Aucune pièce justificative');

    final comptesReglement = <String, int>{};
    for (final p in _pieces) {
      final code = _typeDeReglement(p);
      if (code.isEmpty) continue;
      comptesReglement[code] = (comptesReglement[code] ?? 0) + 1;
    }
    final codes = comptesReglement.keys.toList()..sort();

    final parReglement = _codeReglement == null
        ? _pieces
        : _pieces.where((p) => _typeDeReglement(p) == _codeReglement).toList();

    final comptes = <String, int>{};
    for (final p in parReglement) {
      final t = _typeDe(p);
      comptes[t] = (comptes[t] ?? 0) + 1;
    }
    final types = comptes.keys.toList()..sort();
    final autres = types
        .where((t) => t.toUpperCase() != 'BL' && t.toUpperCase() != 'FACTURE')
        .toList();

    // Pas de « toutes » : un type est toujours selectionne, comme sur l'OR.
    final typeActif = types.contains(_typePiece)
        ? _typePiece!
        : (types.isEmpty ? '' : types.first);
    final visibles = parReglement
        .where((p) => _typeDe(p) == typeActif)
        .toList();

    return Column(
      children: [
        if (codes.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: SizedBox(
              height: 28,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final c in codes) ...[
                    if (c != codes.first) const SizedBox(width: 6),
                    FiltrePastille(
                      label: '$c (${comptesReglement[c]})',
                      icone: LucideIcons.creditCard,
                      couleur: kApCyan,
                      actif: _codeReglement == c,
                      // Un second appui enleve le filtre.
                      onTap: () => setState(
                        () => _codeReglement = _codeReglement == c ? null : c,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: SizedBox(
            height: 28,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final t in types) ...[
                  if (t != types.first) const SizedBox(width: 6),
                  FiltrePastille(
                    label: '$t (${comptes[t]})',
                    icone: _iconeTypePiece(t),
                    couleur: _couleurTypePiece(t, autres),
                    actif: typeActif == t,
                    onTap: () => setState(() => _typePiece = t),
                  ),
                ],
              ],
            ),
          ),
        ),
        Expanded(
          child: visibles.isEmpty
              ? apercuVide('Aucune pièce de ce type')
              : apercuScroll(
                  cle: ValueKey('$_codeReglement|$typeActif'),
                  visibles.map((p) {
                    final type = _typeDe(p);
                    final couleur = _couleurTypePiece(type, autres);
                    final reglement = [
                      _typeDeReglement(p),
                      (p['typeReglementLibelle'] ?? '').toString().trim(),
                    ].where((e) => e.isNotEmpty).toSet().join(' — ');

                    return apercuCarte(
                      titre: p['numPiece'],
                      icone: _iconeTypePiece(type),
                      couleur: couleur,
                      etiquette: type,
                      lignes: [
                        apercuLigne(
                          'Type de règlement',
                          reglement,
                          LucideIcons.creditCard,
                          kApCyan,
                        ),
                        apercuLigne(
                          'Prestataire',
                          p['prestataireLibelle'],
                          LucideIcons.briefcase,
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
                          LucideIcons.wallet,
                          kApVert,
                        ),
                        apercuLigne(
                          'BL liés',
                          p['blsNumeros'],
                          LucideIcons.truck,
                          kApVert,
                        ),
                        apercuLigne(
                          'Bon de commande',
                          p['bonCommandePieceNumero'],
                          LucideIcons.shoppingCart,
                          kApBleu,
                        ),
                        apercuLigne(
                          'Facture liée',
                          p['facturePieceNumero'],
                          LucideIcons.receipt,
                          kApViolet,
                        ),
                        apercuLigneStatut(
                          'Statut',
                          p['status'],
                          avecIcone: true,
                        ),
                      ],
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }

  Widget _ongletInformations() {
    return apercuScroll([
      apercuCarte(
        titre: _v('numero'),
        icone: LucideIcons.droplet,
        couleur: kApViolet,
        etiquette: _v('vehiculeImmatriculation')?.toString(),
        lignes: [
          apercuLigneStatut('Statut', _v('status'), avecIcone: true),
          apercuLigne(
            'Service',
            _v('servicesPrcLibelle') ?? _v('serviceLibelle'),
            LucideIcons.wrench,
            kApBleu,
          ),
          apercuLigne(
            'Lieu',
            _v('lieuReparation'),
            LucideIcons.mapPin,
            kApAmbre,
          ),
          apercuLigne(
            'Description',
            _v('description'),
            LucideIcons.fileText,
            kApArdoise,
          ),
          apercuLigne(
            'Observation',
            _v('observation'),
            LucideIcons.messageSquare,
            kApArdoise,
          ),
          apercuLigne(
            'Organisme',
            _v('organismeLibelle'),
            LucideIcons.building2,
            kApArdoise,
          ),
        ],
      ),
      apercuSection('Cycle de vidange', [
        apercuLigne(
          'Cycle',
          _v('cycleVidangeLibelle'),
          LucideIcons.repeat,
          kApCyan,
        ),
        apercuLigne(
          'Numéro de cycle',
          _v('cycleVidangeNumero'),
          LucideIcons.hash,
          kApArdoise,
        ),
        apercuLigne(
          'Kilométrage du cycle',
          apercuKm(_v('cycleVidangeKilometrage')),
          LucideIcons.gauge,
          kApBleu,
        ),
        apercuLigne(
          'Prochaine vidange',
          apercuKm(_v('prochainKmVidange')),
          LucideIcons.flag,
          kApVert,
        ),
      ]),
      apercuSection('Dernier commentaire', [
        apercuLigne(
          'Commentaire',
          _v('dernierCommentaire'),
          LucideIcons.messageCircle,
          kApArdoise,
        ),
        apercuLigne(
          'Auteur',
          _v('dernierCommentaireAuteur'),
          LucideIcons.user,
          kApBleu,
        ),
        apercuLigne(
          'Date',
          apercuDate(_v('dernierCommentaireDate')),
          LucideIcons.calendar,
          kApViolet,
        ),
      ]),
    ]);
  }

  Widget _ongletPlanification() {
    return apercuScroll([
      apercuSection('Planifié', [
        apercuLigne(
          'Début prévu',
          apercuDate(_v('dateDebutPrevu')),
          LucideIcons.calendar,
          kApBleu,
        ),
        apercuLigne(
          'Fin prévue',
          apercuDate(_v('dateFinPrevu')),
          LucideIcons.calendarCheck,
          kApBleu,
        ),
        apercuLigne(
          'Replanifications',
          _v('nbReplanification'),
          LucideIcons.repeat,
          kApAmbre,
        ),
        apercuLigne(
          'Motif de replanification',
          _v('motifReplanification'),
          LucideIcons.fileText,
          kApAmbre,
        ),
      ]),
      apercuSection('Réalisé', [
        apercuLigne(
          'Début',
          apercuDate(_v('dateDebut')),
          LucideIcons.playCircle,
          kApVert,
        ),
        apercuLigne(
          'Fin',
          apercuDate(_v('dateFin')),
          LucideIcons.checkCircle2,
          kApVert,
        ),
        apercuLigne(
          'Kilométrage',
          apercuKm(_v('kilometrage')),
          LucideIcons.gauge,
          kApBleu,
        ),
      ]),
      apercuSection('Validation', [
        apercuLigne(
          'Validée le',
          apercuDate(_v('dateValidation')),
          LucideIcons.calendarCheck,
          kApVert,
        ),
        apercuLigne(
          'Validée par',
          _v('validePar'),
          LucideIcons.userCheck,
          kApVert,
        ),
        apercuLigne(
          'Observation',
          _v('observationValidation'),
          LucideIcons.fileText,
          kApArdoise,
        ),
      ]),
      apercuSection('Rejet / annulation', [
        apercuLigne(
          'Rejetée le',
          apercuDate(_v('dateRejet')),
          LucideIcons.calendarX,
          kApRouge,
        ),
        apercuLigne(
          'Rejetée par',
          _v('rejetePar'),
          LucideIcons.userX,
          kApRouge,
        ),
        apercuLigne(
          'Motif du rejet',
          _v('observationRejet'),
          LucideIcons.fileText,
          kApRouge,
        ),
        apercuLigne(
          'Annulée le',
          apercuDate(_v('dateAnnulation')),
          LucideIcons.xCircle,
          kApRouge,
        ),
        apercuLigne(
          'Motif d\'annulation',
          _v('descriptionAnnulation'),
          LucideIcons.fileText,
          kApRouge,
        ),
      ]),
    ]);
  }

  Widget _ongletVehicule() {
    return apercuScroll([
      apercuCarte(
        titre: [
          _v('vehiculeMarqueLibelle') ?? _v('marqueLibelle'),
          _v('vehiculeModeleLibelle') ?? _v('modeleLibelle'),
        ].where((e) => e != null && e.toString().trim().isNotEmpty).join(' '),
        icone: LucideIcons.truck,
        couleur: kApBleu,
        etiquette: _v('vehiculeImmatriculation')?.toString(),
        lignes: [
          apercuLigne(
            'Kilométrage actuel',
            apercuKm(_v('vehiculeKmActuel')),
            LucideIcons.gauge,
            kApBleu,
          ),
          apercuLigne(
            'Km dernière vidange',
            apercuKm(_v('vehiculeKmVidange')),
            LucideIcons.droplet,
            kApViolet,
          ),
          apercuLigne(
            'Mise en service',
            apercuDate(_v('vehiculeDateMiseEnService')),
            LucideIcons.calendar,
            kApViolet,
          ),
          apercuLigne(
            'Chauffeur',
            _v('chauffeurNom'),
            LucideIcons.user,
            kApCyan,
          ),
        ],
      ),
      apercuSection('Vidanges précédentes', [
        apercuLigne(
          'Dernière vidange',
          _v('derniereVidangeNumero'),
          LucideIcons.hash,
          kApViolet,
        ),
        apercuLigne(
          'Date',
          apercuDate(_v('derniereVidangeDate')),
          LucideIcons.calendar,
          kApViolet,
        ),
        apercuLigne(
          'Kilométrage',
          apercuKm(_v('derniereVidangeKilometrage')),
          LucideIcons.gauge,
          kApBleu,
        ),
        apercuLigne(
          'Vidange précédente',
          _v('vidangePrecedenteNumero'),
          LucideIcons.hash,
          kApArdoise,
        ),
        apercuLigne(
          'Kilométrage',
          apercuKm(_v('vidangePrecedenteKilometrage')),
          LucideIcons.gauge,
          kApArdoise,
        ),
      ]),
      apercuSection('Dernières synchronisations', [
        apercuLigne(
          'GPS',
          apercuDate(_v('vehiculeSyncGps')),
          LucideIcons.satellite,
          kApCyan,
        ),
        apercuLigne(
          'Gasoil',
          apercuDate(_v('vehiculeSyncGasoil')),
          LucideIcons.fuel,
          kApAmbre,
        ),
        apercuLigne(
          'Feuille de route',
          apercuDate(_v('vehiculeSyncFeuilleRoute')),
          LucideIcons.clipboardList,
          kApViolet,
        ),
      ]),
    ]);
  }

  Widget _ongletPrestataires() {
    final brut = _v('prestataires');
    final prestataires = brut is List
        ? brut.whereType<Map>().toList()
        : const [];

    if (prestataires.isEmpty) return apercuVide('Aucun prestataire');

    return apercuScroll(
      prestataires
          .map(
            (p) => apercuCarte(
              titre: p['libelle'] ?? p['prestataireLibelle'],
              icone: LucideIcons.briefcase,
              couleur: kApAmbre,
              lignes: [
                apercuLigne(
                  'Téléphone',
                  p['telephone'],
                  LucideIcons.phone,
                  kApVert,
                ),
                apercuLigne('E-mail', p['email'], LucideIcons.mail, kApBleu),
                apercuLigne(
                  'Ville',
                  p['villeLibelle'],
                  LucideIcons.building2,
                  kApCyan,
                ),
              ],
            ),
          )
          .toList(),
    );
  }
}
