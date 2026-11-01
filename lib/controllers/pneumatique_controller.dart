import 'package:get/get.dart';
import 'package:logger/logger.dart';
import '../services/api_service.dart';
import 'auth_controller.dart';

/// Liste des pneumatiques, meme fonctionnement que [VidangeController] :
/// chargement de toutes les pages puis filtrage local (recherche + statut).
class PneumatiqueController extends GetxController {
  final Logger _logger = Logger();
  final AuthController _authController = Get.find<AuthController>();

  var pneumatiques = <Map<String, dynamic>>[].obs;
  var filteredPneumatiques = <Map<String, dynamic>>[].obs;
  var isLoading = false.obs;
  var isLoadingMore = false.obs;
  var errorMessage = ''.obs;
  var searchQuery = ''.obs;
  var selectedStatusFilter = 'TOUS'.obs;
  var totalElements = 0.obs;
  var totalPages = 1.obs;
  var currentPage = 0.obs;

  /// Meme pagination que les OR : une page a l'ouverture, la suite au
  /// defilement. Charger les 30 000 lignes d'un coup bloquait l'ecran.
  final int pageSize = 50;

  int get totalCount =>
      totalElements.value > 0 ? totalElements.value : pneumatiques.length;

  List<String> get availableStatuses {
    final statuses = <String>{'TOUS'};
    for (final p in pneumatiques) {
      final s = p['status']?.toString().trim() ?? '';
      if (s.isNotEmpty) statuses.add(s);
    }

    return statuses.toList();
  }

  int countForStatus(String status) {
    if (status == 'TOUS') return totalCount;
    final target = status.trim().toLowerCase();

    return pneumatiques
        .where(
          (p) => (p['status'] ?? '').toString().trim().toLowerCase() == target,
        )
        .length;
  }

  /// La recherche part au serveur : seule une page est chargee localement.
  Map<String, dynamic> _filtre() {
    final query = searchQuery.value.trim();
    String? numSerie;
    String? immat;
    if (query.isNotEmpty) {
      // Une immatriculation porte un tiret ou un espace ; sinon on cherche le
      // numero de serie du pneu.
      if (query.contains('-') || query.contains(' ')) {
        immat = query;
      } else {
        numSerie = query;
      }
    }

    return <String, dynamic>{'numSerie': numSerie, 'immatriculation': immat};
  }

  List<Map<String, dynamic>> _extraire(dynamic responseData) {
    final items = <Map<String, dynamic>>[];
    final contenu = (responseData is Map)
        ? (responseData['content'] ??
              responseData['data']?['content'] ??
              responseData['data'])
        : responseData;

    if (contenu is List) {
      for (final item in contenu) {
        if (item is Map<String, dynamic>) {
          items.add(item);
        } else if (item is Map) {
          items.add(Map<String, dynamic>.from(item));
        }
      }
    }

    return items;
  }

  int? _entier(dynamic responseData, String cle) {
    if (responseData is! Map) return null;
    if (responseData[cle] is num) return (responseData[cle] as num).toInt();
    if (responseData['data'] is Map && responseData['data'][cle] is num) {
      return (responseData['data'][cle] as num).toInt();
    }

    return null;
  }

  @override
  void onInit() {
    super.onInit();
    debounce(
      searchQuery,
      (_) => fetchPneumatiques(showLoading: false),
      time: const Duration(milliseconds: 500),
    );
    fetchPneumatiques();
  }

  Future<void> fetchPneumatiques({bool showLoading = true}) async {
    if (showLoading) isLoading.value = true;
    errorMessage.value = '';
    currentPage.value = 0;

    try {
      final responseData = await _authController.makeRequest(
        ApiService.listPneumatiques(page: 0, size: pageSize),
        method: 'POST',
        body: _filtre(),
        showErrorSnackbar: false,
      );

      final items = _extraire(responseData);
      totalElements.value =
          _entier(responseData, 'totalElements') ?? items.length;
      totalPages.value = _entier(responseData, 'totalPages') ?? 1;
      pneumatiques.value = items;
      _logger.i(
        '✅ ${items.length} pneumatiques (page 0) sur ${totalElements.value}.',
      );
    } catch (e) {
      _logger.w('Erreur chargement pneumatiques : $e');
      errorMessage.value =
          'Impossible de charger les pneumatiques. Vérifiez votre connexion.';
    } finally {
      applyFilters();
      isLoading.value = false;
    }
  }

  /// Page suivante, appelee par le defilement de la liste.
  Future<void> loadNextPage() async {
    if (isLoadingMore.value || isLoading.value) return;
    if (currentPage.value + 1 >= totalPages.value) return;

    isLoadingMore.value = true;
    try {
      final suivante = currentPage.value + 1;
      final responseData = await _authController.makeRequest(
        ApiService.listPneumatiques(page: suivante, size: pageSize),
        method: 'POST',
        body: _filtre(),
        showErrorSnackbar: false,
      );

      final items = _extraire(responseData);
      if (items.isNotEmpty) {
        currentPage.value = suivante;
        pneumatiques.addAll(items);
        applyFilters();
      }
    } catch (e) {
      _logger.w('Erreur pagination pneumatiques : $e');
    } finally {
      isLoadingMore.value = false;
    }
  }

  /// Le statut se filtre sur les pages deja chargees ; la recherche, elle,
  /// repart au serveur (sinon elle ne verrait que la page courante).
  void applyFilters() {
    final statusFilter = selectedStatusFilter.value;
    if (statusFilter == 'TOUS') {
      filteredPneumatiques.value = pneumatiques.toList();

      return;
    }

    final cible = statusFilter.trim().toLowerCase();
    filteredPneumatiques.value = pneumatiques
        .where(
          (p) => (p['status'] ?? '').toString().trim().toLowerCase() == cible,
        )
        .toList();
  }

  void updateSearchQuery(String query) {
    // Le debounce de onInit declenche l'appel serveur.
    searchQuery.value = query;
  }

  void updateStatusFilter(String status) {
    selectedStatusFilter.value = selectedStatusFilter.value == status
        ? 'TOUS'
        : status;
    applyFilters();
  }

  void resetFilters() {
    selectedStatusFilter.value = 'TOUS';
    searchQuery.value = '';
    fetchPneumatiques(showLoading: false);
  }
}
