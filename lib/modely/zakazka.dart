class Zakazka {
  final String nazov;
  final String stav;
  final String datum;
  final String poznamka;
  final String termin;
  final bool hviezdicka;
  final bool dolezita;

  Zakazka({
    required this.nazov,
    required this.stav,
    required this.datum,
    required this.poznamka,
    required this.termin,
    required this.hviezdicka,
    required this.dolezita,
  });

  factory Zakazka.fromJson(Map<String, dynamic> json) => Zakazka(
    nazov: json['nazov'],
    stav: json['stav'],
    datum: json['datum'],
    poznamka: json['poznamka'],
    termin: json['termin'],
    hviezdicka: json['hviezdicka'] ?? false,
    dolezita: json['dolezita'] ?? false,
  );

  Map<String, dynamic> toJson() => {
    'nazov': nazov,
    'stav': stav,
    'datum': datum,
    'poznamka': poznamka,
    'termin': termin,
    'hviezdicka': hviezdicka,
    'dolezita': dolezita,
  };
}
