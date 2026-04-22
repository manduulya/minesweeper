import 'package:flutter_test/flutter_test.dart';
import 'package:mine_master/data/country_fun_facts.dart';

void main() {
  group('countryFunFacts', () {
    test('has entries for all expected countries', () {
      const expectedIsos = [
        'US', 'CA', 'MX', 'BR', 'AR', 'CL', 'CO', 'PE', 'VE', 'BO',
        'PY', 'UY', 'EC', 'GY', 'SR', 'TT', 'JM', 'CU', 'HT', 'DO',
        'GB', 'FR', 'DE', 'IT', 'ES', 'PT', 'NL', 'BE', 'CH', 'AT',
        'SE', 'NO', 'DK', 'FI', 'PL', 'CZ', 'SK', 'HU', 'RO', 'BG',
        'GR', 'RS', 'HR', 'BA', 'SI', 'MK', 'AL', 'ME', 'XK', 'LT',
        'LV', 'EE', 'BY', 'UA', 'MD', 'IE', 'IS', 'LU', 'MT', 'CY',
        'RU', 'TR', 'NG', 'ZA', 'EG', 'KE', 'ET', 'GH', 'TZ', 'UG',
        'MZ', 'ZM', 'ZW', 'AO', 'SD', 'SS', 'SN', 'CI', 'CM', 'MG',
        'IN', 'CN', 'JP', 'KR', 'ID', 'PK', 'BD', 'PH', 'VN', 'TH',
        'MY', 'MM', 'AU', 'NZ', 'SA', 'IR', 'IQ', 'SY', 'JO', 'LB',
        'IL', 'AE', 'KW', 'QA', 'BH', 'OM', 'YE', 'AF', 'KZ', 'UZ',
      ];
      for (final iso in expectedIsos) {
        expect(countryFunFacts.containsKey(iso), isTrue,
            reason: 'Missing entry for ISO: $iso');
      }
    });

    test('no two countries share the same fun fact', () {
      final values = countryFunFacts.values.toList();
      final seen = <String>{};
      for (final fact in values) {
        expect(seen.contains(fact), isFalse,
            reason: 'Duplicate fun fact found: "$fact"');
        seen.add(fact);
      }
    });

    test('no entry contains placeholder text', () {
      const placeholders = [
        'fascinating country',
        'placeholder',
        'lorem ipsum',
        'TODO',
        'fun fact here',
      ];
      for (final entry in countryFunFacts.entries) {
        for (final placeholder in placeholders) {
          expect(
            entry.value.toLowerCase().contains(placeholder.toLowerCase()),
            isFalse,
            reason:
                '${entry.key} contains placeholder text: "${entry.value}"',
          );
        }
      }
    });

    test('every fact is at least 80 characters long', () {
      for (final entry in countryFunFacts.entries) {
        expect(entry.value.length, greaterThanOrEqualTo(80),
            reason: '${entry.key} fact is too short: "${entry.value}"');
      }
    });

    test('no duplicate ISO keys', () {
      // Dart const maps already error at compile time for duplicate keys,
      // but this verifies the map length matches unique key count.
      final keys = countryFunFacts.keys.toList();
      final uniqueKeys = keys.toSet();
      expect(keys.length, equals(uniqueKeys.length),
          reason: 'Found ${keys.length - uniqueKeys.length} duplicate ISO key(s)');
    });
  });
}
