import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../controllers/auth_controller.dart';
import '../../services/api_service.dart';
import '../../widgets/apercu_kit.dart';

/// Historique (renouvellements) d'un document administratif, comme la page
/// « Historique du document » du web.
class DocumentHistoriquePage extends StatefulWidget {
  final int docId;
  final String titre;
  final String sousTitre;

  const DocumentHistoriquePage({
    super.key,
    required this.docId,
    required this.titre,
    this.sousTitre = 'Historique du document',
  });

  @override
  State<DocumentHistoriquePage> createState() => _DocumentHistoriquePageState();
}

class _DocumentHistoriquePageState extends State<DocumentHistoriquePage> {
  final _auth = Get.find<AuthController>();

  List<Map<String, dynamic>> _versions = const [];
  bool _chargement = true;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    try {
      final data = await _auth.makeRequest(
        ApiService.historiqueDocVehicule(widget.docId),
        method: 'GET',
        showErrorSnackbar: false,
      );
      final contenu = data is Map ? (data['content'] ?? data['data']) : data;
      final liste = contenu is List
          ? contenu.whereType<Map>().map(Map<String, dynamic>.from).toList()
          : <Map<String, dynamic>>[];

      // Le plus recent d'abord, comme la page web.
      liste.sort(
        (a, b) => (b['dateCreation'] ?? '').toString().compareTo(
          (a['dateCreation'] ?? '').toString(),
        ),
      );
      if (mounted) setState(() => _versions = liste);
    } catch (_) {
      if (mounted) setState(() => _versions = const []);
    } finally {
      if (mounted) setState(() => _chargement = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ApercuScaffold(
      titre: widget.titre,
      sousTitre: widget.sousTitre,
      chargement: _chargement,
      onglets: const ['Historique'],
      contenus: [
        if (_versions.isEmpty && !_chargement)
          apercuVide(
            "Ce document n'a jamais été renouvelé.\n"
            'Son historique apparaîtra ici après le premier renouvèlement.',
          )
        else
          apercuScroll([
            // Numerotation du web : la plus ancienne version est la Version 1.
            for (var i = 0; i < _versions.length; i++)
              _carte(_versions[i], _versions.length - i),
          ], cle: const ValueKey('doc-historique')),
      ],
    );
  }

  Widget _carte(Map<String, dynamic> h, int version) {
    final valide = h['valide'];

    return apercuCarte(
      titre: 'Version $version',
      icone: LucideIcons.archive,
      couleur: kApViolet,
      etiquette: (h['docAdmPrcLibelle'] ?? '').toString(),
      lignes: [
        apercuLigne(
          'N° document',
          h['numeroDocument'],
          LucideIcons.fileText,
          kApArdoise,
        ),
        apercuLigne('Référence', h['reference'], LucideIcons.hash, kApArdoise),
        apercuLigne(
          'Organisme émetteur',
          h['organismeDocsPrcLibelle'],
          LucideIcons.building2,
          kApArdoise,
        ),
        apercuLigne(
          'Document valide',
          valide == null ? null : (valide == true ? 'Oui' : 'Non'),
          valide == true ? LucideIcons.checkCircle2 : LucideIcons.xCircle,
          valide == true ? kApVert : kApRouge,
        ),
        apercuLigne(
          'Émission',
          apercuDate(h['dateEmission']),
          LucideIcons.calendar,
          kApBleu,
        ),
        apercuLigne(
          'Début validité',
          apercuDate(h['dateDebutValidite']),
          LucideIcons.calendarCheck,
          kApBleu,
        ),
        apercuLigne(
          'Fin validité',
          apercuDate(h['dateFinValidite']),
          LucideIcons.calendarX,
          kApRouge,
        ),
        apercuLigne(
          'Alerte',
          apercuDate(h['dateAlerte']),
          LucideIcons.bellRing,
          kApAmbre,
        ),
        apercuLigne(
          'Coût',
          apercuMontant(h['cout']),
          LucideIcons.wallet,
          kApVert,
        ),
        apercuLigne(
          'Observation',
          h['observation'],
          LucideIcons.messageSquare,
          kApArdoise,
        ),
        apercuLigne(
          'Archivé le',
          apercuDate(h['dateCreation']),
          LucideIcons.archive,
          kApArdoise,
        ),
      ],
    );
  }
}
