import 'dart:convert';

/// Modelo de publicación del marketplace
class MarketplaceItem {
  final int? id;
  final String title;
  final int score;
  final String badge; // Elite, Premium, Verificado, Vendedor
  final double price;
  final double? referencePrice;
  final bool negotiable;
  final String? weight; // "485 kg"
  final String? production; // "12.5 L/dia"
  final String location;
  final String responseTime; // "< 1 hora"
  final bool certified;
  final String? priceRange; // "$1,700 - $2,200"
  final String category; // Ganado, Leche, Queso, Insumos
  final bool promoted;
  final String? offerTag; // "Oferta", "Destacado"
  final List<String> imagePaths;
  final String description;
  final String? areteSisa;
  final String? cvmState; // pending, verified, none
  final bool sisaVerified;
  final bool vacunasAlDia;
  final bool historialCompleto;
  final bool fotosCalidad;
  final String? sourceAnimalId;
  final String? sellerUserId;

  const MarketplaceItem({
    this.id,
    required this.title,
    required this.score,
    required this.badge,
    required this.price,
    this.referencePrice,
    this.negotiable = false,
    this.weight,
    this.production,
    required this.location,
    required this.responseTime,
    this.certified = true,
    this.priceRange,
    required this.category,
    this.promoted = false,
    this.offerTag,
    this.imagePaths = const [],
    this.description = '',
    this.areteSisa,
    this.cvmState = 'none',
    this.sisaVerified = false,
    this.vacunasAlDia = false,
    this.historialCompleto = false,
    this.fotosCalidad = false,
    this.sourceAnimalId,
    this.sellerUserId,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'score': score,
      'badge': badge,
      'price': price,
      'reference_price': referencePrice,
      'negotiable': negotiable ? 1 : 0,
      'weight': weight,
      'production': production,
      'location': location,
      'response_time': responseTime,
      'certified': certified ? 1 : 0,
      'price_range': priceRange,
      'category': category,
      'promoted': promoted ? 1 : 0,
      'offer_tag': offerTag,
      'image_paths': jsonEncode(imagePaths),
      'description': description,
      'arete_sisa': areteSisa,
      'cvm_state': cvmState,
      'sisa_verified': sisaVerified ? 1 : 0,
      'vacunas_al_dia': vacunasAlDia ? 1 : 0,
      'historial_completo': historialCompleto ? 1 : 0,
      'fotos_calidad': fotosCalidad ? 1 : 0,
      'source_animal_id': sourceAnimalId,
      'seller_user_id': sellerUserId,
    };
  }

  factory MarketplaceItem.fromMap(Map<String, dynamic> map) {
    List<String> imgs = [];
    if (map['image_paths'] != null) {
      try {
        final decoded = jsonDecode(map['image_paths']);
        if (decoded is List) {
          imgs = decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {}
    }
    return MarketplaceItem(
      id: map['id'] as int?,
      title: map['title'] as String,
      score: map['score'] as int,
      badge: map['badge'] as String,
      price: (map['price'] as num).toDouble(),
      referencePrice: map['reference_price'] != null
          ? (map['reference_price'] as num).toDouble()
          : null,
      negotiable: map['negotiable'] == 1 || map['negotiable'] == true,
      weight: map['weight'] as String?,
      production: map['production'] as String?,
      location: map['location'] as String,
      responseTime: map['response_time'] as String,
      certified: map['certified'] == 1 || map['certified'] == true,
      priceRange: map['price_range'] as String?,
      category: map['category'] as String,
      promoted: map['promoted'] == 1 || map['promoted'] == true,
      offerTag: map['offer_tag'] as String?,
      imagePaths: imgs,
      description: map['description'] as String,
      areteSisa: map['arete_sisa'] as String?,
      cvmState: map['cvm_state'] as String?,
      sisaVerified: map['sisa_verified'] == 1 || map['sisa_verified'] == true,
      vacunasAlDia: map['vacunas_al_dia'] == 1 || map['vacunas_al_dia'] == true,
      historialCompleto:
          map['historial_completo'] == 1 || map['historial_completo'] == true,
      fotosCalidad: map['fotos_calidad'] == 1 || map['fotos_calidad'] == true,
      sourceAnimalId: map['source_animal_id'] as String?,
      sellerUserId: map['seller_user_id'] as String?,
    );
  }
}
