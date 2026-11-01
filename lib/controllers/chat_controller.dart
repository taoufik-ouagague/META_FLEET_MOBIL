import 'package:get/get.dart';
import 'package:logger/logger.dart';
import '../services/api_service.dart';
import 'auth_controller.dart';

/// Chat employe ↔ administration.
///
/// Un fil par employe : l'employe ne voit que le sien, les porteurs du droit
/// CHAT_REPONDRE voient la liste des fils et y repondent.
class ChatController extends GetxController {
  final Logger _logger = Logger();
  final AuthController _authController = Get.find<AuthController>();

  /// Messages du fil ouvert (le sien, ou celui d'un employe).
  var messages = <Map<String, dynamic>>[].obs;

  /// Liste des fils, cote administration.
  var fils = <Map<String, dynamic>>[].obs;

  var isLoading = false.obs;
  var isSending = false.obs;
  var nonLus = 0.obs;
  var errorMessage = ''.obs;

  bool get peutRepondre =>
      _authController.currentUser.value?.hasAuthority('CHAT_REPONDRE') ?? false;

  @override
  void onInit() {
    super.onInit();
    rafraichirNonLus();
  }

  List<Map<String, dynamic>> _liste(dynamic data) {
    final contenu = (data is Map) ? (data['content'] ?? data['data']) : data;

    return contenu is List
        ? contenu.whereType<Map>().map(Map<String, dynamic>.from).toList()
        : <Map<String, dynamic>>[];
  }

  /// Pastille du bouton de chat.
  Future<void> rafraichirNonLus() async {
    try {
      final data = await _authController.makeRequest(
        ApiService.chatNonLus(),
        method: 'GET',
        showErrorSnackbar: false,
      );
      if (data is Map && data['nonLus'] is num) {
        nonLus.value = (data['nonLus'] as num).toInt();
      }
    } catch (_) {
      // Compteur indisponible : on laisse la valeur precedente.
    }
  }

  /// Fil de l'employe connecte. Le serveur marque au passage les reponses lues.
  Future<void> chargerMonFil({bool showLoading = true}) async {
    if (showLoading) isLoading.value = true;
    errorMessage.value = '';
    try {
      final data = await _authController.makeRequest(
        ApiService.chatMonFil(),
        method: 'GET',
        showErrorSnackbar: false,
      );
      messages.value = _liste(data);
      nonLus.value = 0;
    } catch (e) {
      _logger.w('Erreur chargement du fil : $e');
      errorMessage.value = 'Impossible de charger la discussion.';
    } finally {
      isLoading.value = false;
    }
  }

  /// Liste des fils (droit CHAT_REPONDRE).
  Future<void> chargerFils({bool showLoading = true}) async {
    if (showLoading) isLoading.value = true;
    errorMessage.value = '';
    try {
      final data = await _authController.makeRequest(
        ApiService.chatFils(),
        method: 'GET',
        showErrorSnackbar: false,
      );
      fils.value = _liste(data);
    } catch (e) {
      _logger.w('Erreur chargement des fils : $e');
      errorMessage.value = 'Impossible de charger les discussions.';
    } finally {
      isLoading.value = false;
    }
  }

  /// Fil d'un employe donne (droit CHAT_REPONDRE).
  Future<void> chargerFil(int employeId, {bool showLoading = true}) async {
    if (showLoading) isLoading.value = true;
    errorMessage.value = '';
    try {
      final data = await _authController.makeRequest(
        ApiService.chatFil(employeId),
        method: 'GET',
        showErrorSnackbar: false,
      );
      messages.value = _liste(data);
    } catch (e) {
      _logger.w('Erreur chargement du fil $employeId : $e');
      errorMessage.value = 'Impossible de charger la discussion.';
    } finally {
      isLoading.value = false;
    }
  }

  /// Envoie un message ; [employeId] null = son propre fil.
  /// Les pieces jointes partent en base64, comme la GED.
  Future<bool> envoyer({
    required String contenu,
    int? employeId,
    List<Map<String, dynamic>> piecesJointes = const [],
  }) async {
    if (contenu.trim().isEmpty && piecesJointes.isEmpty) return false;

    isSending.value = true;
    try {
      final data = await _authController.makeRequest(
        employeId == null
            ? ApiService.chatMonFil()
            : ApiService.chatFil(employeId),
        method: 'POST',
        body: {
          'contenu': contenu.trim(),
          if (piecesJointes.isNotEmpty) 'piecesJointes': piecesJointes,
        },
        showErrorSnackbar: false,
      );

      if (data is Map && data['id'] != null) {
        messages.add(Map<String, dynamic>.from(data));

        return true;
      }

      return false;
    } catch (e) {
      _logger.w('Erreur envoi message : $e');
      errorMessage.value = "Le message n'a pas pu être envoyé.";

      return false;
    } finally {
      isSending.value = false;
    }
  }
}
