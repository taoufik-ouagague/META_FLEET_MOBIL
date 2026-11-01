import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../controllers/auth_controller.dart';
import '../../models/vehicule_model.dart';
import '../../services/api_service.dart';
import '../../widgets/apercu_kit.dart';
import '../../widgets/historique_vehicule.dart';
import '../pneumatiques/pneumatique_apercu_page.dart';
import 'document_historique_page.dart';

/// Aperçu d'un véhicule, en consultation seule. Même présentation que la fiche
/// OR : page à onglets, cartes en verre sur le fond ambiant.
class VehiculeApercuPage extends StatefulWidget {
  final VehiculeModel vehicule;

  /// Onglet ouvert a l'arrivee : 0 Informations, 1 Documents, 2 Historique.
  final int ongletInitial;

  const VehiculeApercuPage({
    super.key,
    required this.vehicule,
    this.ongletInitial = 0,
  });

  @override
  State<VehiculeApercuPage> createState() => _VehiculeApercuPageState();
}

class _VehiculeApercuPageState extends State<VehiculeApercuPage> {
  final _auth = Get.find<AuthController>();

  List<Map<String, dynamic>> _documents = const [];
  List<Map<String, dynamic>> _pneus = const [];
  bool _chargement = true;

  VehiculeModel get _v => widget.vehicule;

  @override
  void initState() {
    super.initState();
    _chargerDocuments();
    _chargerPneus();
  }

  @override
  void dispose() {
    super.dispose();
  }

  /// Documents administratifs du véhicule (carte grise, visite, assurance...).
  Future<void> _chargerDocuments() async {
    final id = _v.id;
    if (id == null) {
      if (mounted) setState(() => _chargement = false);
      return;
    }

    try {
      final data = await _auth.makeRequest(
        ApiService.getDocsByVehiculeId(id),
        method: 'GET',
        showErrorSnackbar: false,
      );
      final contenu = data is Map ? (data['content'] ?? data['data']) : data;
      if (contenu is List && mounted) {
        setState(() {
          _documents = contenu
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        });
      }
    } catch (_) {
      // Liste indisponible : l'onglet reste vide, le reste de la fiche tient.
    }
  }

  /// Pneumatiques montes sur le vehicule (filtre serveur par vehiculeId).
  Future<void> _chargerPneus() async {
    final id = _v.id;
    if (id == null) return;

    try {
      final data = await _auth.makeRequest(
        ApiService.listPneumatiques(page: 0, size: 50),
        method: 'POST',
        body: {'vehiculeId': id},
        showErrorSnackbar: false,
      );
      final contenu = data is Map ? (data['content'] ?? data['data']) : data;
      if (contenu is List && mounted) {
        setState(() {
          _pneus = contenu
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        });
      }
    } catch (_) {
      // Liste indisponible : l'onglet reste vide, le reste de la fiche tient.
    }
  }

  Widget _ongletPneumatiques() {
    if (_pneus.isEmpty) return apercuVide('Aucun pneumatique monté');

    return apercuScroll(
      _pneus.map((p) {
        // Le serveur prefixe l'alerte d'un pictogramme que la police ignore.
        final alerte = (p['messageAlert'] ?? '')
            .toString()
            .replaceAll(
              RegExp(
                r'[\u2190-\u2BFF\uFE0F\u{1F000}-\u{1FAFF}]',
                unicode: true,
              ),
              '',
            )
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();

        // apercuCarte n'expose pas de onTap : on l'enveloppe pour ouvrir la
        // fiche du pneu.
        final carte = apercuCarte(
          titre: p['pneuNumSerie'] ?? p['numSerie'],
          icone: LucideIcons.circleDot,
          couleur: alerte.isEmpty ? kApCyan : kApRouge,
          etiquette: p['positionLibelle']?.toString(),
          lignes: [
            apercuLigneStatut('Statut', p['status'], avecIcone: true),
            apercuLigne(
              'Marque',
              p['marqueLibelle'],
              LucideIcons.factory,
              kApArdoise,
            ),
            apercuLigne(
              'Référence fabricant',
              p['referenceFabricant'],
              LucideIcons.hash,
              kApArdoise,
            ),
            apercuLigne(
              'Date de montage',
              apercuDate(p['dateMontage']),
              LucideIcons.calendar,
              kApVert,
            ),
            apercuLigne(
              'Km au montage',
              p['kilometrageMontage'],
              LucideIcons.gauge,
              kApVert,
            ),
            apercuLigne(
              'OR de montage',
              p['numeroOrMontage'],
              LucideIcons.wrench,
              kApVert,
            ),
            apercuLigne(
              'Date de démontage',
              apercuDate(p['dateDeMontage']),
              LucideIcons.calendarX,
              kApAmbre,
            ),
            if (alerte.isNotEmpty)
              apercuLigne(
                'Alerte',
                alerte,
                LucideIcons.alertTriangle,
                kApRouge,
              ),
          ],
        );

        return GestureDetector(
          onTap: () => Get.to(() => PneumatiqueApercuPage(pneu: p)),
          child: carte,
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ApercuScaffold(
      titre: _v.immatriculation ?? _v.displayName,
      sousTitre: 'Consultation',
      chargement: _chargement,
      ongletInitial: widget.ongletInitial,
      onglets: const [
        'Informations',
        'Documents',
        'Pneumatiques',
        'Historique',
        'Équipements',
      ],
      contenus: [
        // Informations et kilométrage dans le même onglet, en slider.
        ApercuSlider(
          pages: [
            ApercuSliderPage(
              label: 'Informations',
              icone: LucideIcons.truck,
              contenu: _ongletInformations(),
            ),
            ApercuSliderPage(
              label: 'Kilométrage',
              icone: LucideIcons.gauge,
              contenu: _ongletKilometrage(),
            ),
          ],
        ),
        _ongletDocuments(),
        _ongletPneumatiques(),
        _v.id == null
            ? apercuVide('Aucun historique')
            : HistoriqueVehicule(vehiculeId: _v.id!),
        _ongletEquipements(),
      ],
    );
  }

  Widget _ongletInformations() {
    return apercuPageCartes([
      apercuCarte(
        titre: _v.displayName,
        icone: LucideIcons.truck,
        couleur: kApBleu,
        etiquette: _v.immatriculation,
        lignes: [
          apercuLigne(
            'Code interne',
            _v.codeInterne,
            LucideIcons.hash,
            kApArdoise,
          ),
          apercuLigne(
            'Immatriculation WW',
            _v.immatriculationWw,
            LucideIcons.creditCard,
            kApArdoise,
          ),
          apercuLigne(
            'Marque',
            _v.marqueLibelle,
            LucideIcons.bookmark,
            kApBleu,
          ),
          apercuLigne('Modèle', _v.modeleLibelle, LucideIcons.car, kApBleu),
          apercuLigne(
            'Catégorie',
            _v.categorieVehiculeLibelle,
            LucideIcons.layers,
            kApCyan,
          ),
          apercuLigne(
            'Type de véhicule',
            _v.typeVehiculeLibelle,
            LucideIcons.truck,
            kApCyan,
          ),
          apercuLigne(
            'Type d\'acquisition',
            _v.typeAcquisitionLibelle,
            LucideIcons.shoppingCart,
            kApViolet,
          ),
          apercuLigne(
            'Statut véhicule',
            _v.statutVehiculeLibelle,
            LucideIcons.activity,
            kApAmbre,
          ),
          apercuLigneStatut('Statut', _v.status, avecIcone: true),
        ],
      ),
      apercuSection('Identité technique', [
        apercuLigne(
          'Numéro de châssis',
          _v.numChassis,
          LucideIcons.fingerprint,
          kApArdoise,
        ),
        apercuLigne(
          'Carburant',
          _v.typeCarburantLibelle,
          LucideIcons.fuel,
          kApAmbre,
        ),
        apercuLigne('Année', _v.annee, LucideIcons.calendar, kApViolet),
        apercuLigne(
          'Mise en service',
          apercuDate(_v.dateMiseEnService),
          LucideIcons.calendarCheck,
          kApViolet,
        ),
        apercuLigne('Couleur', _v.couleur, LucideIcons.palette, kApCyan),
        apercuLigne(
          'Puissance fiscale',
          _v.puissanceFiscale == null ? null : '${_v.puissanceFiscale} CV',
          LucideIcons.gauge,
          kApBleu,
        ),
        apercuLigne(
          'Puissance moteur',
          _v.puissanceMoteur == null ? null : '${_v.puissanceMoteur} Ch',
          LucideIcons.zap,
          kApBleu,
        ),
        apercuLigne(
          'Nombre de places',
          _v.nombrePlaces,
          LucideIcons.users,
          kApArdoise,
        ),
        apercuLigne(
          'Organisme / Site',
          _v.organismeLibelle,
          LucideIcons.building2,
          kApArdoise,
        ),
      ]),
    ]);
  }

  /// Date de dernière synchronisation : la ligne reste visible même sans
  /// date, pour montrer que le compteur n'a jamais été synchronisé.
  String _synchro(dynamic raw) => apercuDate(raw) ?? '—';

  Widget _ongletKilometrage() {
    return apercuPageCartes([
      apercuSection('Compteurs', [
        apercuLigne(
          'Kilométrage actuel',
          apercuKm(_v.kmActuel),
          LucideIcons.gauge,
          kApBleu,
        ),
        apercuLigne(
          'Km GPS',
          apercuKm(_v.kmGps),
          LucideIcons.satellite,
          kApCyan,
        ),
        apercuLigne(
          'Km gasoil',
          apercuKm(_v.kmGasoil),
          LucideIcons.fuel,
          kApAmbre,
        ),
        apercuLigne(
          'Km feuille de route',
          apercuKm(_v.kmFeuilleRoute),
          LucideIcons.clipboardList,
          kApViolet,
        ),
        apercuLigne(
          'Km vidange',
          apercuKm(_v.kmVidange),
          LucideIcons.droplet,
          kApVert,
        ),
        apercuLigne(
          'Seuil alerte vidange',
          apercuKm(_v.kmAlertVidange),
          LucideIcons.bellRing,
          kApRouge,
        ),
        apercuLigne(
          'Taux de consommation',
          _v.tauxConsommation,
          LucideIcons.activity,
          kApArdoise,
        ),
      ]),
      apercuSection('Dernières synchronisations', [
        apercuLigne(
          'GPS',
          _synchro(_v.derniereSynchronisationGps),
          LucideIcons.satellite,
          kApCyan,
        ),
        apercuLigne(
          'Gasoil',
          _synchro(_v.derniereSynchronisationGasoil),
          LucideIcons.fuel,
          kApAmbre,
        ),
        apercuLigne(
          'Feuille de route',
          _synchro(_v.derniereSynchronisationFeuilleRoute),
          LucideIcons.clipboardList,
          kApViolet,
        ),
      ]),
    ]);
  }

  Widget _ongletEquipements() {
    Widget? ligne(String label, bool? present) => apercuLigne(
      label,
      present == null ? null : (present ? 'Oui' : 'Non'),
      present == true ? LucideIcons.checkCircle2 : LucideIcons.minusCircle,
      present == true ? kApVert : kApArdoise,
    );

    return apercuScroll([
      apercuSection('Équipements', [
        ligne('Climatisation', _v.climatisation),
        ligne('Caméra de recul', _v.cameraRecul),
        ligne('Hayon élévateur', _v.hayon),
        ligne('Limiteur de vitesse', _v.limiteurVitesse),
      ]),
    ]);
  }

  Widget _ongletDocuments() {
    if (_documents.isEmpty) return apercuVide('Aucun document');

    return apercuScroll(
      _documents.map((d) {
        final docId = d['id'] is int ? d['id'] as int : -1;

        return apercuCarte(
          titre: d['docAdmPrcLibelle'] ?? d['numeroDocument'],
          icone: LucideIcons.fileText,
          couleur: kApCyan,
          etiquette: d['numeroDocument']?.toString(),
          // L'historique a sa propre page, comme sur le web.
          action: docId < 0
              ? null
              : IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(
                    LucideIcons.history,
                    size: 17,
                    color: kApArdoise,
                  ),
                  tooltip: 'Historique du document',
                  onPressed: () => Get.to(
                    () => DocumentHistoriquePage(
                      docId: docId,
                      titre:
                          (d['docAdmPrcLibelle'] ??
                                  d['numeroDocument'] ??
                                  'Document')
                              .toString(),
                      sousTitre: _v.immatriculation ?? 'Historique du document',
                    ),
                  ),
                ),
          lignes: [
            apercuLigne(
              'Référence',
              d['reference'],
              LucideIcons.hash,
              kApArdoise,
            ),
            apercuLigne(
              'Organisme',
              d['organismeDocsPrcLibelle'],
              LucideIcons.building2,
              kApArdoise,
            ),
            apercuLigne(
              'Émission',
              apercuDate(d['dateEmission']),
              LucideIcons.calendar,
              kApViolet,
            ),
            apercuLigne(
              'Début validité',
              apercuDate(d['dateDebutValidite']),
              LucideIcons.calendarCheck,
              kApBleu,
            ),
            apercuLigne(
              'Fin validité',
              apercuDate(d['dateFinValidite']),
              LucideIcons.calendarX,
              kApRouge,
            ),
            apercuLigne(
              'Alerte',
              apercuDate(d['dateAlerte']),
              LucideIcons.bellRing,
              kApAmbre,
            ),
            apercuLigne(
              'Résultat visite',
              d['resultatVisite'],
              LucideIcons.clipboardCheck,
              kApVert,
            ),
            apercuLigne(
              'Coût',
              apercuMontant(d['cout']),
              LucideIcons.wallet,
              kApVert,
            ),
            apercuLigne(
              'Observation',
              d['observation'],
              LucideIcons.messageSquare,
              kApArdoise,
            ),
            apercuLigneStatut('Statut', d['status'], avecIcone: true),
          ],
        );
      }).toList(),
    );
  }
}
