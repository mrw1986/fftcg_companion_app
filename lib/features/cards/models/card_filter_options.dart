enum CardSortOption {
  nameAsc,
  nameDesc,
  costAsc,
  costDesc,
  powerAsc,
  powerDesc,
  setNumber,
  releaseDate
}

class CardFilterOptions {
  final List<String>? elements;
  final String? cardType;
  final List<String>? costs;
  final List<String>? rarities;
  final String? job;
  final String? category;
  final List<String>? opus;
  final String? powerRange; // e.g., "1000-5000"
  final CardSortOption sortOption;
  final bool ascending;

  const CardFilterOptions({
    this.elements,
    this.cardType,
    this.costs,
    this.rarities,
    this.job,
    this.category,
    this.opus,
    this.powerRange,
    this.sortOption = CardSortOption.setNumber,
    this.ascending = true,
  });

  CardFilterOptions copyWith({
    List<String>? elements,
    String? cardType,
    List<String>? costs,
    List<String>? rarities,
    String? job,
    String? category,
    List<String>? opus,
    String? powerRange,
    CardSortOption? sortOption,
    bool? ascending,
  }) {
    return CardFilterOptions(
      elements: elements ?? this.elements,
      cardType: cardType ?? this.cardType,
      costs: costs ?? this.costs,
      rarities: rarities ?? this.rarities,
      job: job ?? this.job,
      category: category ?? this.category,
      opus: opus ?? this.opus,
      powerRange: powerRange ?? this.powerRange,
      sortOption: sortOption ?? this.sortOption,
      ascending: ascending ?? this.ascending,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'elements': elements,
      'cardType': cardType,
      'costs': costs,
      'rarities': rarities,
      'job': job,
      'category': category,
      'opus': opus,
      'powerRange': powerRange,
      'sortOption': sortOption.index,
      'ascending': ascending,
    };
  }

  factory CardFilterOptions.fromJson(Map<String, dynamic> json) {
    return CardFilterOptions(
      elements: (json['elements'] as List?)?.cast<String>(),
      cardType: json['cardType'] as String?,
      costs: (json['costs'] as List?)?.cast<String>(),
      rarities: (json['rarities'] as List?)?.cast<String>(),
      job: json['job'] as String?,
      category: json['category'] as String?,
      opus: (json['opus'] as List?)?.cast<String>(),
      powerRange: json['powerRange'] as String?,
      sortOption: CardSortOption.values[json['sortOption'] as int],
      ascending: json['ascending'] as bool,
    );
  }

  @override
  String toString() {
    return 'CardFilterOptions(elements: $elements, cardType: $cardType, costs: $costs, rarities: $rarities, job: $job, category: $category, opus: $opus, powerRange: $powerRange, sortOption: $sortOption, ascending: $ascending)';
  }
}
