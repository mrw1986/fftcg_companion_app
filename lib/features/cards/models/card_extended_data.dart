class CardExtendedData {
  final String displayName;
  final String name;
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
}
