import 'package:get/get.dart';
import 'package:logger/logger.dart';
import '../services/api_service.dart';
import 'auth_controller.dart';

class VidangeController extends GetxController {
  final Logger _logger = Logger();
  final AuthController _authController = Get.find<AuthController>();

  var vidanges = <Map<String, dynamic>>[].obs;
  var filteredVidanges = <Map<String, dynamic>>[].obs;
  var isLoading = false.obs;
  var errorMessage = ''.obs;
  var searchQuery = ''.obs;
  var selectedStatusFilter = 'TOUS'.obs;
  var totalElements = 0.obs;

  int get totalCount =>
      totalElements.value > 0 ? totalElements.value : vidanges.length;

  List<String> get availableStatuses {
    final statuses = <String>{'TOUS'};
    for (final v in vidanges) {
      final s = v['status']?.toString().trim() ?? '';
      if (s.isNotEmpty) statuses.add(s);
    }
    return statuses.toList();
  }

  int countForStatus(String status) {
    if (status == 'TOUS') return totalCount;
    final target = status.trim().toLowerCase();
    return vidanges.where((v) {
      final s = (v['status'] ?? '').toString().trim().toLowerCase();
      return s == target;
    }).length;
  }

  @override
  void onInit() {
    super.onInit();
    fetchVidanges();
  }

  /// Récupère la liste complète des vidanges depuis le backend (416 éléments)
  Future<void> fetchVidanges({bool showLoading = true}) async {
    if (showLoading) isLoading.value = true;
    errorMessage.value = '';

    try {
      _logger.i('🛢️ Récupération de la liste complète des vidanges...');

      int page = 0;
      const int pageSize =
          100; // Taille standard compatible Spring Boot Pageable
      final List<Map<String, dynamic>> allItems = [];
      int serverTotal = 0;

      while (true) {
        final url = ApiService.listVidanges(page: page, size: pageSize);
        final responseData = await _authController.makeRequest(
          url,
          method: 'POST',
          body: {
            "numero": null,
            "immatriculation": null,
            "status": null,
            "dateCreationFrom": null,
            "dateCreationTo": null,
          },
          showErrorSnackbar: false,
        );

        final List<Map<String, dynamic>> pageItems = [];
        int totalPages = 1;

        if (responseData is Map) {
          final content =
              responseData['content'] ??
              responseData['data']?['content'] ??
              responseData['data'];

          if (content is List) {
            for (final item in content) {
              if (item is Map<String, dynamic>) {
                pageItems.add(item);
              } else if (item is Map) {
                pageItems.add(Map<String, dynamic>.from(item));
              }
            }
          }

          if (responseData['totalElements'] is num) {
            serverTotal = (responseData['totalElements'] as num).toInt();
          } else if (responseData['data'] is Map &&
              responseData['data']['totalElements'] is num) {
            serverTotal = (responseData['data']['totalElements'] as num)
                .toInt();
          }

          if (responseData['totalPages'] is num) {
            totalPages = (responseData['totalPages'] as num).toInt();
          } else if (responseData['data'] is Map &&
              responseData['data']['totalPages'] is num) {
            totalPages = (responseData['data']['totalPages'] as num).toInt();
          }
        } else if (responseData is List) {
          for (final item in responseData) {
            if (item is Map<String, dynamic>) {
              pageItems.add(item);
            } else if (item is Map) {
              pageItems.add(Map<String, dynamic>.from(item));
            }
          }
          serverTotal = pageItems.length;
        }

        allItems.addAll(pageItems);

        // Met à jour le total d'éléments en temps réel
        if (serverTotal > 0) {
          totalElements.value = serverTotal;
        } else {
          totalElements.value = allItems.length;
        }

        _logger.d(
          'Page $page : ${pageItems.length} reçus. Total: ${allItems.length}/$serverTotal (totalPages: $totalPages)',
        );

        // Condition d'arrêt de pagination
        if (pageItems.isEmpty ||
            pageItems.length < pageSize ||
            page + 1 >= totalPages ||
            (serverTotal > 0 && allItems.length >= serverTotal)) {
          break;
        }

        page++;
      }

      vidanges.value = allItems;
      if (allItems.isEmpty) {
        totalElements.value = 0;
      }
      _logger.i(
        '✅ ${allItems.length} vidanges chargées depuis l\'API (Total: ${totalElements.value}).',
      );
    } catch (e) {
      _logger.w('Erreur chargement vidanges : $e');
      errorMessage.value =
          'Impossible de charger les vidanges. Vérifiez votre connexion.';
    } finally {
      applyFilters();
      isLoading.value = false;
    }
  }

  void applyFilters() {
    final query = searchQuery.value.trim().toLowerCase();
    final statusFilter = selectedStatusFilter.value;

    filteredVidanges.value = vidanges.where((v) {
      if (statusFilter != 'TOUS') {
        final s = (v['status'] ?? '').toString().trim();
        if (s.toLowerCase() != statusFilter.toLowerCase()) return false;
      }
      if (query.isEmpty) return true;

      final numero = (v['numero'] ?? '').toString().toLowerCase();
      final immat = (v['vehiculeImmatriculation'] ?? v['immatriculation'] ?? '')
          .toString()
          .toLowerCase();
      final type =
          (v['servicesPrcLibelle'] ??
                  v['serviceLibelle'] ??
                  v['typeVidangeLibelle'] ??
                  '')
              .toString()
              .toLowerCase();
      final marque = (v['vehiculeMarqueLibelle'] ?? v['marqueLibelle'] ?? '')
          .toString()
          .toLowerCase();
      final modele = (v['vehiculeModeleLibelle'] ?? v['modeleLibelle'] ?? '')
          .toString()
          .toLowerCase();
      final chauffeur =
          (v['chauffeurNom'] ??
                  v['chauffeurNomComplet'] ??
                  v['chaffeurNomComplet'] ??
                  v['chauffeur'] ??
                  '')
              .toString()
              .toLowerCase();
      final agence =
          (v['agenceLibelle'] ??
                  v['vehiculeAgenceLibelle'] ??
                  v['nomAgence'] ??
                  v['agence'] ??
                  '')
              .toString()
              .toLowerCase();

      return numero.contains(query) ||
          immat.contains(query) ||
          type.contains(query) ||
          marque.contains(query) ||
          modele.contains(query) ||
          chauffeur.contains(query) ||
          agence.contains(query);
    }).toList();
  }

  void updateSearchQuery(String query) {
    searchQuery.value = query;
    applyFilters();
  }

  void updateStatusFilter(String status) {
    if (selectedStatusFilter.value == status) {
      selectedStatusFilter.value = 'TOUS';
    } else {
      selectedStatusFilter.value = status;
    }
    applyFilters();
  }

  void resetFilters() {
    selectedStatusFilter.value = 'TOUS';
    searchQuery.value = '';
    applyFilters();
  }
}
