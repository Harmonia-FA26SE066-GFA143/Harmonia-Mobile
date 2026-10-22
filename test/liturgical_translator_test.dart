import 'package:flutter_test/flutter_test.dart';
import 'package:harmonia_mobile/features/calendar/data/calendar_dto.dart';
import 'package:harmonia_mobile/features/calendar/data/liturgical_translator.dart';

void main() {
  group('LiturgicalTranslator Tests', () {
    test('translates Ordinary Time weekdays and Sundays', () {
      expect(
        LiturgicalTranslator.translateCelebration(
          'Wednesday of the Twenty-ninth Week in Ordinary Time',
        ),
        'Thứ Tư tuần XXIX Mùa Thường Niên',
      );
      expect(
        LiturgicalTranslator.translateCelebration(
          'Monday of the First Week in Ordinary Time',
        ),
        'Thứ Hai tuần I Mùa Thường Niên',
      );
      expect(
        LiturgicalTranslator.translateCelebration(
          'Friday of the Thirty-fourth Week in Ordinary Time',
        ),
        'Thứ Sáu tuần XXXIV Mùa Thường Niên',
      );
      expect(
        LiturgicalTranslator.translateCelebration(
          'Twenty-ninth Sunday in Ordinary Time',
        ),
        'Chúa Nhật XXIX Mùa Thường Niên',
      );
      expect(
        LiturgicalTranslator.translateCelebration(
          'Thirtieth Sunday in Ordinary Time',
        ),
        'Chúa Nhật XXX Mùa Thường Niên',
      );
      expect(
        LiturgicalTranslator.translateCelebration(
          '30th Sunday of Ordinary Time',
        ),
        'Chúa Nhật XXX Mùa Thường Niên',
      );
      expect(
        LiturgicalTranslator.translateCelebration(
          '30th Sunday in Ordinary Time',
        ),
        'Chúa Nhật XXX Mùa Thường Niên',
      );
      expect(
        LiturgicalTranslator.translateCelebration(
          'Sunday of the 30th Week of Ordinary Time',
        ),
        'Chúa Nhật XXX Mùa Thường Niên',
      );
      expect(
        LiturgicalTranslator.translateCelebration(
          'Wednesday of the 29th Week of Ordinary Time',
        ),
        'Thứ Tư tuần XXIX Mùa Thường Niên',
      );
      expect(
        LiturgicalTranslator.translateCelebration(
          'Wednesday, 29th Week of Ordinary Time',
        ),
        'Thứ Tư tuần XXIX Mùa Thường Niên',
      );
    });

    test('translates Advent weekdays and Sundays', () {
      expect(
        LiturgicalTranslator.translateCelebration(
          'Tuesday of the First Week of Advent',
        ),
        'Thứ Ba tuần I Mùa Vọng',
      );
      expect(
        LiturgicalTranslator.translateCelebration('First Sunday of Advent'),
        'Chúa Nhật I Mùa Vọng',
      );
      expect(
        LiturgicalTranslator.translateCelebration('Third Sunday of Advent'),
        'Chúa Nhật III Mùa Vọng (Chúa Nhật Vui)',
      );
      expect(
        LiturgicalTranslator.translateCelebration('December 18'),
        'Ngày 18 tháng 12 (Mùa Vọng)',
      );
      expect(
        LiturgicalTranslator.translateCelebration('1st Sunday of Advent'),
        'Chúa Nhật I Mùa Vọng',
      );
    });

    test('translates Lent weekdays, Sundays, and Holy Week', () {
      expect(
        LiturgicalTranslator.translateCelebration('Ash Wednesday'),
        'Thứ Tư Lễ Tro',
      );
      expect(
        LiturgicalTranslator.translateCelebration(
          'Thursday after Ash Wednesday',
        ),
        'Thứ Năm sau Lễ Tro',
      );
      expect(
        LiturgicalTranslator.translateCelebration(
          'Friday of the Fifth Week of Lent',
        ),
        'Thứ Sáu tuần V Mùa Chay',
      );
      expect(
        LiturgicalTranslator.translateCelebration('Second Sunday of Lent'),
        'Chúa Nhật II Mùa Chay',
      );
      expect(
        LiturgicalTranslator.translateCelebration('2nd Sunday of Lent'),
        'Chúa Nhật II Mùa Chay',
      );
      expect(
        LiturgicalTranslator.translateCelebration('Fourth Sunday of Lent'),
        'Chúa Nhật IV Mùa Chay (Chúa Nhật Mừng Vui)',
      );
      expect(
        LiturgicalTranslator.translateCelebration(
          'Palm Sunday of the Passion of the Lord',
        ),
        'Chúa Nhật Lễ Lá (Tưởng niệm Cuộc Thương Khó của Chúa)',
      );
      expect(
        LiturgicalTranslator.translateCelebration('Monday of Holy Week'),
        'Thứ Hai Tuần Thánh',
      );
      expect(
        LiturgicalTranslator.translateCelebration(
          'Thursday of the Lord\'s Supper (Holy Thursday)',
        ),
        'Thứ Năm Tuần Thánh (Thánh lễ Tiệc Ly)',
      );
      expect(
        LiturgicalTranslator.translateCelebration(
          'Friday of the Passion of the Lord (Good Friday)',
        ),
        'Thứ Sáu Tuần Thánh (Tưởng niệm Cuộc Thương Khó của Chúa)',
      );
      expect(
        LiturgicalTranslator.translateCelebration('Holy Saturday'),
        'Thứ Bảy Tuần Thánh (Đêm Canh Thức Vượt Qua)',
      );
    });

    test('translates Easter weekdays, Sundays, and Octave', () {
      expect(
        LiturgicalTranslator.translateCelebration(
          'Easter Sunday of the Resurrection of the Lord',
        ),
        'Đại lễ Phục Sinh (Mừng Chúa Phục Sinh)',
      );
      expect(
        LiturgicalTranslator.translateCelebration(
          'Monday in the Octave of Easter',
        ),
        'Thứ Hai trong tuần Bát Nhật Phục Sinh',
      );
      expect(
        LiturgicalTranslator.translateCelebration(
          'Second Sunday of Easter, or Sunday of Divine Mercy',
        ),
        'Chúa Nhật II Phục Sinh (Kính Lòng Thương Xót Chúa)',
      );
      expect(
        LiturgicalTranslator.translateCelebration(
          'Monday of the Third Week of Easter',
        ),
        'Thứ Hai tuần III Mùa Phục Sinh',
      );
      expect(
        LiturgicalTranslator.translateCelebration('The Ascension of the Lord'),
        'Lễ Chúa Thăng Thiên',
      );
      expect(
        LiturgicalTranslator.translateCelebration('Pentecost Sunday'),
        'Đại lễ Chúa Thánh Thần Hiện Xuống',
      );
    });

    test('translates Christmas season and major solemnities', () {
      expect(
        LiturgicalTranslator.translateCelebration(
          'The Nativity of the Lord (Christmas)',
        ),
        'Đại lễ Chúa Giáng Sinh',
      );
      expect(
        LiturgicalTranslator.translateCelebration(
          'The Holy Family of Jesus, Mary and Joseph',
        ),
        'Lễ Thánh Gia Thất: Chúa Giêsu, Đức Mẹ và Thánh Giuse',
      );
      expect(
        LiturgicalTranslator.translateCelebration('The Epiphany of the Lord'),
        'Lễ Chúa Hiển Linh',
      );
      expect(
        LiturgicalTranslator.translateCelebration('The Baptism of the Lord'),
        'Lễ Chúa Giêsu Chịu Phép Rửa',
      );
      expect(
        LiturgicalTranslator.translateCelebration('The Most Holy Trinity'),
        'Lễ Chúa Ba Ngôi',
      );
      expect(
        LiturgicalTranslator.translateCelebration(
          'The Most Holy Body and Blood of Christ (Corpus Christi)',
        ),
        'Lễ Mình và Máu Thánh Chúa Kitô',
      );
      expect(
        LiturgicalTranslator.translateCelebration(
          'The Most Sacred Heart of Jesus',
        ),
        'Lễ Thánh Tâm Chúa Giêsu',
      );
      expect(
        LiturgicalTranslator.translateCelebration(
          'Our Lord Jesus Christ, King of the Universe',
        ),
        'Lễ Chúa Kitô Vua Vũ Trụ',
      );
      expect(
        LiturgicalTranslator.translateCelebration(
          'The Immaculate Conception of the Blessed Virgin Mary',
        ),
        'Lễ Đức Mẹ Vô Nhiễm Nguyên Tội',
      );
      expect(
        LiturgicalTranslator.translateCelebration(
          'The Assumption of the Blessed Virgin Mary',
        ),
        'Lễ Đức Mẹ Hồn Xác Lên Trời',
      );
      expect(
        LiturgicalTranslator.translateCelebration('All Saints'),
        'Đại lễ Các Thánh Nam Nữ',
      );
    });

    test('translates Saints, Apostles, and Martyrs', () {
      expect(
        LiturgicalTranslator.translateCelebration('Saint Mark, Evangelist'),
        'Thánh Mác-cô, Tác giả Phúc Âm',
      );
      expect(
        LiturgicalTranslator.translateCelebration(
          'Saint Ignatius of Antioch, Bishop and Martyr',
        ),
        'Thánh Inhaxiô thành Antiôkia, Giám mục, Tử đạo',
      );
      expect(
        LiturgicalTranslator.translateCelebration(
          'Saint Callistus I, Pope and Martyr',
        ),
        'Thánh Callistô I, Giáo hoàng, Tử đạo',
      );
      expect(
        LiturgicalTranslator.translateCelebration(
          'Saints Peter and Paul, Apostles',
        ),
        'Lễ Hai Thánh Tông Đồ Phêrô và Phaolô',
      );
      expect(
        LiturgicalTranslator.translateCelebration(
          'Saint Polycarp, Bishop and Martyr',
        ),
        'Thánh Polycarp, Giám mục, Tử đạo',
      );
    });

    test('translates seasons, ranks, and categories', () {
      expect(
        LiturgicalTranslator.translateSeason('OrdinaryTime'),
        'Mùa Thường Niên',
      );
      expect(LiturgicalTranslator.translateSeason('Advent'), 'Mùa Vọng');
      expect(LiturgicalTranslator.translateSeason('Lent'), 'Mùa Chay');
      expect(LiturgicalTranslator.translateSeason('Easter'), 'Mùa Phục Sinh');
      expect(
        LiturgicalTranslator.translateSeason('Christmas'),
        'Mùa Giáng Sinh',
      );

      expect(LiturgicalTranslator.translateRank('Solemnity'), 'Lễ Trọng');
      expect(LiturgicalTranslator.translateRank('Feast'), 'Lễ Kính');
      expect(
        LiturgicalTranslator.translateRank('Obligatory Memorial'),
        'Lễ Nhớ',
      );
      expect(
        LiturgicalTranslator.translateRank('Optional Memorial'),
        'Lễ Nhớ Tùy Chọn',
      );

      expect(
        LiturgicalTranslator.translateCategory('SundayMass'),
        'THÁNH LỄ CHÚA NHẬT',
      );
      expect(
        LiturgicalTranslator.translateCategory('WeekdayMass'),
        'THÁNH LỄ NGÀY',
      );
      expect(LiturgicalTranslator.translateCategory('Solemnity'), 'LỄ TRỌNG');
    });

    test(
      'LiturgicalDay celebrationLabel exposes translated celebration name',
      () {
        final day = LiturgicalDay.fromJson({
          'date': '2026-10-21',
          'celebrationName':
              'Wednesday of the Twenty-ninth Week in Ordinary Time',
          'rank': null,
          'seasonName': 'OrdinaryTime',
        });

        expect(
          day.celebrationName,
          'Wednesday of the Twenty-ninth Week in Ordinary Time',
        );
        expect(day.celebrationLabel, 'Thứ Tư tuần XXIX Mùa Thường Niên');
        expect(day.seasonLabel, 'Mùa Thường Niên');
      },
    );
  });
}
