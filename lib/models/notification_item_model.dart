class NotificationItemModel {
  final int id;
  final String titre;
  final String corps;
  final String? type;
  final int? entityId;
  final String? route;
  final bool isRead;
  final DateTime? dateCreation;

  NotificationItemModel({
    required this.id,
    required this.titre,
    required this.corps,
    this.type,
    this.entityId,
    this.route,
    this.isRead = false,
    this.dateCreation,
  });

  factory NotificationItemModel.fromJson(Map<String, dynamic> json) {
    DateTime? date;
    if (json['dateCreation'] != null) {
      if (json['dateCreation'] is String) {
        date = DateTime.tryParse(json['dateCreation']);
      } else if (json['dateCreation'] is List) {
        final list = json['dateCreation'] as List;
        if (list.length >= 3) {
          date = DateTime(
            list[0] as int,
            list[1] as int,
            list[2] as int,
            list.length > 3 ? list[3] as int : 0,
            list.length > 4 ? list[4] as int : 0,
            list.length > 5 ? list[5] as int : 0,
          );
        }
      }
    }

    return NotificationItemModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      titre: (json['titre'] ?? json['title'] ?? '').toString(),
      corps: (json['corps'] ?? json['body'] ?? '').toString(),
      type: json['type']?.toString(),
      entityId: (json['entityId'] as num?)?.toInt(),
      route: json['route']?.toString(),
      isRead: json['isRead'] == true,
      dateCreation: date,
    );
  }

  NotificationItemModel copyWith({bool? isRead}) {
    return NotificationItemModel(
      id: id,
      titre: titre,
      corps: corps,
      type: type,
      entityId: entityId,
      route: route,
      isRead: isRead ?? this.isRead,
      dateCreation: dateCreation,
    );
  }
}
