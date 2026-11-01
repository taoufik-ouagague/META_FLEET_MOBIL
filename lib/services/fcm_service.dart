import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../controllers/notification_controller.dart';
import '../firebase_options.dart';
import '../screens/dashboard/cards/navigation_fiches.dart';

/// Ouvre la cible d'une notification. Les routes sont posees par le backend :
/// « /or/123 » (onglet Approvisionnement), « /vidange/12 », « /vehicule/7 » et
/// « /vehicule/7/documents » ; tout le reste part en route nommee.
void ouvrirRouteNotification(String? route) {
  if (route == null || route.isEmpty) return;

  final cible = RegExp(
    r'^/(or|vidange|vehicule)/(\d+)(/documents)?$',
  ).firstMatch(route);
  if (cible == null) {
    Get.toNamed(route);

    return;
  }

  final id = int.parse(cible.group(2)!);
  switch (cible.group(1)) {
    case 'or':
      ouvrirFicheOr({'id': id}, onglet: OngletOr.approvisionnement);
    case 'vidange':
      ouvrirFicheVidange({'vidangeId': id});
    default:
      ouvrirFicheVehicule(
        {'id': id},
        onglet: cible.group(3) != null
            ? OngletVehicule.documents
            : OngletVehicule.informations,
      );
  }
}

/// Top-level background message handler requis par Firebase Messaging
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Nécessaire si des plugins ou Firebase sont appelés ici
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (_) {}
  debugPrint(
    '🌙 [FCM Background] Message reçu: ${message.messageId} - ${message.data}',
  );
}

/// Service singleton de gestion des notifications Firebase Cloud Messaging (FCM)
/// compatible avec la structure AppChannel (carre / hr-perfect).
class AppChannel {
  static final AppChannel _instance = AppChannel._internal();
  factory AppChannel() => _instance;
  static AppChannel get instance => _instance;

  AppChannel._internal();

  final Logger _logger = Logger();
  FirebaseApp? _app;
  String? _token;
  final List<void Function(String)> _tokenRefreshListeners = [];
  final List<void Function(RemoteMessage)> _messageListeners = [];

  /// Instance Firebase associée
  FirebaseApp? get app => _app;

  /// Token FCM courant (ou restauré du cache)
  String? get fcmToken => _token;

  /// Obtient le token de manière asynchrone avec secours sur SharedPreferences
  Future<String?> getTokenAsync() async {
    if (_token != null && _token!.isNotEmpty) return _token;
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('fcm_token');
    if (_token != null && _token!.isNotEmpty) return _token;

    try {
      // ignore: deprecated_member_use
      _token = await FirebaseMessaging.instance.getToken();
      if (_token != null) {
        await prefs.setString('fcm_token', _token!);
      }
    } catch (e) {
      _logger.w('⚠️ Impossible de récupérer le token FCM à la demande : $e');
    }
    return _token;
  }

  /// Initialisation de Firebase et du canal FCM
  Future<void> init() async {
    _logger.i('🔧 [FCM] Initialisation de AppChannel / FCM Service...');

    try {
      // 1. Initialiser Firebase avec les options du projet metafleet-02
      if (Firebase.apps.isEmpty) {
        _app = await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        _logger.i('✅ Firebase initialisé avec succès (fresh)');
      } else {
        _app = Firebase.app();
        _logger.i('✅ Firebase déjà initialisé');
      }

      // 2. Restaurer le dernier token en cache local
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString('fcm_token');
      if (_token != null) {
        _logger.d('💾 Token FCM restauré du cache: $_token');
      }

      // 3. Enregistrer le handler de messages en arrière-plan
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // 4. Options d'affichage des notifications en avant-plan sur iOS
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
            alert: true,
            badge: true,
            sound: true,
          );

      // 5. Demander la permission à l'utilisateur
      final NotificationSettings settings = await FirebaseMessaging.instance
          .requestPermission(
            alert: true,
            announcement: false,
            badge: true,
            carPlay: false,
            criticalAlert: false,
            provisional: false,
            sound: true,
          );

      _logger.i(
        '🔔 Statut permission notifications: ${settings.authorizationStatus}',
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        // 6. Récupérer le token FCM
        await _fetchAndPersistToken();

        // 7. Écouter le rafraîchissement du token (nouvelle API onRegistered & onTokenRefresh)
        FirebaseMessaging.instance.onRegistered.listen((fid) async {
          _logger.i('📡 [FCM] Firebase Registration ID reçu : $fid');
          if (_token == null || _token!.isEmpty) {
            _token = fid;
            final p = await SharedPreferences.getInstance();
            await p.setString('fcm_token', fid);
            _notifyTokenListeners(fid);
          }
        });

        // ignore: deprecated_member_use
        FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
          _token = newToken;
          _logger.i('🔄 [FCM] Token rafraîchi: $newToken');
          final p = await SharedPreferences.getInstance();
          await p.setString('fcm_token', newToken);
          _notifyTokenListeners(newToken);
        });

        // 8. Écoute des messages en premier plan (Foreground)
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          _logger.i('📨 [FCM] Message premier plan: ${message.messageId}');
          _handleForegroundNotification(message);

          for (final listener in _messageListeners) {
            try {
              listener(message);
            } catch (e) {
              _logger.e('Erreur listener onMessage: $e');
            }
          }
        });

        // 9. Écoute du clic sur une notification en arrière-plan
        FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
          _logger.i(
            '📬 [FCM] Notification cliquée (app ouverte): ${message.messageId}',
          );
          _handleNotificationClick(message);
        });

        // 10. Traiter un message initial ayant lancé l'application (cold start)
        final RemoteMessage? initialMessage = await FirebaseMessaging.instance
            .getInitialMessage();
        if (initialMessage != null) {
          _logger.i(
            '🚀 [FCM] App lancée depuis notification: ${initialMessage.messageId}',
          );
          _handleNotificationClick(initialMessage);
        }
      } else {
        _logger.w('⚠️ Permission notifications refusée par l\'utilisateur.');
      }
    } catch (e, stack) {
      _logger.e(
        '🔥 [FCM] Erreur initialisation FCM : $e',
        error: e,
        stackTrace: stack,
      );
    }
  }

  void _notifyTokenListeners(String token) {
    for (final listener in _tokenRefreshListeners) {
      try {
        listener(token);
      } catch (e) {
        _logger.e('Erreur listener token refresh: $e');
      }
    }
  }

  /// Récupère et sauvegarde le token FCM
  Future<String?> _fetchAndPersistToken() async {
    try {
      // ignore: deprecated_member_use
      _token = await FirebaseMessaging.instance.getToken();
      if (_token != null && _token!.isNotEmpty) {
        _logger.i('🎯 [FCM] Token obtenu: $_token');
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('fcm_token', _token!);
        return _token;
      } else {
        _logger.w('⚠️ [FCM] Aucun token FCM retourné.');
      }
    } catch (e) {
      _logger.w(
        '⚠️ [FCM] Impossible d\'obtenir le token FCM immédiatement '
        '(normal sur simulateur iOS ou sans certificat APNs actif) : $e',
      );
    }
    return null;
  }

  /// Affichage d'une notification visuelle en premier plan
  void _handleForegroundNotification(RemoteMessage message) {
    if (Get.isRegistered<NotificationController>()) {
      Get.find<NotificationController>().fetchNotifications(showLoading: false);
    }

    final notification = message.notification;
    if (notification != null) {
      Get.snackbar(
        notification.title ?? 'Nouvelle notification',
        notification.body ?? '',
        snackPosition: SnackPosition.TOP,
        backgroundColor: const Color(0xFF1F3A5F),
        colorText: Colors.white,
        borderRadius: 14,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        duration: const Duration(seconds: 5),
        boxShadows: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
        icon: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFF00C6FF).withValues(alpha: 0.18),
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFF00C6FF).withValues(alpha: 0.4),
              width: 1.2,
            ),
          ),
          child: const Icon(
            Icons.notifications_active_rounded,
            color: Color(0xFF00C6FF),
            size: 20,
          ),
        ),
        titleText: Text(
          notification.title ?? 'Notification',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 13.5,
          ),
        ),
        messageText: Text(
          notification.body ?? '',
          style: GoogleFonts.poppins(
            color: const Color(0xFFE2E8F0),
            fontWeight: FontWeight.w400,
            fontSize: 12,
            height: 1.35,
          ),
        ),
        onTap: (_) => _handleNotificationClick(message),
      );
    }
  }

  /// Traitement d'un clic sur notification
  void _handleNotificationClick(RemoteMessage message) {
    final data = message.data;
    _logger.i('👆 Données de notification cliquée: $data');
    ouvrirRouteNotification(data['route'] as String?);
  }

  /// Permet d'écouter les rafraîchissements de token (ex: pour l'envoyer au backend)
  void onTokenRefresh(void Function(String) callback) {
    _tokenRefreshListeners.add(callback);
  }

  /// Permet d'écouter les messages entrants
  void onMessage(void Function(RemoteMessage) callback) {
    _messageListeners.add(callback);
  }
}

/// Alias FcmService pour flexibilité de nommage
typedef FcmService = AppChannel;
