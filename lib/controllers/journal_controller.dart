import 'dart:async';

import 'package:get/get.dart';
import 'package:logger/logger.dart';
import '../services/api_service.dart';
import 'auth_controller.dart';

/// Journal des operations (lignes d'OR et de vidanges). La table depasse les
/// 85 000 lignes : une page a l'ouverture, la suite au defilement, recherche
/// cote serveur — comme le journal du web et la liste des OR.
class JournalController extends GetxController {
  final Logger _logger = Logger();
  final AuthController _authController = Get.find<AuthController>();

  var lignes = <Map<String, dynamic>>[].obs;
  var filteredLignes = <Map<String, dynamic>>[].obs;
  var isLoading = false.obs;
  var isLoadingMore = false.obs;
  var errorMessage = ''.obs;
  var searchQuery = ''.obs;
  var selectedTypeFilter = 'TOUS'.obs;

  /// Filtres serveur repris du journal web.
  var selectedNature = Rxn<Map<String, dynamic>>();
  var articleFilter = ''.obs;

  /// Catalogue des articles pour le selecteur (charge une fois, comme le web).
  var articles = <Map<String, dynamic>>[].obs;
  var chargementArticles = false.obs;

  /// Totaux reels par type, lus sur le serveur (pas sur les pages chargees).
  var totalOr = 0.obs;
  var totalVidange = 0.obs;
  var totalElements = 0.obs;
  var totalPages = 1.obs;
  var currentPage = 0.obs;

  final int pageSize = 50;

  int get totalCount =>
      totalElements.value > 0 ? totalElements.value : lignes.length;

  /// Types connus du journal : la vue n'en produit que deux.
  List<String> get availableTypes => const ['TOUS', 'OR', 'VIDANGE'];

  /// Un serveur sans le filtre `typeOperation` renvoie le total global pour
  /// les deux types : dans ce cas on n'affiche aucun compteur plutot qu'un
  /// chiffre faux.
  bool get comptesParTypeFiables =>
      !(totalOr.value == totalVidange.value && totalOr.value == totalCount);

  int? countForType(String type) {
    if (type == 'TOUS') return totalCount;
    if (!comptesParTypeFiables) return null;

    return type == 'OR' ? totalOr.value : totalVidange.value;
  }

  @override
  void onInit() {
    super.onInit();
    debounce(
      searchQuery,
      (_) => fetchJournal(showLoading: false),
      time: const Duration(milliseconds: 500),
    );
    fetchJournal();
    chargerArticles();
  }

  /// Articles actifs, charges une seule fois : le selecteur les pagine ensuite
  /// localement, 100 par 100, comme le filtre du journal web.
  Future<void> chargerArticles() async {
    if (articles.isNotEmpty || chargementArticles.value) return;

    chargementArticles.value = true;
    try {
      final data = await _authController.makeRequest(
        ApiService.getActiveProduits(),
        method: 'GET',
        showErrorSnackbar: false,
      );
      final contenu = (data is Map) ? (data['content'] ?? data['data']) : data;
      if (contenu is List) {
        articles.value = contenu
            .whereType<Map>()
            .map(Map<String, dynamic>.from)
            .toList();
      }
    } catch (e) {
      _logger.w('Erreur chargement des articles : $e');
    } finally {
      chargementArticles.value = false;
    }
  }

  List<Map<String, dynamic>> _extraire(dynamic data) {
    final contenu = (data is Map)
        ? (data['content'] ?? data['data']?['content'] ?? data['data'])
        : data;

    return contenu is List
        ? contenu.whereType<Map>().map(Map<String, dynamic>.from).toList()
        : <Map<String, dynamic>>[];
  }

  int? _entier(dynamic data, String cle) {
    if (data is! Map) return null;
    if (data[cle] is num) return (data[cle] as num).toInt();
    if (data['data'] is Map && data['data'][cle] is num) {
      return (data['data'][cle] as num).toInt();
    }

    return null;
  }

  /// La recherche porte sur l'immatriculation ou sur le numero d'operation :
  /// une plaque contient un tiret ou un espace, un numero (ORM0107, VID0033)
  /// n'en a pas. Meme heuristique que la liste des OR.
  bool get _chercheUnNumero {
    final q = searchQuery.value.trim();

    return q.isNotEmpty && !q.contains('-') && !q.contains(' ');
  }

  String? get _filtreImmat => _chercheUnNumero ? null : searchQuery.value;
  String? get _filtreNumero => _chercheUnNumero ? searchQuery.value : null;

  int? get _natureId {
    final id = selectedNature.value?['id'];

    return (id is num && id > 0) ? id.toInt() : null;
  }

  /// Total serveur d'un type, sans ramener les lignes (size=1).
  Future<int> _totalPourType(String type) async {
    try {
      final data = await _authController.makeRequest(
        ApiService.journal(
          page: 0,
          size: 1,
          immatriculation: _filtreImmat,
          ordreNumero: _filtreNumero,
          typeOperation: type,
          article: articleFilter.value,
          natureAnomalieId: _natureId,
        ),
        method: 'GET',
        showErrorSnackbar: false,
      );

      return _entier(data, 'totalElements') ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<void> _rafraichirTotauxTypes() async {
    final resultats = await Future.wait([
      _totalPourType('OR'),
      _totalPourType('VIDANGE'),
    ]);
    totalOr.value = resultats[0];
    totalVidange.value = resultats[1];
  }

  Future<void> fetchJournal({bool showLoading = true}) async {
    if (showLoading) isLoading.value = true;
    errorMessage.value = '';
    currentPage.value = 0;

    try {
      final data = await _authController.makeRequest(
        ApiService.journal(
          page: 0,
          size: pageSize,
          immatriculation: _filtreImmat,
          ordreNumero: _filtreNumero,
          typeOperation: selectedTypeFilter.value == 'TOUS'
              ? null
              : selectedTypeFilter.value,
          article: articleFilter.value,
          natureAnomalieId: _natureId,
        ),
        method: 'GET',
        showErrorSnackbar: false,
      );

      final items = _extraire(data);
      totalElements.value = _entier(data, 'totalElements') ?? items.length;
      totalPages.value = _entier(data, 'totalPages') ?? 1;
      lignes.value = items;
      unawaited(_rafraichirTotauxTypes());
      _logger.i(
        '✅ Journal : ${items.length} lignes sur ${totalElements.value}.',
      );
    } catch (e) {
      _logger.w('Erreur chargement journal : $e');
      errorMessage.value =
          'Impossible de charger le journal. Vérifiez votre connexion.';
    } finally {
      applyFilters();
      isLoading.value = false;
    }
  }

  Future<void> loadNextPage() async {
    if (isLoadingMore.value || isLoading.value) return;
    if (currentPage.value + 1 >= totalPages.value) return;

    isLoadingMore.value = true;
    try {
      final suivante = currentPage.value + 1;
      final data = await _authController.makeRequest(
        ApiService.journal(
          page: suivante,
          size: pageSize,
          immatriculation: _filtreImmat,
          ordreNumero: _filtreNumero,
          typeOperation: selectedTypeFilter.value == 'TOUS'
              ? null
              : selectedTypeFilter.value,
          article: articleFilter.value,
          natureAnomalieId: _natureId,
        ),
        method: 'GET',
        showErrorSnackbar: false,
      );

      final items = _extraire(data);
      if (items.isNotEmpty) {
        currentPage.value = suivante;
        lignes.addAll(items);
        applyFilters();
      }
    } catch (e) {
      _logger.w('Erreur pagination journal : $e');
    } finally {
      isLoadingMore.value = false;
    }
  }

  /// Tous les filtres partent au serveur : la liste locale est deja filtree.
  void applyFilters() => filteredLignes.value = lignes.toList();

  void updateSearchQuery(String query) => searchQuery.value = query;

  void updateTypeFilter(String type) {
    selectedTypeFilter.value = selectedTypeFilter.value == type ? 'TOUS' : type;
    fetchJournal(showLoading: false);
  }

  void updateNature(Map<String, dynamic>? nature) {
    selectedNature.value = nature;
    fetchJournal(showLoading: false);
  }

  void updateArticle(String article) {
    articleFilter.value = article.trim();
    fetchJournal(showLoading: false);
  }

  void resetFilters() {
    selectedTypeFilter.value = 'TOUS';
    selectedNature.value = null;
    articleFilter.value = '';
    searchQuery.value = '';
    fetchJournal(showLoading: false);
  }
}
