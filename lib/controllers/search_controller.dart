import 'package:get/get.dart';
import 'package:logger/logger.dart';
import '../models/vehicule_model.dart';
import '../services/api_service.dart';
import 'auth_controller.dart';

class SearchController extends GetxController {
  final Logger _logger = Logger();
  final AuthController _authController = Get.find<AuthController>();

  var searchQuery = ''.obs;
  var isLoading = false.obs;
  var hasSearched = false.obs;

  // Results
  var vehicule = Rxn<VehiculeModel>();
  var vidanges = <Map<String, dynamic>>[].obs;
  var ordres = <Map<String, dynamic>>[].obs;
  var operations = <Map<String, dynamic>>[].obs;
  var pneumatiques = <Map<String, dynamic>>[].obs;
  var documents = <Map<String, dynamic>>[].obs;

  int get totalResults =>
      vidanges.length +
      ordres.length +
      operations.length +
      pneumatiques.length +
      documents.length;

  Future<void> searchByMatricule(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;

    searchQuery.value = q;
    isLoading.value = true;
    hasSearched.value = true;

    vehicule.value = null;
    vidanges.clear();
    ordres.clear();
    operations.clear();
    pneumatiques.clear();
    documents.clear();

    try {
      _logger.i('🔍 Recherche globale: "$q"');

      // 1. Fetch vehicles and find matching one
      await _fetchVehicule(q);

      // 2. Fetch vidanges matching matricule
      await _fetchVidanges(q);

      // 3. Fetch OR matching matricule
      await _fetchOrdres(q);

      // 4. Fetch operations matching matricule
      await _fetchOperations(q);

      // 5. Pneumatiques montes sur le vehicule
      await _fetchPneumatiques(q);

      // 6. Documents administratifs du vehicule
      await _fetchDocuments(q);

      _logger.i('✅ Recherche terminée: $totalResults résultats');
    } catch (e) {
      _logger.e('❌ Erreur recherche: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// Les listes se filtrent cote serveur : charger 500 lignes puis filtrer en
  /// local ne voyait que le debut du parc (29 000 OR) et ne trouvait rien.
  Map<String, dynamic> _filtreImmat(String query) => {'immatriculation': query};

  Future<List> _chercher(String url, String query) async {
    final data = await _authController.makeRequest(
      url,
      method: 'POST',
      body: _filtreImmat(query),
      showErrorSnackbar: false,
    );

    return _extractList(data);
  }

  Future<void> _fetchVehicule(String query) async {
    try {
      final items = await _chercher(
        ApiService.listVehicules(page: 0, size: 20),
        query,
      );
      for (final item in items) {
        if (item is Map) {
          vehicule.value = VehiculeModel.fromJson(
            Map<String, dynamic>.from(item),
          );
          break;
        }
      }
    } catch (e) {
      _logger.w('Véhicule non trouvé: $e');
    }
  }

  Future<void> _fetchVidanges(String query) async {
    try {
      final items = await _chercher(
        ApiService.listVidanges(page: 0, size: 50),
        query,
      );
      vidanges.addAll(items.whereType<Map>().map(Map<String, dynamic>.from));
    } catch (e) {
      _logger.w('Vidanges search error: $e');
    }
  }

  Future<void> _fetchOrdres(String query) async {
    try {
      final items = await _chercher(
        ApiService.listOr(page: 0, size: 50),
        query,
      );
      ordres.addAll(items.whereType<Map>().map(Map<String, dynamic>.from));
    } catch (e) {
      _logger.w('OR search error: $e');
    }
  }

  Future<void> _fetchOperations(String query) async {
    try {
      final items = await _chercher(
        ApiService.listOperations(page: 0, size: 50),
        query,
      );
      operations.addAll(items.whereType<Map>().map(Map<String, dynamic>.from));
    } catch (e) {
      _logger.w('Operations search error: $e');
    }
  }

  Future<void> _fetchPneumatiques(String query) async {
    try {
      final items = await _chercher(
        ApiService.listPneumatiques(page: 0, size: 50),
        query,
      );
      pneumatiques.addAll(
        items.whereType<Map>().map(Map<String, dynamic>.from),
      );
    } catch (e) {
      _logger.w('Pneumatiques search error: $e');
    }
  }

  Future<void> _fetchDocuments(String query) async {
    try {
      final items = await _chercher(
        ApiService.listDocsVehicules(page: 0, size: 50),
        query,
      );
      documents.addAll(items.whereType<Map>().map(Map<String, dynamic>.from));
    } catch (e) {
      _logger.w('Documents search error: $e');
    }
  }

  List _extractList(dynamic data) {
    if (data is Map && data.containsKey('content')) {
      return data['content'] as List? ?? [];
    }
    if (data is Map && data.containsKey('data')) {
      final d = data['data'];
      if (d is Map && d.containsKey('content')) {
        return d['content'] as List? ?? [];
      }
      if (d is List) return d;
    }
    if (data is List) return data;
    return [];
  }

  void clearSearch() {
    searchQuery.value = '';
    hasSearched.value = false;
    vehicule.value = null;
    vidanges.clear();
    ordres.clear();
    operations.clear();
    pneumatiques.clear();
    documents.clear();
  }
}
