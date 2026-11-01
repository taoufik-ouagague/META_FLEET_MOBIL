import 'package:get/get.dart';
import 'package:logger/logger.dart';
import '../services/api_service.dart';
import 'auth_controller.dart';

class DashboardCardData {
  final String id;
  final String title;
  final String category; // 'vidange', 'or', 'docs', 'achats'
  final dynamic icon;
  final dynamic color;
  final List<DashboardPill> pills;
  final int targetTab; // 1: Vehicules, 2: OR, 3: Vidanges, etc.

  DashboardCardData({
    required this.id,
    required this.title,
    required this.category,
    required this.icon,
    required this.color,
    required this.pills,
    required this.targetTab,
  });
}

class DashboardPill {
  final String label;
  final String
  type; // 'depasse' (red), 'imminent' (amber), 'total' (slate/blue)

  DashboardPill({required this.label, required this.type});
}

class DashboardController extends GetxController {
  final Logger _logger = Logger();
  final AuthController _authController = Get.find<AuthController>();

  var isLoading = false.obs;
  var searchQuery = ''.obs;

  // 1. Alertes vidange
  var alertesVidangeCount = 0.obs;
  var alertesVidangeDepasses = 0.obs;
  var alertesVidangeImminents = 0.obs;
  var alertesVidangeList = <dynamic>[].obs;

  // 2. Erreurs kilométrage
  var erreursKmCount = 0.obs;
  var erreursKmList = <dynamic>[].obs;

  // 3. Vidanges planifiées en retard
  var vidangesEnRetardCount = 0.obs;
  var vidangesEnRetardList = <dynamic>[].obs;

  // 4. Opérations administratives en retard
  var operationsEnRetardCount = 0.obs;
  var operationsEnRetardList = <dynamic>[].obs;

  // 5. Conflits de planification
  var conflitsPlanifCount = 0.obs;
  var conflitsPlanifList = <dynamic>[].obs;

  // 6. Demandes d'achat en cours
  var demandesAchatCount = 0.obs;
  var demandesAchatList = <dynamic>[].obs;

  // 7. Bons d'achat validés sans B.C
  var bonsSansBcCount = 0.obs;
  var bonsSansBcList = <dynamic>[].obs;

  // 8. Articles sans bon d'achat validé
  var articlesSansBaList = <dynamic>[].obs;
  var articlesSansBaTotal = 0.obs;
  var articlesSansBaSansBon = 0.obs;

  // 9. Documents expirés
  var docsExpiresCount = 0.obs;
  var docsExpiresList = <dynamic>[].obs;

  // 10. Documents à planifier
  var docsPlanifCount = 0.obs;
  var docsPlanifEscalade = 0.obs;
  var docsPlanifList = <dynamic>[].obs;

  // 11. Vidange sous 3 000 km
  var vidangesSous3000Count = 0.obs;
  var vidangesSous3000List = <dynamic>[].obs;

  // 12. Demandes OR à traiter
  var demandesOrCount = 0.obs;
  var demandesOrList = <dynamic>[].obs;

  // 13. OR non clôturés
  var orNonCloturesCount = 0.obs;
  var orNonCloturesList = <dynamic>[].obs;

  List<dynamic> getItemsForCard(String cardTitle) {
    switch (cardTitle) {
      case 'Alertes vidange':
        return alertesVidangeList;
      case 'Erreurs de kilométrage':
        return erreursKmList;
      case 'Vidanges planifiées en retard':
        return vidangesEnRetardList;
      case 'Opérations administratives en retard':
        return operationsEnRetardList;
      case 'Conflits de planification':
        return conflitsPlanifList;
      case 'Demandes d\'achat en cours':
        return demandesAchatList;
      case 'Bons d\'achat validés sans B.C':
        return bonsSansBcList;
      case 'Documents expirés':
        return docsExpiresList;
      case 'Documents à planifier':
        return docsPlanifList;
      case 'Vidange sous 3 000 km':
        return vidangesSous3000List;
      default:
        return [];
    }
  }

  @override
  void onInit() {
    super.onInit();
    fetchDashboardData();
  }

  List<dynamic> _extractList(dynamic res) {
    if (res == null) return [];
    if (res is List) return res;
    if (res is Map) {
      if (res['content'] is List) return res['content'] as List;
      if (res['data'] is List) return res['data'] as List;
    }
    return [];
  }

  int _extractTotal(dynamic res) {
    if (res == null) return 0;
    if (res is num) return res.toInt();
    if (res is Map) {
      if (res['total'] != null && res['total'] is num) {
        return (res['total'] as num).toInt();
      }
      if (res['count'] != null && res['count'] is num) {
        return (res['count'] as num).toInt();
      }
      if (res['data'] != null) {
        return _extractTotal(res['data']);
      }
    }
    return 0;
  }

  Future<void> fetchDashboardData({bool showLoading = true}) async {
    if (showLoading) isLoading.value = true;
    _logger.i('📊 Chargement des 13 cartes du Tableau de bord GMAO...');

    await Future.wait([
      // 1. Alertes vidange
      _safeCall(() async {
        final res = await _authController.makeRequest(
          ApiService.listAlertesVidange(),
          method: 'GET',
          showErrorSnackbar: false,
        );
        final list = _extractList(res);
        alertesVidangeCount.value = list.length;
        alertesVidangeList.assignAll(list);
        int dep = 0;
        int imm = 0;
        for (final item in list) {
          if (item is Map) {
            final act = item['act'];
            if (act != null && act is num) {
              if (act <= 0) {
                dep++;
              } else if (act <= 500) {
                imm++;
              }
            }
          }
        }
        alertesVidangeDepasses.value = dep;
        alertesVidangeImminents.value = imm;
      }, 'Alertes vidange'),

      // 2. Erreurs de kilométrage
      _safeCall(() async {
        final res = await _authController.makeRequest(
          ApiService.listErreursKilometrage(),
          method: 'GET',
          showErrorSnackbar: false,
        );
        final list = _extractList(res);
        erreursKmCount.value = list.length;
        erreursKmList.assignAll(list);
      }, 'Erreurs kilométrage'),

      // 3. Vidanges planifiées en retard
      _safeCall(() async {
        final res = await _authController.makeRequest(
          ApiService.listVidangesPlanifieesEnRetard(),
          method: 'GET',
          showErrorSnackbar: false,
        );
        final list = _extractList(res);
        vidangesEnRetardCount.value = list.length;
        vidangesEnRetardList.assignAll(list);
      }, 'Vidanges planifiées en retard'),

      // 4. Opérations administratives en retard
      _safeCall(() async {
        final res = await _authController.makeRequest(
          ApiService.listOperationsPlanifieesEnRetard(),
          method: 'GET',
          showErrorSnackbar: false,
        );
        final list = _extractList(res);
        operationsEnRetardCount.value = list.length;
        operationsEnRetardList.assignAll(list);
      }, 'Opérations en retard'),

      // 5. Conflits de planification
      _safeCall(() async {
        final res = await _authController.makeRequest(
          ApiService.listConflitsPlanification(),
          method: 'GET',
          showErrorSnackbar: false,
        );
        final list = _extractList(res);
        conflitsPlanifCount.value = list.length;
        conflitsPlanifList.assignAll(list);
      }, 'Conflits planification'),

      // 6. Demandes d'achat en cours
      _safeCall(() async {
        final res = await _authController.makeRequest(
          ApiService.listDemandesAchatEnCours(),
          method: 'GET',
          showErrorSnackbar: false,
        );
        final list = _extractList(res);
        demandesAchatCount.value = list.length;
        demandesAchatList.assignAll(list);
      }, 'Demandes achat en cours'),

      // 7. Bons d'achat validés sans B.C
      _safeCall(() async {
        final res = await _authController.makeRequest(
          ApiService.listBonsAchatValidesSansBonCommande(),
          method: 'GET',
          showErrorSnackbar: false,
        );
        final list = _extractList(res);
        bonsSansBcCount.value = list.length;
        bonsSansBcList.assignAll(list);
      }, 'Bons sans BC'),

      // 8. Articles sans bon d'achat validé
      _safeCall(() async {
        final res = await _authController.makeRequest(
          ApiService.compteursLignesSansBonAchatValide(),
          method: 'GET',
          showErrorSnackbar: false,
        );
        if (res is Map) {
          articlesSansBaTotal.value = _extractTotal(res['total'] ?? res);
          articlesSansBaSansBon.value = _extractTotal(res['sansAucunBon']);

          final resListe = await _authController.makeRequest(
            ApiService.listLignesSansBonAchatValide(),
            method: 'GET',
            showErrorSnackbar: false,
          );
          articlesSansBaList.assignAll(_extractList(resListe));
        }
      }, 'Articles sans BA'),

      // 9. Documents expirés
      _safeCall(() async {
        final res = await _authController.makeRequest(
          ApiService.listDocsExpires(),
          method: 'GET',
          showErrorSnackbar: false,
        );
        final list = _extractList(res);
        docsExpiresCount.value = list.length;
        docsExpiresList.assignAll(list);
      }, 'Docs expirés'),

      // 10. Documents à planifier
      _safeCall(() async {
        final res = await _authController.makeRequest(
          ApiService.listDocsAPlanifier(),
          method: 'GET',
          showErrorSnackbar: false,
        );
        final list = _extractList(res);
        docsPlanifCount.value = list.length;
        docsPlanifList.assignAll(list);
        int esc = 0;
        for (final item in list) {
          if (item is Map) {
            final reste = item['resteKmVidange'];
            if (reste != null && reste is num && reste < 3000) {
              esc++;
            }
          }
        }
        docsPlanifEscalade.value = esc;
      }, 'Docs à planifier'),

      // 11. Vidange sous 3 000 km
      _safeCall(() async {
        final res = await _authController.makeRequest(
          ApiService.listVidangesSousSeuil(),
          method: 'GET',
          showErrorSnackbar: false,
        );
        final list = _extractList(res);
        vidangesSous3000Count.value = list.length;
        vidangesSous3000List.assignAll(list);
      }, 'Vidanges sous seuil'),

      // 12. Demandes OR à traiter
      _safeCall(() async {
        final res = await _authController.makeRequest(
          ApiService.compteurDemandesATraiter(),
          method: 'GET',
          showErrorSnackbar: false,
        );
        demandesOrCount.value = _extractTotal(res);

        final resListe = await _authController.makeRequest(
          ApiService.listDemandesATraiter(),
          method: 'GET',
          showErrorSnackbar: false,
        );
        demandesOrList.assignAll(_extractList(resListe));
      }, 'Demandes OR'),

      // 13. OR non clôturés
      _safeCall(() async {
        final res = await _authController.makeRequest(
          ApiService.compteurOrNonClotures(),
          method: 'GET',
          showErrorSnackbar: false,
        );
        orNonCloturesCount.value = _extractTotal(res);

        final resListe = await _authController.makeRequest(
          ApiService.listOrNonClotures(),
          method: 'GET',
          showErrorSnackbar: false,
        );
        orNonCloturesList.assignAll(_extractList(resListe));
      }, 'OR non clôturés'),
    ]);

    isLoading.value = false;
    _logger.i('✅ Tableau de bord GMAO actualisé avec succès.');
  }

  Future<void> _safeCall(Future<void> Function() call, String cardName) async {
    try {
      await call();
    } catch (e) {
      _logger.w('⚠️ Données non disponibles pour "$cardName": $e');
    }
  }
}
