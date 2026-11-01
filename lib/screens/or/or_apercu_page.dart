import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:lucide_icons/lucide_icons.dart';
import 'package:printing/printing.dart';

import '../../controllers/auth_controller.dart';
import '../../services/api_service.dart';
import '../../widgets/ambient_background.dart';
import '../../widgets/actions_bon.dart';
import '../../widgets/apercu_kit.dart';
import '../../controllers/vehicule_controller.dart';
import '../../models/vehicule_model.dart';
import '../demandes/demande_or_apercu_page.dart';
import '../vehicules/vehicule_apercu_page.dart';
import '../../widgets/historique_vehicule.dart';
import '../../widgets/page_entrance_animation.dart';

/// Aperçu d'un ordre de réparation.
/// Reprend le découpage de la fiche web : informations, prestataires,
/// approvisionnement, réparation, contrôle qualité, réception financière,
/// intervenants. Seuls les bons d'approvisionnement et d'achat portent des
/// actions (valider, rejeter, supprimer), soumises aux droits de l'utilisateur.
class OrApercuPage extends StatefulWidget {
  final Map<String, dynamic> ordre;

  /// Onglet ouvert a l'arrivee : 0 Informations, 1 Prestataires,
  /// 2 Approvisionnement, 3 Ligne demande, 4 Reparation & controle,
  /// 5 Reception financiere, 6 Intervenants, 7 Historique.
  final int ongletInitial;

  const OrApercuPage({super.key, required this.ordre, this.ongletInitial = 0});

  @override
  State<OrApercuPage> createState() => _OrApercuPageState();
}

class _OrApercuPageState extends State<OrApercuPage>
    with SingleTickerProviderStateMixin {
  /// 2 px de barre de chargement + hauteur d'un TabBar de texte.
  static const double _hauteurOnglets = 48;

  // Palette des lignes d'information : une couleur par famille de donnée
  // (identifiants, dates, véhicule, personnes, lieux, alertes).
  static const _bleu = kApBleu;
  static const _violet = kApViolet;
  static const _cyan = kApCyan;
  static const _vert = kApVert;
  static const _ambre = kApAmbre;
  static const _rouge = kApRouge;
  static const _ardoise = kApArdoise;

  static const _onglets = [
    'Informations',
    'Prestataires',
    'Approvisionnement',
    'Ligne demande',
    'Réparation & contrôle',
    'Réception financière',
    'Intervenants',
    'Historique',
  ];

  late final TabController _tabController;
  final _infoPageController = PageController();
  int _infoPage = 0;
  int _typePiece = 0;
  int _typeBon = 0;
  final _impressionEnCours = <int>{};

  // Un seul contrôleur pour la page : en créer un par dialogue le faisait
  // utiliser après dispose() pendant l'animation de fermeture.
  final _commentaireBon = TextEditingController();
  final _auth = Get.find<AuthController>();

  Map<String, dynamic> _ordre = const {};
  List<Map<String, dynamic>> _prestataires = const [];
  List<Map<String, dynamic>> _demandesAchat = const [];
  List<Map<String, dynamic>> _lignes = const [];
  List<Map<String, dynamic>> _pieces = const [];
  List<Map<String, dynamic>> _intervenants = const [];

  bool _chargement = true;

  int? get _orId {
    final id = _ordre['id'] ?? widget.ordre['id'];
    return id is int ? id : int.tryParse(id?.toString() ?? '');
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: _onglets.length,
      vsync: this,
      initialIndex: widget.ongletInitial.clamp(0, _onglets.length - 1),
    );
    _ordre = Map<String, dynamic>.from(widget.ordre);
    _chargerTout();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _infoPageController.dispose();
    _commentaireBon.dispose();
    super.dispose();
  }

  /// Chaque ressource est indépendante : un échec laisse les autres onglets
  /// utilisables plutôt que de vider toute la fiche.
  Future<void> _chargerTout() async {
    final id = _orId;
    if (id == null) {
      setState(() => _chargement = false);
      return;
    }

    final resultats = await Future.wait([
      _charger(ApiService.getOr(id)),
      _chargerListe(ApiService.getPrestatairesByOr(id), method: 'POST'),
      _chargerListe(ApiService.getDemandesAchatsByOr(id)),
      _chargerListe(ApiService.getLignesByOr(id)),
      _chargerListe(ApiService.getPiecesByOr(id)),
      _chargerListe(ApiService.getIntervenantsByOr(id)),
    ]);

    final prestataires = await _avecCoordonnees(
      resultats[1] as List<Map<String, dynamic>>,
    );

    if (!mounted) return;
    setState(() {
      final detail = resultats[0];
      if (detail is Map<String, dynamic> && detail.isNotEmpty) {
        _ordre = {..._ordre, ...detail};
      }
      _prestataires = prestataires;
      _demandesAchat = resultats[2] as List<Map<String, dynamic>>;
      _lignes = resultats[3] as List<Map<String, dynamic>>;
      _pieces = resultats[4] as List<Map<String, dynamic>>;
      _intervenants = resultats[5] as List<Map<String, dynamic>>;
      _chargement = false;
    });
  }

  /// fournisseursOtPrc ne renvoie que l'id et le libellé du prestataire : on
  /// complète avec adresse / téléphone / e-mail, comme le fait la fiche web.
  /// Les ids identiques ne sont interrogés qu'une fois.
  Future<List<Map<String, dynamic>>> _avecCoordonnees(
    List<Map<String, dynamic>> prestataires,
  ) async {
    final ids = prestataires
        .map((p) => p['prestataireId'])
        .whereType<int>()
        .toSet()
        .toList();
    if (ids.isEmpty) return prestataires;

    final details = await Future.wait(
      ids.map((id) => _charger(ApiService.getFournisseur(id))),
    );

    final parId = <int, Map<String, dynamic>>{};
    for (var i = 0; i < ids.length; i++) {
      final d = details[i];
      if (d is Map<String, dynamic>) parId[ids[i]] = d;
    }

    return prestataires.map((p) {
      final d = parId[p['prestataireId']];
      if (d == null) return p;
      return {
        ...p,
        'adresse': d['adresse'],
        'telephone': d['telephone'],
        'email': d['email'],
        'villeLibelle': d['villeLibelle'],
        'description': p['description'] ?? d['description'],
      };
    }).toList();
  }

  Future<dynamic> _charger(String url, {String method = 'GET'}) async {
    try {
      final data = await _auth.makeRequest(
        url,
        method: method,
        body: method == 'POST' ? const <String, dynamic>{} : null,
        showErrorSnackbar: false,
      );
      if (data is Map) return Map<String, dynamic>.from(data);
      return data;
    } catch (_) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> _chargerListe(
    String url, {
    String method = 'GET',
  }) async {
    final data = await _charger(url, method: method);
    final contenu = data is Map ? (data['content'] ?? data['data']) : data;
    if (contenu is List) {
      return contenu
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return const [];
  }

  @override
  Widget build(BuildContext context) {
    final numero =
        _ordre['numero']?.toString() ??
        _ordre['numeroOrdreReparation']?.toString() ??
        'Ordre de réparation';

    // La barre flotte au-dessus du dégradé : le contenu des onglets est décalé
    // d'autant, sinon il passerait dessous.
    final hauteurBarre =
        MediaQuery.of(context).padding.top + kToolbarHeight + _hauteurOnglets;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1F3A5F), Color(0xFF2563EB)],
            ),
          ),
        ),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, size: 20),
          color: Colors.white,
          onPressed: () => Get.back(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              numero,
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            Text(
              'Consultation',
              style: GoogleFonts.poppins(
                fontSize: 10.5,
                color: Colors.white.withValues(alpha: 0.75),
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(_hauteurOnglets),
          child: Column(
            children: [
              // Hauteur réservée en permanence : sinon l'apparition de la barre
              // de chargement fait déborder le PreferredSize de 2 px.
              SizedBox(
                height: 2,
                child: _chargement
                    ? const LinearProgressIndicator(minHeight: 2)
                    : null,
              ),
              TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white.withValues(alpha: 0.70),
                indicatorColor: Colors.white,
                indicatorSize: TabBarIndicatorSize.label,
                labelStyle: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelStyle: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                tabs: _onglets.map((t) => Tab(text: t)).toList(),
              ),
            ],
          ),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Meme fond que la liste des OR (ecran d'accueil) : sans lui, les
          // cartes en verre se detachent sur un gris plat.
          const AmbientBackground(),
          Padding(
            padding: EdgeInsets.only(top: hauteurBarre),
            child: TabBarView(
              controller: _tabController,
              children: [
                // Maintenu en vie : sinon TabBarView le détruit au changement
                // d'onglet, le PageView se recrée sur la page 0 et _infoPage
                // reste sur 1 — le sélecteur et la carte se désynchronisent.
                _GarderEnVie(child: _ongletInformations()),
                _ongletPrestataires(),
                _ongletApprovisionnement(),
                _ongletLigneDemande(),
                _ongletReparationControle(),
                _ongletReceptionFinanciere(),
                _ongletIntervenants(),
                _ongletHistorique(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Onglets ──

  /// Deux cartes en slider, sur le modèle de la page profil : sélecteur en
  /// haut, PageView, points en bas.
  Widget _ongletInformations() {
    final o = _ordre;

    // Cet onglet est maintenu en vie : l'animation joue à l'ouverture de la
    // page, pas à chaque retour sur l'onglet (sinon le PageView serait recréé
    // et le sélecteur se désynchroniserait à nouveau).
    return Column(
      children: [
        PageEntranceAnimation(
          duration: const Duration(milliseconds: 380),
          slideOffset: 18,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: _selecteurInfo(),
          ),
        ),
        ?_boutonDemande(o),
        const SizedBox(height: 14),
        Expanded(
          child: PageEntranceAnimation(
            duration: const Duration(milliseconds: 420),
            delay: const Duration(milliseconds: 90),
            slideOffset: 22,
            child: PageView(
              controller: _infoPageController,
              onPageChanged: (index) => setState(() => _infoPage = index),
              children: [
                _carteInfo(
                  'Information ordre réparation',
                  LucideIcons.clipboardList,
                  [
                    _ligneRiche(
                      'Matricule',
                      o['vehiculeImmatriculation'],
                      LucideIcons.truck,
                      _cyan,
                    ),
                    // L'ordre et sa date partagent une couleur, la demande et
                    // la sienne une autre : chaque document se lit d'un bloc.
                    _ligneRiche(
                      'Numéro OR',
                      o['numeroOrdreReparation'] ?? o['numero'],
                      LucideIcons.hash,
                      _bleu,
                    ),
                    _ligneRiche(
                      'Date OR',
                      _date(o['dateOrdreReparation']),
                      LucideIcons.calendar,
                      _bleu,
                    ),
                    _ligneRiche(
                      'N° demande',
                      o['numeroDemande'],
                      LucideIcons.fileText,
                      _violet,
                    ),
                    _ligneRiche(
                      'Date demande',
                      _date(o['dateDemande']),
                      LucideIcons.calendarDays,
                      _violet,
                    ),
                    _ligneRiche(
                      'Natures d\'anomalie',
                      _naturesAnomalies(o),
                      LucideIcons.alertTriangle,
                      _rouge,
                    ),
                    _ligneStatut('Statut', o['status'], avecIcone: true),
                    _ligneRiche(
                      'Étape',
                      o['workflowDORLibelle'],
                      LucideIcons.workflow,
                      _bleu,
                    ),
                    _ligneRiche(
                      'Type de demande',
                      o['typeDemandeORLibelle'],
                      LucideIcons.tag,
                      _ardoise,
                    ),
                    _ligneRiche(
                      'Type intervention',
                      o['typeInterventionLibelle'],
                      LucideIcons.wrench,
                      _cyan,
                    ),
                    _ligneRiche(
                      'Priorité',
                      o['prioriteLibelle'],
                      LucideIcons.alertTriangle,
                      _couleurPriorite(o['prioriteLibelle']),
                    ),
                    _ligneRiche(
                      'Service',
                      o['servicesPrcLibelle'],
                      LucideIcons.briefcase,
                      _ardoise,
                    ),
                    _ligneRiche(
                      'Lieu de réparation',
                      o['lieuReparation'],
                      LucideIcons.mapPin,
                      _ambre,
                    ),
                    _ligneRiche(
                      'Intervention souhaitée',
                      _date(o['dateSouhaiteeIntervention']),
                      LucideIcons.calendarCheck,
                      _violet,
                    ),
                    _ligneRiche(
                      'Demandeur',
                      o['demandeurNomComplet'],
                      LucideIcons.user,
                      _vert,
                    ),
                    _ligneRiche(
                      'Chauffeur',
                      o['chauffeurNomComplet'],
                      LucideIcons.userCheck,
                      _vert,
                    ),
                    _ligneRiche(
                      'Fournisseur',
                      o['fournisseurLibelle'],
                      LucideIcons.building2,
                      _ambre,
                    ),
                    _ligneRiche(
                      'Problème',
                      o['descriptionProbleme'],
                      LucideIcons.alertOctagon,
                      _ardoise,
                    ),
                    _ligneRiche(
                      'Commentaire',
                      o['commentaire'],
                      LucideIcons.fileText,
                      _ardoise,
                    ),
                  ],
                ),
                // La carte ouvre la fiche vehicule au tap.
                GestureDetector(
                  onTap: _ouvrirVehicule,
                  child: _carteInfo('Véhicule', LucideIcons.truck, [
                    _ligneRiche(
                      'Immatriculation',
                      o['vehiculeImmatriculation'],
                      LucideIcons.truck,
                      _cyan,
                    ),
                    _ligneRiche(
                      'Marque',
                      o['vehiculeMarqueLibelle'],
                      LucideIcons.tag,
                      _bleu,
                    ),
                    _ligneRiche(
                      'Modèle',
                      o['vehiculeModeleLibelle'],
                      LucideIcons.car,
                      _bleu,
                    ),
                    _ligneRiche(
                      'Catégorie',
                      o['vehiculeCategorieLibelle'],
                      LucideIcons.layers,
                      _violet,
                    ),
                    _ligneRiche(
                      'Genre',
                      o['vehiculeGenreLibelle'],
                      LucideIcons.shieldCheck,
                      _ardoise,
                    ),
                    _ligneRiche(
                      'Type',
                      o['vehiculetype'],
                      LucideIcons.truck,
                      _ardoise,
                    ),
                    _ligneRiche(
                      'Kilométrage',
                      _km(o['kilometrage']),
                      LucideIcons.gauge,
                      _bleu,
                    ),
                    _ligneRiche(
                      'Km réparation',
                      _km(o['kilometrageReparation']),
                      LucideIcons.milestone,
                      _ambre,
                    ),
                    _ligneRiche(
                      'Localisation',
                      o['localisationVehicule'],
                      LucideIcons.mapPin,
                      _ambre,
                    ),
                    _ligneRiche(
                      'Immobilisé',
                      o['vehiculeImmobilise'] == null
                          ? null
                          : (o['vehiculeImmobilise'] == true ? 'Oui' : 'Non'),
                      LucideIcons.lock,
                      o['vehiculeImmobilise'] == true ? _rouge : _vert,
                    ),
                  ]),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        _pointsInfo(),
        const SizedBox(height: 18),
      ],
    );
  }

  Widget _selecteurInfo() {
    Widget pilule(int index, String label, IconData icone) {
      final actif = _infoPage == index;
      return Expanded(
        child: GestureDetector(
          onTap: () => _infoPageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeInOutCubic,
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              color: actif ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              boxShadow: actif
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icone,
                  size: 15,
                  color: actif
                      ? const Color(0xFF1F3A5F)
                      : const Color(0xFF64748B),
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: actif ? FontWeight.w600 : FontWeight.w500,
                    color: actif
                        ? const Color(0xFF1F3A5F)
                        : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.70),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.90),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1F3A5F).withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          pilule(0, 'Ordre', LucideIcons.clipboardList),
          pilule(1, 'Véhicule', LucideIcons.truck),
        ],
      ),
    );
  }

  Widget _pointsInfo() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        2,
        (index) => GestureDetector(
          onTap: () => _infoPageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeInOutCubic,
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: _infoPage == index ? 24 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: _infoPage == index
                  ? const Color(0xFF2563EB)
                  : const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ),
    );
  }

  /// Raccourci vers la demande dont l'ordre est issu : la fiche demande se
  /// recharge depuis son identifiant.
  Widget? _boutonDemande(Map<String, dynamic> o) {
    final id = (o['demandeORId'] as num?)?.toInt();
    if (id == null) return null;

    final numero = (o['numeroDemande'] ?? '').toString().trim();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () =>
              Get.to(() => DemandeOrApercuPage(demande: {'id': id})),
          icon: const Icon(LucideIcons.externalLink, size: 16),
          label: Text(
            numero.isEmpty ? 'Voir la demande' : 'Voir la demande $numero',
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: _violet,
            foregroundColor: Colors.white,
            elevation: 0,
            minimumSize: const Size(0, 44),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  /// Fiche du vehicule : prise dans le controleur deja charge, sinon lue sur
  /// le serveur.
  Future<void> _ouvrirVehicule() async {
    final id = _ordre['vehiculeId'];
    if (id is! int) return;

    if (Get.isRegistered<VehiculeController>()) {
      for (final v in Get.find<VehiculeController>().vehicules) {
        if (v.id == id) {
          Get.to(() => VehiculeApercuPage(vehicule: v));

          return;
        }
      }
    }

    try {
      final data = await _auth.makeRequest(
        ApiService.getVehicule(id),
        method: 'GET',
        showErrorSnackbar: false,
      );
      final brut = data is Map ? (data['data'] ?? data) : null;
      if (brut is Map) {
        Get.to(
          () => VehiculeApercuPage(
            vehicule: VehiculeModel.fromJson(Map<String, dynamic>.from(brut)),
          ),
        );
      }
    } catch (_) {
      // Fiche indisponible : on reste sur l'ordre.
    }
  }

  Widget _carteInfo(String titre, IconData icone, List<Widget?> lignes) {
    final visibles = lignes.whereType<Widget>().toList();

    // Le scroll est au-dessus du Container : sans cela, PageView impose sa
    // hauteur et la carte s'étire bien au-delà de son contenu.
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.95),
            width: 1.3,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1F3A5F).withValues(alpha: 0.06),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF2563EB,
                          ).withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          icone,
                          size: 16,
                          color: const Color(0xFF2563EB),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          titre,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (visibles.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        'Aucune information',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                    )
                  else
                    ...visibles,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _ongletPrestataires() {
    if (_prestataires.isEmpty) return _vide('Aucun prestataire');
    return _scroll(
      _prestataires
          .map(
            (p) => _carte(
              titre: p['prestataireLibelle'] ?? p['fournisseurLibelle'],
              icone: LucideIcons.briefcase,
              couleur: const Color(0xFFD97706),
              lignes: [
                _ligneRiche(
                  'Téléphone',
                  p['telephone'],
                  LucideIcons.phone,
                  _vert,
                ),
                _ligneRiche('E-mail', p['email'], LucideIcons.mail, _bleu),
                _ligneRiche(
                  'Adresse',
                  p['adresse'],
                  LucideIcons.mapPin,
                  _ambre,
                ),
                _ligneRiche(
                  'Ville',
                  p['villeLibelle'],
                  LucideIcons.building2,
                  _cyan,
                ),
                _ligneRiche(
                  'Description',
                  p['description'],
                  LucideIcons.fileText,
                  _ardoise,
                ),
                _ligneRiche(
                  'Date',
                  _date(p['dateCreation']),
                  LucideIcons.calendar,
                  _violet,
                ),
                _ligneStatut('Statut', p['status'], avecIcone: true),
              ],
            ),
          )
          .toList(),
    );
  }

  /// Impression d'un bon. Le rapport arrive en PDF binaire : makeRequest
  /// décode du JSON, on passe donc par un GET brut avec le même jeton.
  Future<void> _imprimerBon(Map<String, dynamic> d) async {
    final id = d['id'];
    if (id is! int || _impressionEnCours.contains(id)) return;

    setState(() => _impressionEnCours.add(id));
    try {
      final appro = _estAppro(d);
      final url = appro
          ? ApiService.rapportBonApprovisionnement(id)
          : ApiService.rapportDemandeAchat(id);

      final reponse = await http
          .get(
            Uri.parse(url),
            headers: {
              if (_auth.userToken.value.isNotEmpty)
                'Authorization': 'Bearer ${_auth.userToken.value}',
            },
          )
          .timeout(const Duration(seconds: 45));

      if (reponse.statusCode == 403) {
        throw Exception(
          'Acces refuse : droit REPORT ou BON_ACHAT / BON_APPRO manquant',
        );
      }
      if (reponse.statusCode != 200) {
        throw Exception('Erreur serveur ${reponse.statusCode}');
      }
      if (reponse.bodyBytes.isEmpty) {
        throw Exception('PDF vide renvoye par le serveur');
      }

      final nom = (d['numeroDemande'] ?? 'bon').toString();
      await Printing.layoutPdf(
        onLayout: (_) async => Uint8List.fromList(reponse.bodyBytes),
        name: appro ? 'Bon appro $nom' : 'Bon achat $nom',
      );
    } catch (e) {
      // Le message exact est indispensable pour distinguer un 403, un PDF vide
      // et un MissingPluginException (plugin ajoute sans rebuild complet).
      debugPrint('Impression bon : $e');
      final message = e is MissingPluginException
          ? 'Plugin d\'impression non chargé : relancez l\'application (rebuild complet).'
          : e.toString().replaceFirst('Exception: ', '');
      Get.snackbar(
        'Impression impossible',
        message,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.white,
        colorText: const Color(0xFF0F172A),
        margin: const EdgeInsets.all(12),
        duration: const Duration(seconds: 6),
      );
    } finally {
      if (mounted) setState(() => _impressionEnCours.remove(id));
    }
  }

  Widget _boutonImprimer(Map<String, dynamic> d) {
    // Un droit d'impression par type de bon, comme sur le web.
    final user = _auth.currentUser.value;
    final droit = _estAppro(d) ? 'BON_APPRO_IMPRIMER' : 'DA_IMPRIMER';
    if (!(user?.hasAuthority(droit) ?? false)) return const SizedBox.shrink();

    final enCours = _impressionEnCours.contains(d['id']);

    return GestureDetector(
      onTap: enCours ? null : () => _imprimerBon(d),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: _bleu.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _bleu.withValues(alpha: 0.30)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (enCours)
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 1.8),
              )
            else
              const Icon(LucideIcons.printer, size: 13, color: _bleu),
            const SizedBox(width: 5),
            Text(
              'Imprimer',
              style: GoogleFonts.poppins(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: _bleu,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Verrou lecture seule de l'ordre : clôturé ou annulé, comme `isCloture`
  /// côté web.
  bool get _orVerrouille {
    final statut = (_ordre['status'] ?? '').toString().toUpperCase();
    return _ordre['dateCloture'] != null ||
        statut.contains('CLÔTUR') ||
        statut.contains('CLOTUR') ||
        statut.contains('ANNUL');
  }

  /// Valider / rejeter / supprimer un bon. Chaque action a son propre droit
  /// côté backend : on masque ce que l'utilisateur ne peut pas faire plutôt que
  /// de lui laisser déclencher un 403.
  /// Le backend ne distingue bon d'appro et bon d'achat que par le champ `type`
  /// (même règle que la fiche web : "APPRO" dans le type = bon d'approvisionnement).
  bool _estAppro(Map<String, dynamic> d) {
    final type = (d['type'] ?? d['typeDemande'] ?? '').toString().toUpperCase();
    return type.contains('APPRO');
  }

  /// Routes des actions sur un bon, cote ordre de reparation.
  String _urlActionBon(String action, bool appro, int id) => switch (action) {
    'valider' =>
      appro
          ? ApiService.validerBonApprovisionnement(id)
          : ApiService.validerBonAchat(id),
    'rejeter' =>
      appro
          ? ApiService.rejeterBonApprovisionnement(id)
          : ApiService.rejeterBonAchat(id),
    _ =>
      appro
          ? ApiService.supprimerBonApprovisionnement(id)
          : ApiService.supprimerBonAchat(id),
  };

  Widget _ongletApprovisionnement() {
    if (_demandesAchat.isEmpty) return _vide('Aucun bon');

    final appros = _demandesAchat.where(_estAppro).toList();
    final achats = _demandesAchat.where((d) => !_estAppro(d)).toList();

    Widget carte(Map<String, dynamic> d, bool appro) => _carte(
      titre: d['numeroDemande'] ?? d['numeroDemandeStock'],
      icone: appro ? LucideIcons.truck : LucideIcons.shoppingCart,
      couleur: appro ? const Color(0xFF0891B2) : const Color(0xFF2563EB),
      etiquette: appro ? 'Bon d\'approvisionnement' : 'Bon d\'achat',
      action: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _boutonImprimer(d),
          MenuActionsBon(
            bon: d,
            appro: appro,
            verrouille: _orVerrouille,
            commentaire: _commentaireBon,
            url: _urlActionBon,
            onTermine: _chargerTout,
          ),
        ],
      ),
      lignes: [
        _ligneRiche(
          'Prestataire',
          d['prestataireLibelle'],
          LucideIcons.building2,
          _ambre,
        ),
        _ligneRiche('Demandeur', d['demandeur'], LucideIcons.user, _vert),
        _ligneRiche(
          'Date demande',
          _date(d['dateDemande']),
          LucideIcons.calendar,
          _violet,
        ),
        _ligneRiche(
          'N° demande stock',
          d['numeroDemandeStock'],
          LucideIcons.hash,
          _bleu,
        ),
        _ligneRiche(
          'Articles',
          d['nbArticles'],
          LucideIcons.clipboardList,
          _bleu,
        ),
        _ligneRiche(
          'Articles sans BC',
          d['nbArticlesSansBc'],
          LucideIcons.fileWarning,
          _ambre,
        ),
        _ligneStatut('Statut', d['status'], avecIcone: true),
        _ligneRiche(
          'Approuvé par',
          d['approuvePar'],
          LucideIcons.userCheck,
          _vert,
        ),
        _ligneRiche(
          'Date validation',
          _date(d['dateValidation']),
          LucideIcons.calendarCheck,
          _vert,
        ),
        _ligneRiche(
          'Rejeté par',
          d['rejetePar'],
          LucideIcons.userCheck,
          _rouge,
        ),
        _ligneRiche(
          'Date rejet',
          _date(d['dateRejet']),
          LucideIcons.calendarX,
          _rouge,
        ),
        _ligneRiche(
          'Description',
          d['description'],
          LucideIcons.fileText,
          _ardoise,
        ),
      ],
    );

    final estAppro = _typeBon == 1;
    final selection = estAppro ? appros : achats;
    final nom = estAppro ? 'Bons d\'approvisionnement' : 'Bons d\'achat';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: _boutonFiltre(
                  actif: !estAppro,
                  onTap: () => setState(() => _typeBon = 0),
                  label: 'Bon d\'achat',
                  icone: LucideIcons.shoppingCart,
                  couleur: _bleu,
                  nombre: achats.length,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _boutonFiltre(
                  actif: estAppro,
                  onTap: () => setState(() => _typeBon = 1),
                  label: 'Bon d\'appro',
                  icone: LucideIcons.truck,
                  couleur: _cyan,
                  nombre: appros.length,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: selection.isEmpty
              ? _vide(estAppro ? 'Aucun bon d\'appro' : 'Aucun bon d\'achat')
              : _scroll(cle: ValueKey(_typeBon), [
                  _titreGroupe('$nom (${selection.length})'),
                  ...selection.map((d) => carte(d, estAppro)),
                ]),
        ),
      ],
    );
  }

  Widget _ongletLigneDemande() {
    if (_lignes.isEmpty) return _vide('Aucune ligne de demande');
    return _scroll(
      _lignes
          .map(
            (l) => _carte(
              titre:
                  l['produitLibelle'] ??
                  l['designationProduit'] ??
                  l['description'],
              icone: LucideIcons.clipboardList,
              couleur: const Color(0xFF0891B2),
              etiquette: l['produitCode']?.toString(),
              lignes: [
                _ligneRiche(
                  'Description',
                  l['description'],
                  LucideIcons.fileText,
                  _ardoise,
                ),
                _ligneRiche('Quantité', l['qte'], LucideIcons.hash, _bleu),
                _ligneRiche('Unité', l['unite'], LucideIcons.tag, _ardoise),
                _ligneRiche(
                  'Prix unitaire',
                  _montant(l['prixUnit']),
                  LucideIcons.creditCard,
                  _bleu,
                ),
                _ligneRiche(
                  'Remise',
                  _pourcent(l['tauxRemise']),
                  LucideIcons.tag,
                  _ambre,
                ),
                _ligneRiche(
                  'TVA',
                  _pourcent(l['tauxTva']),
                  LucideIcons.hash,
                  _ambre,
                ),
                _ligneRiche(
                  'Montant HT',
                  _montant(l['montantHt']),
                  LucideIcons.receipt,
                  _bleu,
                ),
                _ligneRiche(
                  'Montant TVA',
                  _montant(l['montantTva']),
                  LucideIcons.hash,
                  _ambre,
                ),
                _ligneRiche(
                  'Montant TTC',
                  _montant(l['montantTtc']),
                  LucideIcons.creditCard,
                  _vert,
                ),
                _ligneRiche(
                  'N° série',
                  l['numSerie'],
                  LucideIcons.qrCode,
                  _ardoise,
                ),
                _ligneRiche(
                  'Prestataire',
                  l['prestataireLibelle'],
                  LucideIcons.building2,
                  _ambre,
                ),
                _ligneRiche(
                  'Demande achat',
                  l['numeroDemandeAchat'],
                  LucideIcons.shoppingCart,
                  _bleu,
                ),
                _ligneRiche(
                  'Bon appro',
                  l['numeroBonApprovisionnement'],
                  LucideIcons.truck,
                  _cyan,
                ),
                _ligneRiche('BL', l['numeroBl'], LucideIcons.truck, _vert),
                _ligneRiche(
                  'Facture',
                  l['numeroFacture'],
                  LucideIcons.receipt,
                  _violet,
                ),
                _ligneRiche(
                  'Bon de commande',
                  l['numeroBc'],
                  LucideIcons.shoppingCart,
                  _bleu,
                ),
                _ligneRiche(
                  'Devis',
                  l['numeroDevis'],
                  LucideIcons.fileText,
                  _ambre,
                ),
                _ligneStatut('Statut', l['status'], avecIcone: true),
              ],
            ),
          )
          .toList(),
    );
  }

  /// Réparation technique et contrôle qualité : deux étapes successives du
  /// même ordre, regroupées sur un seul onglet.
  Widget _ongletReparationControle() {
    final o = _ordre;
    return _scroll([
      _section('Réparation technique', [
        _ligneRiche(
          'Date réparation',
          _date(o['dateReparation']),
          LucideIcons.wrench,
          _cyan,
        ),
        _ligneRiche(
          'Description',
          o['descriptionReparation'],
          LucideIcons.fileText,
          _ardoise,
        ),
        _ligneRiche(
          'Date début',
          _date(o['dateDebut']),
          LucideIcons.calendar,
          _bleu,
        ),
        _ligneRiche(
          'Date fin',
          _date(o['dateFin']),
          LucideIcons.calendarCheck,
          _bleu,
        ),
        _ligneRiche('Durée', o['dureeStr'], LucideIcons.clock, _ambre),
      ]),
      _section('Contrôle qualité', [
        _ligneRiche(
          'Date contrôle',
          _date(o['dateReparationTechnique']),
          LucideIcons.shieldCheck,
          _vert,
        ),
        _ligneRiche(
          'Description',
          o['descriptionReparationTechnique'],
          LucideIcons.fileText,
          _ardoise,
        ),
        _ligneRiche(
          'Km contrôle qualité',
          _km(o['kmControleQualite']),
          LucideIcons.gauge,
          _bleu,
        ),
      ]),
    ]);
  }

  Widget _ongletReceptionFinanciere() {
    // typePiece en base : BL, FACTURE, B.COMMANDE. DEVIS est prévu par le
    // modèle mais aucune pièce n'en porte encore le type.
    List<Map<String, dynamic>> parType(String motif) => _pieces
        .where(
          (p) =>
              (p['typePiece'] ?? '').toString().toUpperCase().contains(motif),
        )
        .toList();

    final bls = parType('BL');
    final factures = parType('FACTURE');
    final bonsCommande = parType('COMMANDE');
    final devis = parType('DEVIS');

    Widget carte(Map<String, dynamic> p, Color couleur, IconData icone) =>
        _carte(
          titre: p['numPiece'],
          icone: icone,
          couleur: couleur,
          etiquette: p['typePiece']?.toString(),
          lignes: [
            _ligneRiche(
              'Prestataire',
              p['prestataireLibelle'],
              LucideIcons.building2,
              _ambre,
            ),
            _ligneRiche(
              'Date pièce',
              _date(p['datePiece']),
              LucideIcons.calendar,
              _violet,
            ),
            _ligneRiche(
              'Date réception',
              _date(p['dateReception']),
              LucideIcons.calendarCheck,
              _cyan,
            ),
            _ligneRiche(
              'Règlement',
              p['typeReglementLibelle'],
              LucideIcons.creditCard,
              _ardoise,
            ),
            // HT / TVA / TTC : le total est mis en avant en vert.
            _ligneRiche(
              'Montant HT',
              _montant(p['mntHt']),
              LucideIcons.receipt,
              _bleu,
            ),
            _ligneRiche(
              'Montant TVA',
              _montant(p['mntTva']),
              LucideIcons.hash,
              _ambre,
            ),
            _ligneRiche(
              'Montant TTC',
              _montant(p['mntTtc']),
              LucideIcons.creditCard,
              _vert,
            ),
            _ligneRiche('BL liés', p['blsNumeros'], LucideIcons.truck, _vert),
            _ligneRiche(
              'Factures liées',
              p['facturesNumeros'],
              LucideIcons.receipt,
              _violet,
            ),
            _ligneRiche(
              'Bon de commande',
              p['bonCommandePieceNumero'],
              LucideIcons.shoppingCart,
              _bleu,
            ),
            _ligneRiche(
              'Facture liée',
              p['facturePieceNumero'],
              LucideIcons.receipt,
              _violet,
            ),
            _ligneStatut('Statut', p['status'], avecIcone: true),
          ],
        );

    final groupes = [bls, devis, bonsCommande, factures];
    final selection = groupes[_typePiece];
    final (_, nomSel, couleurSel, iconeSel, videSel) = _typesPieces[_typePiece];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: _selecteurPieces(groupes),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: selection.isEmpty
              ? _vide(videSel)
              : _scroll(
                  // La clé force une reconstruction au changement de type :
                  // l'animation d'entrée rejoue à chaque sélection.
                  cle: ValueKey(_typePiece),
                  [
                    _titreGroupe('$nomSel (${selection.length})'),
                    ...selection.map((p) => carte(p, couleurSel, iconeSel)),
                  ],
                ),
        ),
      ],
    );
  }

  /// Ordre des boutons : BL, Devis, B. Commande, Facture.
  static const _typesPieces = [
    ('BL', 'Bons de livraison', _vert, LucideIcons.truck, 'Aucun BL'),
    ('Devis', 'Devis', _ambre, LucideIcons.fileText, 'Aucun devis'),
    (
      'BC',
      'Bons de commande',
      _bleu,
      LucideIcons.shoppingCart,
      'Aucun bon de commande',
    ),
    ('Facture', 'Factures', _violet, LucideIcons.receipt, 'Aucune facture'),
  ];

  Widget _selecteurPieces(List<List<Map<String, dynamic>>> groupes) {
    return Row(
      children: [
        for (var i = 0; i < _typesPieces.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: _boutonFiltre(
              actif: _typePiece == i,
              onTap: () => setState(() => _typePiece = i),
              label: _typesPieces[i].$1,
              icone: _typesPieces[i].$4,
              couleur: _typesPieces[i].$3,
              nombre: groupes[i].length,
            ),
          ),
        ],
      ],
    );
  }

  /// Bouton de filtre partage par les selecteurs de pieces et de bons.
  Widget _boutonFiltre({
    required bool actif,
    required VoidCallback onTap,
    required String label,
    required IconData icone,
    required Color couleur,
    required int nombre,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
        decoration: BoxDecoration(
          color: actif
              ? couleur.withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.70),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: actif
                ? couleur.withValues(alpha: 0.45)
                : Colors.white.withValues(alpha: 0.90),
            width: 1.3,
          ),
        ),
        // FittedBox : icone, libelle et compteur tiennent sur une seule ligne,
        // la mise a l'echelle evite tout debordement sur ecran etroit.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icone,
                size: 14,
                color: actif ? couleur : const Color(0xFF94A3B8),
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: actif ? FontWeight.w700 : FontWeight.w500,
                  color: actif ? couleur : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: actif
                      ? couleur.withValues(alpha: 0.16)
                      : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  '$nombre',
                  style: GoogleFonts.poppins(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: actif ? couleur : const Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ongletIntervenants() {
    if (_intervenants.isEmpty) return _vide('Aucun intervenant');
    return _scroll(
      _intervenants
          .map(
            (i) => _carte(
              titre: i['employeNomPrenom'],
              icone: LucideIcons.user,
              couleur: const Color(0xFF059669),
              etiquette: i['employeMatricule']?.toString(),
              lignes: [
                _ligneRiche(
                  'Action',
                  i['ligneDesignation'],
                  LucideIcons.clipboardList,
                  _bleu,
                ),
                _ligneRiche(
                  'Fonction',
                  i['employeFonction'],
                  LucideIcons.briefcase,
                  _cyan,
                ),
                _ligneRiche('Lieu', i['lieu'], LucideIcons.mapPin, _ambre),
                _ligneRiche(
                  'Début',
                  _date(i['dateDebut']),
                  LucideIcons.calendar,
                  _bleu,
                ),
                _ligneRiche(
                  'Fin',
                  _date(i['dateFin']),
                  LucideIcons.calendarCheck,
                  _bleu,
                ),
                _ligneRiche('Durée', i['dureeStr'], LucideIcons.clock, _ambre),
                _ligneRiche(
                  'Frais déplacement',
                  _montant(i['fraisDeplacement']),
                  LucideIcons.creditCard,
                  _vert,
                ),
                _ligneRiche(
                  'Description',
                  i['description'],
                  LucideIcons.fileText,
                  _ardoise,
                ),
                _ligneStatut('Statut', i['status'], avecIcone: true),
              ],
            ),
          )
          .toList(),
    );
  }

  /// Historique du vehicule concerne : ses OR et vidanges, cliquables.
  Widget _ongletHistorique() {
    final id = (_ordre['vehiculeId'] as num?)?.toInt();
    if (id == null) return apercuVide('Véhicule inconnu');

    return HistoriqueVehicule(vehiculeId: id);
  }

  Widget _titreGroupe(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 2),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF64748B),
        ),
      ),
    );
  }

  String? _pourcent(dynamic raw) {
    if (raw is! num) return null;
    return '${raw.toStringAsFixed(raw % 1 == 0 ? 0 : 2)} %';
  }

  // ── Briques d'affichage ──

  Widget _scroll(List<Widget> enfants, {Key? cle}) =>
      apercuScroll(enfants, cle: cle);

  Widget _vide(String message) => apercuVide(message);

  Widget _section(String titre, List<Widget?> lignes) =>
      apercuSection(titre, lignes);

  Widget _carte({
    required dynamic titre,
    required IconData icone,
    required Color couleur,
    required List<Widget?> lignes,
    String? etiquette,
    Widget? action,
  }) => apercuCarte(
    titre: titre,
    icone: icone,
    couleur: couleur,
    lignes: lignes,
    etiquette: etiquette,
    action: action,
  );

  Color _couleurPriorite(dynamic priorite) {
    final p = priorite?.toString().toUpperCase() ?? '';
    if (p.contains('URGENT') || p.contains('CRITIQUE')) return _rouge;
    if (p.contains('HAUT') || p.contains('ÉLEV') || p.contains('ELEV')) {
      return _ambre;
    }
    return _ardoise;
  }

  Widget? _ligneRiche(
    String label,
    dynamic value,
    IconData icone,
    Color couleur,
  ) => apercuLigne(label, value, icone, couleur);

  Widget? _ligneStatut(String label, dynamic value, {bool avecIcone = false}) =>
      apercuLigneStatut(label, value, avecIcone: avecIcone);

  /// Les natures d'anomalie s'affichent comme un champ ordinaire.
  String? _naturesAnomalies(Map<String, dynamic> o) {
    final natures = <String>[];
    final raw = o['naturesAnomalies'] ?? o['anomalies'];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          final lib = (item['libelle'] ?? item['nom'])?.toString().trim();
          if (lib != null && lib.isNotEmpty && !natures.contains(lib)) {
            natures.add(lib);
          }
        } else if (item is String && item.trim().isNotEmpty) {
          natures.add(item.trim());
        }
      }
    }
    return natures.isEmpty ? null : natures.join(', ');
  }

  // ── Formatage ──

  String? _date(dynamic raw) => apercuDate(raw);

  String? _km(dynamic raw) => apercuKm(raw);

  String? _montant(dynamic raw) => apercuMontant(raw);
}

/// Empêche TabBarView de détruire un onglet qui porte son propre état
/// (contrôleur de PageView, position de défilement).
class _GarderEnVie extends StatefulWidget {
  final Widget child;

  const _GarderEnVie({required this.child});

  @override
  State<_GarderEnVie> createState() => _GarderEnVieState();
}

class _GarderEnVieState extends State<_GarderEnVie>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
