import 'package:hive/hive.dart';

part 'card_extended_data.g.dart';

@HiveType(typeId: 2)
class CardExtendedData {
  @HiveField(0)
  final String displayName;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String value;

  const CardExtendedData({
    required this.displayName,
    required this.name,
    required this.value,
  });

  factory CardExtendedData.fromMap(Map<String, dynamic> map) {
    return CardExtendedData(
      displayName: map['displayName'] as String,
      name: map['name'] as String,
      value: map['value'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'displayName': displayName,
      'name': name,
      'value': value,
    };
  }

  CardExtendedData copyWith({
    String? displayName,
    String? name,
    String? value,
  }) {
    return CardExtendedData(
      displayName: displayName ?? this.displayName,
      name: name ?? this.name,
      value: value ?? this.value,
    );
  }

  @override
  String toString() {
    return 'CardExtendedData(displayName: $displayName, name: $name, value: $value)';
  }
}
