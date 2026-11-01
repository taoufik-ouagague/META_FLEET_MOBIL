import 'package:get/get.dart';
import 'package:logger/logger.dart';
import '../models/vehicule_model.dart';
import '../services/api_service.dart';
import 'auth_controller.dart';

class VehiculeController extends GetxController {
  final Logger _logger = Logger();
  final AuthController _authController = Get.find<AuthController>();

  var vehicules = <VehiculeModel>[].obs;
  var filteredVehicules = <VehiculeModel>[].obs;
  var isLoading = false.obs;
  var errorMessage = ''.obs;
  var searchQuery = ''.obs;
  var selectedTypeFilter = 'TOUS'.obs;
  var selectedMarque = ''.obs;
  var selectedModele = ''.obs;
  var selectedCategorie = ''.obs;

  int get totalActiveCount => vehicules.length;

  bool get hasActiveFilter =>
      selectedMarque.value.isNotEmpty ||
      selectedModele.value.isNotEmpty ||
      selectedCategorie.value.isNotEmpty ||
      searchQuery.value.isNotEmpty;

  List<String> get availableMarques {
    final set = <String>{};
    for (final v in vehicules) {
      final m = v.marqueLibelle?.trim() ?? '';
      if (m.isNotEmpty) set.add(m);
    }
    final list = set.toList();
    list.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  int countForMarque(String marque) {
    final target = marque.trim().toLowerCase();
    return vehicules.where((v) {
      return (v.marqueLibelle ?? '').trim().toLowerCase() == target;
    }).length;
  }

  List<String> get availableModeles {
    final set = <String>{};
    final currentMarque = selectedMarque.value.trim().toLowerCase();
    for (final v in vehicules) {
      if (currentMarque.isNotEmpty) {
        if ((v.marqueLibelle ?? '').trim().toLowerCase() != currentMarque) {
          continue;
        }
      }
      final m = v.modeleLibelle?.trim() ?? '';
      if (m.isNotEmpty) set.add(m);
    }
    final list = set.toList();
    list.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  int countForModele(String modele) {
    final target = modele.trim().toLowerCase();
    final currentMarque = selectedMarque.value.trim().toLowerCase();
    return vehicules.where((v) {
      if (currentMarque.isNotEmpty) {
        if ((v.marqueLibelle ?? '').trim().toLowerCase() != currentMarque) {
          return false;
        }
      }
      return (v.modeleLibelle ?? '').trim().toLowerCase() == target;
    }).length;
  }

  List<String> get availableCategories {
    final set = <String>{};
    for (final v in vehicules) {
      final c = v.categorieDisplay.trim();
      if (c.isNotEmpty) set.add(c);
    }
    final list = set.toList();
    list.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  int countForCategorie(String categorie) {
    final target = categorie.trim().toLowerCase();
    return vehicules.where((v) {
      return v.categorieDisplay.trim().toLowerCase() == target;
    }).length;
  }

  List<String> get availableTypes {
    final types = <String>{'TOUS'};
    for (final v in vehicules) {
      if (v.typeVehiculeLibelle != null &&
          v.typeVehiculeLibelle!.trim().isNotEmpty) {
        types.add(v.typeVehiculeLibelle!.trim());
      }
    }
    return types.toList();
  }

  @override
  void onInit() {
    super.onInit();
    fetchActiveVehicules();
  }

  /// Récupère la liste des véhicules depuis l'API backend (même périmètre que le web)
  Future<void> fetchActiveVehicules({bool showLoading = true}) async {
    if (showLoading) isLoading.value = true;
    errorMessage.value = '';

    try {
      _logger.i('🚛 Récupération des véhicules...');

      // Même source que la liste véhicules du web : listVehicules renvoie tous les
      // statuts sauf '-1'/'-2', là où getActiveVehicules se limite au statut '1'.
      // ponytail: une seule grande page, le filtrage restant côté client ;
      // passer à une pagination réelle si la flotte dépasse ce plafond.
      final responseData = await _authController.makeRequest(
        ApiService.listVehicules(page: 0, size: 2000),
        method: 'POST',
        body: const <String, dynamic>{},
        showErrorSnackbar: false,
      );

      final List<VehiculeModel> list = [];
      if (responseData is List) {
        for (final item in responseData) {
          if (item is Map<String, dynamic>) {
            list.add(VehiculeModel.fromJson(item));
          }
        }
      } else if (responseData is Map && responseData['content'] is List) {
        // En cas de PaginationResponse
        for (final item in responseData['content']) {
          if (item is Map<String, dynamic>) {
            list.add(VehiculeModel.fromJson(item));
          }
        }
      }

      vehicules.value = list;
      _logger.i('✅ ${list.length} véhicules chargés depuis l\'API.');
    } catch (e) {
      _logger.w('Erreur réseau / API lors du chargement des véhicules : $e');
      errorMessage.value =
          'Impossible de charger les véhicules. Vérifiez votre connexion.';
    } finally {
      applyFilters();
      isLoading.value = false;
    }
  }

  /// Applique les filtres de Marque, Modèle, Catégorie et recherche textuelle
  void applyFilters() {
    final query = searchQuery.value.trim().toLowerCase();
    final marque = selectedMarque.value.trim().toLowerCase();
    final modele = selectedModele.value.trim().toLowerCase();
    final categorie = selectedCategorie.value.trim().toLowerCase();

    filteredVehicules.value = vehicules.where((v) {
      // 1. Filtre par Marque
      if (marque.isNotEmpty) {
        if ((v.marqueLibelle ?? '').trim().toLowerCase() != marque) {
          return false;
        }
      }

      // 2. Filtre par Modèle
      if (modele.isNotEmpty) {
        if ((v.modeleLibelle ?? '').trim().toLowerCase() != modele) {
          return false;
        }
      }

      // 3. Filtre par Catégorie de véhicule
      if (categorie.isNotEmpty) {
        if (v.categorieDisplay.trim().toLowerCase() != categorie) return false;
      }

      // 4. Filtre par recherche textuelle
      if (query.isEmpty) return true;

      final immat = v.immatriculation?.toLowerCase() ?? '';
      final immatWw = v.immatriculationWw?.toLowerCase() ?? '';
      final code = v.codeInterne?.toLowerCase() ?? '';
      final marqueStr = v.marqueLibelle?.toLowerCase() ?? '';
      final modeleStr = v.modeleLibelle?.toLowerCase() ?? '';
      final catStr = v.categorieDisplay.toLowerCase();
      final type = v.typeVehiculeLibelle?.toLowerCase() ?? '';
      final organisme = v.organismeLibelle?.toLowerCase() ?? '';

      return immat.contains(query) ||
          immatWw.contains(query) ||
          code.contains(query) ||
          marqueStr.contains(query) ||
          modeleStr.contains(query) ||
          catStr.contains(query) ||
          type.contains(query) ||
          organisme.contains(query);
    }).toList();
  }

  void updateSearchQuery(String query) {
    searchQuery.value = query;
    applyFilters();
  }

  void updateMarqueFilter(String marque) {
    if (selectedMarque.value.trim().toLowerCase() ==
        marque.trim().toLowerCase()) {
      selectedMarque.value = '';
    } else {
      selectedMarque.value = marque.trim();
      // Si le modèle actuellement sélectionné n'appartient pas à la nouvelle marque, le réinitialiser
      if (selectedModele.value.isNotEmpty &&
          !availableModeles.contains(selectedModele.value)) {
        selectedModele.value = '';
      }
    }
    applyFilters();
  }

  void updateModeleFilter(String modele) {
    if (selectedModele.value.trim().toLowerCase() ==
        modele.trim().toLowerCase()) {
      selectedModele.value = '';
    } else {
      selectedModele.value = modele.trim();
    }
    applyFilters();
  }

  void updateCategorieFilter(String categorie) {
    if (selectedCategorie.value.trim().toLowerCase() ==
        categorie.trim().toLowerCase()) {
      selectedCategorie.value = '';
    } else {
      selectedCategorie.value = categorie.trim();
    }
    applyFilters();
  }

  void resetAllFilters() {
    selectedMarque.value = '';
    selectedModele.value = '';
    selectedCategorie.value = '';
    selectedTypeFilter.value = 'TOUS';
    searchQuery.value = '';
    applyFilters();
  }

  void updateTypeFilter(String type) {
    selectedTypeFilter.value = type;
    applyFilters();
  }
}
