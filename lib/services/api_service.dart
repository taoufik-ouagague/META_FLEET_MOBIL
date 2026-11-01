import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String defaultDevUrl = 'http://localhost:8080';
  static const String defaultAndroidEmulatorUrl = 'http://10.0.2.2:8080';
  static const String defaultLanUrl = 'http://192.168.2.242:9797/GMAOAPIPROD';

  static String baseUrl = _resolveDefaultUrl();

  static String _resolveDefaultUrl() {
    if (kIsWeb) return defaultDevUrl;
    if (Platform.isAndroid) return defaultAndroidEmulatorUrl;
    return defaultDevUrl;
  }

  /// Initialise l'URL de base depuis SharedPreferences si elle a été personnalisée
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUrl = prefs.getString('server_base_url');
    if (savedUrl != null && savedUrl.trim().isNotEmpty) {
      baseUrl = savedUrl.trim();
    }
  }

  /// Met à jour l'URL de base et la persiste dans le stockage local
  static Future<void> setBaseUrl(String newUrl) async {
    baseUrl = newUrl.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('server_base_url', baseUrl);
  }

  // ==================== AUTHENTIFICATION & EMPLOYÉS ====================
  static String login() => '$baseUrl/api/auth/login';
  static String changePassword() => '$baseUrl/api/auth/changePassword';
  static String getEmploye(int id) => '$baseUrl/api/employes/getEmploye/$id';
  static String updateUserPhoto(int userId) =>
      '$baseUrl/api/securite/users/updatePhoto/$userId';
  static String updateFcmToken() =>
      '$baseUrl/api/securite/users/updateFcmToken';

  // ==================== VÉHICULES ====================
  static String listVehicules({int page = 0, int size = 20}) =>
      '$baseUrl/api/vehicules/listVehicules?page=$page&size=$size';
  static String getVehicule(int id) => '$baseUrl/api/vehicules/getVehicule/$id';
  static String getActiveVehicules() =>
      '$baseUrl/api/vehicules/getActiveVehicules';
  static String getActiveVehiculesByAgenceConnecte() =>
      '$baseUrl/api/vehicules/getActiveVehiculesByAgenceConnecte';
  static String getActiveMarques() =>
      '$baseUrl/api/marquesPrc/getActiveMarques';
  static String getActiveModeles() =>
      '$baseUrl/api/modelesPrc/getActiveModeles';
  static String getActiveModelesByMarque(int marqueId) =>
      '$baseUrl/api/modelesPrc/getActiveModelesByMarque/$marqueId';
  static String getActiveCategoriesVehicules() =>
      '$baseUrl/api/categoriesVehicules/getActiveCategoriesVehicules';

  // ==================== ORDRES DE RÉPARATION (OR) ====================
  static String listOr({int page = 0, int size = 20}) =>
      '$baseUrl/api/ordrereparation/listOrdresReparations?page=$page&size=$size';
  static String getOr(int id) => '$baseUrl/api/ordrereparation/getORById/$id';

  // Sous-ressources d'un OR (aperçu en consultation)
  static String getLignesByOr(int id) =>
      '$baseUrl/api/lignesDemandeOR/getLignesByOrdreReparation/$id';
  static String getIntervenantsByOr(int id) =>
      '$baseUrl/api/intervenants/getByOrdreReparation/$id';
  // POST côté backend, contrairement aux autres sous-ressources.
  static String getPrestatairesByOr(int id) =>
      '$baseUrl/api/fournisseursOtPrc/getByOrdreReparation/$id';
  static String getDemandesAchatsByOr(int id) =>
      '$baseUrl/api/ordrereparation/getDemandesAchatsByOr/$id';
  // Actions sur les bons : appro et achat ont chacun leur endpoint et leur droit.
  static String validerBonApprovisionnement(int demandeAchatId) =>
      '$baseUrl/api/ordrereparation/validerBonApprovisionnement/$demandeAchatId';
  static String validerBonAchat(int demandeAchatId) =>
      '$baseUrl/api/ordrereparation/validerBonAchat/$demandeAchatId';
  static String rejeterBonApprovisionnement(int demandeAchatId) =>
      '$baseUrl/api/ordrereparation/rejeterBonApprovisionnement/$demandeAchatId';
  static String rejeterBonAchat(int demandeAchatId) =>
      '$baseUrl/api/ordrereparation/rejeterBonAchat/$demandeAchatId';
  static String supprimerBonApprovisionnement(int demandeAchatId) =>
      '$baseUrl/api/ordrereparation/supprimerBonApprovisionnement/$demandeAchatId';
  static String supprimerBonAchat(int demandeAchatId) =>
      '$baseUrl/api/ordrereparation/supprimerBonAchat/$demandeAchatId';

  static String getPiecesByOr(int id) =>
      '$baseUrl/api/ordrereparation/getPiecesByOr/$id';
  // Coordonnées d'un prestataire : absentes de fournisseursOtPrc.
  static String getFournisseur(int id) =>
      '$baseUrl/api/fournisseursPrc/getFournisseurPrc/$id';

  // Rapports PDF : un bon d'approvisionnement a son propre modèle.
  static String rapportDemandeAchat(int id) =>
      '$baseUrl/api/reports/gmao/demandeachat/$id';
  static String rapportBonApprovisionnement(int id) =>
      '$baseUrl/api/reports/gmao/bonapprovisionnement/$id';
  static String getActiveNaturesAnomalies() =>
      '$baseUrl/api/naturesAnomalies/getActiveNaturesAnomalies';

  // ==================== CHAT ====================
  // Fil de l'employe connecte.
  static String chatMonFil() => '$baseUrl/api/chat/monFil';
  static String chatNonLus() => '$baseUrl/api/chat/nonLus';

  // Cote administration (droit CHAT_REPONDRE).
  static String chatFils() => '$baseUrl/api/chat/fils';
  static String chatFil(int employeId) => '$baseUrl/api/chat/fils/$employeId';

  static String chatPieceJointe(int pieceJointeId) =>
      '$baseUrl/api/chat/piecesJointes/$pieceJointeId';

  // ==================== JOURNAL ====================
  // Journal pagine cote serveur (85k+ lignes) : les filtres passent en query.
  static String journal({
    int page = 0,
    int size = 20,
    String? immatriculation,
    String? ordreNumero,
    String? typeOperation,
    String? article,
    int? natureAnomalieId,
  }) {
    final filtres = <String>[
      if ((immatriculation ?? '').trim().isNotEmpty)
        'immatriculation=${Uri.encodeQueryComponent(immatriculation!.trim())}',
      if ((ordreNumero ?? '').trim().isNotEmpty)
        'ordreNumero=${Uri.encodeQueryComponent(ordreNumero!.trim())}',
      if ((typeOperation ?? '').trim().isNotEmpty)
        'typeOperation=${Uri.encodeQueryComponent(typeOperation!.trim())}',
      if ((article ?? '').trim().isNotEmpty)
        'article=${Uri.encodeQueryComponent(article!.trim())}',
      if (natureAnomalieId != null) 'natureAnomalieId=$natureAnomalieId',
    ];

    return '$baseUrl/api/ordrereparation/journal'
        '?page=$page&size=$size'
        '${filtres.isEmpty ? '' : '&${filtres.join('&')}'}';
  }

  // Catalogue des articles, pour le filtre « Article » du journal.
  static String getActiveProduits() =>
      '$baseUrl/api/produitsPrc/getActiveProduits';

  // ==================== PNEUMATIQUES ====================
  static String listPneumatiques({int page = 0, int size = 20}) =>
      '$baseUrl/api/pneumatiques/listPneumatiques?page=$page&size=$size';
  static String getPneumatique(int id) =>
      '$baseUrl/api/pneumatiques/getPneumatique/$id';
  static String historiquePneumatique(int id) =>
      '$baseUrl/api/pneumatiques/historique/$id';

  // ==================== DOCUMENTS VEHICULE ====================
  static String listDocsVehicules({int page = 0, int size = 20}) =>
      '$baseUrl/api/docs-adm-vehicules-prc/listDocs?page=$page&size=$size';

  // ==================== VIDANGES ====================
  static String listVidanges({int page = 0, int size = 20}) =>
      '$baseUrl/api/vidanges/listVidanges?page=$page&size=$size';
  static String getVidange(int id) => '$baseUrl/api/vidanges/getById/$id';
  static String getPiecesByVidange(int id) =>
      '$baseUrl/api/vidanges/getPiecesByVidange/$id';
  static String getArticlesByVidange(int id) =>
      '$baseUrl/api/articlesvidanges/getByVidange/$id';
  static String getDemandesAchatsByVidange(int id) =>
      '$baseUrl/api/vidanges/getDemandesAchatsByVidange/$id';
  // Bons d'achat et d'approvisionnement d'une vidange : memes actions que l'OR,
  // sur les routes du module vidanges.
  static String validerBonAchatVidange(int demandeAchatId) =>
      '$baseUrl/api/vidanges/validerBonAchat/$demandeAchatId';
  static String validerBonApproVidange(int demandeAchatId) =>
      '$baseUrl/api/vidanges/validerBonApprovisionnement/$demandeAchatId';
  static String rejeterBonAchatVidange(int demandeAchatId) =>
      '$baseUrl/api/vidanges/rejeterBonAchat/$demandeAchatId';
  static String rejeterBonApproVidange(int demandeAchatId) =>
      '$baseUrl/api/vidanges/rejeterBonApprovisionnement/$demandeAchatId';
  static String supprimerBonAchatVidange(int demandeAchatId) =>
      '$baseUrl/api/vidanges/supprimerBonAchat/$demandeAchatId';
  static String supprimerBonApproVidange(int demandeAchatId) =>
      '$baseUrl/api/vidanges/supprimerBonApprovisionnement/$demandeAchatId';

  // ==================== OPÉRATIONS ADMINISTRATIVES & AGENDA ====================
  static String listOperations({int page = 0, int size = 20}) =>
      '$baseUrl/api/operations-adm/listOperations?page=$page&size=$size';
  static String getOperation(int id) =>
      '$baseUrl/api/operations-adm/getOperation/$id';
  static String getDocsByVehiculeId(int vehiculeId) =>
      '$baseUrl/api/docs-adm-vehicules-prc/getDocsByVehiculeId/$vehiculeId';
  // Historique (renouvellements) d'un document administratif.
  static String historiqueDocVehicule(int docId) =>
      '$baseUrl/api/docs-adm-vehicules-hist-prc/listByDoc/$docId';

  static String listDocsEnAlerte() =>
      '$baseUrl/api/docs-adm-vehicules-prc/listDocsEnAlerte';

  // ==================== DEMANDES D'ACHAT ====================
  static String listDemandesAchats({int page = 0, int size = 20}) =>
      '$baseUrl/api/demandeachat/listDemandesAchats?page=$page&size=$size';

  // ==================== TABLEAU DE BORD (13 CARTES GMAO) ====================
  // 1. Alertes vidange
  static String listAlertesVidange() =>
      '$baseUrl/api/vidanges/listAlertesVidange';
  // 2. Erreurs de kilométrage
  static String listErreursKilometrage() =>
      '$baseUrl/api/vidanges/listErreursKilometrage';
  // 3. Vidanges planifiées en retard
  static String listVidangesPlanifieesEnRetard() =>
      '$baseUrl/api/vidanges/listVidangesPlanifieesEnRetard';
  // 4. Opérations administratives en retard
  static String listOperationsPlanifieesEnRetard() =>
      '$baseUrl/api/operations-adm/listOperationsPlanifieesEnRetard';
  // 5. Conflits de planification
  static String listConflitsPlanification() =>
      '$baseUrl/api/vidanges/listConflitsPlanification';
  // 6. Demandes d'achat en cours
  static String listDemandesAchatEnCours() =>
      '$baseUrl/api/ordrereparation/listDemandesAchatEnCours';
  // 7. Bons d'achat validés sans B.C
  static String listBonsAchatValidesSansBonCommande() =>
      '$baseUrl/api/ordrereparation/listBonsAchatValidesSansBonCommande';
  // 8. Articles sans bon d'achat validé (compteurs)
  static String compteursLignesSansBonAchatValide() =>
      '$baseUrl/api/ordrereparation/compteursLignesSansBonAchatValide';
  // 9. Documents expirés
  static String listDocsExpires() =>
      '$baseUrl/api/docs-adm-vehicules-prc/listDocsExpires';
  // 10. Documents à planifier
  static String listDocsAPlanifier() =>
      '$baseUrl/api/docs-adm-vehicules-prc/listDocsAPlanifier';
  // 11. Vidange sous 3 000 km
  static String listVidangesSousSeuil() =>
      '$baseUrl/api/vidanges/listVidangesSousSeuil';
  // 12. Demandes OR à traiter
  static String listDemandesOR({int page = 0, int size = 20}) =>
      '$baseUrl/api/demandesOR/listDemandesOR?page=$page&size=$size';
  // GED : documents attaches a une cle, dont les descriptions audio des
  // demandes d'OR (cle « DEMANDE_OR_AUDIO-<id> »).
  static String listGeds(String cle) =>
      '$baseUrl/api/gedsPrc/listGeds?cle=${Uri.encodeComponent(cle)}';
  static String afficherGed() => '$baseUrl/api/gedsPrc/afficherGedsPrc';

  // Validation initiale d'une demande, comme la fiche web.
  static String validerDemandeOR(int id) =>
      '$baseUrl/api/demandesOR/validerDemandeOR/$id';
  static String fausseDeclarationDemande(int id) =>
      '$baseUrl/api/demandesOR/fausseDeclarationDemande/$id';

  static String listOrdresByDemande(int demandeId) =>
      '$baseUrl/api/demandesOR/listOrdresByDemande/$demandeId';
  static String getDemandeOR(int id) =>
      '$baseUrl/api/demandesOR/getDemandeOR/$id';

  static String compteurDemandesATraiter() =>
      '$baseUrl/api/demandesOR/compteurDemandesATraiter';
  // 13. OR non clôturés
  static String compteurOrNonClotures() =>
      '$baseUrl/api/ordrereparation/compteurOrNonClotures';
  // Listes des cartes du tableau de bord : le compteur seul ne suffit pas a
  // remplir la page de detail.
  static String listOrNonClotures({int page = 0, int size = 100}) =>
      '$baseUrl/api/ordrereparation/listOrNonClotures?page=$page&size=$size';
  static String listDemandesATraiter({int page = 0, int size = 100}) =>
      '$baseUrl/api/demandesOR/listDemandesATraiter?page=$page&size=$size';
  static String listLignesSansBonAchatValide() =>
      '$baseUrl/api/ordrereparation/listLignesSansBonAchatValide';

  // ==================== NOTIFICATIONS ====================
  static String getMyNotifications() =>
      '$baseUrl/api/notifications/myNotifications';
  static String getUnreadNotificationCount() =>
      '$baseUrl/api/notifications/unreadCount';
  static String markNotificationAsRead(int id) =>
      '$baseUrl/api/notifications/$id/read';
  static String markAllNotificationsAsRead() =>
      '$baseUrl/api/notifications/readAll';
  static String deleteNotification(int id) =>
      '$baseUrl/api/notifications/deleteNotification/$id';
}
