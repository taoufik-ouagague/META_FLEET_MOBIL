import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/employe_model.dart';
import 'agenda_controller.dart';
import 'dashboard_controller.dart';
import 'demande_or_controller.dart';
import 'chat_controller.dart';
import 'journal_controller.dart';
import 'pneumatique_controller.dart';
import 'or_controller.dart';
import 'vehicule_controller.dart';
import 'vidange_controller.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/fcm_service.dart';

class AuthController extends GetxController {
  final Logger _logger = Logger();

  // Loading states
  var isLoading = false.obs;
  var isAuthenticated = false.obs;
  var isLoadingProfile = false.obs;
  var isUpdatingPhoto = false.obs;

  // Session & User observables
  var userToken = ''.obs;
  var fcmToken = ''.obs;
  var currentUser = Rxn<UserModel>();
  var employeProfile = Rxn<EmployeModel>();
  var serverUrl = ''.obs;

  @override
  void onInit() {
    super.onInit();
    serverUrl.value = ApiService.baseUrl;
    AppChannel.instance.onTokenRefresh((newToken) {
      fcmToken.value = newToken;
      _logger.i('📲 [FCM] Token rafraîchi dans AuthController : $newToken');
    });
    checkAuthStatus();
  }

  /// Vérifie si une session précédente est encore valide dans SharedPreferences
  Future<bool> checkAuthStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await ApiService.init();
      serverUrl.value = ApiService.baseUrl;

      final token = prefs.getString('auth_token');
      final userJsonStr = prefs.getString('auth_user');

      if (token != null && token.isNotEmpty && userJsonStr != null) {
        final Map<String, dynamic> userMap = jsonDecode(userJsonStr);
        final user = UserModel.fromJson(userMap);

        userToken.value = token;
        currentUser.value = user;
        isAuthenticated.value = true;
        _logger.i('👤 Session restaurée pour : ${user.username}');

        // Restaurer profil employé mis en cache
        final empJsonStr = prefs.getString('auth_employe_profile');
        if (empJsonStr != null) {
          try {
            employeProfile.value = EmployeModel.fromJson(
              jsonDecode(empJsonStr),
            );
          } catch (_) {}
        }

        // Rafraîchir les infos employé en arrière-plan
        fetchEmployeProfile();

        // Récupérer et synchroniser le token FCM
        syncFcmToken();

        return true;
      }
    } catch (e) {
      _logger.e('Erreur restauration session : $e');
    }
    isAuthenticated.value = false;
    return false;
  }

  /// Journalisation des charges utiles (corps envoyé, réponse reçue).
  /// Désactivée : les réponses JSON noyaient la console. Passer à true le
  /// temps d'un débogage.
  static const bool tracerPayloads = false;

  /// Helper HTTP calqué sur hr-perfect avec logs et gestion d'erreurs
  Future<dynamic> makeRequest(
    String url, {
    Map<String, dynamic>? body,
    String method = 'POST',
    bool showErrorSnackbar = true,
  }) async {
    try {
      _logger.i('🌐 [$method] Requête vers : $url');
      if (tracerPayloads && body != null) {
        _logger.d('📦 Body : $body');
      }

      if (userToken.value.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        final savedToken = prefs.getString('auth_token');
        if (savedToken != null && savedToken.isNotEmpty) {
          userToken.value = savedToken;
        }
      }

      final headers = {
        'Content-Type': 'application/json',
        if (userToken.value.isNotEmpty)
          'Authorization': 'Bearer ${userToken.value}',
      };

      http.Response response;
      if (method == 'DELETE') {
        response = await http
            .delete(Uri.parse(url), headers: headers)
            .timeout(
              const Duration(seconds: 25),
              onTimeout: () =>
                  throw Exception('Délai d\'attente dépassé (Timeout)'),
            );
      } else if (method == 'POST' || method == 'PUT') {
        final envoyer = method == 'PUT' ? http.put : http.post;

        response =
            await envoyer(
              Uri.parse(url),
              headers: headers,
              body: body != null ? jsonEncode(body) : null,
            ).timeout(
              const Duration(seconds: 25),
              onTimeout: () =>
                  throw Exception('Délai d\'attente dépassé (Timeout)'),
            );
      } else {
        response = await http
            .get(Uri.parse(url), headers: headers)
            .timeout(
              const Duration(seconds: 25),
              onTimeout: () =>
                  throw Exception('Délai d\'attente dépassé (Timeout)'),
            );
      }

      _logger.i('📊 Code HTTP : ${response.statusCode}');
      if (tracerPayloads) {
        _logger.d('📄 Réponse : ${response.body}');
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (response.body.isEmpty) return {};
        try {
          return jsonDecode(utf8.decode(response.bodyBytes));
        } catch (e) {
          return jsonDecode(response.body);
        }
      } else {
        String errorMessage = 'Erreur ${response.statusCode}';
        try {
          final errorData = jsonDecode(utf8.decode(response.bodyBytes));
          if (errorData['message'] != null) {
            errorMessage = errorData['message'];
          } else if (errorData['error'] != null) {
            errorMessage = errorData['error'];
          } else if (errorData['MSG'] != null) {
            errorMessage = errorData['MSG'];
          }
        } catch (_) {
          if (response.body.isNotEmpty) errorMessage = response.body;
        }

        if (response.statusCode == 401) {
          throw Exception(
            errorMessage.isNotEmpty
                ? errorMessage
                : 'Identifiants invalides ou session expirée',
          );
        } else if (response.statusCode == 403) {
          throw Exception(
            'Accès refusé : vous n\'avez pas les droits nécessaires',
          );
        } else if (response.statusCode == 404) {
          throw Exception('Service ou ressource introuvable (404)');
        } else if (response.statusCode >= 500) {
          throw Exception('Erreur serveur (${response.statusCode})');
        } else {
          throw Exception(errorMessage);
        }
      }
    } on http.ClientException catch (e) {
      _logger.e('❌ Erreur réseau HTTP', error: e);
      final msg =
          'Impossible de joindre le serveur. Vérifiez votre connexion/VPN.';
      if (showErrorSnackbar) {
        _showErrorSnackbar(msg);
      }
      throw Exception(msg);
    } catch (e) {
      _logger.e('❌ Exception requête', error: e);
      final cleanMsg = e.toString().replaceFirst('Exception: ', '');
      if (showErrorSnackbar) {
        _showErrorSnackbar(cleanMsg);
      }
      rethrow;
    }
  }

  void _showErrorSnackbar(String message) {
    Get.snackbar(
      'Erreur',
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: const Color(0xFFFEF2F2),
      colorText: const Color(0xFF991B1B),
      borderRadius: 14,
      margin: const EdgeInsets.all(16),
      icon: const Icon(Icons.error_outline, color: Color(0xFFDC2626)),
      duration: const Duration(seconds: 4),
    );
  }

  // ==================== AUTHENTIFICATION ====================
  Future<bool> authenticate(String username, String password) async {
    try {
      isLoading.value = true;
      _logger.i('🔐 Authentification de : $username');

      final url = ApiService.login();
      final data = await makeRequest(
        url,
        body: {'login': username.trim(), 'pwd': password.trim()},
        showErrorSnackbar: false,
      );

      final user = UserModel.fromJson(data);
      if (user.token.isEmpty) {
        throw Exception('Réponse invalide du serveur (aucun jeton reçu)');
      }

      // Sauvegarde dans SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', user.token);
      await prefs.setString('auth_user', jsonEncode(user.toJson()));

      userToken.value = user.token;
      currentUser.value = user;
      isAuthenticated.value = true;

      _logger.i('✅ Authentification réussie pour ${user.username}');

      // Charger le profil employé lié
      fetchEmployeProfile();

      // Récupérer et associer le token FCM
      syncFcmToken();

      // Les écrans du menu sont alimentés par des contrôleurs permanents créés au
      // démarrage, donc avant le login : leur premier appel part sans jeton et
      // revient vide. On relance les chargements maintenant que le jeton existe,
      // sinon il faut tirer pour rafraîchir chaque page.
      rechargerDonneesMetier();

      return true;
    } catch (e) {
      _logger.e('❌ Échec d\'authentification : $e');
      // makeRequest est appelé avec showErrorSnackbar: false pour que l'échec de
      // connexion n'affiche qu'un seul message, couvrant aussi le cas "jeton absent".
      _showErrorSnackbar(e.toString().replaceFirst('Exception: ', ''));
      rethrow;
    } finally {
      isLoading.value = false;
    }
  }

  /// Relance les chargements des écrans du menu (après login, ou à la demande).
  void rechargerDonneesMetier() {
    if (Get.isRegistered<DashboardController>()) {
      Get.find<DashboardController>().fetchDashboardData();
    }
    if (Get.isRegistered<VehiculeController>()) {
      Get.find<VehiculeController>().fetchActiveVehicules();
    }
    if (Get.isRegistered<VidangeController>()) {
      Get.find<VidangeController>().fetchVidanges();
    }
    if (Get.isRegistered<AgendaController>()) {
      Get.find<AgendaController>().fetchAllAgendaData();
    }
    if (Get.isRegistered<DemandeOrController>()) {
      Get.find<DemandeOrController>().fetchDemandes();
    }
    if (Get.isRegistered<OrController>()) {
      final or = Get.find<OrController>();
      or.fetchOrdres();
      or.fetchStatusCounts();
      or.fetchNaturesAnomalies();
    }

    if (Get.isRegistered<PneumatiqueController>()) {
      Get.find<PneumatiqueController>().fetchPneumatiques();
    }
    if (Get.isRegistered<JournalController>()) {
      Get.find<JournalController>().fetchJournal();
    }
    if (Get.isRegistered<ChatController>()) {
      Get.find<ChatController>().rafraichirNonLus();
    }
  }

  /// Récupère, journalise et synchronise le token FCM auprès du serveur
  Future<void> syncFcmToken() async {
    try {
      final token = await AppChannel.instance.getTokenAsync();
      if (token != null && token.isNotEmpty) {
        fcmToken.value = token;
        _logger.i('📲 [FCM] Token actif pour la session : $token');

        // Envoyer le token au backend pour associer l'appareil au compte
        if (isAuthenticated.value && userToken.value.isNotEmpty) {
          try {
            await makeRequest(
              ApiService.updateFcmToken(),
              body: {'fcmToken': token},
              showErrorSnackbar: false,
            );
            _logger.i('✅ [FCM] Token mobile enregistré auprès du serveur.');
          } catch (e) {
            _logger.w(
              '⚠️ [FCM] Impossible d\'enregistrer le token auprès du serveur : $e',
            );
          }
        }
      }
    } catch (e) {
      _logger.w('⚠️ [FCM] Erreur synchronisation token : $e');
    }
  }

  /// Récupère les informations complètes de l'employé connecté
  Future<void> fetchEmployeProfile() async {
    final empId = currentUser.value?.employeId;
    if (empId == null || empId <= 0) return;

    try {
      isLoadingProfile.value = true;
      _logger.i('👤 Chargement des infos employé ID : $empId');

      final url = ApiService.getEmploye(empId);
      final data = await makeRequest(
        url,
        method: 'GET',
        showErrorSnackbar: false,
      );

      if (data != null && data is Map<String, dynamic>) {
        final profile = EmployeModel.fromJson(data);
        employeProfile.value = profile;

        // Mise en cache
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          'auth_employe_profile',
          jsonEncode(profile.toJson()),
        );

        _logger.i('✅ Infos employé chargées : ${profile.displayName}');
      }
    } catch (e) {
      _logger.w('⚠️ Impossible de charger le profil employé : $e');
    } finally {
      isLoadingProfile.value = false;
    }
  }

  /// Déconnexion
  Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
      await prefs.remove('auth_user');
      await prefs.remove('auth_employe_profile');

      userToken.value = '';
      currentUser.value = null;
      employeProfile.value = null;
      isAuthenticated.value = false;

      Get.offAllNamed('/login');
    } catch (e) {
      _logger.e('Erreur déconnexion : $e');
    }
  }

  /// Met à jour l'URL du serveur
  Future<void> updateServerUrl(String newUrl) async {
    await ApiService.setBaseUrl(newUrl);
    serverUrl.value = ApiService.baseUrl;
    Get.snackbar(
      'Serveur configuré',
      'Nouvelle URL : ${serverUrl.value}',
      snackPosition: SnackPosition.TOP,
      backgroundColor: const Color(0xFFF0FDF4),
      colorText: const Color(0xFF166534),
      borderRadius: 14,
      margin: const EdgeInsets.all(16),
      icon: const Icon(Icons.check_circle_outline, color: Color(0xFF16A34A)),
      duration: const Duration(seconds: 3),
    );
  }

  /// Met à jour la photo de profil en base64 pour l'utilisateur connecté
  Future<bool> updateProfilePhoto(String base64Image) async {
    final user = currentUser.value;
    if (user == null || user.id <= 0) {
      Get.snackbar(
        'Erreur',
        'Utilisateur non identifié',
        backgroundColor: const Color(0xFFFEF2F2),
        colorText: const Color(0xFFDC2626),
      );
      return false;
    }

    try {
      isUpdatingPhoto.value = true;
      _logger.i(
        '📷 Envoi de la nouvelle photo pour l\'utilisateur ID : ${user.id}',
      );

      final url = ApiService.updateUserPhoto(user.id);
      await makeRequest(
        url,
        method: 'POST',
        body: {'photo': base64Image},
        showErrorSnackbar: true,
      );

      // Met à jour currentUser avec la nouvelle photo
      final updatedUser = user.copyWith(photo: base64Image);
      currentUser.value = updatedUser;

      // Persister dans SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_user', jsonEncode(updatedUser.toJson()));

      Get.snackbar(
        'Succès',
        'Photo de profil mise à jour avec succès',
        snackPosition: SnackPosition.TOP,
        backgroundColor: const Color(0xFFF0FDF4),
        colorText: const Color(0xFF166534),
        borderRadius: 14,
        margin: const EdgeInsets.all(16),
        icon: const Icon(Icons.check_circle_outline, color: Color(0xFF16A34A)),
        duration: const Duration(seconds: 3),
      );

      return true;
    } catch (e) {
      _logger.e('Erreur mise à jour photo : $e');
      Get.snackbar(
        'Erreur',
        'Échec de la mise à jour de la photo de profil',
        snackPosition: SnackPosition.TOP,
        backgroundColor: const Color(0xFFFEF2F2),
        colorText: const Color(0xFFDC2626),
        borderRadius: 14,
        margin: const EdgeInsets.all(16),
      );
      return false;
    } finally {
      isUpdatingPhoto.value = false;
    }
  }
}
