import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/chat_controller.dart';
import '../../services/api_service.dart';
import '../../widgets/ambient_background.dart';

/// Fil de discussion avec l'administration.
///
/// [employeId] null = son propre fil ; renseigne, c'est le fil d'un employe
/// ouvert par un porteur du droit CHAT_REPONDRE.
class ChatPage extends StatefulWidget {
  final int? employeId;
  final String titre;

  const ChatPage({super.key, this.employeId, this.titre = 'Discussion'});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  static const Color _accent = Color(0xFF2563EB);

  late final ChatController _controller;
  final TextEditingController _champ = TextEditingController();
  final ScrollController _scroll = ScrollController();

  /// Vignettes des images recues, mises en cache par piece jointe.
  final Map<int, File> _images = {};

  /// Lecture des messages vocaux : un seul a la fois.
  final AudioPlayer _lecteur = AudioPlayer();
  int? _audioEnLecture;
  Duration _position = Duration.zero;
  Duration _total = Duration.zero;
  StreamSubscription<Duration>? _suiviPosition;
  StreamSubscription<Duration>? _suiviDuree;
  StreamSubscription<void>? _suiviFin;

  /// Pieces jointes en attente d'envoi (nom + base64).
  final List<Map<String, dynamic>> _pieces = [];

  /// Enregistrement vocal : etat, chrono et niveaux pour la forme d'onde.
  final AudioRecorder _enregistreur = AudioRecorder();
  bool _enregistre = false;
  bool _enPause = false;
  Duration _duree = Duration.zero;
  final List<double> _niveaux = [];
  Timer? _chrono;
  StreamSubscription<Amplitude>? _ecouteNiveaux;
  String? _cheminEnCours;

  @override
  void initState() {
    super.initState();
    _controller = Get.isRegistered<ChatController>()
        ? Get.find<ChatController>()
        : Get.put(ChatController());

    _suiviPosition = _lecteur.onPositionChanged.listen(
      (p) => mounted ? setState(() => _position = p) : null,
    );
    _suiviDuree = _lecteur.onDurationChanged.listen(
      (d) => mounted ? setState(() => _total = d) : null,
    );
    _suiviFin = _lecteur.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _audioEnLecture = null;
          _position = Duration.zero;
        });
      }
    });

    // Apres la premiere frame : le chargement touche des observables, et les
    // modifier pendant la construction de la route leve « setState during
    // build ».
    WidgetsBinding.instance.addPostFrameCallback((_) => _charger());
  }

  @override
  void dispose() {
    _champ.dispose();
    _scroll.dispose();
    _chrono?.cancel();
    _ecouteNiveaux?.cancel();
    _suiviPosition?.cancel();
    _suiviDuree?.cancel();
    _suiviFin?.cancel();
    _lecteur.dispose();
    _enregistreur.dispose();
    super.dispose();
  }

  Future<void> _charger() async {
    if (widget.employeId == null) {
      await _controller.chargerMonFil();
    } else {
      await _controller.chargerFil(widget.employeId!);
    }
    _prechargerImages(_controller.messages.toList());
    _versLeBas();
  }

  void _versLeBas() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  Future<void> _joindreImage(ImageSource source) async {
    final fichier = await ImagePicker().pickImage(
      source: source,
      imageQuality: 70,
    );
    if (fichier == null) return;

    final octets = await File(fichier.path).readAsBytes();
    final nom = fichier.name;
    final extension = nom.contains('.') ? nom.split('.').last : 'jpg';

    setState(() {
      _pieces.add({
        'nomFichier': nom,
        'extension': extension,
        'typeMime': 'image/$extension',
        'base64': base64Encode(octets),
      });
    });
  }

  bool _estImage(Map piece) {
    final mime = (piece['typeMime'] ?? '').toString().toLowerCase();
    final nom = (piece['nomFichier'] ?? '').toString().toLowerCase();

    return mime.startsWith('image/') ||
        RegExp(r'\.(jpg|jpeg|png|gif|webp|heic)$').hasMatch(nom);
  }

  /// Telecharge les images d'un fil : les fichiers sont proteges par le jeton.
  Future<void> _prechargerImages(List<Map<String, dynamic>> messages) async {
    final auth = Get.find<AuthController>();

    for (final m in messages) {
      final pieces = m['piecesJointes'];
      if (pieces is! List) continue;

      for (final p in pieces.whereType<Map>()) {
        final id = p['id'];
        if (id is! int || !_estImage(p) || _images.containsKey(id)) continue;

        try {
          final reponse = await http.get(
            Uri.parse(ApiService.chatPieceJointe(id)),
            headers: {'Authorization': 'Bearer ${auth.userToken.value}'},
          );
          if (reponse.statusCode != 200) continue;

          final dossier = await getTemporaryDirectory();
          final fichier = File('${dossier.path}/chat_img_$id');
          await fichier.writeAsBytes(reponse.bodyBytes, flush: true);
          if (mounted) setState(() => _images[id] = fichier);
        } catch (_) {
          // Image indisponible : la puce de fichier reste affichee.
        }
      }
    }
  }

  bool _estAudio(Map piece) {
    final mime = (piece['typeMime'] ?? '').toString().toLowerCase();
    final nom = (piece['nomFichier'] ?? '').toString().toLowerCase();

    return mime.startsWith('audio/') ||
        nom.endsWith('.m4a') ||
        nom.endsWith('.mp3') ||
        nom.endsWith('.wav') ||
        nom.endsWith('.aac');
  }

  /// Joue (ou arrete) un message vocal. Le fichier est protege par le jeton :
  /// on le telecharge puis on lit la copie locale.
  Future<void> _jouerAudio(Map piece) async {
    final id = piece['id'];
    if (id is! int) return;

    if (_audioEnLecture == id) {
      await _lecteur.stop();
      setState(() => _audioEnLecture = null);

      return;
    }

    try {
      final auth = Get.find<AuthController>();
      final reponse = await http.get(
        Uri.parse(ApiService.chatPieceJointe(id)),
        headers: {'Authorization': 'Bearer ${auth.userToken.value}'},
      );
      if (reponse.statusCode != 200) return;

      final dossier = await getTemporaryDirectory();
      final fichier = File('${dossier.path}/chat_audio_$id.m4a');
      await fichier.writeAsBytes(reponse.bodyBytes, flush: true);

      await _lecteur.play(DeviceFileSource(fichier.path));
      if (mounted) {
        setState(() {
          _audioEnLecture = id;
          _position = Duration.zero;
        });
      }
    } catch (_) {
      // Lecture impossible : la bulle reste affichee telle quelle.
    }
  }

  String _mmss(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  /// Bulle d'un message vocal : lecture, forme d'onde et duree.
  Widget _bulleAudio(Map piece, bool aMoi) {
    final id = piece['id'];
    final enLecture = _audioEnLecture == id;
    final avance = (enLecture && _total.inMilliseconds > 0)
        ? _position.inMilliseconds / _total.inMilliseconds
        : 0.0;

    // Forme d'onde reelle, captee a l'enregistrement ; a defaut, un trace
    // neutre derive de l'identifiant (messages envoyes avant cet ajout).
    final brut = (piece['niveaux'] ?? '').toString();
    final barres = brut.isNotEmpty
        ? brut
              .split(',')
              .map((e) => double.tryParse(e) ?? 0.2)
              .map((e) => e.clamp(0.08, 1.0).toDouble())
              .toList()
        : List<double>.generate(
            32,
            (i) =>
                0.25 +
                ((((id is int ? id : 0).abs() + i * 7919) % 13) / 13) * 0.75,
          );

    final couleurActive = aMoi ? Colors.white : const Color(0xFF2563EB);
    final couleurInactive = aMoi
        ? Colors.white.withValues(alpha: 0.45)
        : const Color(0xFF94A3B8);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () => _jouerAudio(piece),
          child: Icon(
            enLecture ? LucideIcons.pause : LucideIcons.play,
            size: 24,
            color: couleurActive,
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 150,
          height: 30,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < barres.length; i++)
                Container(
                  width: 2.5,
                  height: barres[i] * 26,
                  decoration: BoxDecoration(
                    color: i / barres.length <= avance
                        ? couleurActive
                        : couleurInactive,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          enLecture && _total > Duration.zero
              ? _mmss(_position)
              : _mmss(_total),
          style: GoogleFonts.poppins(
            fontSize: 10.5,
            color: aMoi
                ? Colors.white.withValues(alpha: 0.8)
                : const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  /// Demarre un message vocal : chrono + niveaux pour la forme d'onde.
  Future<void> _demarrerEnregistrement() async {
    if (_enregistre) return;
    if (!await _enregistreur.hasPermission()) return;

    final dossier = await getTemporaryDirectory();
    _cheminEnCours =
        '${dossier.path}/chat-${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _enregistreur.start(const RecordConfig(), path: _cheminEnCours!);

    setState(() {
      _enregistre = true;
      _enPause = false;
      _duree = Duration.zero;
      _niveaux.clear();
    });

    _chrono = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_enPause) setState(() => _duree += const Duration(seconds: 1));
    });

    // L'amplitude est en dBFS (environ -60 a 0) : ramenee en hauteur de barre.
    _ecouteNiveaux = _enregistreur
        .onAmplitudeChanged(const Duration(milliseconds: 120))
        .listen((amplitude) {
          final niveau = ((amplitude.current + 45) / 45).clamp(0.05, 1.0);
          setState(() {
            _niveaux.add(niveau.toDouble());
            if (_niveaux.length > 48) _niveaux.removeAt(0);
          });
        });
  }

  Future<void> _basculerPause() async {
    if (!_enregistre) return;

    if (_enPause) {
      await _enregistreur.resume();
    } else {
      await _enregistreur.pause();
    }
    setState(() => _enPause = !_enPause);
  }

  /// Arrete l'enregistrement et rend le fichier produit.
  Future<String?> _arreterEnregistrement() async {
    _chrono?.cancel();
    await _ecouteNiveaux?.cancel();
    _chrono = null;
    _ecouteNiveaux = null;

    final chemin = await _enregistreur.stop();
    setState(() {
      _enregistre = false;
      _enPause = false;
      _niveaux.clear();
      _duree = Duration.zero;
    });

    return chemin ?? _cheminEnCours;
  }

  Future<void> _annulerEnregistrement() async {
    final chemin = await _arreterEnregistrement();
    if (chemin == null) return;

    try {
      final fichier = File(chemin);
      if (await fichier.exists()) await fichier.delete();
    } catch (_) {
      // Fichier temporaire : son effacement n'est pas critique.
    }
  }

  /// Niveaux de la capture, ramenes a 32 valeurs pour la bulle.
  String _niveauxCompresses(List<double> source) {
    if (source.isEmpty) return '';

    const cible = 32;
    final pas = source.length / cible;
    final retenus = <String>[];
    for (var i = 0; i < cible; i++) {
      final index = (i * pas).floor().clamp(0, source.length - 1);
      retenus.add(source[index].toStringAsFixed(2));
    }

    return retenus.join(',');
  }

  /// Arrete et envoie directement le message vocal.
  Future<void> _envoyerEnregistrement() async {
    // Les niveaux sont vides apres l'arret : on les garde avant.
    final niveaux = _niveauxCompresses(List<double>.from(_niveaux));
    final chemin = await _arreterEnregistrement();
    if (chemin == null) return;

    final octets = await File(chemin).readAsBytes();
    _pieces.add({
      'nomFichier':
          'message-vocal-${DateTime.now().millisecondsSinceEpoch}.m4a',
      'extension': 'm4a',
      'typeMime': 'audio/m4a',
      'base64': base64Encode(octets),
      if (niveaux.isNotEmpty) 'niveaux': niveaux,
    });

    await _envoyer();
  }

  Future<void> _envoyer() async {
    final texte = _champ.text;
    if (texte.trim().isEmpty && _pieces.isEmpty) return;

    final ok = await _controller.envoyer(
      contenu: texte,
      employeId: widget.employeId,
      piecesJointes: List<Map<String, dynamic>>.from(_pieces),
    );

    if (ok) {
      _champ.clear();
      setState(_pieces.clear);
      _prechargerImages(_controller.messages.toList());
      _versLeBas();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
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
          onPressed: Get.back,
        ),
        title: Column(
          children: [
            Text(
              widget.titre,
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            Text(
              widget.employeId == null ? 'Votre discussion' : 'Employé',
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const AmbientBackground(),
          SafeArea(
            // La marge basse est reprise par la barre de saisie, sinon il reste
            // une bande vide sous elle.
            bottom: false,
            child: Column(
              children: [
                Expanded(
                  child: Obx(() {
                    if (_controller.isLoading.value &&
                        _controller.messages.isEmpty) {
                      return const Center(
                        child: CircularProgressIndicator(strokeWidth: 2.2),
                      );
                    }

                    if (_controller.messages.isEmpty) {
                      return _vide();
                    }

                    return ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                      itemCount: _controller.messages.length,
                      itemBuilder: (_, i) => _bulle(_controller.messages[i]),
                    );
                  }),
                ),
                _barreSaisie(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _vide() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              LucideIcons.messageCircle,
              size: 28,
              color: _accent,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Aucun message',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.employeId == null
                ? "Écrivez votre premier message à l'administration."
                : 'Aucun échange avec cet employé pour le moment.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: const Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }

  /// Une bulle par message : les miens a droite, les autres a gauche.
  Widget _bulle(Map<String, dynamic> m) {
    final deAdmin = m['reponse'] == true;
    final aMoi = widget.employeId == null ? !deAdmin : deAdmin;
    final pieces = m['piecesJointes'];
    final texte = (m['contenu'] ?? '').toString();

    return Align(
      alignment: aMoi ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.76,
        ),
        decoration: BoxDecoration(
          color: aMoi
              ? _accent.withValues(alpha: 0.92)
              : Colors.white.withValues(alpha: 0.88),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(aMoi ? 14 : 4),
            bottomRight: Radius.circular(aMoi ? 4 : 14),
          ),
          border: Border.all(
            color: aMoi
                ? Colors.transparent
                : const Color(0xFFE2E8F0).withValues(alpha: 0.9),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Le nom de l'auteur est affiche sur toutes les bulles.
            if ((m['expediteurNom'] ?? '').toString().trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  m['expediteurNom'].toString(),
                  style: GoogleFonts.poppins(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: aMoi ? Colors.white.withValues(alpha: 0.9) : _accent,
                  ),
                ),
              ),
            if (texte.isNotEmpty)
              Text(
                texte,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: aMoi ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            if (pieces is List && pieces.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final p in pieces.whereType<Map>())
                    if (_estAudio(p))
                      _bulleAudio(p, aMoi)
                    else if (_estImage(p) && _images[p['id']] != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(
                          _images[p['id']]!,
                          width: 190,
                          fit: BoxFit.cover,
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: aMoi
                              ? Colors.white.withValues(alpha: 0.18)
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        // La puce est bornee a la largeur de la bulle : un
                        // nom de fichier long debordait la Row.
                        constraints: const BoxConstraints(maxWidth: 220),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              LucideIcons.paperclip,
                              size: 12,
                              color: aMoi
                                  ? Colors.white
                                  : const Color(0xFF475569),
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                (p['nomFichier'] ?? 'pièce jointe').toString(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  fontSize: 10.5,
                                  color: aMoi
                                      ? Colors.white
                                      : const Color(0xFF475569),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                ],
              ),
            ],
            const SizedBox(height: 3),
            Text(
              _heure(m['dateEnvoi']),
              style: GoogleFonts.poppins(
                fontSize: 9.5,
                color: aMoi
                    ? Colors.white.withValues(alpha: 0.75)
                    : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _heure(dynamic raw) {
    final s = (raw ?? '').toString();
    if (s.length < 16) return '';
    final date = s.substring(0, 10).split('-');
    final heure = s.substring(11, 16);

    return date.length == 3 ? '${date[2]}/${date[1]} $heure' : heure;
  }

  /// Barre de saisie facon messagerie : « + » a gauche, champ arrondi, puis
  /// appareil photo et micro — remplaces par l'envoi des qu'il y a du contenu.
  Widget _barreSaisie() {
    final aEnvoyer = _champ.text.trim().isNotEmpty || _pieces.isNotEmpty;

    if (_enregistre) return _panneauEnregistrement();

    return Container(
      padding: EdgeInsets.fromLTRB(
        8,
        8,
        8,
        10 + MediaQuery.of(context).viewPadding.bottom,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        border: Border(
          top: BorderSide(
            color: const Color(0xFFE2E8F0).withValues(alpha: 0.8),
          ),
        ),
      ),
      child: Column(
        children: [
          if (_pieces.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (var i = 0; i < _pieces.length; i++)
                    Chip(
                      label: Text(
                        _pieces[i]['nomFichier'].toString(),
                        style: GoogleFonts.poppins(fontSize: 10.5),
                      ),
                      onDeleted: () => setState(() => _pieces.removeAt(i)),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _actionBarre(
                icone: LucideIcons.plus,
                tooltip: 'Joindre',
                onTap: _feuillePieces,
              ),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: TextField(
                    controller: _champ,
                    minLines: 1,
                    maxLines: 4,
                    onChanged: (_) => setState(() {}),
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: const Color(0xFF0F172A),
                    ),
                    decoration: InputDecoration(
                      hintText: 'Votre message…',
                      hintStyle: GoogleFonts.poppins(
                        fontSize: 13,
                        color: const Color(0xFF94A3B8),
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 11,
                      ),
                    ),
                  ),
                ),
              ),
              if (!aEnvoyer) ...[
                _actionBarre(
                  icone: LucideIcons.camera,
                  tooltip: 'Prendre une photo',
                  onTap: () => _joindreImage(ImageSource.camera),
                ),
                _actionBarre(
                  icone: _enregistre ? LucideIcons.square : LucideIcons.mic,
                  tooltip: _enregistre
                      ? "Arrêter l'enregistrement"
                      : 'Message vocal',
                  couleur: _enregistre ? const Color(0xFFDC2626) : null,
                  onTap: _demarrerEnregistrement,
                ),
              ] else ...[
                const SizedBox(width: 6),
                Obx(
                  () => GestureDetector(
                    onTap: _controller.isSending.value ? null : _envoyer,
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: _controller.isSending.value
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Icon(
                              LucideIcons.send,
                              size: 18,
                              color: Colors.white,
                            ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// Panneau d'enregistrement : chrono, forme d'onde, corbeille, pause, envoi.
  Widget _panneauEnregistrement() {
    final minutes = _duree.inMinutes;
    final secondes = (_duree.inSeconds % 60).toString().padLeft(2, '0');

    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.of(context).viewPadding.bottom,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                '$minutes:$secondes',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 18),
              Expanded(child: _formeOnde()),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(
                  LucideIcons.trash2,
                  size: 24,
                  color: Colors.white,
                ),
                tooltip: "Annuler l'enregistrement",
                onPressed: _annulerEnregistrement,
              ),
              GestureDetector(
                onTap: _basculerPause,
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFEF4444),
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    _enPause ? LucideIcons.play : LucideIcons.pause,
                    size: 22,
                    color: const Color(0xFFEF4444),
                  ),
                ),
              ),
              GestureDetector(
                onTap: _envoyerEnregistrement,
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: const BoxDecoration(
                    color: Color(0xFF22C55E),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    LucideIcons.send,
                    size: 22,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Barres de niveau : hautes quand on parle, points quand c'est silencieux.
  Widget _formeOnde() {
    const nb = 48;
    final niveaux = List<double>.filled(nb, 0.05);
    final depart = nb - _niveaux.length;
    for (var i = 0; i < _niveaux.length; i++) {
      niveaux[depart + i] = _niveaux[i];
    }

    return SizedBox(
      height: 34,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (final niveau in niveaux)
            Container(
              width: 2.5,
              height: (niveau * 34).clamp(2.5, 34.0),
              decoration: BoxDecoration(
                color: niveau < 0.1
                    ? const Color(0xFF94A3B8).withValues(alpha: 0.5)
                    : const Color(0xFF2563EB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
        ],
      ),
    );
  }

  Widget _actionBarre({
    required IconData icone,
    required String tooltip,
    required VoidCallback onTap,
    Color? couleur,
  }) {
    return IconButton(
      icon: Icon(icone, size: 22, color: couleur ?? const Color(0xFF475569)),
      tooltip: tooltip,
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      constraints: const BoxConstraints(minWidth: 36, minHeight: 42),
    );
  }

  /// Choix de la source d'une piece jointe, en feuille de verre.
  Future<void> _feuillePieces() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (contexte) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            color: Colors.white.withValues(alpha: 0.9),
            padding: EdgeInsets.only(
              top: 8,
              bottom: 12 + MediaQuery.of(contexte).viewPadding.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF94A3B8).withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                ListTile(
                  leading: const Icon(
                    LucideIcons.image,
                    color: Color(0xFF7C3AED),
                  ),
                  title: Text(
                    'Galerie',
                    style: GoogleFonts.poppins(fontSize: 13),
                  ),
                  onTap: () {
                    Navigator.of(contexte).pop();
                    _joindreImage(ImageSource.gallery);
                  },
                ),
                ListTile(
                  leading: const Icon(
                    LucideIcons.camera,
                    color: Color(0xFF2563EB),
                  ),
                  title: Text(
                    'Appareil photo',
                    style: GoogleFonts.poppins(fontSize: 13),
                  ),
                  onTap: () {
                    Navigator.of(contexte).pop();
                    _joindreImage(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: const Icon(
                    LucideIcons.mic,
                    color: Color(0xFFDC2626),
                  ),
                  title: Text(
                    'Message vocal',
                    style: GoogleFonts.poppins(fontSize: 13),
                  ),
                  onTap: () {
                    Navigator.of(contexte).pop();
                    _demarrerEnregistrement();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Liste des fils, pour les porteurs du droit CHAT_REPONDRE.
class ChatFilsPage extends StatefulWidget {
  const ChatFilsPage({super.key});

  @override
  State<ChatFilsPage> createState() => _ChatFilsPageState();
}

class _ChatFilsPageState extends State<ChatFilsPage> {
  late final ChatController _controller;
  final TextEditingController _recherche = TextEditingController();
  String _requete = '';

  @override
  void dispose() {
    _recherche.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _controller = Get.isRegistered<ChatController>()
        ? Get.find<ChatController>()
        : Get.put(ChatController());
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _controller.chargerFils(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
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
          onPressed: Get.back,
        ),
        title: Text(
          'Discussions',
          style: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const AmbientBackground(),
          SafeArea(
            child: Obx(() {
              final fils = _filtrer(_controller.fils);

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
                    child: _champRecherche(fils.length),
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () =>
                          _controller.chargerFils(showLoading: false),
                      child: Builder(
                        builder: (_) {
                          if (_controller.isLoading.value &&
                              _controller.fils.isEmpty) {
                            return const Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                              ),
                            );
                          }

                          if (fils.isEmpty) {
                            return ListView(
                              children: [
                                const SizedBox(height: 120),
                                Center(
                                  child: Text(
                                    _requete.trim().isEmpty
                                        ? 'Aucune discussion'
                                        : 'Aucun résultat',
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      color: const Color(0xFF94A3B8),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }

                          return ListView.builder(
                            padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
                            itemCount: fils.length,
                            itemBuilder: (_, i) => _carteFil(fils[i]),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  /// Photo du compte si elle existe, initiale sinon. La photo arrive en
  /// base64, parfois prefixee d'une data-URL.
  static Widget _avatar(dynamic photo, String nom, {double taille = 20}) {
    final brut = (photo ?? '').toString().trim();
    if (brut.isNotEmpty) {
      try {
        final base64Nu = brut.contains(',') ? brut.split(',').last : brut;

        return CircleAvatar(
          radius: taille,
          backgroundImage: MemoryImage(base64Decode(base64Nu)),
        );
      } catch (_) {
        // Photo illisible : on retombe sur l'initiale.
      }
    }

    return CircleAvatar(
      radius: taille,
      backgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.12),
      child: Text(
        nom.trim().isEmpty ? '?' : nom.trim().characters.first.toUpperCase(),
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.w700,
          color: const Color(0xFF2563EB),
        ),
      ),
    );
  }

  /// Filtre les fils sur le nom de l'employe.
  List<Map<String, dynamic>> _filtrer(List<Map<String, dynamic>> fils) {
    final q = _requete.trim().toLowerCase();
    if (q.isEmpty) return fils.toList();

    return fils
        .where(
          (f) => (f['employeNom'] ?? '').toString().toLowerCase().contains(q),
        )
        .toList();
  }

  Widget _champRecherche(int resultats) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.95),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1F3A5F).withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: TextField(
            controller: _recherche,
            onChanged: (v) => setState(() => _requete = v),
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: const Color(0xFF0F172A),
            ),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Filtrer par nom…',
              hintStyle: GoogleFonts.poppins(
                fontSize: 13,
                color: const Color(0xFF94A3B8),
              ),
              prefixIcon: const Padding(
                padding: EdgeInsets.only(left: 14, right: 8),
                child: Icon(
                  LucideIcons.search,
                  size: 18,
                  color: Color(0xFF94A3B8),
                ),
              ),
              prefixIconConstraints: const BoxConstraints(
                minWidth: 0,
                minHeight: 32,
              ),
              suffixIcon: _requete.isEmpty
                  ? null
                  : Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: Text(
                        '$resultats',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ),
              suffixIconConstraints: const BoxConstraints(
                minWidth: 32,
                minHeight: 32,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 13),
            ),
          ),
        ),
      ),
    );
  }

  Widget _carteFil(Map<String, dynamic> f) {
    final nom = (f['employeNom'] ?? '—').toString().trim();
    final nonLus = (f['nonLus'] is num) ? (f['nonLus'] as num).toInt() : 0;
    final id = f['employeId'];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.95)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: ListTile(
            leading: _avatar(f['employePhoto'], nom),
            title: Text(
              nom.isEmpty ? '—' : nom,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              '${f['nbMessages'] ?? 0} message(s)',
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: const Color(0xFF94A3B8),
              ),
            ),
            trailing: nonLus > 0
                ? Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDC2626),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$nonLus',
                      style: GoogleFonts.poppins(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  )
                : const Icon(
                    LucideIcons.chevronRight,
                    size: 16,
                    color: Color(0xFF94A3B8),
                  ),
            onTap: id is! int
                ? null
                : () async {
                    await Get.to(() => ChatPage(employeId: id, titre: nom));
                    _controller.chargerFils(showLoading: false);
                    _controller.rafraichirNonLus();
                  },
          ),
        ),
      ),
    );
  }
}
