// StyleMe - Modelo de datos para Usuario
class UserModel {
  final String id;
  final String nombre;
  final String email;
  final String genero;
  final int totalPrendas;
  final int totalOutfitsGenerados;
  final String creadoEn;
  final String? fotoPerfilUrl;

  UserModel({
    required this.id,
    required this.nombre,
    required this.email,
    required this.genero,
    this.totalPrendas = 0,
    this.totalOutfitsGenerados = 0,
    required this.creadoEn,
    this.fotoPerfilUrl,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id']?.toString() ?? '',
      nombre: json['nombre'] ?? '',
      email: json['email'] ?? '',
      genero: json['genero'] ?? 'otro',
      totalPrendas: json['total_prendas'] ?? 0,
      totalOutfitsGenerados: json['total_outfits_generados'] ?? 0,
      creadoEn: json['creado_en'] ?? '',
      fotoPerfilUrl: json['foto_perfil_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        'email': email,
        'genero': genero,
        'total_prendas': totalPrendas,
        'total_outfits_generados': totalOutfitsGenerados,
        'creado_en': creadoEn,
      };

  // Obtiene la inicial del nombre para el avatar
  String get inicial => nombre.isNotEmpty ? nombre[0].toUpperCase() : 'S';

  // URL completa de la foto de perfil (con baseUrl)
  String? fotoPerfilUrlCompleta(String baseUrl) =>
      fotoPerfilUrl != null ? '$baseUrl$fotoPerfilUrl' : null;

  // Retorna una copia con foto_perfil_url actualizada
  UserModel copyWith({String? fotoPerfilUrl}) => UserModel(
        id: id,
        nombre: nombre,
        email: email,
        genero: genero,
        totalPrendas: totalPrendas,
        totalOutfitsGenerados: totalOutfitsGenerados,
        creadoEn: creadoEn,
        fotoPerfilUrl: fotoPerfilUrl ?? this.fotoPerfilUrl,
      );
}
