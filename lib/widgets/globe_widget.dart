import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:path_drawing/path_drawing.dart';
import '../data/country_fun_facts.dart';
import '../hive/offline_sync_service.dart';
import '../services/api_service.dart';
import '../services/interstitial_ad_service.dart';
import '../sound_manager.dart';
import 'click_button_widget.dart';
import 'peel_particle_system.dart';

class GlobeWidget extends StatefulWidget {
  /// Called with `true` when a country board opens, `false` when it closes.
  final ValueChanged<bool>? onPlayingChanged;

  const GlobeWidget({super.key, this.onPlayingChanged});

  @override
  State<GlobeWidget> createState() => _GlobeWidgetState();
}

class _GlobeWidgetState extends State<GlobeWidget>
    with SingleTickerProviderStateMixin {

  // ── Shader + texture ───────────────────────────────────────────────────────
  ui.FragmentShader? _shader;
  ui.Image?          _mapTexture;
  bool _textureReady   = false;
  bool _capturePending = false;
  final _svgKey = GlobalKey();

  // ── SVG source (loaded once, patched on each reveal) ──────────────────────
  String _baseSvg   = '';   // raw dark-mode SVG from assets
  String _patchedSvg = ''; // base + revealed country colours applied
  bool   _svgLoaded  = false;

  // ── Revealed countries ─────────────────────────────────────────────────────
  // ISO → dominant flag colour applied after winning that country's board
  final Map<String, Color> _revealedCountries = {};

  // True while a country's minesweeper board is open
  bool _boardOpen = false;

  int _consecutiveLosses = 0;
  static const int _lossesPerAd = 5;

  final InterstitialAdService _interstitialAdService = InterstitialAdService();

  // ── Rotation / zoom ────────────────────────────────────────────────────────
  // Globe orientation stored as a row-major 3×3 rotation matrix.
  // Horizontal drag post-multiplies by rotY (world Y — no gimbal lock).
  // Vertical drag post-multiplies by rotX in camera space (no gimbal lock).
  List<double> _rotMat = _rotX(0.1); // match original _userLat = 0.1
  double _zoom = 1.0;

  // ── Rotation matrix helpers ────────────────────────────────────────────────
  static List<double> _rotX(double a) {
    final c = cos(a), s = sin(a);
    return [1,0,0, 0,c,-s, 0,s,c];
  }

  static List<double> _rotY(double a) {
    final c = cos(a), s = sin(a);
    return [c,0,s, 0,1,0, -s,0,c];
  }

  static List<double> _matMul3(List<double> A, List<double> B) => [
    A[0]*B[0]+A[1]*B[3]+A[2]*B[6], A[0]*B[1]+A[1]*B[4]+A[2]*B[7], A[0]*B[2]+A[1]*B[5]+A[2]*B[8],
    A[3]*B[0]+A[4]*B[3]+A[5]*B[6], A[3]*B[1]+A[4]*B[4]+A[5]*B[7], A[3]*B[2]+A[4]*B[5]+A[5]*B[8],
    A[6]*B[0]+A[7]*B[3]+A[8]*B[6], A[6]*B[1]+A[7]*B[4]+A[8]*B[7], A[6]*B[2]+A[7]*B[5]+A[8]*B[8],
  ];

  // Re-orthonormalise to prevent floating-point drift accumulating over many multiplications.
  static List<double> _ortho3(List<double> m) {
    double x0=m[0],x1=m[1],x2=m[2];
    double y0=m[3],y1=m[4],y2=m[5];
    final xL = sqrt(x0*x0+x1*x1+x2*x2);
    x0/=xL; x1/=xL; x2/=xL;
    final d = y0*x0+y1*x1+y2*x2;
    y0-=d*x0; y1-=d*x1; y2-=d*x2;
    final yL = sqrt(y0*y0+y1*y1+y2*y2);
    y0/=yL; y1/=yL; y2/=yL;
    final z0=x1*y2-x2*y1, z1=x2*y0-x0*y2, z2=x0*y1-x1*y0;
    return [x0,x1,x2, y0,y1,y2, z0,z1,z2];
  }

  // ── Auto-rotation ──────────────────────────────────────────────────────────
  late final AnimationController _autoController;

  // ── Country hit-testing ────────────────────────────────────────────────────
  final List<(String, Path)> _countryPathList = [];
  final Map<String, String>  _isoToName       = {};
  bool _pathsLoaded = false;

  // ── Tap tracking ──────────────────────────────────────────────────────────
  Offset?   _tapDownPos;
  DateTime? _tapDownTime;
  bool      _wasDrag          = false;
  double    _previousScale    = 1.0;
  bool      _hadMultiTouch    = false; // latched true the moment 2+ fingers are seen
  int       _activePointers   = 0;     // raw count from Listener — always ahead of recognizer

  // ── Last rendered size (for inverse projection) ────────────────────────────
  Size _lastSize = Size.zero;

  // ── Texture dimensions ─────────────────────────────────────────────────────
  static const double _texW = 2048;
  static const double _texH = 878;

  // ── SVG / shader constants ─────────────────────────────────────────────────
  static const double _svgW   = 2000;
  static const double _svgH   = 857;
  static const double _latMax = 1.3461; // ±77.13° — matches globe.frag

  // ── Dark-mode colours (must match color_map.py) ───────────────────────────
  static const Color _oceanColor = Color(0xFF0B1E3D);

  // ── class="CountryName" → ISO for multi-territory SVG paths ───────────────
  static const Map<String, String> _classToIso = {
    'Russian Federation': 'RU', 'Canada': 'CA', 'United States': 'US',
    'Brazil': 'BR', 'Australia': 'AU', 'Greenland': 'GL', 'France': 'FR',
    'Norway': 'NO', 'United Kingdom': 'GB', 'Denmark': 'DK',
    'Netherlands': 'NL', 'Spain': 'ES', 'Portugal': 'PT', 'New Zealand': 'NZ',
    'Indonesia': 'ID', 'Philippines': 'PH', 'Japan': 'JP', 'Malaysia': 'MY',
    'Papua New Guinea': 'PG', 'Chile': 'CL', 'Argentina': 'AR',
    'Ecuador': 'EC', 'Colombia': 'CO', 'Venezuela': 'VE', 'Italy': 'IT',
    'Greece': 'GR', 'Croatia': 'HR', 'Finland': 'FI', 'Sweden': 'SE',
    'Estonia': 'EE', 'Latvia': 'LV', 'India': 'IN', 'China': 'CN',
    'Myanmar': 'MM', 'Thailand': 'TH', 'Vietnam': 'VN', 'Azerbaijan': 'AZ',
    'Kazakhstan': 'KZ', 'Angola': 'AO', 'Tanzania': 'TZ', 'Mozambique': 'MZ',
    'South Africa': 'ZA', 'Madagascar': 'MG', 'Iceland': 'IS',
    'Ireland': 'IE', 'Mexico': 'MX', 'Cuba': 'CU', 'Bahamas': 'BS',
    'Trinidad and Tobago': 'TT', 'Fiji': 'FJ', 'Solomon Islands': 'SB',
    'Kiribati': 'KI', 'Maldives': 'MV', 'Sri Lanka': 'LK', 'Cyprus': 'CY',
    'Malta': 'MT', 'Comoros': 'KM', 'Mauritius': 'MU', 'Seychelles': 'SC',
    'Cape Verde': 'CV', 'Palau': 'PW', 'Samoa': 'WS', 'Tonga': 'TO',
    'Timor-Leste': 'TL', 'Vanuatu': 'VU', 'Federated States of Micronesia': 'FM',
    'Turkey': 'TR', 'Oman': 'OM', 'New Caledonia': 'NC',
    'Falkland Islands': 'FK', 'Puerto Rico': 'PR', 'French Polynesia': 'PF',
    'American Samoa': 'AS', 'Guadeloupe': 'GP', 'Northern Mariana Islands': 'MP',
    'Turks and Caicos Islands': 'TC', 'Cayman Islands': 'KY',
    'Faeroe Islands': 'FO', 'Canary Islands (Spain)': 'IC',
    'Saint Kitts and Nevis': 'KN', 'Antigua and Barbuda': 'AG',
  };

  // ── Dominant flag colours (~120 countries) ─────────────────────────────────
  // Used to colour a country after the player wins its minesweeper board.
  static const Map<String, Color> _flagColors = {
    // Americas
    'US': Color(0xFFB22234), 'CA': Color(0xFFFF0000), 'MX': Color(0xFF006847),
    'BR': Color(0xFF009C3B), 'AR': Color(0xFF74ACDF), 'CL': Color(0xFFD52B1E),
    'CO': Color(0xFFFCD116), 'VE': Color(0xFFCF142B), 'PE': Color(0xFFD91023),
    'EC': Color(0xFFFFD100), 'BO': Color(0xFFD52B1E), 'PY': Color(0xFFD52B1E),
    'UY': Color(0xFF5B9BD5), 'GY': Color(0xFF009E60), 'SR': Color(0xFF377E3F),
    'CU': Color(0xFF002A8F), 'DO': Color(0xFF002D62), 'HT': Color(0xFF00209F),
    'JM': Color(0xFFFED100), 'TT': Color(0xFFCE1126), 'PA': Color(0xFF005293),
    'CR': Color(0xFF002B7F), 'NI': Color(0xFF3A75C4), 'HN': Color(0xFF0073CF),
    'SV': Color(0xFF0F47AF), 'GT': Color(0xFF4997D0), 'BZ': Color(0xFF003F87),
    // Europe
    'GB': Color(0xFF012169), 'FR': Color(0xFFEF4135), 'DE': Color(0xFFFFCE00),
    'IT': Color(0xFF009246), 'ES': Color(0xFFAA151B), 'PT': Color(0xFF006600),
    'NL': Color(0xFFAE1C28), 'BE': Color(0xFFFFE80C), 'CH': Color(0xFFFF0000),
    'AT': Color(0xFFED2939), 'SE': Color(0xFF006AA7), 'NO': Color(0xFFEF2B2D),
    'DK': Color(0xFFC60C30), 'FI': Color(0xFF003580), 'PL': Color(0xFFDC143C),
    'UA': Color(0xFF005BBB), 'RO': Color(0xFF002B7F), 'HU': Color(0xFFCE2939),
    'CZ': Color(0xFFD7141A), 'SK': Color(0xFF0B4EA2), 'HR': Color(0xFF171796),
    'RS': Color(0xFF0C4076), 'GR': Color(0xFF0D5EAF), 'BG': Color(0xFF009B77),
    'RU': Color(0xFF003791), 'BY': Color(0xFF007727), 'LT': Color(0xFF006A44),
    'LV': Color(0xFF9E3039), 'EE': Color(0xFF0072CE), 'IS': Color(0xFF003897),
    'IE': Color(0xFF169B62), 'AL': Color(0xFFE41E20), 'SI': Color(0xFF003DA5),
    'MK': Color(0xFFF8E400), 'MD': Color(0xFF003DA5), 'AM': Color(0xFFD90012),
    'GE': Color(0xFFFF0000), 'AZ': Color(0xFF0092BC),
    // Asia
    'CN': Color(0xFFDE2910), 'JP': Color(0xFFBC002D), 'KR': Color(0xFF003478),
    'IN': Color(0xFFFF9933), 'PK': Color(0xFF01411C), 'BD': Color(0xFF006A4E),
    'AF': Color(0xFF000000), 'IR': Color(0xFF239F40), 'IQ': Color(0xFFCE1126),
    'SA': Color(0xFF006C35), 'AE': Color(0xFF00732F), 'TR': Color(0xFFE30A17),
    'IL': Color(0xFF003399), 'JO': Color(0xFF007A3D), 'SY': Color(0xFFCE1126),
    'LB': Color(0xFF00A651), 'KW': Color(0xFF007A3D), 'QA': Color(0xFF8D1B3D),
    'OM': Color(0xFFDB161B), 'YE': Color(0xFFCE1126), 'ID': Color(0xFFCE1126),
    'PH': Color(0xFF0038A8), 'VN': Color(0xFFDA251D), 'TH': Color(0xFFA51931),
    'MY': Color(0xFFCC0001), 'MM': Color(0xFFFECB00), 'KH': Color(0xFF032EA1),
    'LA': Color(0xFFCE1126), 'MN': Color(0xFFC4272F), 'KZ': Color(0xFF00AFCA),
    'UZ': Color(0xFF1EB53A), 'TM': Color(0xFF1C8548), 'KG': Color(0xFFE8112D),
    'TJ': Color(0xFFCC0001), 'NP': Color(0xFF003893), 'LK': Color(0xFF8D153A),
    'TW': Color(0xFFFE0000), 'KP': Color(0xFF024FA2),
    // Africa
    'NG': Color(0xFF008751), 'EG': Color(0xFFCE1126), 'ZA': Color(0xFF007A4D),
    'KE': Color(0xFF006600), 'ET': Color(0xFF009A44), 'GH': Color(0xFF006B3F),
    'TZ': Color(0xFF1EB53A), 'MA': Color(0xFFC1272D), 'DZ': Color(0xFF006233),
    'TN': Color(0xFFE70013), 'LY': Color(0xFF000000), 'SD': Color(0xFFD21034),
    'AO': Color(0xFFCC0000), 'MZ': Color(0xFF009A44), 'ZM': Color(0xFF198A00),
    'ZW': Color(0xFF006400), 'MG': Color(0xFFFC3D32), 'CM': Color(0xFF007A5E),
    'CI': Color(0xFFF77F00), 'SN': Color(0xFF00853F), 'ML': Color(0xFF009A00),
    'BF': Color(0xFFEF2B2D), 'GN': Color(0xFFCE1126), 'NE': Color(0xFFE05206),
    'TD': Color(0xFF002664), 'SO': Color(0xFF4189DD), 'UG': Color(0xFF000000),
    'RW': Color(0xFF20603D), 'BI': Color(0xFFCE1126), 'SS': Color(0xFF078930),
    'ER': Color(0xFF4189DD), 'DJ': Color(0xFF6AB2E7), 'MW': Color(0xFF000000),
    'NA': Color(0xFF003580), 'BW': Color(0xFF75AADB), 'SZ': Color(0xFF3E5EB9),
    'LS': Color(0xFF009A44), 'GA': Color(0xFF009E60), 'CG': Color(0xFF009543),
    'CF': Color(0xFF003082), 'GQ': Color(0xFF3E9A00), 'ST': Color(0xFF12AD2B),
    'CV': Color(0xFF003893), 'MR': Color(0xFF006233), 'GM': Color(0xFF3A7728),
    'GW': Color(0xFFCE1126), 'SL': Color(0xFF1EB53A), 'LR': Color(0xFFBF0A30),
    'TG': Color(0xFF006A4E), 'BJ': Color(0xFF008751), 'MU': Color(0xFFEA2839),
    'SC': Color(0xFF003F87), 'KM': Color(0xFF3A75C4), 'CD': Color(0xFF007FFF),
    // Oceania & other
    'AU': Color(0xFF00008B), 'NZ': Color(0xFF00247D), 'PG': Color(0xFF000000),
    'FJ': Color(0xFF68BFE5), 'SB': Color(0xFF0120B5), 'VU': Color(0xFF009543),
    'WS': Color(0xFFCE1126), 'TO': Color(0xFFC10000), 'PW': Color(0xFF4AADD6),
    'FM': Color(0xFF75B2DD), 'GL': Color(0xFFFFFFFF), 'TL': Color(0xFFDC241F),
  };

  // ── Default flag colour for unmapped ISOs ──────────────────────────────────
  static const Color _flagDefault = Color(0xFF4CAF50);

  // ── Flag emoji from ISO code ───────────────────────────────────────────────
  static String _flagEmoji(String iso) {
    if (iso.length != 2) return '🌍';
    const base = 0x1F1E6 - 65;
    return String.fromCharCode(base + iso.codeUnitAt(0)) +
           String.fromCharCode(base + iso.codeUnitAt(1));
  }


  @override
  void initState() {
    super.initState();
    _autoController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 120),
    );
    _loadShader();
    _loadBaseSvg();
    _loadCountryPaths();
    _interstitialAdService.preloadAd();
  }

  // ── Asset loading ──────────────────────────────────────────────────────────

  Future<void> _loadShader() async {
    try {
      final program =
          await ui.FragmentProgram.fromAsset('assets/shaders/globe.frag');
      if (mounted) setState(() => _shader = program.fragmentShader());
    } catch (e) {
      debugPrint('Globe shader load failed: $e');
    }
  }

  Future<void> _loadBaseSvg() async {
    try {
      final raw = await rootBundle.loadString('assets/world_colored.svg');
      if (mounted) {
        setState(() {
          _baseSvg    = raw;
          _patchedSvg = raw; // no reveals yet
          _svgLoaded  = true;
        });
        await _loadProgress(); // apply saved progress once SVG is ready
      }
    } catch (e) {
      debugPrint('SVG load failed: $e');
    }
  }

  /// Loads revealed countries from Hive (instant) then merges any additional
  /// ISOs from the server (if online). Applies everything in one setState so
  /// the initial texture capture already includes all progress.
  /// Also pushes the merged local set back to the server so any previously
  /// failed syncs are caught up on the next app open.
  Future<void> _loadProgress() async {
    final isos = OfflineSyncService.loadWorldMapProgress();

    if (await OfflineSyncService.isOnline()) {
      try {
        final serverIsos = await ApiService().getWorldMapProgress();
        if (serverIsos != null) isos.addAll(serverIsos);
      } catch (_) {}

      // Push the full merged set so missed syncs are caught up
      if (isos.isNotEmpty) _syncProgressToServer(isos.toList());
    }

    // Persist merged set locally
    if (isos.isNotEmpty) OfflineSyncService.saveWorldMapProgress(isos);

    if (isos.isEmpty || !mounted) return;

    setState(() {
      for (final iso in isos) {
        _revealedCountries[iso.toUpperCase()] =
            _flagColors[iso.toUpperCase()] ?? _flagDefault;
      }
      _patchedSvg = _applyRevealedColors();
    });

    // If texture was already captured before progress loaded, refresh it
    if (_textureReady) _recaptureTexture();
  }

  Future<void> _loadCountryPaths() async {
    try {
      final svgStr = await rootBundle.loadString('assets/world_colored.svg');
      final pathTagRx = RegExp(r'<path\b([^>]*)/?>', dotAll: true);
      final idRx      = RegExp(r'\bid="([^"]+)"');
      final classRx   = RegExp(r'\bclass="([^"]+)"');
      final dRx       = RegExp(r'\bd="([^"]+)"');
      final nameRx    = RegExp(r'\bname="([^"]+)"');

      final list  = <(String, Path)>[];
      final names = <String, String>{};

      for (final m in pathTagRx.allMatches(svgStr)) {
        final attrs  = m.group(1) ?? '';
        final dMatch = dRx.firstMatch(attrs);
        if (dMatch == null) continue;
        final dStr = dMatch.group(1) ?? '';
        if (dStr.isEmpty) continue;

        String? iso;
        String? displayName;

        final idMatch = idRx.firstMatch(attrs);
        if (idMatch != null) {
          iso = idMatch.group(1)!.toUpperCase();
          final nameMatch = nameRx.firstMatch(attrs);
          if (nameMatch != null) displayName = nameMatch.group(1);
        } else {
          final clsMatch = classRx.firstMatch(attrs);
          if (clsMatch != null) {
            final cls = clsMatch.group(1) ?? '';
            displayName = cls;
            iso = (_classToIso[cls] ?? cls).toUpperCase();
          }
        }
        if (iso == null) continue;

        try {
          final path = parseSvgPathData(dStr);
          list.add((iso, path));
          if (displayName != null && !names.containsKey(iso)) {
            names[iso] = displayName;
          }
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _countryPathList..clear()..addAll(list);
          _isoToName.addAll(names);
          _pathsLoaded = true;
        });
      }
    } catch (e) {
      debugPrint('Country path loading failed: $e');
    }
  }

  // ── SVG capture ────────────────────────────────────────────────────────────

  /// Initial capture — shows loading screen until done.
  Future<void> _captureSvgTexture() async {
    if (_textureReady || _capturePending || !_svgLoaded) return;
    _capturePending = true;

    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;

    final image = await _captureFromBoundary();
    _capturePending = false;
    if (image != null && mounted) {
      setState(() {
        _mapTexture  = image;
        _textureReady = true;
      });
      _autoController.repeat();
    }
  }

  /// Silent re-capture after a reveal — keeps the current texture until done.
  Future<void> _recaptureTexture() async {
    if (_capturePending) return; // drop if a capture is already in flight
    _capturePending = true;
    await Future.delayed(const Duration(milliseconds: 150));
    if (!mounted) { _capturePending = false; return; }
    final image = await _captureFromBoundary();
    _capturePending = false;
    if (image != null && mounted) {
      setState(() {
        _mapTexture?.dispose();
        _mapTexture = image;
      });
    }
  }

  Future<ui.Image?> _captureFromBoundary() async {
    final boundary =
        _svgKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;
    try {
      return await boundary.toImage(pixelRatio: 3.0);
    } catch (e) {
      debugPrint('toImage failed: $e');
      return null;
    }
  }

  // ── Reveal country (call after player wins a board) ────────────────────────

  /// Colours [iso] with its dominant flag colour and silently refreshes the globe texture.
  void revealCountry(String iso) {
    iso = iso.toUpperCase();
    if (_revealedCountries.containsKey(iso)) return;
    final color = _flagColors[iso] ?? _flagDefault;
    setState(() {
      _revealedCountries[iso] = color;
      _patchedSvg = _applyRevealedColors();
    });
    _recaptureTexture();

    // Persist locally (instant) and sync to server (background)
    final isos = _revealedCountries.keys.toSet();
    OfflineSyncService.saveWorldMapProgress(isos);
    _syncProgressToServer(isos.toList());
  }

  Future<void> _syncProgressToServer(List<String> isos) async {
    if (!await OfflineSyncService.isOnline()) return;
    try {
      await ApiService().saveWorldMapProgress(isos);
    } catch (_) {
      // Server sync failed — local Hive copy is the source of truth until
      // the next successful sync.
    }
  }

  /// Patches the base SVG string to apply all revealed country flag colours.
  String _applyRevealedColors() {
    if (_revealedCountries.isEmpty) return _baseSvg;

    final isoToHex = <String, String>{};
    for (final e in _revealedCountries.entries) {
      final c = e.value;
      final r = (c.r * 255).round();
      final g = (c.g * 255).round();
      final b = (c.b * 255).round();
      isoToHex[e.key.toUpperCase()] =
          '#${r.toRadixString(16).padLeft(2,'0')}${g.toRadixString(16).padLeft(2,'0')}${b.toRadixString(16).padLeft(2,'0')}'.toUpperCase();
    }

    return _baseSvg.replaceAllMapped(
      RegExp(r'<path\b([^>]*)/?>', dotAll: true),
      (m) {
        final tag   = m.group(0)!;
        final attrs = m.group(1)!;

        String? iso;
        final idMatch = RegExp(r'\bid="([^"]+)"').firstMatch(attrs);
        if (idMatch != null) {
          iso = idMatch.group(1)!.toUpperCase();
        } else {
          final clsMatch = RegExp(r'\bclass="([^"]+)"').firstMatch(attrs);
          if (clsMatch != null) {
            iso = _classToIso[clsMatch.group(1)]?.toUpperCase();
          }
        }

        if (iso != null && isoToHex.containsKey(iso)) {
          return tag.replaceFirst(
            RegExp(r'fill="[^"]*"'),
            'fill="${isoToHex[iso]}"',
          );
        }
        return tag;
      },
    );
  }

  @override
  void dispose() {
    _autoController.dispose();
    _mapTexture?.dispose();
    _interstitialAdService.dispose();
    super.dispose();
  }

  // ── Gesture handlers ───────────────────────────────────────────────────────

  void _onScaleStart(ScaleStartDetails details) {
    // Absorb any current auto-rotation into the matrix so the globe freezes
    // exactly where it is when the user touches.
    final autoAngle = _autoController.value * 2 * pi;
    if (autoAngle != 0) {
      _rotMat = _matMul3(_rotMat, _rotY(-autoAngle));
    }
    _autoController.stop();
    _autoController.value = 0;

    _tapDownPos    = details.localFocalPoint;
    _tapDownTime   = DateTime.now();
    _previousScale = 1.0;

    if (details.pointerCount > 1) _hadMultiTouch = true;
    _wasDrag = _hadMultiTouch;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (details.pointerCount > 1) {
      _hadMultiTouch = true;
      _wasDrag = true;
    } else if (_tapDownPos != null &&
        (details.localFocalPoint - _tapDownPos!).distance > 12) {
      _wasDrag = true;
    }
    setState(() {
      if (details.pointerCount <= 1) {
        final sens = 0.005 / _zoom;
        final dx = details.focalPointDelta.dx;
        final dy = details.focalPointDelta.dy;
        // Horizontal drag: post-multiply by rotY (world Y — no gimbal lock).
        // Vertical drag: post-multiply by rotX in camera space — this is the
        // fix for gimbal lock. Pre-multiplying (old approach) rotated around
        // the fixed world X-axis, which caused vertical drags to appear
        // horizontal when the globe had been panned 90° away from the start.
        if (dx != 0) _rotMat = _matMul3(_rotMat, _rotY(-dx * sens));
        if (dy != 0) _rotMat = _matMul3(_rotMat, _rotX(-dy * sens));
        _rotMat = _ortho3(_rotMat);
      }
      if (details.pointerCount > 1) {
        final scaleDelta = details.scale / _previousScale;
        _zoom = (_zoom * scaleDelta).clamp(1.0, 10.0);
        _previousScale = details.scale;
      }
    });
  }

  void _onScaleEnd(ScaleEndDetails details) {
    // Only treat this as a tap when ALL fingers are off the screen, it was
    // a single-finger gesture with no drag, and it completed quickly.
    // _activePointers is decremented by the Listener before this callback fires,
    // so == 0 means the last finger just lifted.
    if (_activePointers == 0 &&
        !_wasDrag &&
        !_hadMultiTouch &&
        _tapDownPos != null &&
        _tapDownTime != null &&
        DateTime.now().difference(_tapDownTime!).inMilliseconds < 300) {
      final pos = _tapDownPos!;
      if (_pathsLoaded && _lastSize != Size.zero) {
        final svgPt = _screenToSvg(pos, _lastSize);
        final iso   = svgPt != null ? _hitTest(svgPt) : null;
        _onCountryTapped(iso);
      }
    }

    if (_activePointers == 0) _hadMultiTouch = false;
    if (_zoom <= 2.0) _autoController.repeat();
  }

  void _onCountryTapped(String? iso) {
    if (iso == null) return;
    if (_boardOpen) return; // already showing a board — ignore
    SoundManager.playClick();
    final name = _isoToName[iso] ?? iso;
    final isRevealed = _revealedCountries.containsKey(iso);

    if (isRevealed) {
      _showRevealDialog(iso, name);
    } else {
      _showMockBoard(iso, name);
    }
  }

  void _showMockBoard(String iso, String name) {
    setState(() => _boardOpen = true);
    widget.onPlayingChanged?.call(true);
    final grid        = _buildCountryGrid(iso);
    final screenSize  = MediaQuery.of(context).size;
    final safePadding = MediaQuery.of(context).padding;
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => _MockBoardDialog(
        countryName: name,
        flagEmoji: _flagEmoji(iso),
        grid: grid,
        screenSize: screenSize,
        safePadding: safePadding,
        onWin: () {
          Navigator.of(context).pop();
          setState(() {
            _boardOpen = false;
            _consecutiveLosses = 0;
          });
          widget.onPlayingChanged?.call(false);
          revealCountry(iso);
          Future.delayed(const Duration(milliseconds: 400), () {
            if (mounted) _showRevealDialog(iso, name, showAd: true);
          });
        },
        onClose: () {
          Navigator.of(context).pop();
          setState(() => _boardOpen = false);
          widget.onPlayingChanged?.call(false);
          _consecutiveLosses++;
          if (_consecutiveLosses >= _lossesPerAd) {
            _consecutiveLosses = 0;
            _interstitialAdService.showAdNow();
          }
        },
        onLose: () {
          _consecutiveLosses++;
          if (_consecutiveLosses >= _lossesPerAd) {
            _consecutiveLosses = 0;
            _interstitialAdService.showAdNow();
          }
        },
      ),
    );
  }

  /// Builds a grid whose cells match the country's SVG shape.
  /// Uses Path.contains() on all paths for [iso] to decide which (col,row)
  /// cells fall inside the country, then scales to ~300–500 inside cells.
  _CountryGrid _buildCountryGrid(String iso) {
    final paths = _countryPathList
        .where((e) => e.$1 == iso)
        .map((e) => e.$2)
        .toList();

    if (paths.isEmpty) return _CountryGrid.fallback();

    Rect bounds = paths.first.getBounds();
    for (final p in paths.skip(1)) {
      bounds = bounds.expandToInclude(p.getBounds());
    }
    if (bounds.isEmpty || bounds.width <= 0 || bounds.height <= 0) {
      return _CountryGrid.fallback();
    }

    // Iteratively find a cellSize that gives 30–130 inside cells.
    double cellSize = max(bounds.width, bounds.height) / 10.0;
    List<(int, int)> cells = [];
    int cols = 0, rows = 0;

    for (int attempt = 0; attempt < 7; attempt++) {
      cells = [];
      cols = (bounds.width  / cellSize).ceil().clamp(1, 200);
      rows = (bounds.height / cellSize).ceil().clamp(1, 200);

      for (int r = 0; r < rows; r++) {
        for (int c = 0; c < cols; c++) {
          final pt = Offset(
            bounds.left + (c + 0.5) * cellSize,
            bounds.top  + (r + 0.5) * cellSize,
          );
          if (paths.any((p) => p.contains(pt))) cells.add((c, r));
        }
      }

      if (cells.length >= 300 && cells.length <= 500) break;
      cellSize *= (cells.length < 300) ? 0.75 : 1.25;
    }

    if (cells.length < 20) return _CountryGrid.fallback();

    final mineCount = (cells.length / 8).round().clamp(5, 60);
    return _CountryGrid(cells: cells, cols: cols, rows: rows, mineCount: mineCount);
  }

  void _showRevealDialog(String iso, String name, {bool showAd = false}) {
    final color = _revealedCountries[iso] ?? (_flagColors[iso] ?? _flagDefault);
    final fact = countryFunFacts[iso] ?? 'A fascinating country full of unique culture, history, and natural wonders waiting to be explored.';
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'dismiss',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 350),
      transitionBuilder: (_, anim, __, child) => FadeTransition(
        opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.08),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
      ),
      pageBuilder: (_, __, ___) => _RevealDialog(
        iso: iso,
        countryName: name,
        flagEmoji: _flagEmoji(iso),
        accentColor: color,
        funFact: fact,
        onAwesome: showAd ? _interstitialAdService.showAdNow : null,
      ),
    );
  }

  // ── Hit testing ────────────────────────────────────────────────────────────

  String? _hitTest(Offset svgPt) {
    for (final (iso, path) in _countryPathList.reversed) {
      if (!path.getBounds().contains(svgPt)) continue;
      if (path.contains(svgPt)) return iso;
    }
    return null;
  }

  /// Reverse-projects a screen tap through the shader math to SVG coordinates.
  Offset? _screenToSvg(Offset tap, Size size) {
    final radius = min(size.width, size.height) / 2.0;
    final cx = size.width  / 2.0;
    final cy = size.height / 2.0;

    final uvzx = (tap.dx - cx) / radius / _zoom;
    final uvzy = (tap.dy - cy) / radius / _zoom;
    final z2   = 1.0 - uvzx * uvzx - uvzy * uvzy;
    if (z2 < 0) return null;

    // Apply the current display rotation matrix (same math as the shader).
    final autoAngle = _autoController.value * 2 * pi;
    final m = autoAngle != 0 ? _matMul3(_rotMat, _rotY(-autoAngle)) : _rotMat;
    final px = uvzx, py = -uvzy, pz = sqrt(z2);
    final rpx = m[0]*px + m[1]*py + m[2]*pz;
    final rpy = m[3]*px + m[4]*py + m[5]*pz;
    final rpz = m[6]*px + m[7]*py + m[8]*pz;

    final sphereLat = asin(rpy.clamp(-1.0, 1.0));
    final sphereLon = atan2(rpx, rpz);

    final v = 0.5 - sphereLat / (2 * _latMax);
    if (v < 0.0 || v > 1.0) return null;

    return Offset(
      (0.5 + sphereLon / (2 * pi)) * _svgW,
      v * _svgH,
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Trigger initial capture once SVG is loaded
    if (!_textureReady && !_capturePending && _svgLoaded) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _captureSvgTexture());
    }

    final labelAlpha = (2.0 - _zoom).clamp(0.0, 1.0);

    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerSignal: (event) {
        if (event is PointerScrollEvent) {
          setState(() {
            final factor = event.scrollDelta.dy < 0 ? 1.12 : 0.89;
            _zoom = (_zoom * factor).clamp(1.0, 10.0);
          });
          if (_zoom > 2.0) {
            if (_autoController.isAnimating) {
              final autoAngle = _autoController.value * 2 * pi;
              if (autoAngle != 0) _rotMat = _matMul3(_rotMat, _rotY(-autoAngle));
              _autoController.stop();
              _autoController.value = 0;
            }
          } else {
            if (!_autoController.isAnimating) _autoController.repeat();
          }
        }
      },
      child: Listener(
        onPointerDown: (_) {
          _activePointers++;
          if (_activePointers > 1) _hadMultiTouch = true;
        },
        onPointerUp:     (_) => _activePointers--,
        onPointerCancel: (_) => _activePointers--,
        child: GestureDetector(
        onScaleStart: _onScaleStart,
        onScaleUpdate: _onScaleUpdate,
        onScaleEnd: _onScaleEnd,
        child: Container(
          color: Colors.black,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ── RepaintBoundary ALWAYS in tree ─────────────────────────────
              // Positioned at (0,0); Stack clips it visually but toImage()
              // captures the full _texW × _texH regardless of clip.
              Positioned(
                left: 0, top: 0,
                child: RepaintBoundary(
                  key: _svgKey,
                  child: SizedBox(
                    width: _texW,
                    height: _texH,
                    child: ColoredBox(
                      color: _oceanColor,
                      child: _svgLoaded
                          ? SvgPicture.string(_patchedSvg, fit: BoxFit.fill)
                          : const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),

              // ── Black cover (hides RepaintBoundary on-screen) ───────────
              // Globe is drawn on top of this.
              Container(color: Colors.black),

              // ── Stars ───────────────────────────────────────────────────
              if (labelAlpha > 0)
                Opacity(
                  opacity: labelAlpha,
                  child: CustomPaint(
                    painter: _StarPainter(),
                    child: const SizedBox.expand(),
                  ),
                ),

              // ── Loading overlay ─────────────────────────────────────────
              if (!_textureReady)
                const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        color: Color(0xFFFFDD00),
                        strokeWidth: 2,
                      ),
                      SizedBox(height: 20),
                      Text(
                        'Preparing globe…',
                        style: TextStyle(color: Colors.white54, fontSize: 14),
                      ),
                    ],
                  ),
                )
              else ...[
                // ── Globe ─────────────────────────────────────────────────
                _buildGlobe(),

                // ── Labels ────────────────────────────────────────────────
                if (!_boardOpen && labelAlpha > 0)
                  Positioned(
                    top: 60, left: 0, right: 0,
                    child: IgnorePointer(
                      child: Opacity(
                        opacity: labelAlpha,
                        child: _buildLabels(),
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
      ),
    );
  }

  // ── Globe ──────────────────────────────────────────────────────────────────

  Widget _buildGlobe() {
    if (_shader == null || _mapTexture == null) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFFFFDD00), strokeWidth: 2,
        ),
      );
    }

    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      final h = constraints.maxHeight;
      _lastSize = Size(w, h);

      final sphereR   = min(w, h) * 0.5;
      final glowAlpha = (2.0 - _zoom).clamp(0.0, 1.0);

      return Stack(
        fit: StackFit.expand,
        children: [
          // Atmosphere glow
          if (glowAlpha > 0.01)
            Center(
              child: Opacity(
                opacity: glowAlpha,
                child: Container(
                  width: sphereR * 2.15,
                  height: sphereR * 2.15,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1976D2).withValues(alpha: 0.5),
                        blurRadius: sphereR * 0.18,
                        spreadRadius: sphereR * 0.04,
                      ),
                      BoxShadow(
                        color: const Color(0xFF42A5F5).withValues(alpha: 0.25),
                        blurRadius: sphereR * 0.35,
                        spreadRadius: sphereR * 0.01,
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Shader globe
          AnimatedBuilder(
            animation: _autoController,
            builder: (_, __) {
              final autoAngle = _autoController.value * 2 * pi;
              final m = autoAngle != 0
                  ? _matMul3(_rotMat, _rotY(-autoAngle))
                  : _rotMat;
              return CustomPaint(
                painter: _GlobePainter(
                  shader: _shader!,
                  texture: _mapTexture!,
                  rotMat: m,
                  zoom: _zoom,
                ),
                child: const SizedBox.expand(),
              );
            },
          ),
        ],
      );
    });
  }

  Widget _buildLabels() {
    final total    = _countryPathList.length;
    final revealed = _revealedCountries.length;
    final progress = total > 0 ? revealed / total : 0.0;

    return Column(
      children: [
        const Text(
          'REVEAL THE WORLD',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFFFFDD00),
            fontFamily: 'Acsioma',
            fontSize: 22,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Drag to rotate  \u2022  Pinch to zoom  \u2022  Tap a country',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.45),
            fontSize: 13,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: _ShimmerProgressBar(value: progress),
        ),
      ],
    );
  }
}

// ── Shimmer progress bar ──────────────────────────────────────────────────────

class _ShimmerProgressBar extends StatefulWidget {
  final double value;
  const _ShimmerProgressBar({required this.value});

  @override
  State<_ShimmerProgressBar> createState() => _ShimmerProgressBarState();
}

class _ShimmerProgressBarState extends State<_ShimmerProgressBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmerCtrl;
  Timer? _idleTimer;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _scheduleNext();
  }

  void _scheduleNext() {
    final delaySecs = 15 + Random().nextInt(6); // 15–20 s
    _idleTimer = Timer(Duration(seconds: delaySecs), () {
      if (!mounted) return;
      _shimmerCtrl.forward(from: 0).then((_) {
        if (mounted) _scheduleNext();
      });
    });
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    _shimmerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmerCtrl,
      builder: (_, __) => CustomPaint(
        painter: _ShimmerBarPainter(
          progress: widget.value,
          shimmer: _shimmerCtrl.value,
        ),
        child: const SizedBox(height: 6, width: double.infinity),
      ),
    );
  }
}

class _ShimmerBarPainter extends CustomPainter {
  final double progress;
  final double shimmer;

  const _ShimmerBarPainter({required this.progress, required this.shimmer});

  @override
  void paint(Canvas canvas, Size size) {
    const radius = Radius.circular(3);

    // Background track
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, radius),
      Paint()..color = Colors.white.withValues(alpha: 0.15),
    );

    if (progress <= 0) return;

    final fillW = size.width * progress.clamp(0.0, 1.0);
    final fillRect = Rect.fromLTWH(0, 0, fillW, size.height);
    final fillRRect = RRect.fromRectAndRadius(fillRect, radius);

    // Filled bar
    canvas.drawRRect(fillRRect, Paint()..color = const Color(0xFFFFDD00));

    // Shimmer highlight — sweeps left→right clipped to the filled area
    if (shimmer > 0 && shimmer < 1) {
      final eased = Curves.easeInOut.transform(shimmer);
      final cx = eased * fillW;
      const hw = 50.0; // half-width of the glow band

      canvas.save();
      canvas.clipRRect(fillRRect);
      canvas.drawRect(
        Rect.fromLTWH(cx - hw, 0, hw * 2, size.height),
        Paint()
          ..shader = LinearGradient(
            colors: [
              Colors.white.withValues(alpha: 0),
              Colors.white.withValues(alpha: 0.65),
              Colors.white.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromLTWH(cx - hw, 0, hw * 2, size.height)),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ShimmerBarPainter old) =>
      old.progress != progress || old.shimmer != shimmer;
}

// ── Painters ──────────────────────────────────────────────────────────────────

class _GlobePainter extends CustomPainter {
  final ui.FragmentShader shader;
  final ui.Image texture;
  final List<double> rotMat; // row-major 3×3
  final double zoom;

  const _GlobePainter({
    required this.shader,
    required this.texture,
    required this.rotMat,
    required this.zoom,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Uniform layout (matches globe.frag declaration order):
    //   vec2  uResolution → slots 0, 1
    //   float uZoom       → slot  2
    //   vec3  uRow0       → slots 3, 4, 5  (row 0 of rotation matrix)
    //   vec3  uRow1       → slots 6, 7, 8  (row 1)
    //   vec3  uRow2       → slots 9, 10, 11 (row 2)
    shader.setFloat(0, size.width);
    shader.setFloat(1, size.height);
    shader.setFloat(2, zoom);
    for (int i = 0; i < 9; i++) { shader.setFloat(3 + i, rotMat[i]); }
    shader.setImageSampler(0, texture);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..shader = shader,
    );
  }

  @override
  bool shouldRepaint(_GlobePainter old) {
    if (old.zoom != zoom) return true;
    for (int i = 0; i < 9; i++) {
      if (old.rotMat[i] != rotMat[i]) return true;
    }
    return false;
  }
}

// ── Country grid data ─────────────────────────────────────────────────────────

class _CountryGrid {
  final List<(int, int)> cells; // (col, row) pairs inside the country shape
  final int cols;
  final int rows;
  final int mineCount;

  const _CountryGrid({
    required this.cells,
    required this.cols,
    required this.rows,
    required this.mineCount,
  });

  factory _CountryGrid.fallback() {
    const c = 20, r = 15;
    return _CountryGrid(
      cells: [for (int row = 0; row < r; row++) for (int col = 0; col < c; col++) (col, row)],
      cols: c,
      rows: r,
      mineCount: 37,
    );
  }
}

// ── Mock minesweeper board dialog ─────────────────────────────────────────────

class _MockBoardDialog extends StatefulWidget {
  final String countryName;
  final String flagEmoji;
  final _CountryGrid grid;
  final Size screenSize;
  final EdgeInsets safePadding;
  final VoidCallback onWin;
  final VoidCallback onClose;
  final VoidCallback? onLose;

  const _MockBoardDialog({
    required this.countryName,
    required this.flagEmoji,
    required this.grid,
    required this.screenSize,
    required this.safePadding,
    required this.onWin,
    required this.onClose,
    this.onLose,
  });

  @override
  State<_MockBoardDialog> createState() => _MockBoardDialogState();
}

class _MockBoardDialogState extends State<_MockBoardDialog>
    with TickerProviderStateMixin {
  // Per-cell state:  0=covered  1=revealed safe  2=mine hit
  late List<int>  _cellState;
  late List<bool> _mines;
  late List<int>  _adjCounts;
  late List<bool> _flagged;
  late Map<(int, int), int> _cellIndex;
  bool _gameOver = false;
  bool _won      = false;
  int? _tappedBombCol;
  int? _tappedBombRow;

  // Fixed cell size in board-space pixels (user zooms with InteractiveViewer)
  static const double _cellPx = 22.0;

  // Zoom / pan controller — initialised with a fitted scale in initState
  late final TransformationController _txCtrl;
  late final Matrix4 _initialTransform;

  // The initial fit scale is stored so it can be used as minScale
  late final double _fitScale;

  // Tap / long-press tracking
  Offset? _pointerDown;
  Timer?  _longPressTimer;
  Offset? _longPressPos;

  // Reset-to-center animation
  AnimationController? _resetCtrl;

  // Win fade-to-black overlay
  AnimationController? _winFadeCtrl;

  // Key on InteractiveViewer so we can convert board-space → screen-space
  final GlobalKey _viewerKey = GlobalKey();

  // Overlay entries for flag ripples
  final List<OverlayEntry> _activeOverlays = [];

  @override
  void initState() {
    super.initState();
    _initBoard();

    final boardW  = widget.grid.cols * _cellPx;
    final boardH  = widget.grid.rows * _cellPx;
    final screen  = widget.screenSize;
    final safe    = widget.safePadding;

    // Scale so the board fits within ~88 % of width and ~65 % of usable height
    final usableH = screen.height - safe.top - safe.bottom;
    _fitScale = min(
      screen.width * 0.88 / boardW,
      usableH      * 0.65 / boardH,
    ).clamp(0.10, 5.0);

    // Translate so the board is centred on screen
    final tx = (screen.width  - boardW * _fitScale) / 2;
    final ty = (usableH       - boardH * _fitScale) / 2 + safe.top - 24;

    _initialTransform = Matrix4.identity()
      ..translate(tx, ty, 0.0)
      ..scale(_fitScale, _fitScale, 1.0);

    _txCtrl = TransformationController(_initialTransform.clone());
  }

  @override
  void dispose() {
    _longPressTimer?.cancel();
    _resetCtrl?.dispose();
    _winFadeCtrl?.dispose();
    for (final e in _activeOverlays) {
      try { e.remove(); } catch (_) {}
    }
    _activeOverlays.clear();
    _txCtrl.dispose();
    super.dispose();
  }

  void _initBoard() {
    final cells = widget.grid.cells;
    final n     = cells.length;
    _gameOver   = false;
    _won        = false;
    _cellState  = List.filled(n, 0);
    _mines      = List.filled(n, false);
    _adjCounts  = List.filled(n, 0);
    _flagged    = List.filled(n, false);
    _cellIndex  = { for (int i = 0; i < n; i++) cells[i]: i };

    final indices = List.generate(n, (i) => i)..shuffle(Random());
    for (int i = 0; i < widget.grid.mineCount; i++) {
      _mines[indices[i]] = true;
    }

    for (int i = 0; i < n; i++) {
      if (_mines[i]) { _adjCounts[i] = -1; continue; }
      final (col, row) = cells[i];
      int count = 0;
      for (int dr = -1; dr <= 1; dr++) {
        for (int dc = -1; dc <= 1; dc++) {
          if (dr == 0 && dc == 0) continue;
          final ni = _cellIndex[(col + dc, row + dr)];
          if (ni != null && _mines[ni]) count++;
        }
      }
      _adjCounts[i] = count;
    }
  }

  void _onTap(int idx) {
    if (_gameOver || _cellState[idx] != 0 || _flagged[idx]) return;
    setState(() {
      if (_mines[idx]) {
        final (tc, tr) = widget.grid.cells[idx];
        _tappedBombCol = tc;
        _tappedBombRow = tr;
        for (int i = 0; i < _mines.length; i++) {
          if (_mines[i]) _cellState[i] = 2;
        }
        _gameOver = true;
        SoundManager.playExplode();
        SoundManager.vibrateExplode();
      } else {
        _floodReveal(idx);
        SoundManager.playReveal();
        SoundManager.vibrateReveal();
        _checkWin();
      }
    });
  }

  void _checkWin() {
    final allSafeRevealed = !Iterable.generate(_mines.length)
        .any((i) => !_mines[i] && _cellState[i] == 0);
    final allMinesFlagged = !Iterable.generate(_mines.length)
        .any((i) => _mines[i] && !_flagged[i]);
    if (allSafeRevealed && allMinesFlagged) {
      _gameOver = true;
      _won      = true;
      SoundManager.playWon();
      SoundManager.vibrateWin();
      _winFadeCtrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 600),
      )..forward();
      Future.delayed(const Duration(milliseconds: 800), widget.onWin);
    }
  }

  void _onLongPress(Offset boardPos) {
    if (_gameOver) return;
    final col = (boardPos.dx / _cellPx).floor();
    final row = (boardPos.dy / _cellPx).floor();
    final idx = _cellIndex[(col, row)];
    if (idx == null || _cellState[idx] != 0) return;
    final currentFlags = _flagged.where((f) => f).length;
    if (!_flagged[idx] && currentFlags >= widget.grid.mineCount) return;
    setState(() {
      _flagged[idx] = !_flagged[idx];
      _checkWin();
    });
    if (_flagged[idx]) {
      _triggerFlagRipple(col, row);
      SoundManager.playFlag();
      SoundManager.vibrateFlag();
    } else {
      SoundManager.playUnflag();
      SoundManager.vibrateUnflag();
    }
  }

  void _floodReveal(int idx) {
    if (_cellState[idx] != 0 || _mines[idx] || _flagged[idx]) return;
    _cellState[idx] = 1;
    final (col, row) = widget.grid.cells[idx];
    _triggerPeelAnimation(col, row);
    if (_adjCounts[idx] == 0) {
      for (int dr = -1; dr <= 1; dr++) {
        for (int dc = -1; dc <= 1; dc++) {
          final ni = _cellIndex[(col + dc, row + dr)];
          if (ni != null) _floodReveal(ni);
        }
      }
    }
  }

  /// Converts a board-space cell position to screen-space offset.
  Offset _cellScreenOffset(int col, int row) {
    final m = _txCtrl.value;
    return MatrixUtils.transformPoint(
      m, Offset(col * _cellPx, row * _cellPx));
  }

  double get _currentScale => _txCtrl.value.entry(0, 0);

  void _triggerPeelAnimation(int col, int row) {
    final delayMs = row * 20 + col * 6;
    Timer(Duration(milliseconds: delayMs), () {
      if (!mounted) return;
      final viewerBox    = _viewerKey.currentContext?.findRenderObject() as RenderBox?;
      final viewerOrigin = viewerBox?.localToGlobal(Offset.zero) ?? Offset.zero;
      final localOff     = _cellScreenOffset(col, row);
      final screenOff    = viewerOrigin + localOff;
      final tileScreen   = Size(_cellPx * _currentScale, _cellPx * _currentScale);
      PeelParticleSystem.instance.addParticle(screenOff, tileScreen, context);
    });
  }

  void _triggerFlagRipple(int col, int row) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // _cellScreenOffset gives coords in InteractiveViewer local space.
      // Add the viewer's own screen position to get true screen coords.
      final viewerBox = _viewerKey.currentContext?.findRenderObject() as RenderBox?;
      final viewerOrigin = viewerBox?.localToGlobal(Offset.zero) ?? Offset.zero;
      final localOff  = _cellScreenOffset(col, row);
      final scale     = _currentScale;
      final center    = viewerOrigin + localOff + Offset(_cellPx * scale / 2, _cellPx * scale / 2);
      late OverlayEntry entry;
      entry = OverlayEntry(
        builder: (_) => _BoardFlagRipple(
          center: center,
          onComplete: () {
            _activeOverlays.remove(entry);
            try { entry.remove(); } catch (_) {}
          },
        ),
      );
      _activeOverlays.add(entry);
      Overlay.of(context).insert(entry);
    });
  }

  @override
  Widget build(BuildContext context) {
    final safe   = widget.safePadding;
    final boardW = widget.grid.cols * _cellPx;
    final boardH = widget.grid.rows * _cellPx;

    return Dialog.fullscreen(
      backgroundColor: Colors.transparent,
      child: Material(
        color: Colors.transparent,
        child: Stack(
          fit: StackFit.expand,
          children: [

            // ── Zoomable / pannable board ────────────────────────────────────
            // InteractiveViewer(constrained:false) lets the board live in its
            // own coordinate space. The Listener inside receives localPosition
            // already transformed back to board-pixel space by the framework,
            // so col = localPosition.dx / _cellPx is always correct regardless
            // of current zoom / pan state.
            InteractiveViewer(
              key: _viewerKey,
              transformationController: _txCtrl,
              constrained: false,
              minScale: _fitScale,
              maxScale: 12.0,
              boundaryMargin: EdgeInsets.all(double.infinity),
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (e) {
                  _pointerDown    = e.localPosition;
                  _longPressPos   = e.localPosition;
                  _longPressTimer?.cancel();
                  _longPressTimer = Timer(
                    const Duration(milliseconds: 450),
                    () {
                      final pos = _longPressPos;
                      _pointerDown = null; // prevent tap from also firing
                      if (pos != null) _onLongPress(pos);
                    },
                  );
                },
                onPointerMove: (e) {
                  // If finger moves more than 10 board-px, it's a pan — kill the
                  // long-press timer and the pending tap so neither fires.
                  final down = _pointerDown;
                  if (down != null &&
                      (e.localPosition - down).distance > 10) {
                    _longPressTimer?.cancel();
                    _longPressTimer = null;
                    _pointerDown    = null;
                    _longPressPos   = null;
                  }
                },
                onPointerUp: (e) {
                  _longPressTimer?.cancel();
                  _longPressTimer = null;
                  _longPressPos   = null;
                  final down = _pointerDown;
                  _pointerDown = null;
                  if (down == null) return;
                  if ((e.localPosition - down).distance > 8) return;
                  final col = (e.localPosition.dx / _cellPx).floor();
                  final row = (e.localPosition.dy / _cellPx).floor();
                  final idx = _cellIndex[(col, row)];
                  if (idx != null) _onTap(idx);
                },
                onPointerCancel: (_) {
                  _longPressTimer?.cancel();
                  _longPressTimer = null;
                  _pointerDown    = null;
                  _longPressPos   = null;
                },
                child: RepaintBoundary(
                  child: SizedBox(
                    width: boardW,
                    height: boardH,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        CustomPaint(
                          size: Size(boardW, boardH),
                          painter: _BoardPainter(
                            cells:      widget.grid.cells,
                            cellStates: _cellState,
                            adjCounts:  _adjCounts,
                            flagged:    _flagged,
                            cellPx:     _cellPx,
                            rows:       widget.grid.rows,
                          ),
                        ),
                        // Flag icons overlaid as Flutter widgets (reliable across all platforms)
                        for (int i = 0; i < widget.grid.cells.length; i++)
                          if (_flagged[i])
                            Positioned(
                              left: widget.grid.cells[i].$1 * _cellPx,
                              top:  widget.grid.cells[i].$2 * _cellPx,
                              width:  _cellPx - 1,
                              height: _cellPx - 1,
                              child: Center(
                                child: Image.asset('assets/flag.webp', width: 14, height: 14),
                              ),
                            ),
                        // Animated bomb cells overlaid for revealed mine cells
                        for (int i = 0; i < widget.grid.cells.length; i++)
                          if (_cellState[i] == 2)
                            Positioned(
                              left: widget.grid.cells[i].$1 * _cellPx,
                              top:  widget.grid.cells[i].$2 * _cellPx,
                              width:  _cellPx - 1,
                              height: _cellPx - 1,
                              child: _AnimatedBombCell(
                                cellPx: _cellPx,
                                delayMs: (() {
                                  final tc = _tappedBombCol ?? widget.grid.cells[i].$1;
                                  final tr = _tappedBombRow ?? widget.grid.cells[i].$2;
                                  final dc = (widget.grid.cells[i].$1 - tc).abs();
                                  final dr = (widget.grid.cells[i].$2 - tr).abs();
                                  return ((dc + dr) * 60).clamp(0, 500);
                                })(),
                              ),
                            ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ── Top bar: mine count (left) • close (right) • hint below ────
            Positioned(
              top: safe.top + 12,
              left: 14,
              right: 14,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Mine count — left
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0B1E3D).withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Image.asset('assets/bombRevealed.webp', width: 30, height: 30),
                            const SizedBox(width: 6),
                            Text(
                              '${widget.grid.mineCount - _flagged.where((f) => f).length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Close — right
                      GestureDetector(
                        onTap: widget.onClose,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFF0B1E3D).withValues(alpha: 0.85),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white24),
                          ),
                          child: const Icon(Icons.close, color: Colors.white70, size: 20),
                        ),
                      ),
                    ],
                  ),
                  if (!_gameOver) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Clear the mines to reveal this country!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // ── Bottom bar — covers globe-screen text showing through ────────
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                height: safe.bottom + 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.70),
                      Colors.black.withValues(alpha: 0.85),
                    ],
                  ),
                ),
              ),
            ),


            // ── Bottom: try again ────────────────────────────────────────────
            if (_gameOver && !_won)
              Positioned(
                bottom: safe.bottom + 120,
                left: 0, right: 0,
                child: Center(
                  child: ClickButton(
                    onPressed: () async {
                      widget.onLose?.call();
                      _resetCtrl?.dispose();
                      _resetCtrl = AnimationController(
                        vsync: this,
                        duration: const Duration(milliseconds: 450),
                      );
                      final anim = Matrix4Tween(
                        begin: _txCtrl.value.clone(),
                        end:   _initialTransform.clone(),
                      ).animate(CurvedAnimation(
                        parent: _resetCtrl!,
                        curve: Curves.easeInOut,
                      ));
                      anim.addListener(() => _txCtrl.value = anim.value);
                      _resetCtrl!.forward();
                      setState(_initBoard);
                    },
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                    ),
                    child: Container(
                      width: 220,
                      height: 52,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0B1E3D),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFFA200).withValues(alpha: 0.45),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text(
                          'TRY AGAIN',
                          style: TextStyle(
                            color: Color(0xFFFFDD00),
                            fontFamily: 'Acsioma',
                            fontSize: 20,
                            fontWeight: FontWeight.normal,
                            letterSpacing: 1,
                            shadows: [
                              Shadow(
                                color: Colors.black,
                                blurRadius: 10,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // ── Win fade-to-black overlay ──────────────────────────────────
            if (_won && _winFadeCtrl != null)
              AnimatedBuilder(
                animation: _winFadeCtrl!,
                builder: (_, __) => IgnorePointer(
                  child: Container(
                    color: Colors.black.withValues(alpha: _winFadeCtrl!.value),
                  ),
                ),
              ),

          ],
        ),
      ),
    );
  }
}

// ── Board painter ─────────────────────────────────────────────────────────────

class _BoardPainter extends CustomPainter {
  final List<(int, int)> cells;
  final List<int>  cellStates; // 0=covered, 1=revealed, 2=mine
  final List<int>  adjCounts;
  final List<bool> flagged;
  final double     cellPx;
  final int        rows; // total grid rows, used for neon gradient

  const _BoardPainter({
    required this.cells,
    required this.cellStates,
    required this.adjCounts,
    required this.flagged,
    required this.cellPx,
    required this.rows,
  });

  /// Neon spectrum top-to-bottom (cool palette — no red/pink):
  ///   row 0   → neon mint       #00FFD0
  ///   row 33% → electric cyan   #00CCFF
  ///   row 66% → electric blue   #0055FF
  ///   row 100%→ neon violet     #7700FF
  static Color _neonForRow(int row, int totalRows) {
    if (totalRows <= 1) return const Color(0xFF00FFD0);
    final t = (row / (totalRows - 1)).clamp(0.0, 1.0);
    const c0 = Color(0xFF00FFD0); // neon mint
    const c1 = Color(0xFF00CCFF); // electric cyan
    const c2 = Color(0xFF0055FF); // electric blue
    const c3 = Color(0xFF7700FF); // neon violet
    if (t < 0.33) return Color.lerp(c0, c1, t / 0.33)!;
    if (t < 0.66) return Color.lerp(c1, c2, (t - 0.33) / 0.33)!;
    return Color.lerp(c2, c3, (t - 0.66) / 0.34)!;
  }

  void _drawButton(Canvas canvas, int col, int row, Color neon,
      {bool pressed = false}) {
    const gap    = 1.0;
    const r      = Radius.circular(4.0);
    final bevel  = (cellPx * 0.14).clamp(1.5, 3.5);
    final x = col * cellPx;
    final y = row * cellPx;
    final w = cellPx - gap;
    final h = cellPx - gap;

    if (pressed) {
      // Pressed / revealed — flat inset look
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), r),
        Paint()..color = Color.lerp(neon, Colors.black, 0.45)!,
      );
      return;
    }

    // ── Bottom-right shadow (makes the button look raised) ───────────────
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(x, y + bevel, w, h - bevel), r),
      Paint()..color = Color.lerp(neon, Colors.black, 0.50)!,
    );

    // ── Main face: diagonal gradient (bright top-left → dark bottom-right)
    final faceRect = Rect.fromLTWH(x, y, w, h - bevel);
    canvas.drawRRect(
      RRect.fromRectAndRadius(faceRect, r),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(neon, Colors.white, 0.40)!,
            neon,
            Color.lerp(neon, Colors.black, 0.22)!,
          ],
          stops: const [0.0, 0.50, 1.0],
        ).createShader(faceRect),
    );

    // ── Thin top-edge highlight ──────────────────────────────────────────
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x + bevel * 0.5, y + 0.5, w - bevel, bevel * 0.7),
        const Radius.circular(2),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.40),
    );

    // ── Subtle dark outer border ─────────────────────────────────────────
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), r),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
  }

  void _paintText(Canvas canvas, String text, double fontSize,
      Color color, int col, int row) {
    const gap = 1.0;
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(
        col * cellPx + (cellPx - gap - tp.width)  / 2,
        row * cellPx + (cellPx - gap - tp.height) / 2,
      ),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    const gap    = 1.0;
    const radius = Radius.circular(4.0);

    // Revealed tile paints (shared across all cells)
    final revealedPaint = Paint()..color = const Color(0xFFBDBDBD);
    final borderPaint   = Paint()
      ..color = Colors.black.withValues(alpha: 0.60)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    for (int i = 0; i < cells.length; i++) {
      final (col, row) = cells[i];
      final neon = _neonForRow(row, rows);

      final baseRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(col * cellPx, row * cellPx, cellPx - gap, cellPx - gap),
        radius,
      );

      switch (cellStates[i]) {

        // ── Covered ──────────────────────────────────────────────────────
        case 0:
          _drawButton(canvas, col, row, neon);

        // ── Revealed safe ────────────────────────────────────────────────
        case 1:
          // Inset / pressed look: dark inner shadow ring
          canvas.drawRRect(baseRect, revealedPaint);
          canvas.drawRRect(baseRect, borderPaint);
          // Inner shadow to look sunken
          canvas.drawRRect(
            baseRect,
            Paint()
              ..color = Colors.black.withValues(alpha: 0.12)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.5,
          );
          final adj = adjCounts[i];
          if (adj > 0) {
            _paintText(canvas, '$adj', cellPx * 0.55, Colors.black, col, row);
          }

        // ── Mine hit — background drawn by _AnimatedBombCell overlay ────
        case 2:
          // Draw a subtle dark base so the cell isn't blank before the
          // animated overlay scales in.
          canvas.drawRRect(baseRect, Paint()..color = const Color(0xFF4A0000));
      }
    }
  }

  @override
  bool shouldRepaint(_BoardPainter old) => true;
}

// ── Board flag ripple ─────────────────────────────────────────────────────────

class _BoardFlagRipple extends StatefulWidget {
  final Offset center;
  final VoidCallback onComplete;
  const _BoardFlagRipple({required this.center, required this.onComplete});
  @override
  State<_BoardFlagRipple> createState() => _BoardFlagRippleState();
}

class _BoardFlagRippleState extends State<_BoardFlagRipple>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    )..forward().whenComplete(widget.onComplete);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) {
          final t       = Curves.easeOut.transform(_ctrl.value);
          final radius  = 10.0 + t * 44.0;
          final opacity = (1.0 - t).clamp(0.0, 1.0);
          return Stack(children: [
            Positioned(
              left: widget.center.dx - radius,
              top:  widget.center.dy - radius,
              width: radius * 2, height: radius * 2,
              child: Opacity(
                opacity: opacity,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.red.shade400, width: 2.0),
                  ),
                ),
              ),
            ),
          ]);
        },
      ),
    );
  }
}

// ── Reveal celebration dialog ─────────────────────────────────────────────────

class _RevealDialog extends StatefulWidget {
  final String iso;
  final String countryName;
  final String flagEmoji;
  final Color  accentColor;
  final String funFact;
  final VoidCallback? onAwesome;

  const _RevealDialog({
    required this.iso,
    required this.countryName,
    required this.flagEmoji,
    required this.accentColor,
    required this.funFact,
    this.onAwesome,
  });

  @override
  State<_RevealDialog> createState() => _RevealDialogState();
}

class _RevealDialogState extends State<_RevealDialog>
    with SingleTickerProviderStateMixin {
  static const String _title = 'CONGRATULATIONS!';
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: _title.length * 55),
    )..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 360),
        decoration: BoxDecoration(
          color: const Color(0xFF0D1B2A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: widget.accentColor.withValues(alpha: 0.6), width: 2),
          boxShadow: [
            BoxShadow(
              color: widget.accentColor.withValues(alpha: 0.3),
              blurRadius: 32,
              spreadRadius: 4,
            ),
          ],
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Animated letter-by-letter title
                  AnimatedBuilder(
                    animation: _ctrl,
                    builder: (_, __) {
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(_title.length, (i) {
                          final t = ((_ctrl.value * _title.length) - i).clamp(0.0, 1.0);
                          final scale = Curves.elasticOut.transform(t);
                          return Transform.scale(
                            scale: scale,
                            child: Opacity(
                              opacity: t.clamp(0.0, 1.0),
                              child: Text(
                                _title[i],
                                style: const TextStyle(
                                  color: Color(0xFFFFDD00),
                                  fontFamily: 'Acsioma',
                                  fontSize: 14,
                                  letterSpacing: 2,
                                ),
                              ),
                            ),
                          );
                        }),
                      );
                    },
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'YOU REVEALED',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      letterSpacing: 3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.countryName,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: widget.accentColor,
                      fontFamily: 'Acsioma',
                      fontSize: 22,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Flag emoji in a circle
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF0B2448),
                      border: Border.all(
                        color: widget.accentColor.withValues(alpha: 0.5),
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        widget.flagEmoji,
                        style: const TextStyle(fontSize: 48),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Fun fact
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0B2448),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: widget.accentColor.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      widget.funFact,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        widget.onAwesome?.call();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.accentColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text(
                        'AWESOME!',
                        style: TextStyle(
                          fontFamily: 'Acsioma',
                          letterSpacing: 2,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // X button — hidden when the AWESOME button is present
            if (widget.onAwesome == null)
            Positioned(
              top: 10,
              right: 10,
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                  child: const Icon(Icons.close, color: Colors.white54, size: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _StarPainter extends CustomPainter {
  static final List<Offset> _pos = List.generate(
    220,
    (i) => Offset(Random(i * 13 + 7).nextDouble(), Random(i * 17 + 3).nextDouble()),
  );
  static final List<double> _r =
      List.generate(220, (i) => Random(i * 31).nextDouble() * 1.4 + 0.3);
  static final List<double> _a =
      List.generate(220, (i) => Random(i * 19).nextDouble() * 0.55 + 0.4);

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < _pos.length; i++) {
      canvas.drawCircle(
        Offset(_pos[i].dx * size.width, _pos[i].dy * size.height),
        _r[i],
        Paint()..color = Colors.white.withValues(alpha: _a[i]),
      );
    }
  }

  @override
  bool shouldRepaint(_StarPainter _) => false;
}

// ── Animated bomb cell ────────────────────────────────────────────────────────

class _AnimatedBombCell extends StatefulWidget {
  final double cellPx;
  final int    delayMs;
  const _AnimatedBombCell({required this.cellPx, required this.delayMs});

  @override
  State<_AnimatedBombCell> createState() => _AnimatedBombCellState();
}

class _AnimatedBombCellState extends State<_AnimatedBombCell>
    with TickerProviderStateMixin {
  late final AnimationController _scaleCtrl;
  late final AnimationController _pulseCtrl;
  late final Animation<double>   _scaleAnim;
  late final Animation<double>   _pulseAnim;
  late final Animation<Color?>   _colorAnim;
  Timer? _delayTimer;

  @override
  void initState() {
    super.initState();
    _scaleCtrl = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );
    _pulseCtrl = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _scaleAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scaleCtrl, curve: Curves.elasticOut),
    );
    _pulseAnim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _colorAnim = ColorTween(
      begin: Colors.red.shade400,
      end:   Colors.yellow.shade400,
    ).animate(_pulseAnim);

    _delayTimer = Timer(Duration(milliseconds: widget.delayMs), () {
      if (!mounted) return;
      _scaleCtrl.forward();
      _pulseCtrl.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _scaleCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.cellPx - 1;
    return AnimatedBuilder(
      animation: Listenable.merge([_scaleAnim, _pulseAnim]),
      builder: (_, __) {
        final color = _colorAnim.value ?? Colors.red.shade400;
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: Colors.black.withValues(alpha: 0.6),
              width: 0.8,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.65 * _pulseAnim.value),
                blurRadius: 10.0 * _pulseAnim.value,
                spreadRadius: 2.5 * _pulseAnim.value,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Transform.scale(
            scale: _scaleAnim.value,
            child: Image.asset(
              'assets/bombRevealed.webp',
              width:  widget.cellPx * 0.62,
              height: widget.cellPx * 0.62,
            ),
          ),
        );
      },
    );
  }
}
