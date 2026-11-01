import 'package:get/get.dart';
import 'package:logger/logger.dart';
import '../services/api_service.dart';
import 'auth_controller.dart';

enum AgendaEventType { vidange, document }

enum AgendaTabMode { agenda, aPlanifier, conflits }

enum PlanifierSource { vidanges, documents }

class AgendaEventItem {
  final String id;
  final int? rawId;
  final AgendaEventType type;
  final String immatriculation;
  final String marque;
  final String modele;
  final String status;
  final DateTime date;
  final String dateStr; // YYYY-MM-DD
  final String? timeStr;
  final String? prestataire;
  final double? kilometrage;
  final String? docLibelle;
  final String? docNumero;
  final String? observation;
  final int? vehiculeId;
  final bool isConflict;
  final Map<String, dynamic> rawData;

  AgendaEventItem({
    required this.id,
    this.rawId,
    required this.type,
    required this.immatriculation,
    this.marque = '',
    this.modele = '',
    required this.status,
    required this.date,
    required this.dateStr,
    this.timeStr,
    this.prestataire,
    this.kilometrage,
    this.docLibelle,
    this.docNumero,
    this.observation,
    this.vehiculeId,
    this.isConflict = false,
    required this.rawData,
  });
}

class ConflitSemaineItem {
  final int? vehiculeId;
  final String immatriculation;
  final String lundi;
  final List<ConflitActionItem> actions;

  ConflitSemaineItem({
    this.vehiculeId,
    required this.immatriculation,
    required this.lundi,
    required this.actions,
  });
}

class ConflitActionItem {
  final String cle;
  final String libelle;
  final String date;
  final bool ouverte;
  final String type;

  ConflitActionItem({
    required this.cle,
    required this.libelle,
    required this.date,
    required this.ouverte,
    required this.type,
  });
}

class AgendaController extends GetxController {
  final Logger _logger = Logger();
  final AuthController _authController = Get.find<AuthController>();

  // États réactifs
  var isLoading = false.obs;
  var errorMessage = ''.obs;

  // Onglet sélectionné : Agenda (calendrier), À planifier (alertes), Conflits
  var selectedTab = AgendaTabMode.agenda.obs;

  // Sous-source pour "À planifier" : vidanges ou documents
  var planifierSource = PlanifierSource.vidanges.obs;

  // Date courante / Curseur calendrier
  var cursorMonth = DateTime(DateTime.now().year, DateTime.now().month, 1).obs;
  var selectedDate = Rxn<DateTime>();

  // Filtres
  var searchQuery = ''.obs;
  var selectedStatusFilter = 'TOUS'.obs;

  // Données brutes backend
  var plannedVidanges = <Map<String, dynamic>>[].obs;
  var plannedOperations = <Map<String, dynamic>>[].obs;
  var alertesVidange = <Map<String, dynamic>>[].obs;
  var docsEnAlerte = <Map<String, dynamic>>[].obs;
  var backendConflits = <Map<String, dynamic>>[].obs;
  var vehiculesById = <int, Map<String, dynamic>>{}.obs;

  // Données unifiées
  var allEvents = <AgendaEventItem>[].obs;
  var conflitsSemaine = <ConflitSemaineItem>[].obs;
  var conflictEventKeys = <String>{}.obs;

  @override
  void onInit() {
    super.onInit();
    fetchAllAgendaData();
  }

  /// Récupère toutes les données nécessaires depuis le backend
  Future<void> fetchAllAgendaData({bool showLoading = true}) async {
    if (showLoading) isLoading.value = true;
    errorMessage.value = '';

    try {
      _logger.i('📅 Chargement des données de planification & agenda...');

      // 1. Véhicules actifs (pour enrichir marque/modèle/km)
      try {
        final vehRes = await _authController.makeRequest(
          ApiService.getActiveVehicules(),
          method: 'GET',
          showErrorSnackbar: false,
        );
        final list = _extractList(vehRes);
        final vMap = <int, Map<String, dynamic>>{};
        for (final v in list) {
          final id = v['id'] is num ? (v['id'] as num).toInt() : null;
          if (id != null) vMap[id] = v;
        }
        vehiculesById.value = vMap;
      } catch (e) {
        _logger.w('Erreur getActiveVehicules: $e');
      }

      // 2. Vidanges enregistrées (tous statuts)
      try {
        final vidRes = await _authController.makeRequest(
          ApiService.listVidanges(page: 0, size: 500),
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
        plannedVidanges.value = _extractList(vidRes);
      } catch (e) {
        _logger.w('Erreur listVidanges: $e');
        plannedVidanges.clear();
      }

      // 3. Opérations administratives (documents enregistrés)
      try {
        final opRes = await _authController.makeRequest(
          ApiService.listOperations(page: 0, size: 500),
          method: 'POST',
          body: {},
          showErrorSnackbar: false,
        );
        plannedOperations.value = _extractList(opRes);
      } catch (e) {
        _logger.w('Erreur listOperations: $e');
        plannedOperations.clear();
      }

      // 4. Alertes vidange (véhicules à vidanger)
      try {
        final alerteRes = await _authController.makeRequest(
          ApiService.listAlertesVidange(),
          method: 'GET',
          showErrorSnackbar: false,
        );
        alertesVidange.value = _extractList(alerteRes);
      } catch (e) {
        _logger.w('Erreur listAlertesVidange: $e');
        alertesVidange.clear();
      }

      // 5. Documents en alerte (à renouveler)
      try {
        final docRes = await _authController.makeRequest(
          ApiService.listDocsEnAlerte(),
          method: 'GET',
          showErrorSnackbar: false,
        );
        docsEnAlerte.value = _extractList(docRes);
      } catch (e) {
        _logger.w('Erreur listDocsEnAlerte: $e');
        docsEnAlerte.clear();
      }

      // 6. Conflits de planification du backend
      try {
        final confRes = await _authController.makeRequest(
          ApiService.listConflitsPlanification(),
          method: 'GET',
          showErrorSnackbar: false,
        );
        backendConflits.value = _extractList(confRes);
      } catch (e) {
        _logger.w('Erreur listConflitsPlanification: $e');
        backendConflits.clear();
      }

      // 7. Traiter et unifier les données
      _processUnifiedEvents();
    } catch (e) {
      _logger.e('Erreur générale fetchAllAgendaData: $e');
      errorMessage.value = 'Erreur lors du chargement des données.';
    } finally {
      isLoading.value = false;
    }
  }

  List<Map<String, dynamic>> _extractList(dynamic res) {
    if (res == null) return [];
    final d = (res is Map && res.containsKey('data')) ? res['data'] : res;
    if (d is List) {
      return d.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    if (d is Map && d['content'] is List) {
      return (d['content'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    return [];
  }

  void _processUnifiedEvents() {
    // ── Détection des conflits de la semaine (façon planifiervidange/index.vue) ──
    final groups = <String, ConflitSemaineItem>{};

    void ajouterConflit(
      int? vehiculeId,
      String immat,
      String dateStr,
      ConflitActionItem action,
    ) {
      if (vehiculeId == null || dateStr.isEmpty) return;
      DateTime? dt;
      try {
        dt = DateTime.parse(dateStr.substring(0, 10));
      } catch (_) {
        return;
      }
      if (dt.weekday == DateTime.sunday) return; // Dimanche exclu
      final lundi = _getMondayOfWeek(dt);
      final cle = '$vehiculeId|$lundi';

      if (!groups.containsKey(cle)) {
        groups[cle] = ConflitSemaineItem(
          vehiculeId: vehiculeId,
          immatriculation: immat,
          lundi: lundi,
          actions: [],
        );
      }
      groups[cle]!.actions.add(action);
    }

    const vidangesAgenda = [
      'Planifié',
      'Replanifié',
      'En cours',
      'Validé',
      'Clôturé',
    ];
    const vidangesOuvertes = ['Planifié', 'Replanifié', 'En cours'];
    const operationsAgenda = ['Planifié', 'Replanifié', 'Clôturé'];
    const operationsOuvertes = ['Planifié', 'Replanifié'];

    // Analyser vidanges
    for (final v in plannedVidanges) {
      final status = v['status']?.toString() ?? '';
      final rawDate =
          v['dateDebutPrevu'] ?? v['dateDebut'] ?? v['dateCreation'];
      if (!vidangesAgenda.contains(status) || rawDate == null) continue;
      final dateStr = rawDate.toString().substring(0, 10);
      final vId = v['vehiculeId'] is num
          ? (v['vehiculeId'] as num).toInt()
          : null;
      final immat =
          v['vehiculeImmatriculation']?.toString() ??
          v['numero']?.toString() ??
          '—';
      final vNum = v['numero'] != null ? ' ${v['numero']}' : '';

      ajouterConflit(
        vId,
        immat,
        dateStr,
        ConflitActionItem(
          cle: 'p-${v['id']}',
          libelle: 'Vidange$vNum',
          date: dateStr,
          ouverte: vidangesOuvertes.contains(status),
          type: 'vidange',
        ),
      );
    }

    // Analyser opérations administratives
    for (final o in plannedOperations) {
      final status = o['status']?.toString() ?? '';
      final rawDate = o['dateDebut'];
      if (!operationsAgenda.contains(status) || rawDate == null) continue;
      final dateStr = rawDate.toString().substring(0, 10);
      final vId = o['vehiculeId'] is num
          ? (o['vehiculeId'] as num).toInt()
          : null;
      final immat =
          o['vehiculeImmatriculation']?.toString() ??
          o['docAdmPrcLibelle']?.toString() ??
          '—';

      ajouterConflit(
        vId,
        immat,
        dateStr,
        ConflitActionItem(
          cle: 'o-${o['id']}',
          libelle: o['docAdmPrcLibelle']?.toString() ?? 'Document',
          date: dateStr,
          ouverte: operationsOuvertes.contains(status),
          type: 'document',
        ),
      );
    }

    // Garder seulement les groupes avec >= 2 actions dont au moins une ouverte
    final conflits = groups.values.where((g) {
      return g.actions.length >= 2 && g.actions.any((a) => a.ouverte);
    }).toList();

    conflits.sort((a, b) => a.lundi.compareTo(b.lundi));
    conflitsSemaine.value = conflits;

    final conflictKeys = <String>{};
    for (final c in conflits) {
      for (final a in c.actions) {
        conflictKeys.add(a.cle);
      }
    }
    conflictEventKeys.assignAll(conflictKeys);

    // ── Construire la liste unifiée des événements ──
    final events = <AgendaEventItem>[];

    // 1. Vidanges
    for (final v in plannedVidanges) {
      final rawDate =
          v['dateDebutPrevu'] ?? v['dateDebut'] ?? v['dateCreation'];
      if (rawDate == null) continue;
      DateTime? dt;
      try {
        dt = DateTime.parse(rawDate.toString());
      } catch (_) {
        continue;
      }
      final dateStr =
          "${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";
      final timeStr = (dt.hour != 0 || dt.minute != 0)
          ? "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}"
          : null;

      final vId = v['vehiculeId'] is num
          ? (v['vehiculeId'] as num).toInt()
          : null;
      final veh = vId != null ? vehiculesById[vId] : null;

      final immat =
          v['vehiculeImmatriculation']?.toString() ??
          veh?['immatriculation']?.toString() ??
          v['numero']?.toString() ??
          '—';
      final marque = veh?['marqueLibelle']?.toString() ?? '';
      final modele = veh?['modeleLibelle']?.toString() ?? '';
      final status = v['status']?.toString() ?? 'Planifié';
      final km = (v['kilometrage'] ?? veh?['kmActuel']) is num
          ? ((v['kilometrage'] ?? veh?['kmActuel']) as num).toDouble()
          : null;

      String? prest;
      if (v['prestataires'] is List && (v['prestataires'] as List).isNotEmpty) {
        prest = (v['prestataires'] as List)
            .map((p) => p['libelle']?.toString())
            .whereType<String>()
            .join(', ');
      }

      final key = 'p-${v['id']}';
      events.add(
        AgendaEventItem(
          id: key,
          rawId: v['id'] is num ? (v['id'] as num).toInt() : null,
          type: AgendaEventType.vidange,
          immatriculation: immat,
          marque: marque,
          modele: modele,
          status: status,
          date: dt,
          dateStr: dateStr,
          timeStr: timeStr,
          prestataire: prest,
          kilometrage: km,
          observation:
              v['observationPlanification']?.toString() ??
              v['observation']?.toString(),
          vehiculeId: vId,
          isConflict: conflictKeys.contains(key),
          rawData: v,
        ),
      );
    }

    // 2. Opérations administratives (documents)
    for (final o in plannedOperations) {
      final rawDate = o['dateDebut'];
      if (rawDate == null) continue;
      DateTime? dt;
      try {
        dt = DateTime.parse(rawDate.toString());
      } catch (_) {
        continue;
      }
      final dateStr =
          "${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";
      final timeStr = (dt.hour != 0 || dt.minute != 0)
          ? "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}"
          : null;

      final vId = o['vehiculeId'] is num
          ? (o['vehiculeId'] as num).toInt()
          : null;
      final veh = vId != null ? vehiculesById[vId] : null;

      final immat =
          o['vehiculeImmatriculation']?.toString() ??
          veh?['immatriculation']?.toString() ??
          o['docAdmPrcLibelle']?.toString() ??
          '—';
      final marque = veh?['marqueLibelle']?.toString() ?? '';
      final modele = veh?['modeleLibelle']?.toString() ?? '';
      final status = o['status']?.toString() ?? 'Planifié';
      final km = (veh?['kmActuel']) is num
          ? (veh?['kmActuel'] as num).toDouble()
          : null;

      final key = 'o-${o['id']}';
      events.add(
        AgendaEventItem(
          id: key,
          rawId: o['id'] is num ? (o['id'] as num).toInt() : null,
          type: AgendaEventType.document,
          immatriculation: immat,
          marque: marque,
          modele: modele,
          status: status,
          date: dt,
          dateStr: dateStr,
          timeStr: timeStr,
          prestataire: o['prestataireLibelle']?.toString(),
          kilometrage: km,
          docLibelle: o['docAdmPrcLibelle']?.toString(),
          docNumero: o['docAdmVehiculeNumero']?.toString(),
          observation:
              o['observationPlanification']?.toString() ??
              o['observation']?.toString(),
          vehiculeId: vId,
          isConflict: conflictKeys.contains(key),
          rawData: o,
        ),
      );
    }

    // Trier par date décroissante
    events.sort((a, b) => b.date.compareTo(a.date));
    allEvents.value = events;
  }

  String _getMondayOfWeek(DateTime dt) {
    final diff = dt.weekday - 1; // 0 pour lundi, 6 pour dimanche
    final monday = dt.subtract(Duration(days: diff));
    return "${monday.year.toString().padLeft(4, '0')}-${monday.month.toString().padLeft(2, '0')}-${monday.day.toString().padLeft(2, '0')}";
  }

  // Navigation dans le calendrier
  void changeMonth(int delta) {
    final y = cursorMonth.value.year;
    final m = cursorMonth.value.month + delta;
    cursorMonth.value = DateTime(y, m, 1);
  }

  void selectDay(DateTime? day) {
    if (day == null) {
      selectedDate.value = null;
    } else {
      if (selectedDate.value != null &&
          selectedDate.value!.year == day.year &&
          selectedDate.value!.month == day.month &&
          selectedDate.value!.day == day.day) {
        selectedDate.value = null; // Désélectionner au re-clic
      } else {
        selectedDate.value = day;
      }
    }
  }

  // Statuts disponibles
  List<String> get availableStatuses {
    final set = <String>{'TOUS'};
    const preferredOrder = [
      'Planifié',
      'Replanifié',
      'En cours',
      'Validé',
      'Clôturé',
      'Actif',
    ];
    for (final s in preferredOrder) {
      if (allEvents.any((e) => e.status.toLowerCase() == s.toLowerCase())) {
        set.add(s);
      }
    }
    for (final e in allEvents) {
      if (!set.contains(e.status) && e.status.isNotEmpty) {
        set.add(e.status);
      }
    }
    return set.toList();
  }

  int countForStatus(String s) {
    if (s == 'TOUS') return allEvents.length;
    final target = s.trim().toLowerCase();
    return allEvents
        .where((e) => e.status.trim().toLowerCase() == target)
        .length;
  }

  // Événements filtrés
  List<AgendaEventItem> get filteredEvents {
    var list = allEvents.toList();

    // Filtre statut
    if (selectedStatusFilter.value != 'TOUS') {
      final s = selectedStatusFilter.value.trim().toLowerCase();
      list = list.where((e) => e.status.trim().toLowerCase() == s).toList();
    }

    // Filtre recherche textuelle
    if (searchQuery.value.trim().isNotEmpty) {
      final q = searchQuery.value.trim().toLowerCase();
      list = list.where((e) {
        return e.immatriculation.toLowerCase().contains(q) ||
            e.marque.toLowerCase().contains(q) ||
            e.modele.toLowerCase().contains(q) ||
            (e.prestataire ?? '').toLowerCase().contains(q) ||
            (e.docLibelle ?? '').toLowerCase().contains(q);
      }).toList();
    }

    // Filtre date spécifique si sélectionnée
    if (selectedDate.value != null) {
      final d = selectedDate.value!;
      final dStr =
          "${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
      list = list.where((e) => e.dateStr == dStr).toList();
    } else {
      // Filtrer par mois courant affiché dans le calendrier
      final cy = cursorMonth.value.year;
      final cm = cursorMonth.value.month;
      list = list
          .where((e) => e.date.year == cy && e.date.month == cm)
          .toList();
    }

    return list;
  }

  // Map des dates ayant des événements pour le mois affiché
  Map<String, List<AgendaEventItem>> get eventsByDateMap {
    final map = <String, List<AgendaEventItem>>{};
    for (final e in allEvents) {
      if (!map.containsKey(e.dateStr)) {
        map[e.dateStr] = [];
      }
      map[e.dateStr]!.add(e);
    }
    return map;
  }

  // Filtre pour "À planifier" (Alertes vidange ou Documents à renouveler)
  List<Map<String, dynamic>> get filteredAlertesVidange {
    final q = searchQuery.value.trim().toLowerCase();
    if (q.isEmpty) return alertesVidange;
    return alertesVidange.where((a) {
      final immat = a['immatriculation']?.toString().toLowerCase() ?? '';
      final mod = a['modele']?.toString().toLowerCase() ?? '';
      final mrq = a['marque']?.toString().toLowerCase() ?? '';
      return immat.contains(q) || mod.contains(q) || mrq.contains(q);
    }).toList();
  }

  List<Map<String, dynamic>> get filteredDocsEnAlerte {
    final q = searchQuery.value.trim().toLowerCase();
    if (q.isEmpty) return docsEnAlerte;
    return docsEnAlerte.where((d) {
      final immat = d['immatriculation']?.toString().toLowerCase() ?? '';
      final doc = d['document']?.toString().toLowerCase() ?? '';
      return immat.contains(q) || doc.contains(q);
    }).toList();
  }
}
