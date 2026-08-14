enum BslAdministrativeEntity { federation, republikaSrpska, brcko }

class BslAdministrativeArea {
  final String displayName;
  final String geocodingName;
  final BslAdministrativeEntity entity;
  final List<String> aliases;

  const BslAdministrativeArea({
    required this.displayName,
    required this.geocodingName,
    required this.entity,
    this.aliases = const [],
  });
}

abstract final class BslAdministrativeAreas {
  static const List<BslAdministrativeArea> values = [
    BslAdministrativeArea(displayName: 'Bihać', geocodingName: 'Bihać', entity: BslAdministrativeEntity.federation),
    BslAdministrativeArea(displayName: 'Bosanska Krupa', geocodingName: 'Bosanska Krupa', entity: BslAdministrativeEntity.federation),
    BslAdministrativeArea(displayName: 'Bosanski Petrovac', geocodingName: 'Bosanski Petrovac', entity: BslAdministrativeEntity.federation),
    BslAdministrativeArea(displayName: 'Bužim', geocodingName: 'Bužim', entity: BslAdministrativeEntity.federation),
    BslAdministrativeArea(displayName: 'Cazin', geocodingName: 'Cazin', entity: BslAdministrativeEntity.federation),
    BslAdministrativeArea(displayName: 'Ključ', geocodingName: 'Ključ', entity: BslAdministrativeEntity.federation),
    BslAdministrativeArea(displayName: 'Sanski Most', geocodingName: 'Sanski Most', entity: BslAdministrativeEntity.federation),
    BslAdministrativeArea(displayName: 'Velika Kladuša', geocodingName: 'Velika Kladuša', entity: BslAdministrativeEntity.federation),
    BslAdministrativeArea(displayName: 'Domaljevac-Šamac', geocodingName: 'Domaljevac', entity: BslAdministrativeEntity.federation),
    BslAdministrativeArea(displayName: 'Odžak', geocodingName: 'Odžak', entity: BslAdministrativeEntity.federation),
    BslAdministrativeArea(displayName: 'Orašje', geocodingName: 'Orašje', entity: BslAdministrativeEntity.federation),
    BslAdministrativeArea(displayName: 'Banovići', geocodingName: 'Banovići', entity: BslAdministrativeEntity.federation),
    BslAdministrativeArea(displayName: 'Čelić', geocodingName: 'Čelić', entity: BslAdministrativeEntity.federation),
    BslAdministrativeArea(displayName: 'Doboj Istok', geocodingName: 'Doboj Istok', entity: BslAdministrativeEntity.federation),
    BslAdministrativeArea(displayName: 'Gračanica', geocodingName: 'Gračanica', entity: BslAdministrativeEntity.federation),
    BslAdministrativeArea(displayName: 'Gradačac', geocodingName: 'Gradačac', entity: BslAdministrativeEntity.federation),
    BslAdministrativeArea(displayName: 'Kalesija', geocodingName: 'Kalesija', entity: BslAdministrativeEntity.federation),
    BslAdministrativeArea(displayName: 'Kladanj', geocodingName: 'Kladanj', entity: BslAdministrativeEntity.federation),
    BslAdministrativeArea(displayName: 'Lukavac', geocodingName: 'Lukavac', entity: BslAdministrativeEntity.federation),
    BslAdministrativeArea(displayName: 'Sapna', geocodingName: 'Sapna', entity: BslAdministrativeEntity.federation),
    BslAdministrativeArea(displayName: 'Srebrenik', geocodingName: 'Srebrenik', entity: BslAdministrativeEntity.federation),
    BslAdministrativeArea(displayName: 'Teočak', geocodingName: 'Teočak', entity: BslAdministrativeEntity.federation),
    BslAdministrativeArea(displayName: 'Tuzla', geocodingName: 'Tuzla', entity: BslAdministrativeEntity.federation),
    BslAdministrativeArea(displayName: 'Živinice', geocodingName: 'Živinice', entity: BslAdministrativeEntity.federation),
    BslAdministrativeArea(displayName: 'Breza', geocodingName: 'Breza', entity: BslAdministrativeEntity.federation),
    BslAdministrativeArea(displayName: 'Doboj Jug', geocodingName: 'Doboj Jug', entity: BslAdministrativeEntity.federation),
    BslAdministrativeArea(displayName: 'Kakanj', geocodingName: 'Kakanj', entity: BslAdministrativeEntity.federation),
    BslAdministrativeArea(displayName: 'Maglaj', geocodingName: 'Maglaj', entity: BslAdministrativeEntity.federation),
    BslAdministrativeArea(displayName: 'Olovo', geocodingName: 'Olovo', entity: BslAdministrativeEntity.federation),
    BslAdministrativeArea(displayName: 'Tešanj', geocodingName: 'Tešanj', entity: BslAdministrativeEntity.federation),
    BslAdministrativeArea(displayName: 'Usora', geocodingName: 'Usora', entity: BslAdministrativeEntity.federation),
    BslAdministrativeArea(displayName: 'Vareš', geocodingName: 'Vareš', entity: BslAdministrativeEntity.federation),
    BslAdministrativeArea(displayName: 'Visoko', geocodingName: 'Visoko', entity: BslAdministrativeEntity.federation),
    BslAdministrativeArea(displayName: 'Zavidovići', geocodingName: 'Zavidovići', entity: BslAdministrativeEntity.federation),
    BslAdministrativeArea(displayName: 'Zenica', geocodingName: 'Zenica', entity: BslAdministrativeEntity.federation),
    BslAdministrativeArea(displayName: 'Žepče', geocodingName: 'Žepče', entity: BslAdministrativeEntity.federation),
    BslAdministrativeArea(displayName: 'Foča-Ustikolina', geocodingName: 'Ustikolina', entity: BslAdministrativeEntity.federation, aliases: ['Foča (FBiH)', 'Foča Ustikolina']),
    BslAdministrativeArea(displayName: 'Goražde', geocodingName: 'Goražde', entity: BslAdministrativeEntity.federation),
    BslAdministrativeArea(displayName: 'Pale-Prača', geocodingName: 'Prača', entity: BslAdministrativeEntity.federation, aliases: ['Pale (FBiH)', 'Pale Prača']),
    BslAdministrativeArea(displayName: 'Bugojno', geocodingName: 'Bugojno', entity: BslAdministrativeEntity.federation),
    BslAdministrativeArea(displayName: 'Busovača', geocodingName: 'Busovača', entity: BslAdministrativeEntity.federation),
    BslAdministrativeArea(displayName: 'Dobretići', geocodingName: 'Dobretići', entity: BslAdministrativeEntity.federation),
    BslAdministrativeArea(displayName: 'Donji Vakuf', geocodingName: 'Donji Vakuf', entity: BslAdministrativeEntity.federation),
    BslAdministrativeArea(displayName: 'Fojnica', geocodingName: 'Fojnica', entity: BslAdministrativeEntity.federation),
    BslAdministrativeArea(displayName: 'Gornji Vakuf-Uskoplje', geocodingName: 'Gornji Vakuf-Uskoplje', entity: BslAdministrativeEntity.federation),
    BslAdministrativeArea(displayName: 'Jajce', geocodingName: 'Jajce', entity: BslAdministrativeEntity.federation),
    BslAdministrativeArea(displayName: 'Kiseljak', geocodingName: 'Kiseljak', entity: BslAdministrativeEntity.federation),
    BslAdministrativeArea(displayName: 'Kreševo', geocodingName: 'Kreševo', entity: BslAdministrativeEntity.federation),
    BslAdministrativeArea(displayName: 'Novi Travnik', geocodingName: 'Novi Travnik', entity: BslAdministrativeEntity.federation),
    BslAdministrativeArea(displayName: 'Travnik', geocodingName: 'Travnik', entity: BslAdministrativeEntity.federation),
    BslAdministrativeArea(displayName: 'Vitez', geocodingName: 'Vitez', entity: BslAdministrativeEntity.federation),
    BslAdministrativeArea(displayName: 'Čapljina', geocodingName: 'Čapljina', entity: BslAdministrativeEntity.federation),
    BslAdministrativeArea(displayName: 'Čitluk', geocodingName: 'Čitluk', entity: BslAdministrativeEntity.federation),
    BslAdministrativeArea(displayName: 'Jablanica', geocodingName: 'Jablanica', entity: BslAdministrativeEntity.federation),
    BslAdministrativeArea(displayName: 'Konjic', geocodingName: 'Konjic', entity: BslAdministrativeEntity.federation),
    BslAdministrativeArea(displayName: 'Mostar', geocodingName: 'Mostar', entity: BslAdministrativeEntity.federation),
    BslAdministrativeArea(displayName: 'Neum', geocodingName: 'Neum', entity: BslAdministrativeEntity.federation),
    BslAdministrativeArea(displayName: 'Prozor-Rama', geocodingName: 'Prozor', entity: BslAdministrativeEntity.federation),
    BslAdministrativeArea(displayName: 'Ravno', geocodingName: 'Ravno', entity: BslAdministrativeEntity.federation),
    BslAdministrativeArea(displayName: 'Stolac', geocodingName: 'Stolac', entity: BslAdministrativeEntity.federation),
    BslAdministrativeArea(displayName: 'Grude', geocodingName: 'Grude', entity: BslAdministrativeEntity.federation),
    BslAdministrativeArea(displayName: 'Ljubuški', geocodingName: 'Ljubuški', entity: BslAdministrativeEntity.federation),
    BslAdministrativeArea(displayName: 'Posušje', geocodingName: 'Posušje', entity: BslAdministrativeEntity.federation),
    BslAdministrativeArea(displayName: 'Široki Brijeg', geocodingName: 'Široki Brijeg', entity: BslAdministrativeEntity.federation),
    BslAdministrativeArea(displayName: 'Centar Sarajevo', geocodingName: 'Centar Sarajevo', entity: BslAdministrativeEntity.federation),
    BslAdministrativeArea(displayName: 'Hadžići', geocodingName: 'Hadžići', entity: BslAdministrativeEntity.federation),
    BslAdministrativeArea(displayName: 'Ilidža', geocodingName: 'Ilidža', entity: BslAdministrativeEntity.federation),
    BslAdministrativeArea(displayName: 'Ilijaš', geocodingName: 'Ilijaš', entity: BslAdministrativeEntity.federation),
    BslAdministrativeArea(displayName: 'Novi Grad Sarajevo', geocodingName: 'Novi Grad Sarajevo', entity: BslAdministrativeEntity.federation),
    BslAdministrativeArea(displayName: 'Novo Sarajevo', geocodingName: 'Novo Sarajevo', entity: BslAdministrativeEntity.federation),
    BslAdministrativeArea(displayName: 'Stari Grad Sarajevo', geocodingName: 'Stari Grad Sarajevo', entity: BslAdministrativeEntity.federation),
    BslAdministrativeArea(displayName: 'Trnovo (FBiH)', geocodingName: 'Trnovo', entity: BslAdministrativeEntity.federation, aliases: ['Trnovo FBiH']),
    BslAdministrativeArea(displayName: 'Vogošća', geocodingName: 'Vogošća', entity: BslAdministrativeEntity.federation),
    BslAdministrativeArea(displayName: 'Sarajevo', geocodingName: 'Sarajevo', entity: BslAdministrativeEntity.federation),
    BslAdministrativeArea(displayName: 'Bosansko Grahovo', geocodingName: 'Bosansko Grahovo', entity: BslAdministrativeEntity.federation),
    BslAdministrativeArea(displayName: 'Drvar', geocodingName: 'Drvar', entity: BslAdministrativeEntity.federation),
    BslAdministrativeArea(displayName: 'Glamoč', geocodingName: 'Glamoč', entity: BslAdministrativeEntity.federation),
    BslAdministrativeArea(displayName: 'Kupres (FBiH)', geocodingName: 'Kupres', entity: BslAdministrativeEntity.federation, aliases: ['Kupres FBiH']),
    BslAdministrativeArea(displayName: 'Livno', geocodingName: 'Livno', entity: BslAdministrativeEntity.federation),
    BslAdministrativeArea(displayName: 'Tomislavgrad', geocodingName: 'Tomislavgrad', entity: BslAdministrativeEntity.federation),
    BslAdministrativeArea(displayName: 'Banja Luka', geocodingName: 'Banja Luka', entity: BslAdministrativeEntity.republikaSrpska),
    BslAdministrativeArea(displayName: 'Bijeljina', geocodingName: 'Bijeljina', entity: BslAdministrativeEntity.republikaSrpska),
    BslAdministrativeArea(displayName: 'Gradiška', geocodingName: 'Gradiška', entity: BslAdministrativeEntity.republikaSrpska),
    BslAdministrativeArea(displayName: 'Derventa', geocodingName: 'Derventa', entity: BslAdministrativeEntity.republikaSrpska),
    BslAdministrativeArea(displayName: 'Doboj', geocodingName: 'Doboj', entity: BslAdministrativeEntity.republikaSrpska),
    BslAdministrativeArea(displayName: 'Zvornik', geocodingName: 'Zvornik', entity: BslAdministrativeEntity.republikaSrpska),
    BslAdministrativeArea(displayName: 'Istočno Sarajevo', geocodingName: 'Istočno Sarajevo', entity: BslAdministrativeEntity.republikaSrpska),
    BslAdministrativeArea(displayName: 'Laktaši', geocodingName: 'Laktaši', entity: BslAdministrativeEntity.republikaSrpska),
    BslAdministrativeArea(displayName: 'Prijedor', geocodingName: 'Prijedor', entity: BslAdministrativeEntity.republikaSrpska),
    BslAdministrativeArea(displayName: 'Prnjavor', geocodingName: 'Prnjavor', entity: BslAdministrativeEntity.republikaSrpska),
    BslAdministrativeArea(displayName: 'Trebinje', geocodingName: 'Trebinje', entity: BslAdministrativeEntity.republikaSrpska),
    BslAdministrativeArea(displayName: 'Berkovići', geocodingName: 'Berkovići', entity: BslAdministrativeEntity.republikaSrpska),
    BslAdministrativeArea(displayName: 'Bileća', geocodingName: 'Bileća', entity: BslAdministrativeEntity.republikaSrpska),
    BslAdministrativeArea(displayName: 'Bratunac', geocodingName: 'Bratunac', entity: BslAdministrativeEntity.republikaSrpska),
    BslAdministrativeArea(displayName: 'Brod', geocodingName: 'Brod', entity: BslAdministrativeEntity.republikaSrpska),
    BslAdministrativeArea(displayName: 'Čajniče', geocodingName: 'Čajniče', entity: BslAdministrativeEntity.republikaSrpska),
    BslAdministrativeArea(displayName: 'Čelinac', geocodingName: 'Čelinac', entity: BslAdministrativeEntity.republikaSrpska),
    BslAdministrativeArea(displayName: 'Donji Žabar', geocodingName: 'Donji Žabar', entity: BslAdministrativeEntity.republikaSrpska),
    BslAdministrativeArea(displayName: 'Foča', geocodingName: 'Foča', entity: BslAdministrativeEntity.republikaSrpska, aliases: ['Foča (RS)']),
    BslAdministrativeArea(displayName: 'Gacko', geocodingName: 'Gacko', entity: BslAdministrativeEntity.republikaSrpska),
    BslAdministrativeArea(displayName: 'Han Pijesak', geocodingName: 'Han Pijesak', entity: BslAdministrativeEntity.republikaSrpska),
    BslAdministrativeArea(displayName: 'Istočna Ilidža', geocodingName: 'Istočna Ilidža', entity: BslAdministrativeEntity.republikaSrpska),
    BslAdministrativeArea(displayName: 'Istočni Drvar', geocodingName: 'Istočni Drvar', entity: BslAdministrativeEntity.republikaSrpska),
    BslAdministrativeArea(displayName: 'Istočni Mostar', geocodingName: 'Istočni Mostar', entity: BslAdministrativeEntity.republikaSrpska),
    BslAdministrativeArea(displayName: 'Istočni Stari Grad', geocodingName: 'Istočni Stari Grad', entity: BslAdministrativeEntity.republikaSrpska),
    BslAdministrativeArea(displayName: 'Istočno Novo Sarajevo', geocodingName: 'Istočno Novo Sarajevo', entity: BslAdministrativeEntity.republikaSrpska),
    BslAdministrativeArea(displayName: 'Jezero', geocodingName: 'Jezero', entity: BslAdministrativeEntity.republikaSrpska),
    BslAdministrativeArea(displayName: 'Kalinovik', geocodingName: 'Kalinovik', entity: BslAdministrativeEntity.republikaSrpska),
    BslAdministrativeArea(displayName: 'Kneževo', geocodingName: 'Kneževo', entity: BslAdministrativeEntity.republikaSrpska),
    BslAdministrativeArea(displayName: 'Kostajnica', geocodingName: 'Kostajnica', entity: BslAdministrativeEntity.republikaSrpska),
    BslAdministrativeArea(displayName: 'Kotor Varoš', geocodingName: 'Kotor Varoš', entity: BslAdministrativeEntity.republikaSrpska),
    BslAdministrativeArea(displayName: 'Kozarska Dubica', geocodingName: 'Kozarska Dubica', entity: BslAdministrativeEntity.republikaSrpska),
    BslAdministrativeArea(displayName: 'Krupa na Uni', geocodingName: 'Krupa na Uni', entity: BslAdministrativeEntity.republikaSrpska),
    BslAdministrativeArea(displayName: 'Kupres (RS)', geocodingName: 'Istočni Kupres', entity: BslAdministrativeEntity.republikaSrpska, aliases: ['Kupres RS', 'Istočni Kupres']),
    BslAdministrativeArea(displayName: 'Lopare', geocodingName: 'Lopare', entity: BslAdministrativeEntity.republikaSrpska),
    BslAdministrativeArea(displayName: 'Ljubinje', geocodingName: 'Ljubinje', entity: BslAdministrativeEntity.republikaSrpska),
    BslAdministrativeArea(displayName: 'Milići', geocodingName: 'Milići', entity: BslAdministrativeEntity.republikaSrpska),
    BslAdministrativeArea(displayName: 'Modriča', geocodingName: 'Modriča', entity: BslAdministrativeEntity.republikaSrpska),
    BslAdministrativeArea(displayName: 'Mrkonjić Grad', geocodingName: 'Mrkonjić Grad', entity: BslAdministrativeEntity.republikaSrpska),
    BslAdministrativeArea(displayName: 'Nevesinje', geocodingName: 'Nevesinje', entity: BslAdministrativeEntity.republikaSrpska),
    BslAdministrativeArea(displayName: 'Novi Grad', geocodingName: 'Novi Grad', entity: BslAdministrativeEntity.republikaSrpska),
    BslAdministrativeArea(displayName: 'Novo Goražde', geocodingName: 'Novo Goražde', entity: BslAdministrativeEntity.republikaSrpska),
    BslAdministrativeArea(displayName: 'Osmaci', geocodingName: 'Osmaci', entity: BslAdministrativeEntity.republikaSrpska),
    BslAdministrativeArea(displayName: 'Oštra Luka', geocodingName: 'Oštra Luka', entity: BslAdministrativeEntity.republikaSrpska),
    BslAdministrativeArea(displayName: 'Pale', geocodingName: 'Pale', entity: BslAdministrativeEntity.republikaSrpska, aliases: ['Pale (RS)']),
    BslAdministrativeArea(displayName: 'Pelagićevo', geocodingName: 'Pelagićevo', entity: BslAdministrativeEntity.republikaSrpska),
    BslAdministrativeArea(displayName: 'Petrovac (RS)', geocodingName: 'Drinić', entity: BslAdministrativeEntity.republikaSrpska, aliases: ['Petrovac RS', 'Drinić']),
    BslAdministrativeArea(displayName: 'Petrovo', geocodingName: 'Petrovo', entity: BslAdministrativeEntity.republikaSrpska),
    BslAdministrativeArea(displayName: 'Ribnik', geocodingName: 'Ribnik', entity: BslAdministrativeEntity.republikaSrpska),
    BslAdministrativeArea(displayName: 'Rogatica', geocodingName: 'Rogatica', entity: BslAdministrativeEntity.republikaSrpska),
    BslAdministrativeArea(displayName: 'Rudo', geocodingName: 'Rudo', entity: BslAdministrativeEntity.republikaSrpska),
    BslAdministrativeArea(displayName: 'Šamac', geocodingName: 'Šamac', entity: BslAdministrativeEntity.republikaSrpska),
    BslAdministrativeArea(displayName: 'Šekovići', geocodingName: 'Šekovići', entity: BslAdministrativeEntity.republikaSrpska),
    BslAdministrativeArea(displayName: 'Šipovo', geocodingName: 'Šipovo', entity: BslAdministrativeEntity.republikaSrpska),
    BslAdministrativeArea(displayName: 'Sokolac', geocodingName: 'Sokolac', entity: BslAdministrativeEntity.republikaSrpska),
    BslAdministrativeArea(displayName: 'Srbac', geocodingName: 'Srbac', entity: BslAdministrativeEntity.republikaSrpska),
    BslAdministrativeArea(displayName: 'Srebrenica', geocodingName: 'Srebrenica', entity: BslAdministrativeEntity.republikaSrpska),
    BslAdministrativeArea(displayName: 'Stanari', geocodingName: 'Stanari', entity: BslAdministrativeEntity.republikaSrpska),
    BslAdministrativeArea(displayName: 'Teslić', geocodingName: 'Teslić', entity: BslAdministrativeEntity.republikaSrpska),
    BslAdministrativeArea(displayName: 'Trnovo (RS)', geocodingName: 'Trnovo', entity: BslAdministrativeEntity.republikaSrpska, aliases: ['Trnovo RS']),
    BslAdministrativeArea(displayName: 'Ugljevik', geocodingName: 'Ugljevik', entity: BslAdministrativeEntity.republikaSrpska),
    BslAdministrativeArea(displayName: 'Višegrad', geocodingName: 'Višegrad', entity: BslAdministrativeEntity.republikaSrpska),
    BslAdministrativeArea(displayName: 'Vlasenica', geocodingName: 'Vlasenica', entity: BslAdministrativeEntity.republikaSrpska),
    BslAdministrativeArea(displayName: 'Vukosavlje', geocodingName: 'Vukosavlje', entity: BslAdministrativeEntity.republikaSrpska),
    BslAdministrativeArea(displayName: 'Brčko distrikt', geocodingName: 'Brčko', entity: BslAdministrativeEntity.brcko, aliases: ['Brčko', 'Brcko distrikt', 'Brcko']),
  ];

  static List<String> get displayNames {
    final names = values.map((area) => area.displayName).toList(growable: false)
      ..sort((a, b) => normalize(a).compareTo(normalize(b)));
    return List<String>.unmodifiable(names);
  }

  static BslAdministrativeArea? findExact(String input) {
    final normalizedInput = normalize(input);
    if (normalizedInput.isEmpty) return null;

    for (final area in values) {
      if (normalize(area.displayName) == normalizedInput ||
          normalize(area.geocodingName) == normalizedInput) {
        return area;
      }

      for (final alias in area.aliases) {
        if (normalize(alias) == normalizedInput) return area;
      }
    }

    return null;
  }

  static String canonicalDisplayName(String input) {
    return findExact(input)?.displayName ?? input.trim();
  }

  static String geocodingNameFor(String input) {
    return findExact(input)?.geocodingName ?? input.trim();
  }

  static String entityQualifier(BslAdministrativeArea area) {
    switch (area.entity) {
      case BslAdministrativeEntity.federation:
        return 'Federacija Bosne i Hercegovine';
      case BslAdministrativeEntity.republikaSrpska:
        return 'Republika Srpska';
      case BslAdministrativeEntity.brcko:
        return 'Brčko distrikt';
    }
  }

  static String normalize(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll('č', 'c')
        .replaceAll('ć', 'c')
        .replaceAll('š', 's')
        .replaceAll('ž', 'z')
        .replaceAll('đ', 'dj')
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim();
  }
}
