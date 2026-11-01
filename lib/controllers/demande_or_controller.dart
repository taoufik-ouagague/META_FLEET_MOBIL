import 'package:get/get.dart';
import 'package:logger/logger.dart';

import '../services/api_service.dart';
import 'auth_controller.dart';

/// Demandes d'OR du menu. Charge une fois au demarrage et apres le login, comme
/// les controleurs vehicules / OR / vidanges : la page s'affiche instantanement
/// sur les donnees deja en memoire et se rafraichit en arriere-plan.
class DemandeOrController extends GetxController {
  final Logger _logger = Logger();
  final AuthController _authController = Get.find<AuthController>();

  var demandes = <Map<String, dynamic>>[].obs;
  var isLoading = false.obs;
  var isLoadingMore = false.obs;
  var errorMessage = ''.obs;

  /// Total annonce par le serveur, toutes pages confondues.
  var totalElements = 0.obs;

  static const int _taillePage = 100;
  int _page = 0;

  /// Reste-t-il des pages a charger ?
  bool get aPlusDePages =>
      totalElements.value > 0 && demandes.length < totalElements.value;

  @override
  void onInit() {
    super.onInit();
    fetchDemandes();
  }

  /// Recharge depuis la premiere page. `showLoading` a false pour un
  /// rafraichissement silencieux : la liste affichee n'est pas remplacee par
  /// un spinner.
  Future<void> fetchDemandes({bool showLoading = true}) async {
    if (showLoading && demandes.isEmpty) isLoading.value = true;
    errorMessage.value = '';
    _page = 0;

    try {
      final page = await _chargerPage(0);
      demandes.value = page;
      _logger.i(
        '✅ ${demandes.length}/${totalElements.value} demandes chargées.',
      );
    } catch (e) {
      _logger.w('Erreur chargement demandes : $e');
      errorMessage.value = e.toString().replaceFirst('Exception: ', '');
    } finally {
      isLoading.value = false;
    }
  }

  /// Page suivante, ajoutee a la suite : la liste complete arrive par paliers
  /// au lieu d'une seule requete qui depassait le delai d'attente.
  Future<void> chargerPageSuivante() async {
    if (isLoadingMore.value || isLoading.value || !aPlusDePages) return;

    isLoadingMore.value = true;
    try {
      final suivante = await _chargerPage(_page + 1);
      if (suivante.isNotEmpty) {
        _page++;
        demandes.addAll(suivante);
        _logger.i(
          '✅ ${demandes.length}/${totalElements.value} demandes chargées.',
        );
      }
    } catch (e) {
      _logger.w('Erreur page ${_page + 1} : $e');
    } finally {
      isLoadingMore.value = false;
    }
  }

  Future<List<Map<String, dynamic>>> _chargerPage(int page) async {
    final data = await _authController.makeRequest(
      ApiService.listDemandesOR(page: page, size: _taillePage),
      method: 'POST',
      body: const <String, dynamic>{},
      showErrorSnackbar: false,
    );

    if (data is Map && data['totalElements'] is num) {
      totalElements.value = (data['totalElements'] as num).toInt();
    }

    final contenu = data is Map ? (data['content'] ?? data['data']) : data;
    if (contenu is! List) return const [];

    return contenu
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  /// Recherche (immatriculation ou numero) et filtres par valeur.
  List<Map<String, dynamic>> filtrees(
    String requete, {
    String? nature,
    String? statut,
    String? chauffeur,
  }) {
    final q = requete.trim().toLowerCase();

    return demandes.where((d) {
      if (q.isNotEmpty) {
        final immat = (d['vehiculeImmatriculation'] ?? '')
            .toString()
            .toLowerCase();
        final numero = (d['numeroDemande'] ?? '').toString().toLowerCase();
        if (!immat.contains(q) && !numero.contains(q)) return false;
      }
      if (nature != null && !naturesDe(d).contains(nature)) return false;
      if (statut != null && statutDe(d) != statut) return false;
      if (chauffeur != null && chauffeurDe(d) != chauffeur) return false;

      return true;
    }).toList();
  }

  /// Natures d'anomalies d'une demande : liste d'objets cote backend.
  List<String> naturesDe(Map<String, dynamic> d) {
    final brut = d['naturesAnomalies'] ?? d['anomalies'];
    if (brut is! List) return const [];

    return brut
        .map((e) {
          final libelle = e is Map
              ? (e['natureAnomalieLibelle'] ?? e['libelle'] ?? e['nom'])
              : e;
          return libelle?.toString().trim() ?? '';
        })
        .where((e) => e.isNotEmpty && e != 'null')
        .toSet()
        .toList();
  }

  String statutDe(Map<String, dynamic> d) =>
      (d['workflowDORLibelle'] ?? d['status'] ?? '').toString().trim();

  String chauffeurDe(Map<String, dynamic> d) =>
      (d['chaffeurNomComplet'] ?? d['chauffeurNomComplet'] ?? '')
          .toString()
          .trim();

  /// Valeurs distinctes + nombre de demandes, pour alimenter les selecteurs.
  Map<String, int> comptes(
    List<String> Function(Map<String, dynamic>) valeurs,
  ) {
    final comptes = <String, int>{};
    for (final d in demandes) {
      for (final v in valeurs(d).toSet()) {
        if (v.isEmpty) continue;
        comptes[v] = (comptes[v] ?? 0) + 1;
      }
    }

    return comptes;
  }
}
