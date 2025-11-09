// Файли нав: lib/models/transport_model.dart

class TransportCategory {
  final int id;
  final String name;

  TransportCategory({required this.id, required this.name});

  factory TransportCategory.fromJson(Map<String, dynamic> json) {
    return TransportCategory(
      id: json['id'],
      name: json['name'],
    );
  }

  // Ин ду функсия барои дуруст кор кардани DropdownButton муҳиманд
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TransportCategory &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
