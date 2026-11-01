class VehiculeModel {
  final int? id;
  final String? immatriculation;
  final String? immatriculationWw;
  final String? numChassis;
  final String? codeInterne;
  final String? marqueLibelle;
  final String? modeleLibelle;
  final String? typeVehiculeLibelle;
  final String? typeAcquisitionLibelle;
  final String? statutVehiculeLibelle;
  final String? status;
  final String? organismeLibelle;
  final String? typeCarburantLibelle;
  final int? marqueId;
  final int? modeleId;
  final int? categorieVehiculeId;
  final String? categorieVehiculeLibelle;
  final double? kmActuel;
  final int? annee;
  final String? couleur;
  final int? puissanceFiscale;
  final int? puissanceMoteur;
  final int? nombrePlaces;
  final String? dateMiseEnService;
  final bool? hayon;
  final bool? climatisation;
  final bool? cameraRecul;
  final bool? limiteurVitesse;
  final double? tauxConsommation;
  final int? kmAlertVidange;
  final double? kmGps;
  final double? kmGasoil;
  final double? kmVidange;
  final double? kmFeuilleRoute;
  final String? derniereSynchronisationGps;
  final String? derniereSynchronisationGasoil;
  final String? derniereSynchronisationFeuilleRoute;

  const VehiculeModel({
    this.id,
    this.immatriculation,
    this.immatriculationWw,
    this.numChassis,
    this.codeInterne,
    this.marqueLibelle,
    this.modeleLibelle,
    this.typeVehiculeLibelle,
    this.typeAcquisitionLibelle,
    this.statutVehiculeLibelle,
    this.status,
    this.organismeLibelle,
    this.typeCarburantLibelle,
    this.marqueId,
    this.modeleId,
    this.categorieVehiculeId,
    this.categorieVehiculeLibelle,
    this.kmActuel,
    this.annee,
    this.couleur,
    this.puissanceFiscale,
    this.puissanceMoteur,
    this.nombrePlaces,
    this.dateMiseEnService,
    this.hayon,
    this.climatisation,
    this.cameraRecul,
    this.limiteurVitesse,
    this.tauxConsommation,
    this.kmAlertVidange,
    this.kmGps,
    this.kmGasoil,
    this.kmVidange,
    this.kmFeuilleRoute,
    this.derniereSynchronisationGps,
    this.derniereSynchronisationGasoil,
    this.derniereSynchronisationFeuilleRoute,
  });

  String get categorieDisplay {
    if (categorieVehiculeLibelle != null &&
        categorieVehiculeLibelle!.trim().isNotEmpty) {
      return categorieVehiculeLibelle!.trim();
    }
    if (categorieVehiculeId == 1) return 'Véhicule à moteur';
    if (categorieVehiculeId == 2) return 'Remorque';
    if (categorieVehiculeId == 3) return 'Semi-remorque';
    if (categorieVehiculeId == 4) return 'Engin';
    if (typeVehiculeLibelle != null && typeVehiculeLibelle!.trim().isNotEmpty) {
      return typeVehiculeLibelle!.trim();
    }
    return 'Véhicule à moteur';
  }

  String get displayName {
    final marque = marqueLibelle?.trim() ?? '';
    final modele = modeleLibelle?.trim() ?? '';
    final name = '$marque $modele'.trim();
    if (name.isNotEmpty) return name;
    if (immatriculation?.isNotEmpty == true) return immatriculation!;
    return 'Véhicule #${id ?? 0}';
  }

  static String formatKm(double? km) {
    if (km == null) return '- km';
    final parts = <String>[];
    String str = km.toInt().toString();
    while (str.length > 3) {
      parts.insert(0, str.substring(str.length - 3));
      str = str.substring(0, str.length - 3);
    }
    parts.insert(0, str);
    return '${parts.join(' ')} km';
  }

  String get formattedKm => formatKm(kmActuel);

  /// Le backend renvoie un libellé ("Actif", "Inactif", "Vendu"...) via
  /// GlobalConstants.getStatusLibelle. Absent de certains endpoints : on
  /// considère alors le véhicule actif.
  String get statusLabel {
    final s = status?.trim() ?? '';
    return s.isEmpty ? 'Actif' : s;
  }

  bool get isActif => statusLabel.toUpperCase() == 'ACTIF';

  factory VehiculeModel.fromJson(Map<String, dynamic> json) {
    double? parseDouble(dynamic val) {
      if (val == null) return null;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString());
    }

    int? parseInt(dynamic val) {
      if (val == null) return null;
      if (val is int) return val;
      if (val is num) return val.toInt();
      return int.tryParse(val.toString());
    }

    bool? parseBool(dynamic val) {
      if (val == null) return null;
      if (val is bool) return val;
      if (val is num) return val == 1;
      final s = val.toString().toLowerCase();
      return s == 'true' || s == '1' || s == 'oui';
    }

    return VehiculeModel(
      id: parseInt(json['id']),
      immatriculation: json['immatriculation']?.toString(),
      immatriculationWw: json['immatriculationWw']?.toString(),
      numChassis: json['numChassis']?.toString(),
      codeInterne: json['codeInterne']?.toString(),
      marqueLibelle: json['marqueLibelle']?.toString(),
      modeleLibelle: json['modeleLibelle']?.toString(),
      typeVehiculeLibelle: json['typeVehiculeLibelle']?.toString(),
      typeAcquisitionLibelle: json['typeAcquisitionLibelle']?.toString(),
      statutVehiculeLibelle: json['statutVehiculeLibelle']?.toString(),
      status: json['status']?.toString(),
      organismeLibelle: json['organismeLibelle']?.toString(),
      typeCarburantLibelle: json['typeCarburantLibelle']?.toString(),
      marqueId: parseInt(json['marqueId'] ?? json['idMarque']),
      modeleId: parseInt(json['modeleId'] ?? json['idModele']),
      categorieVehiculeId: parseInt(
        json['categoriesVehiculesPrcId'] ??
            json['categorieVehiculeId'] ??
            json['idCategorie'],
      ),
      categorieVehiculeLibelle:
          json['categoriesVehiculesPrcLibelle']?.toString() ??
          json['categorieVehiculeLibelle']?.toString() ??
          json['categorieLibelle']?.toString(),
      kmActuel: parseDouble(json['kmActuel'] ?? json['kmGps']),
      annee: parseInt(json['annee']),
      couleur: json['couleur']?.toString(),
      puissanceFiscale: parseInt(json['puissanceFiscale']),
      puissanceMoteur: parseInt(json['puissanceMoteur']),
      nombrePlaces: parseInt(json['nombrePlaces']),
      dateMiseEnService: json['dateMiseEnService']?.toString(),
      hayon: parseBool(json['hayon']),
      climatisation: parseBool(json['climatisation']),
      cameraRecul: parseBool(json['cameraRecul']),
      limiteurVitesse: parseBool(json['limiteurVitesse']),
      tauxConsommation: parseDouble(json['tauxConsommation']),
      kmAlertVidange: parseInt(json['kmAlertVidange']),
      kmGps: parseDouble(json['kmGps']),
      kmGasoil: parseDouble(json['kmGasoil']),
      kmVidange: parseDouble(json['kmVidange']),
      kmFeuilleRoute: parseDouble(json['kmFeuilleRoute']),
      derniereSynchronisationGps: json['derniereSynchronisationGps']
          ?.toString(),
      derniereSynchronisationGasoil: json['derniereSynchronisationGasoil']
          ?.toString(),
      derniereSynchronisationFeuilleRoute:
          json['derniereSynchronisationFeuilleRoute']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'immatriculation': immatriculation,
      'immatriculationWw': immatriculationWw,
      'numChassis': numChassis,
      'codeInterne': codeInterne,
      'marqueLibelle': marqueLibelle,
      'modeleLibelle': modeleLibelle,
      'typeVehiculeLibelle': typeVehiculeLibelle,
      'typeAcquisitionLibelle': typeAcquisitionLibelle,
      'statutVehiculeLibelle': statutVehiculeLibelle,
      'status': status,
      'organismeLibelle': organismeLibelle,
      'typeCarburantLibelle': typeCarburantLibelle,
      'marqueId': marqueId,
      'modeleId': modeleId,
      'categorieVehiculeId': categorieVehiculeId,
      'categorieVehiculeLibelle': categorieVehiculeLibelle,
      'kmActuel': kmActuel,
      'annee': annee,
      'couleur': couleur,
      'puissanceFiscale': puissanceFiscale,
      'puissanceMoteur': puissanceMoteur,
      'nombrePlaces': nombrePlaces,
      'dateMiseEnService': dateMiseEnService,
      'hayon': hayon,
      'climatisation': climatisation,
      'cameraRecul': cameraRecul,
      'limiteurVitesse': limiteurVitesse,
      'tauxConsommation': tauxConsommation,
      'kmAlertVidange': kmAlertVidange,
    };
  }
}
