// lib/service_utils/country_data.dart

class CountryData {
  final String name;
  final String flagCode;

  const CountryData({required this.name, required this.flagCode});
}

class CountryHelper {
  // Comprehensive list of countries with proper ISO 3166-1 alpha-2 codes
  // These codes work with the country_flags package
  static const List<CountryData> countries = [
    CountryData(name: 'International', flagCode: 'international'),

    // A
    CountryData(name: 'Afghanistan', flagCode: 'af'),
    CountryData(name: 'Albania', flagCode: 'al'),
    CountryData(name: 'Algeria', flagCode: 'dz'),
    CountryData(name: 'Andorra', flagCode: 'ad'),
    CountryData(name: 'Angola', flagCode: 'ao'),
    CountryData(name: 'Antigua and Barbuda', flagCode: 'ag'),
    CountryData(name: 'Argentina', flagCode: 'ar'),
    CountryData(name: 'Armenia', flagCode: 'am'),
    CountryData(name: 'Australia', flagCode: 'au'),
    CountryData(name: 'Austria', flagCode: 'at'),
    CountryData(name: 'Azerbaijan', flagCode: 'az'),

    // B
    CountryData(name: 'Bahamas', flagCode: 'bs'),
    CountryData(name: 'Bahrain', flagCode: 'bh'),
    CountryData(name: 'Bangladesh', flagCode: 'bd'),
    CountryData(name: 'Barbados', flagCode: 'bb'),
    CountryData(name: 'Belarus', flagCode: 'by'),
    CountryData(name: 'Belgium', flagCode: 'be'),
    CountryData(name: 'Belize', flagCode: 'bz'),
    CountryData(name: 'Benin', flagCode: 'bj'),
    CountryData(name: 'Bhutan', flagCode: 'bt'),
    CountryData(name: 'Bolivia', flagCode: 'bo'),
    CountryData(name: 'Bosnia and Herzegovina', flagCode: 'ba'),
    CountryData(name: 'Botswana', flagCode: 'bw'),
    CountryData(name: 'Brazil', flagCode: 'br'),
    CountryData(name: 'Brunei', flagCode: 'bn'),
    CountryData(name: 'Bulgaria', flagCode: 'bg'),
    CountryData(name: 'Burkina Faso', flagCode: 'bf'),
    CountryData(name: 'Burundi', flagCode: 'bi'),

    // C
    CountryData(name: 'Cambodia', flagCode: 'kh'),
    CountryData(name: 'Cameroon', flagCode: 'cm'),
    CountryData(name: 'Canada', flagCode: 'ca'),
    CountryData(name: 'Cape Verde', flagCode: 'cv'),
    CountryData(name: 'Central African Republic', flagCode: 'cf'),
    CountryData(name: 'Chad', flagCode: 'td'),
    CountryData(name: 'Chile', flagCode: 'cl'),
    CountryData(name: 'China', flagCode: 'cn'),
    CountryData(name: 'Colombia', flagCode: 'co'),
    CountryData(name: 'Comoros', flagCode: 'km'),
    CountryData(name: 'Congo', flagCode: 'cg'),
    CountryData(name: 'Costa Rica', flagCode: 'cr'),
    CountryData(name: 'Croatia', flagCode: 'hr'),
    CountryData(name: 'Cuba', flagCode: 'cu'),
    CountryData(name: 'Cyprus', flagCode: 'cy'),
    CountryData(name: 'Czech Republic', flagCode: 'cz'),

    // D
    CountryData(name: 'Denmark', flagCode: 'dk'),
    CountryData(name: 'Djibouti', flagCode: 'dj'),
    CountryData(name: 'Dominica', flagCode: 'dm'),
    CountryData(name: 'Dominican Republic', flagCode: 'do'),

    // E
    CountryData(name: 'East Timor', flagCode: 'tl'),
    CountryData(name: 'Ecuador', flagCode: 'ec'),
    CountryData(name: 'Egypt', flagCode: 'eg'),
    CountryData(name: 'El Salvador', flagCode: 'sv'),
    CountryData(name: 'Equatorial Guinea', flagCode: 'gq'),
    CountryData(name: 'Eritrea', flagCode: 'er'),
    CountryData(name: 'Estonia', flagCode: 'ee'),
    CountryData(name: 'Eswatini', flagCode: 'sz'),
    CountryData(name: 'Ethiopia', flagCode: 'et'),

    // F
    CountryData(name: 'Fiji', flagCode: 'fj'),
    CountryData(name: 'Finland', flagCode: 'fi'),
    CountryData(name: 'France', flagCode: 'fr'),

    // G
    CountryData(name: 'Gabon', flagCode: 'ga'),
    CountryData(name: 'Gambia', flagCode: 'gm'),
    CountryData(name: 'Georgia', flagCode: 'ge'),
    CountryData(name: 'Germany', flagCode: 'de'),
    CountryData(name: 'Ghana', flagCode: 'gh'),
    CountryData(name: 'Greece', flagCode: 'gr'),
    CountryData(name: 'Grenada', flagCode: 'gd'),
    CountryData(name: 'Guatemala', flagCode: 'gt'),
    CountryData(name: 'Guinea', flagCode: 'gn'),
    CountryData(name: 'Guinea-Bissau', flagCode: 'gw'),
    CountryData(name: 'Guyana', flagCode: 'gy'),

    // H
    CountryData(name: 'Haiti', flagCode: 'ht'),
    CountryData(name: 'Honduras', flagCode: 'hn'),
    CountryData(name: 'Hungary', flagCode: 'hu'),

    // I
    CountryData(name: 'Iceland', flagCode: 'is'),
    CountryData(name: 'India', flagCode: 'in'),
    CountryData(name: 'Indonesia', flagCode: 'id'),
    CountryData(name: 'Iran', flagCode: 'ir'),
    CountryData(name: 'Iraq', flagCode: 'iq'),
    CountryData(name: 'Ireland', flagCode: 'ie'),
    CountryData(name: 'Israel', flagCode: 'il'),
    CountryData(name: 'Italy', flagCode: 'it'),
    CountryData(name: 'Ivory Coast', flagCode: 'ci'),

    // J
    CountryData(name: 'Jamaica', flagCode: 'jm'),
    CountryData(name: 'Japan', flagCode: 'jp'),
    CountryData(name: 'Jordan', flagCode: 'jo'),

    // K
    CountryData(name: 'Kazakhstan', flagCode: 'kz'),
    CountryData(name: 'Kenya', flagCode: 'ke'),
    CountryData(name: 'Kiribati', flagCode: 'ki'),
    CountryData(name: 'Kuwait', flagCode: 'kw'),
    CountryData(name: 'Kyrgyzstan', flagCode: 'kg'),

    // L
    CountryData(name: 'Laos', flagCode: 'la'),
    CountryData(name: 'Latvia', flagCode: 'lv'),
    CountryData(name: 'Lebanon', flagCode: 'lb'),
    CountryData(name: 'Lesotho', flagCode: 'ls'),
    CountryData(name: 'Liberia', flagCode: 'lr'),
    CountryData(name: 'Libya', flagCode: 'ly'),
    CountryData(name: 'Liechtenstein', flagCode: 'li'),
    CountryData(name: 'Lithuania', flagCode: 'lt'),
    CountryData(name: 'Luxembourg', flagCode: 'lu'),

    // M
    CountryData(name: 'Madagascar', flagCode: 'mg'),
    CountryData(name: 'Malawi', flagCode: 'mw'),
    CountryData(name: 'Malaysia', flagCode: 'my'),
    CountryData(name: 'Maldives', flagCode: 'mv'),
    CountryData(name: 'Mali', flagCode: 'ml'),
    CountryData(name: 'Malta', flagCode: 'mt'),
    CountryData(name: 'Marshall Islands', flagCode: 'mh'),
    CountryData(name: 'Mauritania', flagCode: 'mr'),
    CountryData(name: 'Mauritius', flagCode: 'mu'),
    CountryData(name: 'Mexico', flagCode: 'mx'),
    CountryData(name: 'Micronesia', flagCode: 'fm'),
    CountryData(name: 'Moldova', flagCode: 'md'),
    CountryData(name: 'Monaco', flagCode: 'mc'),
    CountryData(name: 'Mongolia', flagCode: 'mn'),
    CountryData(name: 'Montenegro', flagCode: 'me'),
    CountryData(name: 'Morocco', flagCode: 'ma'),
    CountryData(name: 'Mozambique', flagCode: 'mz'),
    CountryData(name: 'Myanmar', flagCode: 'mm'),

    // N
    CountryData(name: 'Namibia', flagCode: 'na'),
    CountryData(name: 'Nauru', flagCode: 'nr'),
    CountryData(name: 'Nepal', flagCode: 'np'),
    CountryData(name: 'Netherlands', flagCode: 'nl'),
    CountryData(name: 'New Zealand', flagCode: 'nz'),
    CountryData(name: 'Nicaragua', flagCode: 'ni'),
    CountryData(name: 'Niger', flagCode: 'ne'),
    CountryData(name: 'Nigeria', flagCode: 'ng'),
    CountryData(name: 'North Korea', flagCode: 'kp'),
    CountryData(name: 'North Macedonia', flagCode: 'mk'),
    CountryData(name: 'Norway', flagCode: 'no'),

    // O
    CountryData(name: 'Oman', flagCode: 'om'),

    // P
    CountryData(name: 'Pakistan', flagCode: 'pk'),
    CountryData(name: 'Palau', flagCode: 'pw'),
    CountryData(name: 'Palestine', flagCode: 'ps'),
    CountryData(name: 'Panama', flagCode: 'pa'),
    CountryData(name: 'Papua New Guinea', flagCode: 'pg'),
    CountryData(name: 'Paraguay', flagCode: 'py'),
    CountryData(name: 'Peru', flagCode: 'pe'),
    CountryData(name: 'Philippines', flagCode: 'ph'),
    CountryData(name: 'Poland', flagCode: 'pl'),
    CountryData(name: 'Portugal', flagCode: 'pt'),

    // Q
    CountryData(name: 'Qatar', flagCode: 'qa'),

    // R
    CountryData(name: 'Romania', flagCode: 'ro'),
    CountryData(name: 'Russia', flagCode: 'ru'),
    CountryData(name: 'Rwanda', flagCode: 'rw'),

    // S
    CountryData(name: 'Saint Kitts and Nevis', flagCode: 'kn'),
    CountryData(name: 'Saint Lucia', flagCode: 'lc'),
    CountryData(name: 'Saint Vincent and the Grenadines', flagCode: 'vc'),
    CountryData(name: 'Samoa', flagCode: 'ws'),
    CountryData(name: 'San Marino', flagCode: 'sm'),
    CountryData(name: 'Sao Tome and Principe', flagCode: 'st'),
    CountryData(name: 'Saudi Arabia', flagCode: 'sa'),
    CountryData(name: 'Senegal', flagCode: 'sn'),
    CountryData(name: 'Serbia', flagCode: 'rs'),
    CountryData(name: 'Seychelles', flagCode: 'sc'),
    CountryData(name: 'Sierra Leone', flagCode: 'sl'),
    CountryData(name: 'Singapore', flagCode: 'sg'),
    CountryData(name: 'Slovakia', flagCode: 'sk'),
    CountryData(name: 'Slovenia', flagCode: 'si'),
    CountryData(name: 'Solomon Islands', flagCode: 'sb'),
    CountryData(name: 'Somalia', flagCode: 'so'),
    CountryData(name: 'South Africa', flagCode: 'za'),
    CountryData(name: 'South Korea', flagCode: 'kr'),
    CountryData(name: 'South Sudan', flagCode: 'ss'),
    CountryData(name: 'Spain', flagCode: 'es'),
    CountryData(name: 'Sri Lanka', flagCode: 'lk'),
    CountryData(name: 'Sudan', flagCode: 'sd'),
    CountryData(name: 'Suriname', flagCode: 'sr'),
    CountryData(name: 'Sweden', flagCode: 'se'),
    CountryData(name: 'Switzerland', flagCode: 'ch'),
    CountryData(name: 'Syria', flagCode: 'sy'),

    // T
    CountryData(name: 'Taiwan', flagCode: 'tw'),
    CountryData(name: 'Tajikistan', flagCode: 'tj'),
    CountryData(name: 'Tanzania', flagCode: 'tz'),
    CountryData(name: 'Thailand', flagCode: 'th'),
    CountryData(name: 'Togo', flagCode: 'tg'),
    CountryData(name: 'Tonga', flagCode: 'to'),
    CountryData(name: 'Trinidad and Tobago', flagCode: 'tt'),
    CountryData(name: 'Tunisia', flagCode: 'tn'),
    CountryData(name: 'Turkey', flagCode: 'tr'),
    CountryData(name: 'Turkmenistan', flagCode: 'tm'),
    CountryData(name: 'Tuvalu', flagCode: 'tv'),

    // U
    CountryData(name: 'Uganda', flagCode: 'ug'),
    CountryData(name: 'Ukraine', flagCode: 'ua'),
    CountryData(name: 'United Arab Emirates', flagCode: 'ae'),
    CountryData(name: 'United Kingdom', flagCode: 'gb'),
    CountryData(name: 'United States', flagCode: 'us'),
    CountryData(name: 'Uruguay', flagCode: 'uy'),
    CountryData(name: 'Uzbekistan', flagCode: 'uz'),

    // V
    CountryData(name: 'Vanuatu', flagCode: 'vu'),
    CountryData(name: 'Vatican City', flagCode: 'va'),
    CountryData(name: 'Venezuela', flagCode: 've'),
    CountryData(name: 'Vietnam', flagCode: 'vn'),

    // Y
    CountryData(name: 'Yemen', flagCode: 'ye'),

    // Z
    CountryData(name: 'Zambia', flagCode: 'zm'),
    CountryData(name: 'Zimbabwe', flagCode: 'zw'),
  ];

  // Helper method to get country by flag code
  static CountryData? getCountryByFlagCode(String flagCode) {
    try {
      return countries.firstWhere((country) => country.flagCode == flagCode);
    } catch (e) {
      return null;
    }
  }

  // Helper method to get all countries sorted alphabetically
  static List<CountryData> getCountriesSorted() {
    final sorted = List<CountryData>.from(countries);
    sorted.sort((a, b) => a.name.compareTo(b.name));
    return sorted;
  }
}
