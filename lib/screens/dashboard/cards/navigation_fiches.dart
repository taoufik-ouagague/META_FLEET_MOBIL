import 'package:get/get.dart';

import '../../../controllers/auth_controller.dart';
import '../../../models/vehicule_model.dart';
import '../../../services/api_service.dart';
import '../../demandes/demande_or_apercu_page.dart';
import '../../or/or_apercu_page.dart';
import '../../vehicules/vehicule_apercu_page.dart';
import '../../vidanges/vidange_apercu_page.dart';

/// Onglets de la fiche OR, pour que les cartes du tableau de bord ouvrent
/// directement la partie concernee.
class OngletVehicule {
  static const informations = 0;
  static const documents = 1;
  static const historique = 2;
}

class OngletOr {
  static const informations = 0;
  static const approvisionnement = 2;
  static const ligneDemande = 3;
  static const receptionFinanciere = 5;
}

int? _entier(dynamic valeur) {
  if (valeur is int) return valeur;
  if (valeur is num) return valeur.toInt();
  return int.tryParse(valeur?.toString() ?? '');
}

void _introuvable(String quoi) {
  Get.snackbar(
    'Fiche indisponible',
    'Impossible de retrouver $quoi de cette ligne.',
    snackPosition: SnackPosition.BOTTOM,
  );
}

/// La fiche OR recharge tout depuis l'identifiant : un ordre reduit a son id
/// suffit, meme quand la ligne vient d'un bon d'achat ou d'une ligne demande.
void ouvrirFicheOr(
  Map<String, dynamic> item, {
  int onglet = OngletOr.informations,
}) {
  final id = _entier(item['ordreReparationId'] ?? item['id']);
  if (id == null) return _introuvable("l'ordre de réparation");

  Get.to(() => OrApercuPage(ordre: {'id': id}, ongletInitial: onglet));
}

void ouvrirFicheDemandeOr(Map<String, dynamic> item) {
  if (_entier(item['id']) == null) return _introuvable('la demande');

  Get.to(() => DemandeOrApercuPage(demande: item));
}

/// Alertes et erreurs de kilometrage : la ligne porte le vehicule et, selon la
/// source, l'identifiant de sa derniere vidange. A defaut, on va la chercher
/// par le vehicule — la liste est triee du plus recent au plus ancien.
Future<void> ouvrirFicheVidange(Map<String, dynamic> item) async {
  final auth = Get.find<AuthController>();
  final idVidange = _entier(item['vidangeId'] ?? item['idVidange']);

  if (idVidange != null) {
    try {
      final data = await auth.makeRequest(
        ApiService.getVidange(idVidange),
        method: 'GET',
        showErrorSnackbar: false,
      );
      if (data is Map) {
        Get.to(
          () => VidangeApercuPage(vidange: Map<String, dynamic>.from(data)),
        );
        return;
      }
    } catch (_) {
      // Fiche indisponible : on tente par le vehicule.
    }
  }

  final idVehicule = _entier(item['vehiculeId'] ?? item['id']);
  if (idVehicule != null) {
    try {
      final data = await auth.makeRequest(
        ApiService.listVidanges(page: 0, size: 1),
        method: 'POST',
        body: {'vehiculeId': idVehicule},
        showErrorSnackbar: false,
      );
      final contenu = data is Map ? (data['content'] ?? data['data']) : data;
      if (contenu is List && contenu.isNotEmpty && contenu.first is Map) {
        Get.to(
          () => VidangeApercuPage(
            vidange: Map<String, dynamic>.from(contenu.first as Map),
          ),
        );
        return;
      }
    } catch (_) {
      // Liste indisponible : on retombe sur le vehicule.
    }
  }

  // Vehicule sans vidange enregistree : sa fiche, sur l'onglet Historique.
  ouvrirFicheVehicule(item, onglet: OngletVehicule.historique);
}

/// Fiche vehicule : la ligne ne porte que quelques champs, d'ou le
/// rechargement avant ouverture.
Future<void> ouvrirFicheVehicule(
  Map<String, dynamic> item, {
  int onglet = OngletVehicule.informations,
}) async {
  final id = _entier(item['vehiculeId'] ?? item['id']);
  if (id == null) return _introuvable('le véhicule');

  Map<String, dynamic> brut = {
    'id': id,
    'immatriculation': item['immatriculation'],
    'marqueLibelle': item['marque'],
    'modeleLibelle': item['modele'],
  };

  try {
    final data = await Get.find<AuthController>().makeRequest(
      ApiService.getVehicule(id),
      method: 'GET',
      showErrorSnackbar: false,
    );
    if (data is Map) brut = Map<String, dynamic>.from(data);
  } catch (_) {
    // Fiche indisponible : on ouvre avec le peu que porte la ligne.
  }

  Get.to(
    () => VehiculeApercuPage(
      vehicule: VehiculeModel.fromJson(brut),
      ongletInitial: onglet,
    ),
  );
}
