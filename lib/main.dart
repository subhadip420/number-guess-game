import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:number_guess_game/privacy_policy_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'glass_settings_menu.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Google Mobile Ads
  await MobileAds.instance.initialize();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // App theme state (Dark / Light)
  bool isDark = true;

  /// Load saved theme from SharedPreferences
  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      isDark = prefs.getBool('isDark') ?? true;
    });
  }

  /// Save theme preference
  Future<void> _saveTheme(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDark', value);
  }

  @override
  void initState() {
    super.initState();
    // Restore previously selected theme
    _loadTheme();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: isDark ? Brightness.dark : Brightness.light,
        scaffoldBackgroundColor: isDark
            ? const Color(0xFF1E1E2C)
            : Colors.lightBlue.shade50,
      ),
      home: GuessGame(
        toggleTheme: () async {
          setState(() {
            isDark = !isDark;
          });
          await _saveTheme(isDark);
        },
        isDark: isDark,
      ),
    );
  }
}

class GuessGame extends StatefulWidget {
  final VoidCallback toggleTheme;
  final bool isDark;

  const GuessGame({super.key, required this.toggleTheme, required this.isDark});

  @override
  State<GuessGame> createState() => _GuessGameState();
}

class _GuessGameState extends State<GuessGame>
    with SingleTickerProviderStateMixin {
  // User input controller
  final TextEditingController _controller = TextEditingController();

  // Random number generator
  final Random _random = Random();

  // Sound player
  final AudioPlayer _player = AudioPlayer();

  // Confetti animation controller
  late ConfettiController _confettiController;

  // Secret target number
  late int _targetNumber;

  // Wrong guess shake animation
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  // Current game status
  String _message = "Guess a number between 1 and 100";
  int _attempts = 0;

  // Score history and best score
  List<int> scoreHistory = [];
  int? highestScore;

  bool _showAllHistory = false;

  // Round state
  bool _roundCompleted = false;

  // Sound setting
  bool _soundEnabled = true;

  // Button press animation
  bool _clickAnim = false;

  // Banner Ads
  BannerAd? _topBannerAd;
  BannerAd? _bottomBannerAd;

  bool _isTopBannerReady = false;
  bool _isBottomBannerReady = false;

  // Native Ad
  NativeAd? _nativeAd;
  bool _isNativeAdLoaded = false;

  // Full-screen Ads
  InterstitialAd? _interstitialAd;
  RewardedAd? _rewardedAd;

  // Gameplay stats

  int _roundCounter = 0;
  int _hintCount = 0;

  @override
  void initState() {
    super.initState();
    // Generate first target number
    _targetNumber = _random.nextInt(100) + 1;

    // Confetti setup
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 2),
    );

    // Load saved data and settings
    _loadSavedData();
    _loadSoundSetting();

    // Load ads
    _loadBannerAds();
    _loadNativeAd();
    _loadInterstitialAd();
    _loadRewardedAd();

    // Shake animation setup
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _shakeAnimation = CurvedAnimation(
      parent: _shakeController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    // Dispose animations, audio and ads
    _confettiController.dispose();
    _player.dispose();
    _shakeController.dispose();

    _topBannerAd?.dispose();
    _bottomBannerAd?.dispose();
    _nativeAd?.dispose();

    super.dispose();
  }

  /// Load top and bottom banner ads
  void _loadBannerAds() {
    // Top Banner Ad
    _topBannerAd = BannerAd(
      //adUnitId: 'ca-app-pub-3940256099942544/6300978111', // Test BannerAd
      adUnitId: 'ca-app-pub-5454466291921987/3550650192',  //Real BannerAd id
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          setState(() {
            _isTopBannerReady = true;
          });
        },
      ),
    )..load();

    // Bottom Banner Ad
    _bottomBannerAd = BannerAd(
      //adUnitId: 'ca-app-pub-3940256099942544/6300978111', // Test Banner Ad
      adUnitId: 'ca-app-pub-5454466291921987/3550650192',  //Real BannerAd id
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          setState(() {
            _isBottomBannerReady = true;
          });
        },
      ),
    )..load();
  }

  /// Load native ad for score history section
  void _loadNativeAd() {
    _nativeAd = NativeAd(
      //adUnitId: 'ca-app-pub-3940256099942544/2247696110', // Test Native Ad
      adUnitId: 'ca-app-pub-5454466291921987/8643194771', // Real Native Ad

      listener: NativeAdListener(
        onAdLoaded: (ad) {
          setState(() {
            _isNativeAdLoaded = true;
          });
        },

        onAdFailedToLoad: (ad, error) {
          ad.dispose();
        },
      ),

      request: const AdRequest(),

      nativeTemplateStyle: NativeTemplateStyle(
        templateType: TemplateType.medium,
      ),
    );

    _nativeAd!.load();
  }

  /// Load full-screen interstitial ad
  void _loadInterstitialAd() {
    InterstitialAd.load(
      //adUnitId: 'ca-app-pub-3940256099942544/1033173712', //Test Interstitial Ad Id
      adUnitId: 'ca-app-pub-5454466291921987/1147848130', //Real Interstitial Ad Id
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
        },
        onAdFailedToLoad: (error) {
          _interstitialAd = null;
        },
      ),
    );
  }

  /// Show full-screen interstitial ad
  void _showInterstitialAd() {
    if (_interstitialAd == null) return;

    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      // Reload ad after closing
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();

        _loadInterstitialAd();
      },

      // Reload ad if failed to show
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();

        _loadInterstitialAd();
      },
    );

    _interstitialAd!.show();

    _interstitialAd = null;
  }

  /// Load rewarded ad for hints
  void _loadRewardedAd() {
    RewardedAd.load(
      //adUnitId: 'ca-app-pub-3940256099942544/5224354917', //Test Rewarded Ad Id
      adUnitId: 'ca-app-pub-5454466291921987/2209648363', //Real Rewarded Ad Id
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
        },
        onAdFailedToLoad: (error) {
          _rewardedAd = null;
        },
      ),
    );
  }

  /// Show rewarded ad and give hint reward
  void _showRewardedAd() {
    if (_rewardedAd == null) return;

    _rewardedAd!.show(
      onUserEarnedReward: (ad, reward) {
        // User earned a hint
        _giveHint();
      },
    );

    _rewardedAd = null;
    // Preload next rewarded ad
    _loadRewardedAd();
  }

  /// Generate progressive hints for current target number
  void _giveHint() {
    _hintCount++;

    String hint = "";

    switch (_hintCount) {
      // Hint 1: Higher or lower than 50
      case 1:
        hint = _targetNumber > 50
            ? "💡 Number is Greater than 50"
            : "💡 Number is Less than or Equal to 50";
        break;

      // Hint 2: Number range
      case 2:
        int start = (_targetNumber ~/ 10) * 10;
        int end = start + 10;

        hint = "💡 Number is between $start and $end";
        break;

      // Hint 3: Odd or even
      case 3:
        hint = _targetNumber % 2 == 0
            ? "💡 Number is Even"
            : "💡 Number is Odd";
        break;
    }

    setState(() {
      _message = hint;
    });
  }

  /// Load sound preference
  Future<void> _loadSoundSetting() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _soundEnabled = prefs.getBool('soundEnabled') ?? true;
    });
  }

  /// Save sound preference
  Future<void> _saveSoundSetting() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('soundEnabled', _soundEnabled);
  }

  /// Clear saved score history and best score
  Future<void> _clearAllHistory() async {
    FocusManager.instance.primaryFocus?.unfocus();

    final prefs = await SharedPreferences.getInstance();

    await prefs.remove('scoreHistory');
    await prefs.remove('highestScore');

    setState(() {
      scoreHistory.clear();
      highestScore = null;
    });

    Fluttertoast.showToast(msg: "Round history deleted successfully.");
  }

  /// Show clear history bottom sheet
  void _showClearOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: widget.isDark ? const Color(0xFF1C1C2E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Clear History",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),

              //const SizedBox(height: 20),
              Divider(color: Colors.white24, thickness: 1),

              // Delete all saved round history
              ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.red),
                title: const Text(
                  "Delete All Round History.",
                  style: TextStyle(color: Colors.red),
                ),

                onTap: () async {
                  Navigator.pop(context);

                  await Future.delayed(const Duration(milliseconds: 200));

                  _clearAllHistory();
                },
              ),

              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  /// Load score history and best score
  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();

    final savedScores = prefs.getStringList('scoreHistory');
    final savedHighest = prefs.getInt('highestScore');

    setState(() {
      if (savedScores != null) {
        scoreHistory = savedScores.map((e) => int.parse(e)).toList();
      }
      highestScore = savedHighest;
    });
  }

  /// Save score history and best score
  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setStringList(
      'scoreHistory',
      scoreHistory.map((e) => e.toString()).toList(),
    );

    if (highestScore != null) {
      await prefs.setInt('highestScore', highestScore!);
    }
  }

  /// Validate and process user guess
  void _checkGuess() async {
    // Hide keyboard
    FocusScope.of(context).unfocus();

    // Ignore input if round already completed
    if (_roundCompleted) return;

    int? guess = int.tryParse(_controller.text);

    // Handle invalid input
    if (guess == null) {
      setState(() {
        _message = "Enter valid number!";
      });

      if (_soundEnabled) {
        await AudioPlayer().play(AssetSource('error.mp3'));
      }

      _shakeController.forward(from: 0);
      return;
    }

    // Increase attempt count
    setState(() {
      _attempts++;
    });

    // Limit guess range to 1-100
    if (guess > 100) {
      setState(() {
        _message = "Number should be less than or equal to 100.";
      });

      if (_soundEnabled) {
        await AudioPlayer().play(AssetSource('error.mp3'));
      }

      return;
    }

    // Guess is higher than target number
    if (guess > _targetNumber) {
      setState(() {
        _message = "Oops! $guess is Too High, \n Try Lower.";
      });
      if (_soundEnabled) {
        //await _player.play(AssetSource('high.mp3'));
        await AudioPlayer().play(AssetSource('high.mp3'));
      }
    }
    // Guess is lower than target number
    else if (guess < _targetNumber) {
      setState(() {
        _message = "Oops! $guess is Too Low, \n Try Higher.";
      });
      if (_soundEnabled) {
        //await _player.play(AssetSource('low.mp3'));
        await AudioPlayer().play(AssetSource('low.mp3'));
      }
    }
    // Correct guess
    else {
      // Track completed rounds
      _roundCounter++;

      setState(() {
        _message = "Congrats! You guessed it in $_attempts attempt(s). 🎉";
        _roundCompleted = true;

        // Add score to history
        scoreHistory.insert(0, _attempts);

        // Keep only latest 20 records
        if (scoreHistory.length > 20) {
          scoreHistory.removeLast();
        }

        // Update best score
        if (highestScore == null || _attempts < highestScore!) {
          highestScore = _attempts;
        }
      });

      // Play celebration animation
      _confettiController.play();

      if (_soundEnabled) {
        await AudioPlayer().play(AssetSource('success.mp3'));
      }

      // Save updated records
      await _saveData();
    }
  }

  // Start a new round
  Future<void> _nextRound() async {
    // Play restart sound
    if (_soundEnabled) {
      await AudioPlayer().play(AssetSource('restart.mp3'));
    }

    if (!_roundCompleted) {
      _roundCounter++;
    }

    // Show interstitial ad after every 3 completed rounds
    // if (_completedRounds > 0 && _completedRounds % 3 == 0) {
    //   _showInterstitialAd();
    // }

    if (_roundCounter > 0 && _roundCounter % 4 == 0) {
      _showInterstitialAd();
    }

    setState(() {
      // Generate new target number
      _targetNumber = _random.nextInt(100) + 1;
      _attempts = 0;
      _message = "New Round! Guess again.";
      _controller.clear();
      _roundCompleted = false;
      // Reset hint counter
      _hintCount = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = widget.isDark;

    return Scaffold(
      // Glassmorphism AppBar
      appBar: AppBar(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: isDark ? Colors.white : Colors.black,

        // Status bar styling
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        ),

        // Glass blur background
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.white.withValues(alpha: 0.18),

                border: Border(
                  bottom: BorderSide(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.08),
                  ),
                ),
              ),
            ),
          ),
        ),

        // Game title
        title: Text(
          "Number Guess Challenge",
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.vt323(
            fontSize: 25,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xE7052C3A),
          ),
        ),

        // Settings menu button
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Tooltip(
              message: "Settings",
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),

                  splashColor: isDark
                      ? Colors.white24
                      : const Color(0xE70D698A).withValues(alpha: 0.2),

                  highlightColor: Colors.transparent,

                  onTap: _openSettings,

                  child: Container(
                    padding: const EdgeInsets.all(10),
                    child: Icon(
                      Icons.more_vert_rounded,
                      size: 22,
                      color: isDark ? Colors.white : const Color(0xE70D698A),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),

      extendBodyBehindAppBar: true,

      bottomNavigationBar: _isBottomBannerReady
          ? SizedBox(
              height: _bottomBannerAd!.size.height.toDouble(),
              child: AdWidget(ad: _bottomBannerAd!),
            )
          : null,

      // Main game screen UI
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark
              ? const LinearGradient(
                  colors: [
                    Color(0xFF0F2027),
                    Color(0xFF203A43),
                    Color(0xFF2C5364),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : const LinearGradient(
                  colors: [Color(0xFFB2EBF2), Color(0xFFE0F7FA)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
        ),
        child: SafeArea(
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),

                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),

                    // Top banner advertisement
                    if (_isTopBannerReady)
                      Center(
                        child: SizedBox(
                          width: _topBannerAd!.size.width.toDouble(),
                          height: _topBannerAd!.size.height.toDouble(),
                          child: AdWidget(ad: _topBannerAd!),
                        ),
                      ),

                    const SizedBox(height: 30),

                    // Main game card
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF16213E).withValues(alpha: 0.9)
                            : const Color(0xFFDFFAF1),
                        borderRadius: BorderRadius.circular(25),

                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF0E4286).withValues(alpha: 0.9)
                              : const Color(0xFF70C0AE),
                          width: 4,
                        ),

                        boxShadow: [
                          BoxShadow(
                            color: isDark
                                ? Colors.blueAccent.withValues(alpha: 0.6)
                                : Colors.black.withValues(alpha: 0.1),
                            blurRadius: 25,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Game title
                          Text(
                            "Guess the Number",
                            style: GoogleFonts.orbitron(
                              color: isDark ? Colors.white : Colors.black,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 5),

                          Text(
                            "Enter a number (1-100)",
                            style: GoogleFonts.exo2(
                              fontSize: 13,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),

                          const SizedBox(height: 20),

                          // User number input field with shake animation
                          AnimatedBuilder(
                            animation: _shakeController,
                            builder: (context, child) {
                              double shake =
                                  8 *
                                  sin(
                                    _shakeController.value * 3 * 3.1416,
                                  ); // smooth sine shake

                              return Transform.translate(
                                offset: Offset(shake, 0),
                                child: child,
                              );
                            },
                            child: TextField(
                              controller: _controller,
                              textAlign: TextAlign.center,
                              keyboardType: TextInputType.number,

                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],

                              style: GoogleFonts.electrolize(
                                color: isDark ? Colors.white : Colors.black87,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                              decoration: InputDecoration(
                                hintText: "00",
                                hintStyle: GoogleFonts.orbitron(
                                  color: isDark
                                      ? const Color(0xFFBBBBBB)
                                      : const Color(0xFFBBBBBB),
                                  fontWeight: FontWeight.w500,
                                ),
                                filled: true,
                                fillColor: isDark
                                    ? const Color(0xFF032B48)
                                    : Colors.grey.shade200,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(30),
                                  borderSide: BorderSide(
                                    color: isDark
                                        ? const Color(0xFF001F54)
                                        : const Color(0xFF1976D2),
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 25),

                          // Guess button
                          GestureDetector(
                            onTap: _roundCompleted
                                ? null
                                : () async {
                                    setState(() {
                                      _clickAnim = true;
                                    });

                                    await Future.delayed(
                                      const Duration(milliseconds: 100),
                                    );

                                    setState(() {
                                      _clickAnim = false;
                                    });

                                    _checkGuess();
                                  },
                            // Button press animation
                            child: AnimatedScale(
                              duration: const Duration(milliseconds: 100),
                              scale: _clickAnim ? 0.92 : 1.0,
                              // Disable button after round completion
                              child: Opacity(
                                opacity: _roundCompleted ? 0.5 : 1.0,
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 15,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: _roundCompleted
                                        ? LinearGradient(
                                            colors: [
                                              Colors.grey.shade500,
                                              Colors.grey.shade400,
                                            ],
                                          )
                                        : (isDark
                                              ? const LinearGradient(
                                                  colors: [
                                                    Color(0xE70D698A),
                                                    Color(0xAB126A91),
                                                  ],
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                )
                                              : const LinearGradient(
                                                  colors: [
                                                    Color(0xFF15C2BD),
                                                    Color(0xFF019FAB),
                                                  ],
                                                )),

                                    borderRadius: BorderRadius.circular(30),

                                    boxShadow: _roundCompleted
                                        ? []
                                        : [
                                            BoxShadow(
                                              color: isDark
                                                  ? const Color(
                                                      0xE70D698A,
                                                    ).withValues(alpha: 0.6)
                                                  : const Color(
                                                      0xFF15C2BD,
                                                    ).withValues(alpha: 0.5),
                                              blurRadius: 22,
                                              spreadRadius: 3,
                                            ),
                                          ],
                                  ),
                                  child: Center(
                                    // Dynamic button state (Guess / Completed)
                                    child: Text(
                                      _roundCompleted ? "COMPLETED" : "GUESS",
                                      style: GoogleFonts.audiowide(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Animated game feedback message
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 400),
                            child: Text(
                              _message,
                              key: ValueKey(_message),
                              textAlign: TextAlign.center,
                              style: GoogleFonts.vt323(
                                color: isDark
                                    ? const Color(0xFFFD784F)
                                    : const Color(0xFFFF5B02),
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 25),

                    // Hint and restart controls
                    Row(
                      children: [
                        // Rewarded hint button
                        GestureDetector(
                          onTap: () {
                            // Disable hints after round completion
                            if (_roundCompleted) {
                              Fluttertoast.showToast(
                                msg: "Round completed. Start a new round.",
                              );

                              return;
                            }

                            // Maximum 3 hints per round
                            if (_hintCount >= 3) {
                              Fluttertoast.showToast(
                                msg:
                                    "You can get hints up to 3 times per round.",
                              );

                              return;
                            }

                            // Rewarded ad not ready yet
                            if (_rewardedAd == null) {
                              Fluttertoast.showToast(
                                msg: "Hint is loading. Please try again.",
                              );

                              _loadRewardedAd();

                              return;
                            }

                            // Show rewarded ad and give hint
                            _showRewardedAd();
                          },

                          child: Opacity(
                            opacity: _roundCompleted ? 0.5 : 1.0,
                            // Hint button with remaining hint count
                            child: Container(
                              width: 82,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF032B48)
                                    : const Color(0xFFF7FFFE),

                                borderRadius: BorderRadius.circular(16),

                                border: Border.all(
                                  color: isDark
                                      ? Colors.cyanAccent
                                      : Colors.teal,
                                  width: 1.5,
                                ),

                                // Disable glow when hints are exhausted
                                boxShadow: _roundCompleted || _hintCount >= 3
                                    ? []
                                    : [
                                        BoxShadow(
                                          color: isDark
                                              ? Colors.cyanAccent.withValues(
                                                  alpha: 0.45,
                                                )
                                              : Colors.teal.withValues(
                                                  alpha: 0.35,
                                                ),
                                          blurRadius: 14,
                                          spreadRadius: 1,
                                        ),
                                      ],
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _hintCount >= 3
                                        ? Icons.check_circle
                                        : Icons.tips_and_updates_rounded,
                                    color: isDark
                                        ? Colors.cyanAccent
                                        : Colors.teal,
                                    size: 22,
                                  ),

                                  const SizedBox(height: 4),

                                  // Dynamic hint state (Hint / Used)
                                  Text(
                                    _hintCount >= 3
                                        ? "Used"
                                        : "Hint (${3 - _hintCount})",
                                    style: GoogleFonts.audiowide(
                                      color: isDark
                                          ? Colors.cyanAccent
                                          : Colors.teal,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // Current attempt counter
                        Expanded(
                          child: Center(
                            child: Text(
                              "Attempts: $_attempts",
                              style: GoogleFonts.vt323(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                          ),
                        ),

                        // Restart current round
                        GestureDetector(
                          onTap: () async {
                            // Prevent restart before first guess
                            if (_attempts == 0) {
                              Fluttertoast.showToast(
                                msg: "Make a guess before restarting.",
                              );
                              return;
                            }

                            // Start a new round
                            _nextRound();
                          },
                          child: Opacity(
                            opacity: _attempts == 0 ? 0.5 : 1.0,

                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF032B48)
                                    : const Color(0xFFF7FFFE),

                                borderRadius: BorderRadius.circular(16),

                                border: Border.all(
                                  color: isDark
                                      ? Colors.cyanAccent
                                      : Colors.teal,
                                  width: 1.5,
                                ),

                                // Disable glow when restart is unavailable
                                boxShadow: _attempts == 0
                                    ? []
                                    : [
                                        BoxShadow(
                                          color: isDark
                                              ? Colors.cyanAccent.withValues(
                                                  alpha: 0.5,
                                                )
                                              : Colors.teal.withValues(
                                                  alpha: 0.35,
                                                ),
                                          blurRadius: 18,
                                          spreadRadius: 2,
                                        ),
                                      ],
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.refresh_rounded,
                                    color: isDark
                                        ? Colors.cyanAccent
                                        : Colors.teal,
                                    size: 22,
                                  ),

                                  const SizedBox(height: 4),

                                  Text(
                                    "Restart",
                                    style: GoogleFonts.audiowide(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? Colors.cyanAccent
                                          : Colors.teal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 15),

                    // High score badge
                    if (highestScore != null)
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),

                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),

                            boxShadow: [
                              BoxShadow(
                                color:
                                    (isDark
                                            ? const Color(0xFFFFC107)
                                            : const Color(0xFFFF8F00))
                                        .withValues(alpha: 0.18),
                                blurRadius: 18,
                                spreadRadius: 2,
                              ),
                            ],
                          ),

                          child: Text(
                            "🏆 Highest Score: $highestScore attempts",
                            style: GoogleFonts.electrolize(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? const Color(0xFFFFD54F)
                                  : const Color(0xFFE65100),
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 20),

                    // Round history section
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF0F172A).withValues(alpha: 0.4)
                            : const Color(0xFFEAFDFC),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF0891B2) // Dark mode border
                              : const Color(0xFF14B8A6), // Light mode border
                          width: 1.8,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // History section header
                          Text(
                            "Round History",
                            style: GoogleFonts.exo2(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                          Text(
                            "Last 20 games",
                            style: GoogleFonts.exo2(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),

                          const SizedBox(height: 5),

                          Divider(
                            color: isDark ? Colors.white24 : Colors.black12,
                            thickness: 1,
                          ),

                          const SizedBox(height: 5),

                          // Show empty state when no rounds are played
                          scoreHistory.isEmpty
                              ? Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 20,
                                  ),
                                  child: Text(
                                    "No rounds played yet",
                                    style: GoogleFonts.exo2(
                                      color: isDark
                                          ? Colors.grey
                                          : Colors.black54,
                                    ),
                                  ),
                                )
                              : Column(
                                  children: [
                                    // Display recent round records
                                    ListView.builder(
                                      shrinkWrap: true,
                                      physics:
                                          const NeverScrollableScrollPhysics(),

                                      itemCount: _showAllHistory
                                          ? scoreHistory.length
                                          : (scoreHistory.length > 5
                                                ? 5
                                                : scoreHistory.length),

                                      itemBuilder: (context, index) {
                                        int score = scoreHistory[index];

                                        // Highlight best score entry
                                        bool isHighest = score == highestScore;

                                        return Card(
                                          color: isHighest
                                              ? (isDark
                                                    ? const Color(0xFF436E67)
                                                    : const Color(0xFF9EE0D3))
                                              : (isDark
                                                    ? const Color(
                                                        0xFFC4EBF5,
                                                      ).withValues(alpha: 0.4)
                                                    : const Color(0xFFD2FCF6)),
                                          child: ListTile(
                                            leading: const Icon(
                                              Icons.emoji_events,
                                              color: Colors.amber,
                                            ),
                                            title: Text(
                                              "Round ${scoreHistory.length - index}",
                                              style: GoogleFonts.exo2(
                                                fontWeight: isHighest
                                                    ? FontWeight.bold
                                                    : FontWeight.normal,

                                                color: isHighest
                                                    ? (isDark
                                                          ? Colors.white
                                                          : Colors.black87)
                                                    : (isDark
                                                          ? Colors.white
                                                          : Colors.black87),
                                              ),
                                            ),
                                            trailing: Text(
                                              "$score attempts",
                                              style: GoogleFonts.electrolize(
                                                fontWeight: isHighest
                                                    ? FontWeight.bold
                                                    : FontWeight.normal,

                                                color: isHighest
                                                    ? (isDark
                                                          ? const Color(
                                                              0xFFFFD54F,
                                                            )
                                                          : const Color(
                                                              0xFF423014,
                                                            ))
                                                    : (isDark
                                                          ? Colors.white
                                                          : Colors.black54),
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),

                                    // Expand / collapse history list
                                    if (scoreHistory.length > 5)
                                      // View more / less history
                                      TextButton.icon(
                                        onPressed: () {
                                          setState(() {
                                            _showAllHistory = !_showAllHistory;
                                          });
                                        },

                                        icon: Icon(
                                          _showAllHistory
                                              ? Icons.expand_less
                                              : Icons.expand_more,
                                          color: isDark
                                              ? const Color(0xFF4FC3F7)
                                              : const Color(0xFF1976D2),
                                        ),

                                        label: Text(
                                          _showAllHistory
                                              ? "View Less"
                                              : "View More",
                                          style: TextStyle(
                                            color: isDark
                                                ? const Color(0xFF4FC3F7)
                                                : const Color(0xFF1976D2),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Native advertisement
                    if (_isNativeAdLoaded)
                      Container(
                        height: 350,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.red),
                        ),
                        child: AdWidget(ad: _nativeAd!),
                      ),

                    const SizedBox(height: 20),

                    // Clear saved history button
                    if (scoreHistory.isNotEmpty)
                      Center(
                        child: GestureDetector(
                          onTap: _showClearOptions,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF2D0B0B)
                                  : const Color(0xFFFFF1F1),

                              borderRadius: BorderRadius.circular(16),

                              border: Border.all(
                                color: isDark
                                    ? const Color(0xFFFF6B6B)
                                    : const Color(0xFFD32F2F),
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.delete_outline,
                                  color: isDark
                                      ? const Color(0xFFFF6B6B)
                                      : const Color(0xFFD32F2F),
                                  size: 22,
                                ),

                                const SizedBox(width: 8),

                                Text(
                                  "Clear History",
                                  style: GoogleFonts.electrolize(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? const Color(0xFFFF6B6B)
                                        : const Color(0xFFD32F2F),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                    const SizedBox(height: 20),
                  ], // ✅ Column children closed
                ),
              ),

              // Celebration confetti animation
              ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                shouldLoop: false,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Open settings menu
  Future<void> _openSettings() async {
    FocusManager.instance.primaryFocus?.unfocus();
    await showGlassSettingsMenu(
      context: context,
      isDark: widget.isDark,

      items: [
        // Sound preference
        SettingsMenuItem(
          title: "Sound",
          value: _soundEnabled,

          iconBuilder: (value) => value ? Icons.volume_up : Icons.volume_off,

          onChanged: (value) async {
            setState(() {
              _soundEnabled = value;
            });

            await _saveSoundSetting();
          },
        ),

        // Theme switch
        SettingsMenuItem(
          title: "Dark Mode",
          value: widget.isDark,

          affectsTheme: true,

          iconBuilder: (value) => value ? Icons.dark_mode : Icons.light_mode,

          onChanged: (value) {
            widget.toggleTheme();
          },
        ),

        // Privacy policy page
        SettingsMenuItem(
          title: "Privacy Policy",
          value: false,
          isAction: true,
          iconBuilder: (_) => Icons.privacy_tip_outlined,
          onChanged: (_) {},
          onTap: () {
            Navigator.pop(context);

            _openPrivacyPolicy();
          },
        ),

        // App information
        SettingsMenuItem(
          title: "About",
          value: false,
          isAction: true,
          iconBuilder: (_) => Icons.info_outline,
          onChanged: (_) {},
          onTap: () {
            Navigator.pop(context);

            _showAboutDialog();
          },
        ),
      ],
    );

    FocusManager.instance.primaryFocus?.unfocus();
  }

  /// Show app information dialog
  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("About"),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Number Guess Challenge"),
              SizedBox(height: 8),
              Text("Version 1.0.0"),
              SizedBox(height: 8),
              Text("© SP Tech Studios"),
            ],
          ),
        );
      },
    );
  }

  /// Open privacy policy page
  void _openPrivacyPolicy() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PrivacyPolicyPage()),
    );
  }
}

///End GuessGameState Class
