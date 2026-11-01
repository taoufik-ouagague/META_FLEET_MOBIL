class EmployeModel {
  final int? id;
  final String? nom;
  final String? prenom;
  final String? nomPrenom;
  final String? cin;
  final String? telephone;
  final String? adresse;
  final String? email;
  final String? matricule;
  final String? code;
  final String? organismeLibelle;
  final String? fonctionLibelle;
  final String? agenceLibelle;
  final String? status;

  EmployeModel({
    this.id,
    this.nom,
    this.prenom,
    this.nomPrenom,
    this.cin,
    this.telephone,
    this.adresse,
    this.email,
    this.matricule,
    this.code,
    this.organismeLibelle,
    this.fonctionLibelle,
    this.agenceLibelle,
    this.status,
  });

  factory EmployeModel.fromJson(Map<String, dynamic> json) {
    return EmployeModel(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? ''),
      nom: json['nom']?.toString(),
      prenom: json['prenom']?.toString(),
      nomPrenom:
          json['nomPrenom']?.toString() ??
          (json['prenom'] != null && json['nom'] != null
              ? '${json['prenom']} ${json['nom']}'.trim()
              : null),
      cin: json['cin']?.toString(),
      telephone: json['telephone']?.toString(),
      adresse: json['adresse']?.toString(),
      email: json['email']?.toString(),
      matricule: json['matricule']?.toString(),
      code: json['code']?.toString(),
      organismeLibelle: json['organismeLibelle']?.toString(),
      fonctionLibelle: json['fonctionLibelle']?.toString(),
      agenceLibelle: json['agenceLibelle']?.toString(),
      status: json['status']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nom': nom,
      'prenom': prenom,
      'nomPrenom': nomPrenom,
      'cin': cin,
      'telephone': telephone,
      'adresse': adresse,
      'email': email,
      'matricule': matricule,
      'code': code,
      'organismeLibelle': organismeLibelle,
      'fonctionLibelle': fonctionLibelle,
      'agenceLibelle': agenceLibelle,
      'status': status,
    };
  }

  String get displayName {
    if (nomPrenom != null && nomPrenom!.trim().isNotEmpty) {
      return nomPrenom!.trim();
    }
    if (prenom != null && nom != null) return '$prenom $nom'.trim();
    return nom ?? prenom ?? 'Employé';
  }
}
