import 'package:get/get.dart';
import 'package:logger/logger.dart';
import '../models/notification_item_model.dart';
import '../services/api_service.dart';
import 'auth_controller.dart';

class NotificationController extends GetxController {
  final Logger _logger = Logger();
  final AuthController _authController = Get.find<AuthController>();

  var notifications = <NotificationItemModel>[].obs;
  var isLoading = false.obs;
  var unreadCount = 0.obs;

  /// Filtre de la liste : vrai = seulement les non lues.
  var nonLuesSeulement = false.obs;

  List<NotificationItemModel> get listeAffichee => nonLuesSeulement.value
      ? notifications.where((n) => !n.isRead).toList()
      : notifications;

  @override
  void onInit() {
    super.onInit();
    fetchNotifications();
    fetchUnreadCount();
  }

  Future<void> fetchNotifications({bool showLoading = true}) async {
    if (showLoading) isLoading.value = true;
    try {
      final responseData = await _authController.makeRequest(
        ApiService.getMyNotifications(),
        method: 'GET',
        showErrorSnackbar: false,
      );

      final List<NotificationItemModel> list = [];
      if (responseData is List) {
        for (final item in responseData) {
          if (item is Map<String, dynamic>) {
            list.add(NotificationItemModel.fromJson(item));
          } else if (item is Map) {
            list.add(
              NotificationItemModel.fromJson(Map<String, dynamic>.from(item)),
            );
          }
        }
      }

      notifications.value = list;
      _updateUnreadCountFromList();
      _logger.i('🔔 [NOTIF] ${list.length} notifications chargées');
    } catch (e) {
      _logger.e('🔥 [NOTIF] Erreur lors du chargement des notifications: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> fetchUnreadCount() async {
    try {
      final responseData = await _authController.makeRequest(
        ApiService.getUnreadNotificationCount(),
        method: 'GET',
        showErrorSnackbar: false,
      );
      if (responseData is Map && responseData['unreadCount'] is num) {
        unreadCount.value = (responseData['unreadCount'] as num).toInt();
      }
    } catch (e) {
      _updateUnreadCountFromList();
    }
  }

  Future<void> markAsRead(int id) async {
    // Mise à jour optimiste dans l'UI
    final idx = notifications.indexWhere((n) => n.id == id);
    if (idx != -1 && !notifications[idx].isRead) {
      notifications[idx] = notifications[idx].copyWith(isRead: true);
      _updateUnreadCountFromList();
    }

    try {
      await _authController.makeRequest(
        ApiService.markNotificationAsRead(id),
        method: 'PUT',
        showErrorSnackbar: false,
      );
    } catch (e) {
      _logger.e('Erreur lors du marquage comme lu: $e');
    }
  }

  Future<void> markAllAsRead() async {
    for (int i = 0; i < notifications.length; i++) {
      if (!notifications[i].isRead) {
        notifications[i] = notifications[i].copyWith(isRead: true);
      }
    }
    unreadCount.value = 0;

    try {
      await _authController.makeRequest(
        ApiService.markAllNotificationsAsRead(),
        method: 'PUT',
        showErrorSnackbar: false,
      );
    } catch (e) {
      _logger.e('Erreur lors du marquage de tout comme lu: $e');
    }
  }

  /// Suppression d'une notification : retrait immediat de la liste, puis appel API.
  /// En cas d'echec on recharge pour ne pas mentir a l'utilisateur.
  Future<void> supprimer(int id) async {
    final index = notifications.indexWhere((n) => n.id == id);
    if (index == -1) return;

    final supprimee = notifications[index];
    notifications.removeAt(index);
    _updateUnreadCountFromList();

    try {
      await _authController.makeRequest(
        ApiService.deleteNotification(id),
        method: 'POST',
        showErrorSnackbar: false,
      );
    } catch (e) {
      _logger.e('Erreur lors de la suppression de la notification $id: $e');
      notifications.insert(index, supprimee);
      _updateUnreadCountFromList();
      Get.snackbar(
        'Suppression impossible',
        'La notification n\'a pas pu être supprimée.',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  void _updateUnreadCountFromList() {
    unreadCount.value = notifications.where((n) => !n.isRead).length;
  }
}
