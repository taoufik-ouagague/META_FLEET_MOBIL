import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:lucide_icons/lucide_icons.dart';
import 'package:path_provider/path_provider.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/demande_or_controller.dart';
import '../../services/api_service.dart';
import '../../widgets/apercu_kit.dart';
import '../../controllers/vehicule_controller.dart';
import '../../models/vehicule_model.dart';
import '../or/or_apercu_page.dart';
import '../vehicules/vehicule_apercu_page.dart';

/// Aperçu d'une demande d'ordre de réparation, en consultation seule.
/// Même présentation que les fiches OR, vidange et véhicule.
class DemandeOrApercuPage extends StatefulWidget {
  final Map<String, dynamic> demande;

  /// Onglet ouvert a l'arrivee, pour les acces directs depuis le tableau de bord.
  final int ongletInitial;

  const DemandeOrApercuPage({
    super.key,
    required this.demande,
    this.ongletInitial = 0,
  });

  @override
  State<DemandeOrApercuPage> createState() => _DemandeOrApercuPageState();
}

class _DemandeOrApercuPageState extends State<DemandeOrApercuPage> {
  final _auth = Get.find<AuthController>();
  final _commentaire = TextEditingController();
  final _lecteur = AudioPlayer();

  /// Descriptions audio (GED, cle `DEMANDE_OR_AUDIO-<id>`).
  List<Map<String, dynamic>> _audios = const [];
  int? _audioEnLecture;
  int? _audioEnChargement;
  Duration _position = Duration.zero;
  Duration _duree = Duration.zero;

  late Map<String, dynamic> _demande = Map<String, dynamic>.from(
    widget.demande,
  );

  /// Ordres de reparation issus de la demande, pour y acceder directement.
  List<Map<String, dynamic>> _ordres = const [];
  bool _enCours = false;

  @override
  void initState() {
    super.initState();
    _chargerDemande();
    _chargerAudios();
    _chargerOrdres();
    _lecteur.onPlayerComplete.listen((_) {
      if (!mounted) return;
      setState(() {
        _audioEnLecture = null;
        _position = Duration.zero;
      });
    });
    _lecteur.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _lecteur.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duree = d);
    });
  }

  @override
  void dispose() {
    _commentaire.dispose();
    _lecteur.dispose();
    super.dispose();
  }

  /// Liste des notes vocales attachees a la demande.
  Future<void> _chargerAudios() async {
    final id = _v('id');
    if (id is! int) return;

    try {
      final data = await _auth.makeRequest(
        ApiService.listGeds('DEMANDE_OR_AUDIO-$id'),
        method: 'GET',
        showErrorSnackbar: false,
      );

      final contenu = data is Map ? (data['body'] ?? data['data']) : data;
      if (contenu is List && mounted) {
        setState(() {
          _audios = contenu
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        });
      }
    } catch (_) {
      // Pas de note vocale, ou GED indisponible : la section reste masquee.
    }
  }

  /// Lecture / arret d'une note. Le binaire arrive en base64 et se joue
  /// directement depuis la memoire, sans fichier temporaire.
  Future<void> _jouer(Map<String, dynamic> audio) async {
    final id = audio['id'];
    if (id is! int) return;

    if (_audioEnLecture == id) {
      await _lecteur.pause();
      if (mounted) setState(() => _audioEnLecture = null);

      return;
    }

    setState(() {
      _position = Duration.zero;
      _duree = Duration.zero;
    });

    setState(() => _audioEnChargement = id);
    try {
      // afficherGedsPrc renvoie le binaire brut (Ogg/Opus, MP3...) : passer par
      // makeRequest le ferait decoder en JSON et echouer sur « OggS ».
      final reponse = await http
          .post(
            Uri.parse(ApiService.afficherGed()),
            headers: {
              'Content-Type': 'application/json',
              if (_auth.userToken.value.isNotEmpty)
                'Authorization': 'Bearer ${_auth.userToken.value}',
            },
            body: jsonEncode({'cle': 'DEMANDE_OR_AUDIO-${_v('id')}', 'id': id}),
          )
          .timeout(const Duration(seconds: 45));

      if (reponse.statusCode != 200 || reponse.bodyBytes.isEmpty) {
        throw Exception('Lecture impossible (${reponse.statusCode})');
      }

      // Certaines installations renvoient quand meme du JSON avec le binaire
      // en base64 : on bascule dessus quand le corps commence par « { ».
      var octets = Uint8List.fromList(reponse.bodyBytes);
      if (octets.isNotEmpty && octets.first == 0x7B) {
        final corps = jsonDecode(utf8.decode(octets));
        final brut = corps is Map
            ? (corps['body'] is Map
                  ? (corps['body']['contentAsByteArray'] ??
                        corps['body']['content'])
                  : (corps['contentAsByteArray'] ?? corps['content']))
            : null;
        if (brut == null) throw Exception('Fichier audio introuvable');

        var texte = brut.toString();
        final separateur = texte.indexOf('base64,');
        if (separateur > 0) {
          texte = texte.substring(separateur + 'base64,'.length);
        }
        octets = base64Decode(texte.replaceAll(RegExp(r'\s'), ''));
      }

      // Le serveur convertit les notes Ogg/Opus en m4a : on se fie au contenu
      // recu, pas au nom du document, qui garde son extension d'origine.
      final estOgg =
          octets.length > 4 &&
          octets[0] == 0x4F &&
          octets[1] == 0x67 &&
          octets[2] == 0x67 &&
          octets[3] == 0x53;

      if (Platform.isIOS && estOgg) {
        throw Exception(
          'Note au format Opus non convertie : vérifier ffmpeg sur le serveur '
          '(media.ffmpeg.path).',
        );
      }

      final nomFichier = (audio['nomFichier'] ?? 'note').toString();
      var extension = nomFichier.contains('.')
          ? nomFichier.split('.').last.toLowerCase()
          : 'm4a';
      if (!estOgg && (extension == 'opus' || extension == 'ogg')) {
        extension = 'm4a';
      }

      final dossier = await getTemporaryDirectory();
      final fichier = File('${dossier.path}/ged_audio_$id.$extension');
      await fichier.writeAsBytes(octets, flush: true);

      await _lecteur.play(DeviceFileSource(fichier.path));
      if (mounted) setState(() => _audioEnLecture = id);
    } catch (e) {
      Get.snackbar(
        'Audio',
        e.toString().replaceFirst('Exception: ', ''),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFFFEF2F2),
        colorText: const Color(0xFF991B1B),
        borderRadius: 14,
        margin: const EdgeInsets.all(16),
      );
    } finally {
      if (mounted) setState(() => _audioEnChargement = null);
    }
  }

  /// Carte « Description audio » : une bulle par note, facon messagerie.
  Widget? _carteAudios() {
    if (_audios.isEmpty) return null;

    return ApercuVerre(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: kApViolet.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(LucideIcons.mic, size: 14, color: kApViolet),
              ),
              const SizedBox(width: 10),
              const Expanded(child: Text('Description audio')),
            ],
          ),
          const SizedBox(height: 10),
          ..._audios.map(_bulleAudio),
        ],
      ),
    );
  }

  Widget _bulleAudio(Map<String, dynamic> audio) {
    final id = audio['id'];
    final enLecture = _audioEnLecture == id;
    final enChargement = _audioEnChargement == id;

    final duree = enLecture ? _duree : Duration.zero;
    final position = enLecture ? _position : Duration.zero;
    final avancement = duree.inMilliseconds == 0
        ? 0.0
        : (position.inMilliseconds / duree.inMilliseconds).clamp(0.0, 1.0);

    final nom = (audio['nomFichier'] ?? 'Note vocale').toString();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 9, 14, 9),
        decoration: BoxDecoration(
          color: kApViolet.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: kApViolet.withValues(alpha: 0.18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: enChargement ? null : () => _jouer(audio),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: kApViolet,
                      shape: BoxShape.circle,
                    ),
                    child: enChargement
                        ? const Padding(
                            padding: EdgeInsets.all(10),
                            child: CircularProgressIndicator(
                              strokeWidth: 1.8,
                              color: Colors.white,
                            ),
                          )
                        : Icon(
                            enLecture ? Icons.pause : Icons.play_arrow,
                            size: 20,
                            color: Colors.white,
                          ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, contraintes) {
                      return GestureDetector(
                        // Clic sur l'onde : deplacement dans la note en cours.
                        onTapDown: (details) {
                          if (!enLecture || duree == Duration.zero) return;
                          final ratio =
                              (details.localPosition.dx / contraintes.maxWidth)
                                  .clamp(0.0, 1.0);
                          _lecteur.seek(
                            Duration(
                              milliseconds: (duree.inMilliseconds * ratio)
                                  .round(),
                            ),
                          );
                        },
                        child: SizedBox(
                          height: 30,
                          child: CustomPaint(
                            size: Size(contraintes.maxWidth, 30),
                            painter: _OndeAudio(
                              graine: nom.hashCode,
                              avancement: avancement,
                              couleur: kApViolet,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Padding(
              padding: const EdgeInsets.only(left: 46),
              child: Row(
                children: [
                  Text(
                    enLecture && duree > Duration.zero
                        ? '${_mmss(position)} / ${_mmss(duree)}'
                        : nom,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: const Color(0xFF64748B).withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _mmss(Duration d) {
    final minutes = d.inMinutes.toString();
    final secondes = (d.inSeconds % 60).toString().padLeft(2, '0');

    return '$minutes:$secondes';
  }

  dynamic _v(String cle) => _demande[cle];

  /// Natures d'anomalies : liste d'objets cote backend.
  String? get _natures {
    final brut = _v('naturesAnomalies') ?? _v('anomalies');
    if (brut is! List || brut.isEmpty) return null;

    final libelles = <String>[];
    for (final e in brut) {
      final texte = e is Map
          ? (e['natureAnomalieLibelle'] ?? e['libelle'] ?? e['nom'] ?? '')
                .toString()
          : e.toString();
      final propre = texte.trim();
      if (propre.isNotEmpty && propre != 'null' && !libelles.contains(propre)) {
        libelles.add(propre);
      }
    }

    return libelles.isEmpty ? null : libelles.join(', ');
  }

  /// Validation initiale faite ? Meme test que la fiche web.
  bool get _valideeInitialement => _v('dateValidationInitial') != null;

  bool get _peutValider =>
      _auth.currentUser.value?.hasAuthority(
        'DEMANDES_OR_ENREGISTRER_VALIDER',
      ) ??
      false;

  /// Recharge la demande apres une action, et met la liste a jour.
  Future<void> _recharger() async {
    await _chargerDemande();

    if (Get.isRegistered<DemandeOrController>()) {
      Get.find<DemandeOrController>().fetchDemandes(showLoading: false);
    }
  }

  /// Fiche complete depuis l'identifiant : la page peut donc etre ouverte avec
  /// un simple {'id': ...}, depuis le tableau de bord ou la fiche OR.
  Future<void> _chargerDemande() async {
    final id = _v('id');
    if (id is! int) return;

    try {
      final data = await _auth.makeRequest(
        ApiService.getDemandeOR(id),
        method: 'GET',
        showErrorSnackbar: false,
      );
      if (data is Map && mounted) {
        setState(() => _demande = Map<String, dynamic>.from(data));
      }
    } catch (_) {
      // La fiche reste sur les donnees precedentes.
    }
  }

  Future<void> _action({required bool fausseDeclaration}) async {
    final id = _v('id');
    if (id is! int || _enCours) return;

    _commentaire.text = fausseDeclaration ? '' : 'RAS';

    final confirme = await Get.dialog<bool>(
      apercuDialogueAction(
        titre: fausseDeclaration ? 'Fausse déclaration' : 'Valider la demande',
        numero: _v('numeroDemande')?.toString() ?? '',
        message: fausseDeclaration
            ? 'Le motif est obligatoire : il est enregistré sur la demande.'
            : 'La validation initiale ouvre le diagnostic.',
        libelleAction: fausseDeclaration ? 'Déclarer' : 'Valider',
        couleur: fausseDeclaration ? kApAmbre : kApVert,
        icone: fausseDeclaration
            ? LucideIcons.alertTriangle
            : LucideIcons.checkCircle2,
        commentaire: _commentaire,
      ),
      barrierColor: const Color(0xFF0F172A).withValues(alpha: 0.35),
    );

    if (confirme != true) return;

    final texte = _commentaire.text.trim();
    if (fausseDeclaration && texte.isEmpty) {
      Get.snackbar(
        'Motif requis',
        'Le motif de fausse déclaration est obligatoire.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFFFEF3C7),
        colorText: const Color(0xFF92400E),
        borderRadius: 14,
        margin: const EdgeInsets.all(16),
      );

      return;
    }

    setState(() => _enCours = true);
    try {
      final reponse = await _auth.makeRequest(
        fausseDeclaration
            ? ApiService.fausseDeclarationDemande(id)
            : ApiService.validerDemandeOR(id),
        method: 'POST',
        body: {'description': texte.isEmpty ? 'RAS' : texte},
      );

      final message = reponse is Map
          ? (reponse['message']?.toString() ?? 'Opération effectuée')
          : 'Opération effectuée';
      Get.snackbar(
        _v('numeroDemande')?.toString() ?? 'Demande',
        message,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFFF0FDF4),
        colorText: const Color(0xFF166534),
        borderRadius: 14,
        margin: const EdgeInsets.all(16),
      );

      await _recharger();
    } catch (_) {
      // makeRequest a deja affiche l'erreur.
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  /// Ordres nes de la demande : la fiche web les liste par le meme appel.
  Future<void> _chargerOrdres() async {
    final id = (_v('id') as num?)?.toInt();
    if (id == null) return;

    try {
      final data = await _auth.makeRequest(
        ApiService.listOrdresByDemande(id),
        method: 'GET',
        showErrorSnackbar: false,
      );
      final contenu = data is Map ? (data['content'] ?? data['data']) : data;
      if (contenu is List && mounted) {
        setState(() {
          _ordres = contenu
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        });
      }
    } catch (_) {
      // Liste indisponible : la fiche reste utilisable sans le raccourci.
    }
  }

  /// Raccourci vers l'ordre issu de la demande, comme le bouton « Voir
  /// l'ordre » de la fiche web : un seul bouton, pas une carte.
  Widget? _boutonOrdre() {
    if (_ordres.isEmpty) return null;

    final ordre = _ordres.first;
    final id = (ordre['id'] as num?)?.toInt();
    if (id == null) return null;

    final numero = (ordre['numeroOrdreReparation'] ?? ordre['numero'] ?? '')
        .toString()
        .trim();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => Get.to(() => OrApercuPage(ordre: {'id': id})),
          icon: const Icon(LucideIcons.externalLink, size: 16),
          label: Text(numero.isEmpty ? "Voir l'ordre" : "Voir l'ordre $numero"),
          style: ElevatedButton.styleFrom(
            backgroundColor: kApVert,
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

  @override
  Widget build(BuildContext context) {
    return ApercuScaffold(
      ongletInitial: widget.ongletInitial,
      titre: _v('numeroDemande')?.toString() ?? 'Demande',
      sousTitre: 'Consultation',
      onglets: const ['Informations', 'Véhicule', 'Suivi', 'Intervenants'],
      contenus: [
        _ongletInformations(),
        _ongletVehicule(),
        _ongletSuivi(),
        _ongletIntervenants(),
      ],
    );
  }

  /// Actions de validation initiale : visibles tant que la demande n'est pas
  /// validee, comme le bloc « Validation initiale » de la fiche web.
  Widget? _carteActions() {
    if (_valideeInitialement || !_peutValider) return null;

    return ApercuVerre(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: kApVert.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  LucideIcons.checkCircle2,
                  size: 14,
                  color: kApVert,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(child: Text('Validation initiale')),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _enCours
                      ? null
                      : () => _action(fausseDeclaration: false),
                  icon: const Icon(LucideIcons.check, size: 15),
                  label: const Text('Valider'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kApVert,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _enCours
                      ? null
                      : () => _action(fausseDeclaration: true),
                  icon: const Icon(LucideIcons.alertTriangle, size: 15),
                  label: const Text('Fausse décl.'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kApAmbre,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _ongletInformations() {
    return apercuScroll([
      ?_carteActions(),
      ?_boutonOrdre(),
      ?_carteAudios(),
      apercuCarte(
        titre: _v('numeroDemande'),
        icone: LucideIcons.clipboardList,
        couleur: kApBleu,
        etiquette: _v('vehiculeImmatriculation')?.toString(),
        lignes: [
          apercuLigneStatut(
            'Statut',
            _v('workflowDORLibelle') ?? _v('status'),
            avecIcone: true,
          ),
          apercuLigne(
            'Date demande',
            apercuDate(_v('dateDemande')),
            LucideIcons.calendar,
            kApViolet,
          ),
          apercuLigne(
            'Type',
            _v('typeDemandeORLibelle'),
            LucideIcons.tag,
            kApCyan,
          ),
          apercuLigne(
            'Priorité',
            _v('prioriteLibelle'),
            LucideIcons.flame,
            kApAmbre,
          ),
          apercuLigne(
            'Natures d\'anomalies',
            _natures,
            LucideIcons.alertTriangle,
            kApRouge,
          ),
          apercuLigne(
            'Problème',
            _v('descriptionProbleme'),
            LucideIcons.fileText,
            kApArdoise,
          ),
          apercuLigne(
            'Kilométrage',
            apercuKm(_v('kilometrage')),
            LucideIcons.gauge,
            kApBleu,
          ),
        ],
      ),
      apercuSection('Demandeur', [
        apercuLigne(
          'Demandeur',
          _v('demandeurNomComplet'),
          LucideIcons.user,
          kApVert,
        ),
        apercuLigne(
          'Agent de saisie',
          _v('agentSaisieNomComplet'),
          LucideIcons.userCheck,
          kApArdoise,
        ),
        apercuLigne(
          'Service',
          _v('servicesPrcLibelle'),
          LucideIcons.wrench,
          kApViolet,
        ),
        apercuLigne(
          'Agence',
          _v('agenceLibelle'),
          LucideIcons.building2,
          kApArdoise,
        ),
        apercuLigne(
          'Chauffeur',
          _v('chaffeurNomComplet'),
          LucideIcons.user,
          kApCyan,
        ),
      ]),
      apercuSection('Immobilisation', [
        apercuLigne(
          'Localisation',
          _v('localisationVehicule'),
          LucideIcons.mapPin,
          kApAmbre,
        ),
        apercuLigne(
          'Véhicule immobilisé',
          _v('vehiculeImmobilise') == null
              ? null
              : (_v('vehiculeImmobilise') == true ? 'Oui' : 'Non'),
          LucideIcons.lock,
          _v('vehiculeImmobilise') == true ? kApRouge : kApVert,
        ),
        apercuLigne(
          'Début',
          apercuDate(_v('dateDebutImmobilisation')),
          LucideIcons.calendar,
          kApViolet,
        ),
        apercuLigne(
          'Fin',
          apercuDate(_v('dateFinImmobilisation')),
          LucideIcons.calendarCheck,
          kApViolet,
        ),
        apercuLigne(
          'Intervention souhaitée',
          apercuDate(_v('dateSouhaiteeIntervention')),
          LucideIcons.calendarClock,
          kApBleu,
        ),
      ]),
    ]);
  }

  /// Fiche du vehicule : prise dans le controleur deja charge, sinon lue sur
  /// le serveur. apercuCarte n'a pas de onTap, d'ou l'enveloppe.
  Future<void> _ouvrirVehicule() async {
    final id = _v('vehiculeId');
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
      // Fiche indisponible : on reste sur la demande.
    }
  }

  Widget _ongletVehicule() {
    return apercuScroll([
      GestureDetector(
        onTap: _ouvrirVehicule,
        child: apercuCarte(
          titre: [
            _v('vehiculeMarqueLibelle'),
            _v('vehiculeModeleLibelle'),
          ].where((e) => e != null && e.toString().trim().isNotEmpty).join(' '),
          icone: LucideIcons.truck,
          couleur: kApBleu,
          etiquette: _v('vehiculeImmatriculation')?.toString(),
          lignes: [
            apercuLigne(
              'Kilométrage',
              apercuKm(_v('kilometrage')),
              LucideIcons.gauge,
              kApBleu,
            ),
            apercuLigne(
              'Mise en service',
              apercuDate(_v('vehiculeDateMiseEnService')),
              LucideIcons.calendar,
              kApViolet,
            ),
            apercuLigne(
              'Âge',
              _v('vehiculeAge'),
              LucideIcons.hourglass,
              kApArdoise,
            ),
            apercuLigne(
              'Lieu de réparation',
              _v('lieuReparation'),
              LucideIcons.mapPin,
              kApAmbre,
            ),
            apercuLigne(
              'Prestataire',
              _v('libellePrestataire'),
              LucideIcons.briefcase,
              kApAmbre,
            ),
          ],
        ),
      ),
    ]);
  }

  Widget _ongletSuivi() {
    return apercuScroll([
      apercuSection('Validation initiale', [
        apercuLigne(
          'Date',
          apercuDate(_v('dateValidationInitial')),
          LucideIcons.calendarCheck,
          kApVert,
        ),
        apercuLigne(
          'Description',
          _v('descriptionInitial'),
          LucideIcons.fileText,
          kApArdoise,
        ),
      ]),
      apercuSection('Diagnostic', [
        apercuLigne(
          'Début',
          apercuDate(_v('dateDebutDiagnostic')),
          LucideIcons.playCircle,
          kApBleu,
        ),
        apercuLigne(
          'Fin',
          apercuDate(_v('dateFinDiagnostic')),
          LucideIcons.checkCircle2,
          kApVert,
        ),
        apercuLigne(
          'Description',
          _v('descriptionDiagnostic'),
          LucideIcons.fileText,
          kApArdoise,
        ),
      ]),
      apercuSection('Clôture / rejet', [
        apercuLigne(
          'Clôturée le',
          apercuDate(_v('dateCloture')),
          LucideIcons.checkCircle2,
          kApVert,
        ),
        apercuLigne(
          'Description',
          _v('descriptionCloture'),
          LucideIcons.fileText,
          kApArdoise,
        ),
        apercuLigne(
          'Rejetée le',
          apercuDate(_v('dateRejet')),
          LucideIcons.xCircle,
          kApRouge,
        ),
        apercuLigne(
          'Motif du rejet',
          _v('descriptionRejet'),
          LucideIcons.fileText,
          kApRouge,
        ),
        apercuLigne(
          'Fausse déclaration',
          apercuDate(_v('dateFausseDeclaration')),
          LucideIcons.alertOctagon,
          kApRouge,
        ),
        apercuLigne(
          'Description',
          _v('descriptionFausseDec'),
          LucideIcons.fileText,
          kApRouge,
        ),
      ]),
      apercuSection('Transformation', [
        apercuLigne(
          'Transformée en OR',
          _v('transformeEnOrdre') == null
              ? null
              : (_v('transformeEnOrdre') == true ? 'Oui' : 'Non'),
          LucideIcons.wrench,
          _v('transformeEnOrdre') == true ? kApVert : kApArdoise,
        ),
        apercuLigne(
          'OR sans réparation',
          _v('orSansReparation') == null
              ? null
              : (_v('orSansReparation') == true ? 'Oui' : 'Non'),
          LucideIcons.fileMinus,
          kApArdoise,
        ),
      ]),
    ]);
  }

  Widget _ongletIntervenants() {
    final brut = _v('intervenants');
    final intervenants = brut is List
        ? brut.whereType<Map>().toList()
        : const [];

    if (intervenants.isEmpty) return apercuVide('Aucun intervenant');

    return apercuScroll(
      intervenants
          .map(
            (i) => apercuCarte(
              titre: i['libelle'] ?? i['nom'],
              icone: LucideIcons.user,
              couleur: kApVert,
              lignes: const [],
            ),
          )
          .toList(),
    );
  }
}

/// Onde sonore decorative : barres de hauteur stable (tirees du nom du
/// fichier), colorees jusqu'a la position de lecture.
class _OndeAudio extends CustomPainter {
  final int graine;
  final double avancement;
  final Color couleur;

  _OndeAudio({
    required this.graine,
    required this.avancement,
    required this.couleur,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const largeurBarre = 3.0;
    const espace = 3.0;
    final nombre = (size.width / (largeurBarre + espace)).floor();
    if (nombre <= 0) return;

    final peintureLue = Paint()..color = couleur;
    final peintureRestante = Paint()..color = couleur.withValues(alpha: 0.25);

    var etat = graine.abs() % 100000 + 1;
    for (var i = 0; i < nombre; i++) {
      // Generateur simple : des hauteurs variees mais identiques a chaque rendu.
      etat = (etat * 1103515245 + 12345) & 0x7FFFFFFF;
      final hauteur = 6 + (etat % 100) / 100 * (size.height - 8);
      final x = i * (largeurBarre + espace);
      final y = (size.height - hauteur) / 2;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, largeurBarre, hauteur),
          const Radius.circular(2),
        ),
        i / nombre <= avancement ? peintureLue : peintureRestante,
      );
    }
  }

  @override
  bool shouldRepaint(_OndeAudio ancien) =>
      ancien.avancement != avancement || ancien.graine != graine;
}
