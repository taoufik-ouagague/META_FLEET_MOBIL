import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/vehicule_controller.dart';
import '../../models/vehicule_model.dart';
import '../../services/api_service.dart';
import '../../widgets/apercu_kit.dart';

/// Apercu d'un pneumatique, en consultation seule. Les donnees viennent de la
/// liste (le DTO de liste porte deja tous les champs) : pas d'appel au serveur.
class PneumatiqueApercuPage extends StatefulWidget {
  final Map<String, dynamic> pneu;

  const PneumatiqueApercuPage({super.key, required this.pneu});

  @override
  State<PneumatiqueApercuPage> createState() => _PneumatiqueApercuPageState();
}

class _PneumatiqueApercuPageState extends State<PneumatiqueApercuPage> {
  final _auth = Get.find<AuthController>();

  Map<String, dynamic> get pneu => widget.pneu;

  /// Historique des montages, charge a l'ouverture pour alimenter l'onglet.
  List<Map<String, dynamic>> _historique = const [];
  bool _chargement = true;

  @override
  void initState() {
    super.initState();
    _chargerHistorique();
  }

  Future<void> _chargerHistorique() async {
    final id = pneu['id'];
    if (id is! int) {
      setState(() => _chargement = false);

      return;
    }

    try {
      final data = await _auth.makeRequest(
        ApiService.historiquePneumatique(id),
        method: 'GET',
        showErrorSnackbar: false,
      );

      final brut = (data is Map) ? (data['data'] ?? data['content']) : data;
      final liste = <Map<String, dynamic>>[];
      if (brut is List) {
        for (final item in brut) {
          if (item is Map) liste.add(Map<String, dynamic>.from(item));
        }
      }
      if (mounted) setState(() => _historique = liste);
    } catch (_) {
      if (mounted) setState(() => _historique = const []);
    } finally {
      if (mounted) setState(() => _chargement = false);
    }
  }

  static const Color _accent = Color(0xFF0EA5E9);
  static const Color kBleu = Color(0xFF2563EB);

  String _texte(dynamic v) {
    final s = (v ?? '').toString().trim();

    return (s.isEmpty || s == 'null') ? '' : s;
  }

  String _km(dynamic km) {
    if (km == null) return '';
    final valeur = (km is num) ? km.toInt() : int.tryParse(km.toString());
    if (valeur == null) return '';

    final str = valeur.toString();
    final parts = <String>[];
    var i = str.length;
    while (i > 3) {
      parts.insert(0, str.substring(i - 3, i));
      i -= 3;
    }
    parts.insert(0, str.substring(0, i));

    return '${parts.join(' ')} km';
  }

  String _date(dynamic raw) {
    final s = _texte(raw);
    if (s.length < 10) return '';
    final d = s.substring(0, 10).split('-');

    return d.length == 3 ? '${d[2]}/${d[1]}/${d[0]}' : s.substring(0, 10);
  }

  /// Le serveur prefixe l'alerte d'un pictogramme que la police ne dessine pas.
  String _alerte() => _texte(pneu['messageAlert'])
      .replaceAll(RegExp(r'[←-⯿️\u{1F000}-\u{1FAFF}]', unicode: true), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  /// Les vehicules sont deja en memoire (controleur permanent) : on y lit la
  /// fiche du porteur sans appel reseau. Null si le vehicule n'y figure pas.
  VehiculeModel? _vehicule() {
    final id = pneu['vehiculeId'];
    if (id is! int || !Get.isRegistered<VehiculeController>()) return null;

    for (final v in Get.find<VehiculeController>().vehicules) {
      if (v.id == id) return v;
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final numSerie = _texte(pneu['pneuNumSerie']).isNotEmpty
        ? _texte(pneu['pneuNumSerie'])
        : _texte(pneu['numSerie']);
    final alerte = _alerte();
    final v = _vehicule();

    return ApercuScaffold(
      titre: numSerie.isEmpty ? 'Pneumatique' : numSerie,
      sousTitre: 'Consultation',
      chargement: _chargement,
      onglets: const ['Informations', 'Historique'],
      contenus: [
        // Deux pages de slider : l'identite du pneu, puis sa vie sur le vehicule.
        ApercuSlider(
          pages: [
            ApercuSliderPage(
              label: 'Fiche',
              icone: LucideIcons.circleDot,
              contenu: apercuScroll([
                if (alerte.isNotEmpty) _bandeauAlerte(alerte),
                apercuCarte(
                  titre: numSerie,
                  icone: LucideIcons.circleDot,
                  couleur: _accent,
                  etiquette: _texte(pneu['marqueLibelle']),
                  lignes: [
                    apercuLigneStatut(
                      'Statut',
                      pneu['status'],
                      avecIcone: true,
                    ),
                    apercuLigne(
                      'Référence fabricant',
                      _texte(pneu['referenceFabricant']),
                      LucideIcons.hash,
                      _accent,
                    ),
                    apercuLigne(
                      'Fournisseur',
                      _texte(pneu['fournisseursLibelle']),
                      LucideIcons.store,
                      _accent,
                    ),
                    apercuLigne(
                      'Description',
                      _texte(pneu['description']),
                      LucideIcons.fileText,
                      _accent,
                    ),
                  ],
                ),
                apercuSection('Véhicule', [
                  apercuLigne(
                    'Immatriculation',
                    v?.immatriculation ?? _texte(pneu['vehiculeLibelle']),
                    LucideIcons.truck,
                    kBleu,
                  ),
                  apercuLigne(
                    'Marque',
                    v?.marqueLibelle,
                    LucideIcons.factory,
                    kBleu,
                  ),
                  apercuLigne(
                    'Modèle',
                    v?.modeleLibelle,
                    LucideIcons.car,
                    kBleu,
                  ),
                  apercuLigne(
                    'Type',
                    v?.typeVehiculeLibelle,
                    LucideIcons.layers,
                    kBleu,
                  ),
                  apercuLigne(
                    'Catégorie',
                    v?.categorieVehiculeLibelle,
                    LucideIcons.tag,
                    kBleu,
                  ),
                  apercuLigne(
                    'Carburant',
                    v?.typeCarburantLibelle,
                    LucideIcons.fuel,
                    kBleu,
                  ),
                  apercuLigne(
                    'N° chassis',
                    v?.numChassis,
                    LucideIcons.hash,
                    kBleu,
                  ),
                  apercuLigne('Année', v?.annee, LucideIcons.calendar, kBleu),
                  apercuLigne(
                    'Km actuel du véhicule',
                    _km(v?.kmActuel ?? pneu['kilometragevehicule']),
                    LucideIcons.gauge,
                    kBleu,
                  ),
                  apercuLigne(
                    'Position du pneu',
                    _texte(pneu['positionLibelle']),
                    LucideIcons.mapPin,
                    kBleu,
                  ),
                  apercuLigneStatut(
                    'Statut du véhicule',
                    v?.statutVehiculeLibelle,
                  ),
                ]),
              ], cle: const ValueKey('pneu-fiche')),
            ),
            ApercuSliderPage(
              label: 'Montage',
              icone: LucideIcons.truck,
              contenu: apercuScroll([
                apercuSection('Montage', [
                  apercuLigne(
                    'Date de montage',
                    _date(pneu['dateMontage']),
                    LucideIcons.calendar,
                    const Color(0xFF10B981),
                  ),
                  apercuLigne(
                    'Km au montage',
                    _km(pneu['kilometrageMontage']),
                    LucideIcons.gauge,
                    const Color(0xFF10B981),
                  ),
                  apercuLigne(
                    'OR de montage',
                    _texte(pneu['numeroOrMontage']),
                    LucideIcons.wrench,
                    const Color(0xFF10B981),
                  ),
                ]),
                apercuSection('Démontage', [
                  apercuLigne(
                    'Date de démontage',
                    _date(pneu['dateDeMontage']),
                    LucideIcons.calendarX,
                    const Color(0xFFF59E0B),
                  ),
                  apercuLigne(
                    'OR de démontage',
                    _texte(pneu['numeroOrDemontage']),
                    LucideIcons.wrench,
                    const Color(0xFFF59E0B),
                  ),
                ]),
                apercuSection('Caractéristiques', [
                  apercuLigne(
                    'Potentiel du pneu',
                    _km(pneu['kilometragePneu']),
                    LucideIcons.activity,
                    const Color(0xFF7C3AED),
                  ),
                  apercuLigne(
                    'Indice de charge',
                    _texte(pneu['indiceChargeLibelle']),
                    LucideIcons.scale,
                    const Color(0xFF7C3AED),
                  ),
                  apercuLigne(
                    'Indice de vitesse',
                    _texte(pneu['indiceVitesseLibelle']),
                    LucideIcons.zap,
                    const Color(0xFF7C3AED),
                  ),
                  apercuLigne(
                    'Largeur',
                    _texte(pneu['largeur']),
                    LucideIcons.moveHorizontal,
                    const Color(0xFF7C3AED),
                  ),
                  apercuLigne(
                    'Diamètre',
                    _texte(pneu['diametre']),
                    LucideIcons.circle,
                    const Color(0xFF7C3AED),
                  ),
                  apercuLigne(
                    "Date d'acquisition",
                    _date(pneu['dateAquisition']),
                    LucideIcons.calendarPlus,
                    const Color(0xFF7C3AED),
                  ),
                  apercuLigne(
                    'Montant HT',
                    _texte(pneu['montantHT']),
                    LucideIcons.banknote,
                    const Color(0xFF7C3AED),
                  ),
                ]),
              ], cle: const ValueKey('pneu-montage')),
            ),
          ],
        ),
        _ongletHistorique(),
      ],
    );
  }

  Widget _ongletHistorique() {
    if (_historique.isEmpty) {
      return apercuVide(
        _chargement ? 'Chargement…' : 'Aucun montage enregistré pour ce pneu',
      );
    }

    return apercuScroll([
      for (final l in _historique) _carteHistorique(l),
    ], cle: const ValueKey('pneu-historique'));
  }

  Widget _carteHistorique(Map<String, dynamic> ligne) {
    final courant = ligne['courant'] == true;
    final numSerie = _texte(ligne['numSerie']);

    return apercuCarte(
      titre: numSerie.isEmpty ? '—' : numSerie,
      icone: courant ? LucideIcons.circleDot : LucideIcons.history,
      couleur: courant ? _accent : const Color(0xFF94A3B8),
      etiquette: courant ? 'Pneu courant' : null,
      lignes: [
        apercuLigneStatut('Statut', ligne['statut'], avecIcone: true),
        apercuLigne(
          'Véhicule',
          _texte(ligne['immatriculation']),
          LucideIcons.truck,
          kBleu,
        ),
        apercuLigne(
          'Position',
          _texte(ligne['position']),
          LucideIcons.mapPin,
          kBleu,
        ),
        apercuLigne(
          'Montage',
          _date(ligne['dateMontage']),
          LucideIcons.calendar,
          const Color(0xFF10B981),
        ),
        apercuLigne(
          'Km au montage',
          _km(ligne['kilometrageMontage']),
          LucideIcons.gauge,
          const Color(0xFF10B981),
        ),
        apercuLigne(
          'OR de montage',
          _texte(ligne['numeroOrMontage']),
          LucideIcons.wrench,
          const Color(0xFF10B981),
        ),
        apercuLigne(
          'Démontage',
          _date(ligne['dateDemontage']),
          LucideIcons.calendarX,
          const Color(0xFFF59E0B),
        ),
        apercuLigne(
          'OR de démontage',
          _texte(ligne['numeroOrDemontage']),
          LucideIcons.wrench,
          const Color(0xFFF59E0B),
        ),
        apercuLigne(
          'Km véhicule',
          _km(ligne['kilometrageVehicule']),
          LucideIcons.activity,
          const Color(0xFF7C3AED),
        ),
      ],
    );
  }

  Widget _bandeauAlerte(String message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFDC2626).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFDC2626).withValues(alpha: 0.22),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            LucideIcons.alertTriangle,
            size: 15,
            color: Color(0xFFDC2626),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFDC2626),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
