// lib/models/place_ref.dart

class PlaceRef {
  final String id;
  final String name;
  final String? address;
  final double? lat;
  final double? lng;
  final String? googlePlaceId;

  const PlaceRef({
    required this.id,
    required this.name,
    this.address,
    this.lat,
    this.lng,
    this.googlePlaceId,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        if (address != null) 'address': address,
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
        if (googlePlaceId != null) 'place_id': googlePlaceId,
      };

  factory PlaceRef.fromMap(Map<String, dynamic> m) => PlaceRef(
        id: m['id']?.toString() ?? '',
        name: m['name']?.toString() ?? '',
        address: m['address']?.toString(),
        lat: m['lat'] != null ? double.tryParse(m['lat'].toString()) : null,
        lng: m['lng'] != null ? double.tryParse(m['lng'].toString()) : null,
        googlePlaceId: m['place_id']?.toString(),
      );
}
