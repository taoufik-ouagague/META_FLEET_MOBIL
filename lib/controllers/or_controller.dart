import 'package:get/get.dart';
import 'package:logger/logger.dart';
import '../services/api_service.dart';
import 'auth_controller.dart';

class OrController extends GetxController {
  final Logger _logger = Logger();
  final AuthController _authController = Get.find<AuthController>();

  var ordres = <Map<String, dynamic>>[].obs;
  var filteredOrdres = <Map<String, dynamic>>[].obs;
  var isLoading = false.obs;
  var isLoadingMore = false.obs;
  var errorMessage = ''.obs;
  var searchQuery = ''.obs;
  var selectedStatusFilter = 'TOUS'.obs;
  var selectedNatureAnomalie = Rxn<Map<String, dynamic>>();
  var naturesAnomalies = <Map<String, dynamic>>[].obs;
  var isLoadingNatures = false.obs;
  var natureCounts = <int, int>{}.obs;
  var isLoadingNatureCounts = false.obs;

  var totalElements = 0.obs;
  var totalPages = 1.obs;
  var currentPage = 0.obs;
  final int pageSize = 50;

  var totalTous = 0.obs;
  var totalActif = 0.obs;
  var totalCloture = 0.obs;
  var isLoadingCounts = false.obs;

  int get totalCount =>
      totalElements.value > 0 ? totalElements.value : ordres.length;

  bool get hasActiveFilter =>
      selectedStatusFilter.value != 'TOUS' ||
      selectedNatureAnomalie.value != null ||
      searchQuery.value.isNotEmpty;

  List<String> get availableStatuses => const ['TOUS', 'Actif', 'Clôturé'];

  /// Liste des natures d'anomalies disponibles (API + chargées + repli)
  List<Map<String, dynamic>> get availableNatures {
    final list = <Map<String, dynamic>>[];
    final seen = <String>{};

    // 1. Depuis l'API
    for (final item in naturesAnomalies) {
      final lib =
          (item['libelle'] ?? item['nom'] ?? item['natureAnomalie'] ?? '')
              .toString()
              .trim();
      final id = (item['id'] as num?)?.toInt() ?? 0;
      if (lib.isNotEmpty && !seen.contains(lib.toLowerCase())) {
        seen.add(lib.toLowerCase());
        list.add({'id': id, 'libelle': lib});
      }
    }

    // 2. Extraites des OR actuellement chargés
    for (final o in ordres) {
      if (o['naturesAnomalies'] is List) {
        for (final n in o['naturesAnomalies']) {
          if (n is Map) {
            final lib = (n['libelle'] ?? n['nom'] ?? n['natureAnomalie'] ?? '')
                .toString()
                .trim();
            final id = (n['id'] as num?)?.toInt() ?? 0;
            if (lib.isNotEmpty && !seen.contains(lib.toLowerCase())) {
              seen.add(lib.toLowerCase());
              list.add({'id': id, 'libelle': lib});
            }
          }
        }
      }
      final singleLib = (o['natureAnomalieLibelle'] ?? '').toString().trim();
      final singleId = (o['natureAnomalieId'] as num?)?.toInt() ?? 0;
      if (singleLib.isNotEmpty && !seen.contains(singleLib.toLowerCase())) {
        seen.add(singleLib.toLowerCase());
        list.add({'id': singleId, 'libelle': singleLib});
      }
    }

    // 3. Natures d'anomalies courantes en repli si la liste est encore vide
    if (list.isEmpty) {
      const fallbackList = [
        {'id': 1, 'libelle': 'Panne moteur'},
        {'id': 2, 'libelle': 'Freinage défaillant'},
        {'id': 3, 'libelle': 'Vidange complète'},
        {'id': 4, 'libelle': 'Climatisation HS'},
        {'id': 5, 'libelle': 'Pneus usés'},
        {'id': 6, 'libelle': 'Circuit électrique'},
        {'id': 7, 'libelle': 'Suspension & Amortisseurs'},
        {'id': 8, 'libelle': 'Boîte de vitesses'},
        {'id': 9, 'libelle': 'Carrosserie'},
      ];
      for (final f in fallbackList) {
        final lib = f['libelle'] as String;
        if (!seen.contains(lib.toLowerCase())) {
          seen.add(lib.toLowerCase());
          list.add(Map<String, dynamic>.from(f));
        }
      }
    }

    list.sort(
      (a, b) => (a['libelle'] ?? '').toString().toLowerCase().compareTo(
        (b['libelle'] ?? '').toString().toLowerCase(),
      ),
    );
    return list;
  }

  /// Compte les OR correspondant à cette nature (total serveur exact)
  int countForNature(Map<String, dynamic> nature) {
    final targetId = (nature['id'] as num?)?.toInt();
    final targetLib =
        (nature['libelle'] ?? nature['nom'] ?? nature['natureAnomalie'] ?? '')
            .toString()
            .trim()
            .toLowerCase();

    // 1. Total exact mis en cache depuis le serveur
    if (targetId != null && natureCounts.containsKey(targetId)) {
      return natureCounts[targetId]!;
    }

    // 2. Si c'est la nature actuellement sélectionnée, son total exact est déjà dans totalElements
    final sel = selectedNatureAnomalie.value;
    if (sel != null) {
      final selId = (sel['id'] as num?)?.toInt();
      final selLib = (sel['libelle'] ?? '').toString().trim().toLowerCase();
      if ((targetId != null && targetId == selId) ||
          (targetLib.isNotEmpty && targetLib == selLib)) {
        if (totalElements.value > 0) return totalElements.value;
      }
    }

    return 0;
  }

  int? countForStatus(String status) {
    if (status == 'TOUS') {
      return totalTous.value > 0
          ? totalTous.value
          : (totalElements.value > 0 ? totalElements.value : null);
    }
    if (status == 'Actif') {
      return totalActif.value > 0 ? totalActif.value : null;
    }
    if (status == 'Clôturé' || status == 'Cloture') {
      return totalCloture.value > 0 ? totalCloture.value : null;
    }
    return null;
  }

  Map<String, dynamic> _buildFilterPayload({
    String? overrideStatus,
    String? overrideQuery,
    int? overrideNatureId,
  }) {
    final status = overrideStatus ?? selectedStatusFilter.value;
    final query = (overrideQuery ?? searchQuery.value).trim();

    // Résolution précise de l'ID de la nature d'anomalie
    int? natureId = overrideNatureId;
    if (natureId == null && selectedNatureAnomalie.value != null) {
      final raw = selectedNatureAnomalie.value!;
      if (raw['id'] is num && (raw['id'] as num) > 0) {
        natureId = (raw['id'] as num).toInt();
      }
      final targetLib =
          (raw['libelle'] ?? raw['nom'] ?? raw['natureAnomalie'] ?? '')
              .toString()
              .trim()
              .toLowerCase();
      if ((natureId == null || natureId <= 0) && targetLib.isNotEmpty) {
        for (final item in naturesAnomalies) {
          final itemLib =
              (item['libelle'] ?? item['nom'] ?? item['natureAnomalie'] ?? '')
                  .toString()
                  .trim()
                  .toLowerCase();
          if (itemLib == targetLib) {
            final id = (item['id'] as num?)?.toInt();
            if (id != null && id > 0) {
              natureId = id;
              break;
            }
          }
        }
      }
    }

    String? statusCode;
    if (status == 'Actif') {
      statusCode = '1';
    } else if (status == 'Clôturé' || status == 'Cloture') {
      statusCode = '4';
    }

    String? numOr;
    String? immat;
    if (query.isNotEmpty) {
      if (query.contains('-') ||
          query.contains(' ') ||
          (RegExp(r'[A-Za-z]').hasMatch(query) &&
              RegExp(r'\d').hasMatch(query))) {
        immat = query;
      } else {
        numOr = query;
      }
    }

    final payload = <String, dynamic>{
      "numeroOrdreReparation": numOr,
      "immatriculation": immat,
      "status": statusCode,
      "natureAnomalieId": (natureId != null && natureId > 0) ? natureId : null,
    };

    return payload;
  }

  @override
  void onInit() {
    super.onInit();
    debounce(
      searchQuery,
      (_) => fetchOrdres(showLoading: false),
      time: const Duration(milliseconds: 500),
    );
    fetchOrdres();
    fetchStatusCounts();
    fetchNaturesAnomalies();
  }

  /// Récupère la première page des ordres de réparation et initialise le total d'éléments (ex: 29828, ou 4087 avec filtre)
  Future<void> fetchOrdres({bool showLoading = true}) async {
    if (showLoading) isLoading.value = true;
    errorMessage.value = '';
    currentPage.value = 0;

    try {
      _logger.i(
        '🔧 Récupération des OR (statut: ${selectedStatusFilter.value}, nature: ${selectedNatureAnomalie.value?['libelle']})...',
      );
      final url = ApiService.listOr(page: 0, size: pageSize);
      final payload = _buildFilterPayload();

      final responseData = await _authController.makeRequest(
        url,
        method: 'POST',
        body: payload,
        showErrorSnackbar: false,
      );

      final List<Map<String, dynamic>> items = [];

      if (responseData is Map) {
        final content =
            responseData['content'] ??
            responseData['data']?['content'] ??
            responseData['data'];

        if (content is List) {
          for (final item in content) {
            if (item is Map<String, dynamic>) {
              items.add(item);
            } else if (item is Map) {
              items.add(Map<String, dynamic>.from(item));
            }
          }
        }

        int count = 0;
        if (responseData['totalElements'] is num) {
          count = (responseData['totalElements'] as num).toInt();
        } else if (responseData['data'] is Map &&
            responseData['data']['totalElements'] is num) {
          count = (responseData['data']['totalElements'] as num).toInt();
        }

        if (count > 0) {
          totalElements.value = count;
          // Mise à jour de totalTous UNIQUEMENT sans filtre actif (global 29828)
          if (!hasActiveFilter) {
            totalTous.value = count;
            if (totalActif.value > 0 && totalCloture.value == 0) {
              totalCloture.value = count - totalActif.value;
            }
          } else if (selectedStatusFilter.value == 'Actif' &&
              selectedNatureAnomalie.value == null) {
            totalActif.value = count;
          } else if (selectedStatusFilter.value == 'Clôturé' &&
              selectedNatureAnomalie.value == null) {
            totalCloture.value = count;
          }
        }

        if (responseData['totalPages'] is num) {
          totalPages.value = (responseData['totalPages'] as num).toInt();
        } else if (responseData['data'] is Map &&
            responseData['data']['totalPages'] is num) {
          totalPages.value = (responseData['data']['totalPages'] as num)
              .toInt();
        }
      } else if (responseData is List) {
        for (final item in responseData) {
          if (item is Map<String, dynamic>) {
            items.add(item);
          } else if (item is Map) {
            items.add(Map<String, dynamic>.from(item));
          }
        }
        totalElements.value = items.length;
      }

      if (items.isNotEmpty) {
        ordres.value = items;
        _logger.i(
          '✅ ${items.length} OR chargés pour ce filtre. Total serveur: ${totalElements.value} éléments.',
        );
      } else {
        if (totalElements.value == 0) {
          _logger.i('ℹ️ Aucun OR distant reçu, chargement démo si liste vide.');
          if (ordres.isEmpty) _loadFallbackOrdres();
        } else {
          ordres.value = [];
        }
      }
    } catch (e) {
      _logger.w('Erreur chargement OR : $e');
      if (ordres.isEmpty) {
        _loadFallbackOrdres();
      }
    } finally {
      applyFilters();
      isLoading.value = false;
    }
  }

  /// Chargement infini au défilement (pagination progressive des 29828 éléments)
  Future<void> loadNextPage() async {
    if (isLoadingMore.value || isLoading.value) return;
    if (currentPage.value + 1 >= totalPages.value) return;

    isLoadingMore.value = true;
    try {
      final nextPage = currentPage.value + 1;
      _logger.d('🔧 Chargement page $nextPage des OR...');
      final url = ApiService.listOr(page: nextPage, size: pageSize);
      final payload = _buildFilterPayload();

      final responseData = await _authController.makeRequest(
        url,
        method: 'POST',
        body: payload,
        showErrorSnackbar: false,
      );

      final List<Map<String, dynamic>> items = [];
      if (responseData is Map) {
        final content =
            responseData['content'] ??
            responseData['data']?['content'] ??
            responseData['data'];
        if (content is List) {
          for (final item in content) {
            if (item is Map<String, dynamic>) {
              items.add(item);
            } else if (item is Map) {
              items.add(Map<String, dynamic>.from(item));
            }
          }
        }
      }

      if (items.isNotEmpty) {
        currentPage.value = nextPage;
        ordres.addAll(items);
        applyFilters();
        _logger.d(
          '✅ Page $nextPage chargée (+${items.length} OR, total chargés: ${ordres.length}/${totalElements.value})',
        );
      }
    } catch (e) {
      _logger.w('Erreur pagination OR : $e');
    } finally {
      isLoadingMore.value = false;
    }
  }

  /// Récupère en arrière-plan le total exact sur le serveur pour Actif et Clôturé
  Future<void> fetchStatusCounts() async {
    if (isLoadingCounts.value) return;
    isLoadingCounts.value = true;
    try {
      final futures = await Future.wait([
        _authController.makeRequest(
          ApiService.listOr(page: 0, size: 1),
          method: 'POST',
          body: _buildFilterPayload(overrideStatus: 'Actif'),
          showErrorSnackbar: false,
        ),
        _authController.makeRequest(
          ApiService.listOr(page: 0, size: 1),
          method: 'POST',
          body: _buildFilterPayload(overrideStatus: 'Clôturé'),
          showErrorSnackbar: false,
        ),
      ]);

      final resActif = futures[0];
      int actif = 0;
      if (resActif is Map) {
        if (resActif['totalElements'] is num) {
          actif = (resActif['totalElements'] as num).toInt();
        } else if (resActif['data'] is Map &&
            resActif['data']['totalElements'] is num) {
          actif = (resActif['data']['totalElements'] as num).toInt();
        }
      }
      if (actif > 0) {
        totalActif.value = actif;
        if (totalTous.value > actif) {
          totalCloture.value = totalTous.value - actif;
        }
      }

      final resCloture = futures[1];
      int cloture = 0;
      if (resCloture is Map) {
        if (resCloture['totalElements'] is num) {
          cloture = (resCloture['totalElements'] as num).toInt();
        } else if (resCloture['data'] is Map &&
            resCloture['data']['totalElements'] is num) {
          cloture = (resCloture['data']['totalElements'] as num).toInt();
        }
      }
      if (cloture > 0 && cloture != actif) {
        totalCloture.value = cloture;
        if (totalTous.value > cloture && totalActif.value == 0) {
          totalActif.value = totalTous.value - cloture;
        }
      }

      _logger.i(
        '📊 Status counts OR chargés: Actif=${totalActif.value}, Clôturé=${totalCloture.value}',
      );
    } catch (e) {
      _logger.d('Notice: Impossible de charger les compteurs de statut: $e');
    } finally {
      isLoadingCounts.value = false;
    }
  }

  Future<void> fetchNaturesAnomalies() async {
    if (isLoadingNatures.value) return;
    isLoadingNatures.value = true;
    try {
      final url = ApiService.getActiveNaturesAnomalies();
      final responseData = await _authController.makeRequest(
        url,
        method: 'GET',
        showErrorSnackbar: false,
      );

      final List<Map<String, dynamic>> items = [];
      if (responseData is List) {
        for (final item in responseData) {
          if (item is Map) {
            items.add(Map<String, dynamic>.from(item));
          }
        }
      } else if (responseData is Map) {
        final list = responseData['data'] ?? responseData['content'];
        if (list is List) {
          for (final item in list) {
            if (item is Map) {
              items.add(Map<String, dynamic>.from(item));
            }
          }
        }
      }

      if (items.isNotEmpty) {
        items.sort((a, b) {
          final lA = (a['libelle'] ?? a['nom'] ?? a['natureAnomalie'] ?? '')
              .toString();
          final lB = (b['libelle'] ?? b['nom'] ?? b['natureAnomalie'] ?? '')
              .toString();
          return lA.toLowerCase().compareTo(lB.toLowerCase());
        });
        naturesAnomalies.value = items;
        _logger.i(
          '✅ ${items.length} Natures d\'anomalies chargées depuis l\'API.',
        );
        fetchNatureCounts();
      }
    } catch (e) {
      _logger.d(
        'Notice: Natures d\'anomalies distantes non chargées ($e), repli sur les données locales.',
      );
    } finally {
      isLoadingNatures.value = false;
    }
  }

  /// Récupère en parallèle les totaux réels sur le serveur pour chaque nature d'anomalie
  Future<void> fetchNatureCounts() async {
    if (isLoadingNatureCounts.value) return;
    final listToCount = availableNatures;
    if (listToCount.isEmpty) return;

    isLoadingNatureCounts.value = true;
    try {
      final futures = <Future<dynamic>>[];
      final List<int> ids = [];

      for (final nat in listToCount) {
        final id = (nat['id'] as num?)?.toInt();
        if (id != null && id > 0) {
          ids.add(id);
          futures.add(
            _authController.makeRequest(
              ApiService.listOr(page: 0, size: 1),
              method: 'POST',
              body: {'natureAnomalieId': id},
              showErrorSnackbar: false,
            ),
          );
        }
      }

      final results = await Future.wait(futures);
      for (int i = 0; i < results.length; i++) {
        final res = results[i];
        final id = ids[i];
        if (res is Map) {
          int count = 0;
          if (res['totalElements'] is num) {
            count = (res['totalElements'] as num).toInt();
          } else if (res['data'] is Map &&
              res['data']['totalElements'] is num) {
            count = (res['data']['totalElements'] as num).toInt();
          }
          if (count > 0) {
            natureCounts[id] = count;
          }
        }
      }
      _logger.i(
        '📊 Totaux réels par nature d\'anomalie chargés: $natureCounts',
      );
    } catch (e) {
      _logger.d('Notice fetchNatureCounts: $e');
    } finally {
      isLoadingNatureCounts.value = false;
    }
  }

  void applyFilters() {
    final query = searchQuery.value.trim().toLowerCase();
    if (query.isEmpty) {
      filteredOrdres.value = List<Map<String, dynamic>>.from(ordres);
      return;
    }

    filteredOrdres.value = ordres.where((o) {
      final numero = (o['numero'] ?? o['numeroOrdreReparation'] ?? '')
          .toString()
          .toLowerCase();
      final numeroDemande = (o['numeroDemande'] ?? '').toString().toLowerCase();
      final immat = (o['immatriculation'] ?? o['vehiculeImmatriculation'] ?? '')
          .toString()
          .toLowerCase();
      final chauffeur = (o['chauffeur'] ?? o['chauffeurNom'] ?? '')
          .toString()
          .toLowerCase();
      final nature = (o['natureAnomalieLibelle'] ?? '')
          .toString()
          .toLowerCase();
      final typeIntervention = (o['typeInterventionLibelle'] ?? '')
          .toString()
          .toLowerCase();

      return numero.contains(query) ||
          numeroDemande.contains(query) ||
          immat.contains(query) ||
          chauffeur.contains(query) ||
          nature.contains(query) ||
          typeIntervention.contains(query);
    }).toList();
  }

  void updateSearchQuery(String query) {
    searchQuery.value = query;
    applyFilters();
  }

  Future<void> updateStatusFilter(String status) async {
    if (selectedStatusFilter.value == status) {
      selectedStatusFilter.value = 'TOUS';
    } else {
      selectedStatusFilter.value = status;
    }
    await fetchOrdres(showLoading: true);
  }

  Future<void> updateNatureAnomalieFilter(Map<String, dynamic>? nature) async {
    if (nature == null) {
      selectedNatureAnomalie.value = null;
    } else {
      final currentId = selectedNatureAnomalie.value?['id'];
      final currentLib = selectedNatureAnomalie.value?['libelle']
          ?.toString()
          .toLowerCase();
      final newId = nature['id'];
      final newLib = nature['libelle']?.toString().toLowerCase();

      if (currentId == newId && currentLib == newLib) {
        selectedNatureAnomalie.value = null;
      } else {
        selectedNatureAnomalie.value = nature;
      }
    }
    await fetchOrdres(showLoading: true);
  }

  Future<void> resetFilters() async {
    selectedStatusFilter.value = 'TOUS';
    selectedNatureAnomalie.value = null;
    searchQuery.value = '';
    await fetchOrdres(showLoading: true);
  }

  /// Étape courante du workflow d'un OR
  String currentEtape(Map<String, dynamic> ordre) {
    final steps = ordre['listEtape'];
    if (steps is! List || steps.isEmpty) return '—';
    final active = steps.where((e) => e is Map && e['active'] == 1).toList();
    if (active.isNotEmpty) {
      return active.last['libelle']?.toString() ?? '—';
    }
    return '—';
  }

  bool isCloture(Map<String, dynamic> ordre) {
    final status = ordre['status']?.toString().toLowerCase() ?? '';
    return status.contains('clot') || status.contains('clos');
  }

  void _loadFallbackOrdres() {
    totalElements.value = 29828;
    totalTous.value = 29828;
    totalActif.value = 1420;
    totalCloture.value = 28408;
    ordres.value = [
      {
        'id': 1,
        'numero': 'ORM0001',
        'numeroDemande': 'DEM0001',
        'immatriculation': '14285-A-26',
        'chauffeur': 'Ahmed El Amrani',
        'natureAnomalieLibelle': 'Panne moteur',
        'typeInterventionLibelle': 'Corrective',
        'status': 'Actif',
        'dateDemande': '2026-09-20',
        'lieuReparation': 'Interne',
        'montantTotal': 4500.00,
        'listEtape': [
          {'libelle': 'Généré', 'active': 0},
          {'libelle': 'D/Achat', 'active': 0},
          {'libelle': 'Réparation', 'active': 1},
        ],
      },
      {
        'id': 2,
        'numero': 'ORM0002',
        'numeroDemande': 'DEM0002',
        'immatriculation': '89542-B-06',
        'chauffeur': 'Youssef Bouali',
        'natureAnomalieLibelle': 'Freinage défaillant',
        'typeInterventionLibelle': 'Corrective',
        'status': 'Actif',
        'dateDemande': '2026-09-18',
        'lieuReparation': 'Externe',
        'montantTotal': 2800.00,
        'listEtape': [
          {'libelle': 'Généré', 'active': 1},
        ],
      },
      {
        'id': 3,
        'numero': 'ORM0003',
        'numeroDemande': 'DEM0003',
        'immatriculation': '23561-D-50',
        'chauffeur': 'Karim Tadlaoui',
        'natureAnomalieLibelle': 'Vidange complète',
        'typeInterventionLibelle': 'Préventive',
        'status': 'Clôturé',
        'dateDemande': '2026-09-10',
        'lieuReparation': 'Interne',
        'montantTotal': 1200.00,
        'listEtape': [
          {'libelle': 'Généré', 'active': 0},
          {'libelle': 'Réparation', 'active': 0},
          {'libelle': 'Clôture', 'active': 1},
        ],
      },
      {
        'id': 4,
        'numero': 'ORM0004',
        'numeroDemande': 'DEM0004',
        'immatriculation': '47896-A-11',
        'chauffeur': 'Omar Bennis',
        'natureAnomalieLibelle': 'Climatisation HS',
        'typeInterventionLibelle': 'Corrective',
        'status': 'Actif',
        'dateDemande': '2026-09-22',
        'lieuReparation': 'Externe',
        'montantTotal': 3200.00,
        'listEtape': [
          {'libelle': 'Généré', 'active': 0},
          {'libelle': 'D/Achat', 'active': 1},
        ],
      },
      {
        'id': 5,
        'numero': 'ORM0005',
        'numeroDemande': 'DEM0005',
        'immatriculation': '78412-F-33',
        'chauffeur': 'Said Chraibi',
        'natureAnomalieLibelle': 'Pneus usés',
        'typeInterventionLibelle': 'Préventive',
        'status': 'Clôturé',
        'dateDemande': '2026-09-05',
        'lieuReparation': 'Interne',
        'montantTotal': 6800.00,
        'listEtape': [
          {'libelle': 'Généré', 'active': 0},
          {'libelle': 'Réparation', 'active': 0},
          {'libelle': 'R/Technique', 'active': 0},
          {'libelle': 'Clôture', 'active': 1},
        ],
      },
    ];
  }
}
