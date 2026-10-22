/// Utility to translate Liturgical Calendar celebration names, seasons,
/// and ranks from English (John Romano D'Orazio LitCal API) into Vietnamese.
class LiturgicalTranslator {
  LiturgicalTranslator._();

  static const Map<String, String> _ordinals = {
    'first': 'I',
    'second': 'II',
    'third': 'III',
    'fourth': 'IV',
    'fifth': 'V',
    'sixth': 'VI',
    'seventh': 'VII',
    'eighth': 'VIII',
    'ninth': 'IX',
    'tenth': 'X',
    'eleventh': 'XI',
    'twelfth': 'XII',
    'thirteenth': 'XIII',
    'fourteenth': 'XIV',
    'fifteenth': 'XV',
    'sixteenth': 'XVI',
    'seventeenth': 'XVII',
    'eighteenth': 'XVIII',
    'nineteenth': 'XIX',
    'twentieth': 'XX',
    'twenty-first': 'XXI',
    'twenty-second': 'XXII',
    'twenty-third': 'XXIII',
    'twenty-fourth': 'XXIV',
    'twenty-fifth': 'XXV',
    'twenty-sixth': 'XXVI',
    'twenty-seventh': 'XXVII',
    'twenty-eighth': 'XXVIII',
    'twenty-ninth': 'XXIX',
    'thirtieth': 'XXX',
    'thirty-first': 'XXXI',
    'thirty-second': 'XXXII',
    'thirty-third': 'XXXIII',
    'thirty-fourth': 'XXXIV',
  };

  static const Map<String, String> _daysOfWeek = {
    'monday': 'Thứ Hai',
    'tuesday': 'Thứ Ba',
    'wednesday': 'Thứ Tư',
    'thursday': 'Thứ Năm',
    'friday': 'Thứ Sáu',
    'saturday': 'Thứ Bảy',
    'sunday': 'Chúa Nhật',
  };

  static const Map<String, String> _exactCelebrations = {
    // Christmas Season & Epiphany
    'the nativity of the lord (christmas)': 'Đại lễ Chúa Giáng Sinh',
    'the nativity of the lord': 'Đại lễ Chúa Giáng Sinh',
    'christmas': 'Đại lễ Chúa Giáng Sinh',
    'the holy family of jesus, mary and joseph':
        'Lễ Thánh Gia Thất: Chúa Giêsu, Đức Mẹ và Thánh Giuse',
    'the holy family': 'Lễ Thánh Gia Thất: Chúa Giêsu, Đức Mẹ và Thánh Giuse',
    'octave day of the nativity of the lord, solemnity of mary, mother of god':
        'Lễ Đức Maria, Mẹ Thiên Chúa',
    'mary, mother of god': 'Lễ Đức Maria, Mẹ Thiên Chúa',
    'the epiphany of the lord': 'Lễ Chúa Hiển Linh',
    'the epiphany': 'Lễ Chúa Hiển Linh',
    'the baptism of the lord': 'Lễ Chúa Giêsu Chịu Phép Rửa',

    // Lent & Holy Week
    'ash wednesday': 'Thứ Tư Lễ Tro',
    'palm sunday of the passion of the lord':
        'Chúa Nhật Lễ Lá (Tưởng niệm Cuộc Thương Khó của Chúa)',
    'palm sunday': 'Chúa Nhật Lễ Lá',
    'thursday of the lord\'s supper (holy thursday)':
        'Thứ Năm Tuần Thánh (Thánh lễ Tiệc Ly)',
    'thursday of the lord\'s supper': 'Thứ Năm Tuần Thánh (Thánh lễ Tiệc Ly)',
    'holy thursday': 'Thứ Năm Tuần Thánh (Thánh lễ Tiệc Ly)',
    'friday of the passion of the lord (good friday)':
        'Thứ Sáu Tuần Thánh (Tưởng niệm Cuộc Thương Khó của Chúa)',
    'friday of the passion of the lord':
        'Thứ Sáu Tuần Thánh (Tưởng niệm Cuộc Thương Khó của Chúa)',
    'good friday': 'Thứ Sáu Tuần Thánh (Tưởng niệm Cuộc Thương Khó của Chúa)',
    'holy saturday': 'Thứ Bảy Tuần Thánh (Đêm Canh Thức Vượt Qua)',

    // Easter Season
    'easter sunday of the resurrection of the lord':
        'Đại lễ Phục Sinh (Mừng Chúa Phục Sinh)',
    'easter sunday': 'Đại lễ Phục Sinh (Mừng Chúa Phục Sinh)',
    'second sunday of easter, or sunday of divine mercy':
        'Chúa Nhật II Phục Sinh (Kính Lòng Thương Xót Chúa)',
    'second sunday of easter (or sunday of divine mercy)':
        'Chúa Nhật II Phục Sinh (Kính Lòng Thương Xót Chúa)',
    'second sunday of easter':
        'Chúa Nhật II Phục Sinh (Kính Lòng Thương Xót Chúa)',
    'fourth sunday of easter': 'Chúa Nhật IV Phục Sinh (Chúa Chiên Lành)',
    'the ascension of the lord': 'Lễ Chúa Thăng Thiên',
    'ascension of the lord': 'Lễ Chúa Thăng Thiên',
    'pentecost sunday': 'Đại lễ Chúa Thánh Thần Hiện Xuống',
    'the blessed virgin mary, mother of the church':
        'Lễ Đức Trinh Nữ Maria, Mẹ Hội Thánh',
    'monday after pentecost':
        'Thứ Hai sau Lễ Hiện Xuống (Đức Mẹ là Mẹ Hội Thánh)',

    // Solemnities of the Lord & Saints
    'the most holy trinity': 'Lễ Chúa Ba Ngôi',
    'the most holy body and blood of christ (corpus christi)':
        'Lễ Mình và Máu Thánh Chúa Kitô',
    'the most holy body and blood of christ': 'Lễ Mình và Máu Thánh Chúa Kitô',
    'corpus christi': 'Lễ Mình và Máu Thánh Chúa Kitô',
    'the most sacred heart of jesus': 'Lễ Thánh Tâm Chúa Giêsu',
    'the immaculate heart of the blessed virgin mary':
        'Lễ Trái Tim Vô Nhiễm Đức Trinh Nữ Maria',
    'the immaculate heart of mary': 'Lễ Trái Tim Vô Nhiễm Đức Trinh Nữ Maria',
    'our lord jesus christ, king of the universe': 'Lễ Chúa Kitô Vua Vũ Trụ',
    'the transfiguration of the lord': 'Lễ Chúa Biến Hình',
    'the exaltation of the holy cross': 'Lễ Suy Tôn Thánh Giá',
    'the presentation of the lord': 'Lễ Dâng Chúa Trong Đền Thánh (Lễ Nến)',
    'the annunciation of the lord': 'Lễ Truyền Tin cho Đức Mẹ',
    'sunday of the word of god': 'Chúa Nhật Lời Chúa',

    // Marian Solemnities & Feasts
    'the immaculate conception of the blessed virgin mary':
        'Lễ Đức Mẹ Vô Nhiễm Nguyên Tội',
    'the assumption of the blessed virgin mary': 'Lễ Đức Mẹ Hồn Xác Lên Trời',
    'the nativity of the blessed virgin mary':
        'Lễ Sinh Nhật Đức Trinh Nữ Maria',
    'the visitation of the blessed virgin mary':
        'Lễ Đức Mẹ Thăm Viếng Bà Elisabeth',
    'the presentation of the blessed virgin mary':
        'Lễ Đức Mẹ Dâng Mình Trong Đền Thờ',
    'the queenship of the blessed virgin mary': 'Lễ Đức Maria Nữ Vương',
    'our lady of sorrows': 'Lễ Đức Mẹ Sầu Bi',
    'our lady of the rosary': 'Lễ Đức Mẹ Mân Côi',
    'our lady of mount carmel': 'Lễ Đức Mẹ Núi Cát Minh',
    'our lady of lourdes': 'Lễ Đức Mẹ Lộ Đức',
    'our lady of fatima': 'Lễ Đức Mẹ Fatima',
    'our lady of guadalupe': 'Lễ Đức Mẹ Guadalupe',

    // Major Saints, Apostles, Martyrs
    'saint joseph, spouse of the blessed virgin mary':
        'Lễ Thánh Giuse, Bạn Trăm Năm Đức Maria',
    'saint joseph the worker': 'Lễ Thánh Giuse Thợ',
    'the nativity of saint john the baptist':
        'Lễ Sinh Nhật Thánh Gioan Tẩy Giả',
    'the beheading of saint john the baptist':
        'Lễ Thánh Gioan Tẩy Giả Bị Trảm Quyết',
    'saints peter and paul, apostles': 'Lễ Hai Thánh Tông Đồ Phêrô và Phaolô',
    'saint peter and saint paul, apostles':
        'Lễ Hai Thánh Tông Đồ Phêrô và Phaolô',
    'all saints': 'Đại lễ Các Thánh Nam Nữ',
    'the commemoration of all the faithful departed (all souls\' day)':
        'Lễ Các Đẳng Linh Hồn',
    'the commemoration of all the faithful departed': 'Lễ Các Đẳng Linh Hồn',
    'all souls\' day': 'Lễ Các Đẳng Linh Hồn',
    'the dedication of the lateran basilica':
        'Lễ Cung Hiến Vương Cung Thánh Đường Latêranô',
    'the chair of saint peter the apostle': 'Lễ Lập Tông Tòa Thánh Phêrô',
    'the conversion of saint paul the apostle':
        'Lễ Thánh Phaolô Tông Đồ Trở Lại',
    'conversion of saint paul the apostle': 'Lễ Thánh Phaolô Tông Đồ Trở Lại',
    'the holy innocents, martyrs': 'Lễ Các Thánh Anh Hài, Tử Đạo',
    'the holy guardian angels': 'Lễ Các Thiên Thần Bản Mệnh',
    'saints michael, gabriel and raphael, archangels':
        'Lễ Các Tổng Lãnh Thiên Thần Micae, Gabriel và Raphael',
    'saint stephen, the first martyr': 'Thánh Stêphanô, Tử đạo tiên khởi',
    'saint stephen, first martyr': 'Thánh Stêphanô, Tử đạo tiên khởi',

    // Apostles and Evangelists
    'saint andrew, apostle': 'Thánh Anrê, Tông đồ',
    'saint thomas, apostle': 'Thánh Tôma, Tông đồ',
    'saint james, apostle': 'Thánh Giacôbê, Tông đồ',
    'saint john, apostle and evangelist':
        'Thánh Gioan, Tông đồ và Tác giả Phúc Âm',
    'saint mark, evangelist': 'Thánh Mác-cô, Tác giả Phúc Âm',
    'saint luke, evangelist': 'Thánh Lu-ca, Tác giả Phúc Âm',
    'saint matthew, apostle and evangelist':
        'Thánh Mátthêu, Tông đồ và Tác giả Phúc Âm',
    'saints philip and james, apostles':
        'Hai Thánh Philípphê và Giacôbê, Tông đồ',
    'saint bartholomew, apostle': 'Thánh Batôlômêô, Tông đồ',
    'saints simon and jude, apostles': 'Hai Thánh Simon và Giuđa, Tông đồ',
    'saint matthias, apostle': 'Thánh Mátthia, Tông đồ',
    'saint barnabas, apostle': 'Thánh Barnaba, Tông đồ',
    'saint mary magdalene': 'Thánh Maria Ma-đa-lê-na',
    'saint martha, saint mary and saint lazarus':
        'Thánh Mácta, Maria và Ladarô',
    'saint martha': 'Thánh Mácta',

    // Prominent Saints & Martyrs
    'saint ignatius of antioch, bishop and martyr':
        'Thánh Inhaxiô thành Antiôkia, Giám mục, Tử đạo',
    'saint callistus i, pope and martyr':
        'Thánh Callistô I, Giáo hoàng, Tử đạo',
    'saint teresa of calcutta': 'Thánh Têrêsa Calcutta',
    'saint thérèse of the child jesus, virgin and doctor of the church':
        'Thánh Têrêsa Hài Đồng Giêsu, Trinh nữ, Tiến sĩ Hội Thánh',
    'saint therese of the child jesus, virgin and doctor of the church':
        'Thánh Têrêsa Hài Đồng Giêsu, Trinh nữ, Tiến sĩ Hội Thánh',
    'saint francis of assisi': 'Thánh Phanxicô thành Assisi',
    'saint francis xavier, priest': 'Thánh Phanxicô Xaviê, Linh mục',
    'saint anthony of padua, priest and doctor of the church':
        'Thánh Antôn thành Padova, Linh mục, Tiến sĩ Hội Thánh',
    'saint thomas aquinas, priest and doctor of the church':
        'Thánh Tôma Aquinô, Linh mục, Tiến sĩ Hội Thánh',
    'saint augustine, bishop and doctor of the church':
        'Thánh Augustinô, Giám mục, Tiến sĩ Hội Thánh',
    'saint jerome, priest and doctor of the church':
        'Thánh Giêrônimô, Linh mục, Tiến sĩ Hội Thánh',
    'saint ambrose, bishop and doctor of the church':
        'Thánh Ambrôsiô, Giám mục, Tiến sĩ Hội Thánh',
    'saint dominic, priest': 'Thánh Đaminh, Linh mục',
    'saint benedict, abbot': 'Thánh Biển Đức, Viện phụ',
    'saint cecilia, virgin and martyr':
        'Thánh Cêcilia, Trinh nữ, Tử đạo (Quan thầy giới Thánh nhạc)',
    'saint agnes, virgin and martyr': 'Thánh Anê, Trinh nữ, Tử đạo',
    'saint lucy, virgin and martyr': 'Thánh Lucia, Trinh nữ, Tử đạo',
    'saint nicholas, bishop': 'Thánh Nicôla, Giám mục',
    'saint patrick, bishop': 'Thánh Patrick, Giám mục',
    'saint vincent de paul, priest': 'Thánh Vincentê Phaolô, Linh mục',
    'saint john mary vianney, priest':
        'Thánh Gioan Maria Vianney, Linh mục (Quan thầy các Cha sở)',
    'saint john vianney, priest':
        'Thánh Gioan Maria Vianney, Linh mục (Quan thầy các Cha sở)',
    'saint john bosco, priest': 'Thánh Gioan Bosco, Linh mục',
    'saint monica': 'Thánh Mônica',
    'saint maximilian mary kolbe, priest and martyr':
        'Thánh Maximilianô Kolbe, Linh mục, Tử đạo',
    'saint lawrence, deacon and martyr': 'Thánh Lôrensô, Phó tế, Tử đạo',
    'saint andrew dung-lac, priest, and companions, martyrs':
        'Thánh Anrê Dũng Lạc, Linh mục và các Bạn Tử Đạo',
    'saint andrew dung-lac and companions, martyrs':
        'Thánh Anrê Dũng Lạc, Linh mục và các Bạn Tử Đạo',
  };

  static String? _parseOrdinal(String text) {
    final lower = text.trim().toLowerCase();
    final fromWord = _ordinals[lower];
    if (fromWord != null) return fromWord;

    final numStr = lower.replaceAll(RegExp(r'[^\d]'), '');
    final num = int.tryParse(numStr);
    if (num != null && num >= 1 && num <= 34) {
      const romanNumerals = [
        '',
        'I',
        'II',
        'III',
        'IV',
        'V',
        'VI',
        'VII',
        'VIII',
        'IX',
        'X',
        'XI',
        'XII',
        'XIII',
        'XIV',
        'XV',
        'XVI',
        'XVII',
        'XVIII',
        'XIX',
        'XX',
        'XXI',
        'XXII',
        'XXIII',
        'XXIV',
        'XXV',
        'XXVI',
        'XXVII',
        'XXVIII',
        'XXIX',
        'XXX',
        'XXXI',
        'XXXII',
        'XXXIII',
        'XXXIV',
      ];
      return romanNumerals[num];
    }
    return null;
  }

  /// Translates a celebration name into friendly Vietnamese.
  static String translateCelebration(String rawName) {
    final trimmed = rawName.trim();
    if (trimmed.isEmpty) return trimmed;

    final lower = trimmed.toLowerCase();

    // 1. Direct dictionary match
    final directMatch = _exactCelebrations[lower];
    if (directMatch != null) return directMatch;

    // 2. Weekdays and Sundays of the Nth Week in Ordinary Time:
    // e.g. "Wednesday of the Twenty-ninth Week in Ordinary Time", "Wednesday of the 29th Week of Ordinary Time", "Sunday of the 30th Week of Ordinary Time"
    final weekdayOtMatch = RegExp(
      r'^(monday|tuesday|wednesday|thursday|friday|saturday|sunday)(?:\s+of\s+the|,\s*)?\s*([\w-]+)\s+week\s+(?:of|in)\s+ordinary\s+time$',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (weekdayOtMatch != null) {
      final dow =
          _daysOfWeek[weekdayOtMatch.group(1)!.toLowerCase()] ??
          weekdayOtMatch.group(1)!;
      final ord =
          _parseOrdinal(weekdayOtMatch.group(2)!) ?? weekdayOtMatch.group(2)!;
      return dow == 'Chúa Nhật'
          ? 'Chúa Nhật $ord Mùa Thường Niên'
          : '$dow tuần $ord Mùa Thường Niên';
    }

    // 3. Sundays in Ordinary Time:
    // e.g. "30th Sunday of Ordinary Time", "30th Sunday in Ordinary Time", "Thirtieth Sunday in Ordinary Time"
    final sundayOtMatch = RegExp(
      r'^([\w-]+)\s+sunday\s+(?:of|in)\s+ordinary\s+time$',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (sundayOtMatch != null) {
      final ord =
          _parseOrdinal(sundayOtMatch.group(1)!) ?? sundayOtMatch.group(1)!;
      return 'Chúa Nhật $ord Mùa Thường Niên';
    }

    // 4. Weekdays of Advent:
    // e.g. "Tuesday of the First Week of Advent", "Tuesday of the 1st Week of Advent"
    final weekdayAdvMatch = RegExp(
      r'^(monday|tuesday|wednesday|thursday|friday|saturday|sunday)(?:\s+of\s+the|,\s*)?\s*([\w-]+)\s+week\s+(?:of|in)\s+advent$',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (weekdayAdvMatch != null) {
      final dow =
          _daysOfWeek[weekdayAdvMatch.group(1)!.toLowerCase()] ??
          weekdayAdvMatch.group(1)!;
      final ord =
          _parseOrdinal(weekdayAdvMatch.group(2)!) ?? weekdayAdvMatch.group(2)!;
      return dow == 'Chúa Nhật'
          ? 'Chúa Nhật $ord Mùa Vọng'
          : '$dow tuần $ord Mùa Vọng';
    }

    // 5. Sundays of Advent:
    // e.g. "First Sunday of Advent", "1st Sunday of Advent"
    final sundayAdvMatch = RegExp(
      r'^([\w-]+)\s+sunday\s+(?:of|in)\s+advent$',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (sundayAdvMatch != null) {
      final ord =
          _parseOrdinal(sundayAdvMatch.group(1)!) ?? sundayAdvMatch.group(1)!;
      final note = ord == 'III' ? ' (Chúa Nhật Vui)' : '';
      return 'Chúa Nhật $ord Mùa Vọng$note';
    }

    // 6. Weekdays of Lent:
    // e.g. "Tuesday of the Second Week of Lent", "Tuesday, 2nd Week of Lent"
    final weekdayLentMatch = RegExp(
      r'^(monday|tuesday|wednesday|thursday|friday|saturday|sunday)(?:\s+of\s+the|,\s*)?\s*([\w-]+)\s+week\s+(?:of|in)\s+lent$',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (weekdayLentMatch != null) {
      final dow =
          _daysOfWeek[weekdayLentMatch.group(1)!.toLowerCase()] ??
          weekdayLentMatch.group(1)!;
      final ord =
          _parseOrdinal(weekdayLentMatch.group(2)!) ??
          weekdayLentMatch.group(2)!;
      return dow == 'Chúa Nhật'
          ? 'Chúa Nhật $ord Mùa Chay'
          : '$dow tuần $ord Mùa Chay';
    }

    // 7. Sundays of Lent:
    // e.g. "Second Sunday of Lent", "2nd Sunday of Lent", "Second Sunday in Lent"
    final sundayLentMatch = RegExp(
      r'^([\w-]+)\s+sunday\s+(?:of|in)\s+lent$',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (sundayLentMatch != null) {
      final ord =
          _parseOrdinal(sundayLentMatch.group(1)!) ?? sundayLentMatch.group(1)!;
      final note = ord == 'IV' ? ' (Chúa Nhật Mừng Vui)' : '';
      return 'Chúa Nhật $ord Mùa Chay$note';
    }

    // 8. Days after Ash Wednesday:
    // e.g. "Thursday after Ash Wednesday"
    final afterAshMatch = RegExp(
      r'^(\w+)\s+after\s+ash\s+wednesday$',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (afterAshMatch != null) {
      final dow =
          _daysOfWeek[afterAshMatch.group(1)!.toLowerCase()] ??
          afterAshMatch.group(1)!;
      return '$dow sau Lễ Tro';
    }

    // 9. Holy Week weekdays:
    // e.g. "Monday of Holy Week"
    final holyWeekMatch = RegExp(
      r'^(\w+)\s+of\s+holy\s+week$',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (holyWeekMatch != null) {
      final dow =
          _daysOfWeek[holyWeekMatch.group(1)!.toLowerCase()] ??
          holyWeekMatch.group(1)!;
      return '$dow Tuần Thánh';
    }

    // 10. Days in the Octave of Easter:
    // e.g. "Monday in the Octave of Easter"
    final easterOctaveMatch = RegExp(
      r'^(\w+)\s+(in|within)\s+the\s+octave\s+of\s+easter$',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (easterOctaveMatch != null) {
      final dow =
          _daysOfWeek[easterOctaveMatch.group(1)!.toLowerCase()] ??
          easterOctaveMatch.group(1)!;
      return '$dow trong tuần Bát Nhật Phục Sinh';
    }

    // 11. Weekdays of Easter:
    // e.g. "Monday of the Third Week of Easter", "Monday, 3rd Week of Easter"
    final weekdayEasterMatch = RegExp(
      r'^(monday|tuesday|wednesday|thursday|friday|saturday|sunday)(?:\s+of\s+the|,\s*)?\s*([\w-]+)\s+week\s+(?:of|in)\s+easter$',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (weekdayEasterMatch != null) {
      final dow =
          _daysOfWeek[weekdayEasterMatch.group(1)!.toLowerCase()] ??
          weekdayEasterMatch.group(1)!;
      final ord =
          _parseOrdinal(weekdayEasterMatch.group(2)!) ??
          weekdayEasterMatch.group(2)!;
      return dow == 'Chúa Nhật'
          ? 'Chúa Nhật $ord Mùa Phục Sinh'
          : '$dow tuần $ord Mùa Phục Sinh';
    }

    // 12. Sundays of Easter:
    // e.g. "Third Sunday of Easter", "3rd Sunday of Easter", "Third Sunday in Easter"
    final sundayEasterMatch = RegExp(
      r'^([\w-]+)\s+sunday\s+(?:of|in)\s+easter$',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (sundayEasterMatch != null) {
      final ord =
          _parseOrdinal(sundayEasterMatch.group(1)!) ??
          sundayEasterMatch.group(1)!;
      final note = ord == 'IV' ? ' (Chúa Chiên Lành)' : '';
      return 'Chúa Nhật $ord Mùa Phục Sinh$note';
    }

    // 13. Days before / after Epiphany:
    // e.g. "Thursday after the Epiphany"
    final epiphanyRelMatch = RegExp(
      r'^(\w+)\s+(before|after)\s+the\s+epiphany$',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (epiphanyRelMatch != null) {
      final dow =
          _daysOfWeek[epiphanyRelMatch.group(1)!.toLowerCase()] ??
          epiphanyRelMatch.group(1)!;
      final rel = epiphanyRelMatch.group(2)!.toLowerCase() == 'before'
          ? 'trước'
          : 'sau';
      return '$dow $rel Lễ Hiển Linh';
    }

    // 14. Days in the Octave of Christmas:
    // e.g. "Fifth Day within the Octave of the Nativity of the Lord", "5th Day in the Octave of Christmas"
    final christmasOctaveMatch = RegExp(
      r'^([\w-]+)\s+day\s+(in|within)\s+the\s+octave\s+of\s+(the\s+nativity\s+of\s+the\s+lord|christmas)$',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (christmasOctaveMatch != null) {
      final ord =
          _parseOrdinal(christmasOctaveMatch.group(1)!) ??
          christmasOctaveMatch.group(1)!;
      return 'Ngày thứ $ord trong tuần Bát Nhật Giáng Sinh';
    }

    // 15. Late Advent December calendar dates:
    // e.g. "December 18"
    final decMatch = RegExp(
      r'^december\s+(\d{1,2})$',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (decMatch != null) {
      return 'Ngày ${decMatch.group(1)} tháng 12 (Mùa Vọng)';
    }

    // 16. Fallback pattern for Saint / Saints feasts and memorials
    return _translateSaintFallback(trimmed);
  }

  static String _translateSaintFallback(String input) {
    var result = input;

    // Prefixes
    if (result.startsWith('Saint ')) {
      result = 'Thánh ${result.substring(6)}';
    } else if (result.startsWith('Saints ')) {
      result = 'Các Thánh ${result.substring(7)}';
    } else if (result.startsWith('Blessed ')) {
      result = 'Chân phước ${result.substring(8)}';
    } else if (result.startsWith('Memorial of Saint ')) {
      result = 'Lễ nhớ Thánh ${result.substring(18)}';
    } else if (result.startsWith('Memorial of Saints ')) {
      result = 'Lễ nhớ Các Thánh ${result.substring(19)}';
    } else if (result.startsWith('Optional Memorial of Saint ')) {
      result = 'Lễ nhớ tùy chọn Thánh ${result.substring(27)}';
    } else if (result.startsWith('Feast of Saint ')) {
      result = 'Lễ kính Thánh ${result.substring(15)}';
    } else if (result.startsWith('Solemnity of Saint ')) {
      result = 'Lễ trọng Thánh ${result.substring(19)}';
    }

    // Suffixes and ecclesiastical titles
    result = result
        .replaceAll(', Pope and Martyr', ', Giáo hoàng, Tử đạo')
        .replaceAll(', Bishop and Martyr', ', Giám mục, Tử đạo')
        .replaceAll(', Priest and Martyr', ', Linh mục, Tử đạo')
        .replaceAll(', Deacon and Martyr', ', Phó tế, Tử đạo')
        .replaceAll(', Virgin and Martyr', ', Trinh nữ, Tử đạo')
        .replaceAll(
          ', Bishop and Doctor of the Church',
          ', Giám mục, Tiến sĩ Hội Thánh',
        )
        .replaceAll(
          ', Priest and Doctor of the Church',
          ', Linh mục, Tiến sĩ Hội Thánh',
        )
        .replaceAll(
          ', Virgin and Doctor of the Church',
          ', Trinh nữ, Tiến sĩ Hội Thánh',
        )
        .replaceAll(', Doctor of the Church', ', Tiến sĩ Hội Thánh')
        .replaceAll(', Pope', ', Giáo hoàng')
        .replaceAll(', Bishop', ', Giám mục')
        .replaceAll(', Priest', ', Linh mục')
        .replaceAll(', Deacon', ', Phó tế')
        .replaceAll(', Virgin', ', Trinh nữ')
        .replaceAll(', Religious', ', Tu sĩ')
        .replaceAll(', Martyr', ', Tử đạo')
        .replaceAll(', Martyrs', ', Tử đạo')
        .replaceAll(', Abbot', ', Viện phụ')
        .replaceAll(', Hermit', ', Ẩn sĩ')
        .replaceAll(', Apostle', ', Tông đồ')
        .replaceAll(', Apostles', ', Tông đồ')
        .replaceAll(', Evangelist', ', Tác giả Phúc Âm')
        .replaceAll(' and Companions, Martyrs', ' và các Bạn Tử Đạo')
        .replaceAll(' and Companions', ' và các Bạn');

    return result;
  }

  /// Translates a liturgical season name into Vietnamese.
  static String translateSeason(String? rawSeason) {
    if (rawSeason == null || rawSeason.trim().isEmpty) return '';
    final lower = rawSeason.trim().toLowerCase();
    switch (lower) {
      case 'advent':
        return 'Mùa Vọng';
      case 'christmas':
        return 'Mùa Giáng Sinh';
      case 'lent':
        return 'Mùa Chay';
      case 'easter':
        return 'Mùa Phục Sinh';
      case 'ordinarytime':
      case 'ordinary time':
        return 'Mùa Thường Niên';
      default:
        return rawSeason;
    }
  }

  /// Translates a liturgical rank/grade into Vietnamese.
  static String? translateRank(String? rawRank) {
    if (rawRank == null || rawRank.trim().isEmpty) return null;
    final lower = rawRank.trim().toLowerCase();
    switch (lower) {
      case 'solemnity':
        return 'Lễ Trọng';
      case 'feast':
        return 'Lễ Kính';
      case 'obligatory memorial':
      case 'memorial':
        return 'Lễ Nhớ';
      case 'optional memorial':
        return 'Lễ Nhớ Tùy Chọn';
      default:
        return rawRank;
    }
  }

  /// Translates mass / ceremony category into Vietnamese.
  static String translateCategory(String? rawCategory) {
    if (rawCategory == null || rawCategory.trim().isEmpty) return 'PHỤNG VỤ';
    final lower = rawCategory.trim().toLowerCase();
    switch (lower) {
      case 'sundaymass':
      case 'sunday':
        return 'THÁNH LỄ CHÚA NHẬT';
      case 'weekdaymass':
      case 'weekday':
        return 'THÁNH LỄ NGÀY';
      case 'solemnity':
        return 'LỄ TRỌNG';
      case 'feast':
        return 'LỄ KÍNH';
      case 'wedding':
        return 'THÁNH LỄ HÔN PHỐI';
      case 'funeral':
        return 'THÁNH LỄ AN TÁNG';
      case 'baptism':
        return 'NGHI THỨC RỬA TỘI';
      case 'confirmation':
        return 'THÁNH LỄ THÊM SỨC';
      case 'adoration':
        return 'CHẦU THÁNH THỂ';
      case 'penance':
      case 'reconciliation':
        return 'BÍ TÍCH GIAO HÒA';
      default:
        return rawCategory.toUpperCase();
    }
  }
}
