import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:number_guess_game/privacy_policy_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'splash_screen.dart';
import 'glass_settings_menu.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await MobileAds.instance.initialize();

  runApp(const MyApp());
}

// class SplashStarter extends StatefulWidget {
//   const SplashStarter({super.key});
//
//   @override
//   State<SplashStarter> createState() => _SplashStarterState();
// }

// class _SplashStarterState extends State<SplashStarter> {
//   bool isDark = true;
//
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       debugShowCheckedModeBanner: false,
//       home: SplashScreen(isDark: isDark),
//     );
//   }
// }

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {


  bool isDark = true;

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      isDark = prefs.getBool('isDark') ?? true;
    });
  }

  Future<void> _saveTheme(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDark', value);
  }
  @override
  void initState() {
    super.initState();
    _loadTheme();
  }




  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: isDark ? Brightness.dark : Brightness.light,
        scaffoldBackgroundColor:
        isDark ? const Color(0xFF1E1E2C) : Colors.lightBlue.shade50,
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

  const GuessGame(
      {super.key, required this.toggleTheme, required this.isDark});

  @override
  State<GuessGame> createState() => _GuessGameState();
}

class _GuessGameState extends State<GuessGame>
    with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final Random _random = Random();
  final AudioPlayer _player = AudioPlayer();

  late ConfettiController _confettiController;
  late int _targetNumber;

  /////
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;
  ////

  String _message = "Guess a number between 1 and 100";
  int _attempts = 0;

  List<int> scoreHistory = [];
  int? highestScore;
  bool _showAllHistory = false;

  bool _roundCompleted = false;
  bool _soundEnabled = true; // ✅ Added
  bool _clickAnim = false;

  BannerAd? _topBannerAd;
  BannerAd? _bottomBannerAd;

  bool _isTopBannerReady = false;
  bool _isBottomBannerReady = false;

  NativeAd? _nativeAd;
  bool _isNativeAdLoaded = false;

  InterstitialAd? _interstitialAd;
  RewardedAd? _rewardedAd;

  int _completedRounds = 0;
  int _hintCount = 0;
  @override
  void initState() {
    super.initState();
    _targetNumber = _random.nextInt(100) + 1;
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 2));

    _loadSavedData();
    _loadSoundSetting();

    _loadBannerAds();
    _loadNativeAd();
    _loadInterstitialAd();
    _loadRewardedAd();

    /////
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _shakeAnimation = CurvedAnimation(
      parent: _shakeController,
      curve: Curves.easeInOut,
    );
    ////

  }

  @override
  void dispose() {
    _confettiController.dispose();
    _player.dispose();
    super.dispose();
    ///
    _shakeController.dispose();
    _topBannerAd?.dispose();
    _bottomBannerAd?.dispose();
    _nativeAd?.dispose();
    ///
  }

  void _loadBannerAds() {

    // Top Banner
    _topBannerAd = BannerAd(
      adUnitId: 'ca-app-pub-3940256099942544/6300978111', // Test Native Ad
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

    // Bottom Banner
    _bottomBannerAd = BannerAd(
      adUnitId: 'ca-app-pub-3940256099942544/6300978111', // Test Native Ad
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

  void _loadNativeAd() {
    _nativeAd = NativeAd(
      adUnitId: 'ca-app-pub-3940256099942544/2247696110', // Test Native Ad

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

  void _loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: 'ca-app-pub-3940256099942544/1033173712',
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

  void _showInterstitialAd() {
    if (_interstitialAd == null) return;

    _interstitialAd!.fullScreenContentCallback =
        FullScreenContentCallback(
          onAdDismissedFullScreenContent: (ad) {
            ad.dispose();

            _loadInterstitialAd();
          },
          onAdFailedToShowFullScreenContent: (ad, error) {
            ad.dispose();

            _loadInterstitialAd();
          },
        );

    _interstitialAd!.show();

    _interstitialAd = null;
  }

  void _loadRewardedAd() {
    RewardedAd.load(
      adUnitId:
      'ca-app-pub-3940256099942544/5224354917',
      request: const AdRequest(),
      rewardedAdLoadCallback:
      RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
        },
        onAdFailedToLoad: (error) {
          _rewardedAd = null;
        },
      ),
    );
  }

  void _showRewardedAd() {
    if (_rewardedAd == null) return;

    _rewardedAd!.show(
      onUserEarnedReward: (ad, reward) {

        _giveHint();

      },
    );

    _rewardedAd = null;

    _loadRewardedAd();
  }

  void _giveHint() {

    _hintCount++;

    String hint = "";

    switch (_hintCount) {

      case 1:
        hint = _targetNumber > 50
            ? "💡 Number is Greater than 50"
            : "💡 Number is Less than or Equal to 50";
        break;

      case 2:
        int start = (_targetNumber ~/ 10) * 10;
        int end = start + 10;

        hint = "💡 Number is between $start and $end";
        break;

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

  Future<void> _loadSoundSetting() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _soundEnabled = prefs.getBool('soundEnabled') ?? true;
    });
  }

  Future<void> _saveSoundSetting() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('soundEnabled', _soundEnabled);
  }

  // Future<void> _clearScoreHistoryOnly() async {
  //   final prefs = await SharedPreferences.getInstance();
  //
  //   await prefs.remove('scoreHistory');
  //
  //   setState(() {
  //     scoreHistory.clear();
  //   });
  // }

  // Future<void> _clearAllHistory() async {
  //   final prefs = await SharedPreferences.getInstance();
  //
  //   await prefs.remove('scoreHistory');
  //   await prefs.remove('highestScore');
  //
  //   setState(() {
  //     scoreHistory.clear();
  //     highestScore = null;
  //   });
  // }

  Future<void> _clearAllHistory() async {

    FocusManager.instance.primaryFocus?.unfocus();

    final prefs = await SharedPreferences.getInstance();

    await prefs.remove('scoreHistory');
    await prefs.remove('highestScore');

    setState(() {
      scoreHistory.clear();
      highestScore = null;
    });

    Fluttertoast.showToast(
      msg: "Round history deleted successfully.",
    );
  }

  void _showClearOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: widget.isDark
          ? const Color(0xFF1C1C2E)
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [

              const Text(
                "Clear History",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

              //const SizedBox(height: 20),
              Divider(
                color: Colors.white24,
                thickness: 1,
              ),

              // ListTile(
              //   leading: const Icon(Icons.history),
              //   title: const Text("Delete Score History Only."),
              //   onTap: () {
              //     Navigator.pop(context);
              //     _clearScoreHistoryOnly();
              //   },
              // ),

              ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.red),
                title: const Text(
                  "Delete All Round History.",
                  style: TextStyle(color: Colors.red),
                ),
                // onTap: () {
                //   Navigator.pop(context);
                //   _clearAllHistory();
                // },
                onTap: () async {

                  Navigator.pop(context);

                  await Future.delayed(
                    const Duration(milliseconds: 200),
                  );

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


  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();

    final savedScores = prefs.getStringList('scoreHistory');
    final savedHighest = prefs.getInt('highestScore');

    setState(() {
      if (savedScores != null) {
        scoreHistory =
            savedScores.map((e) => int.parse(e)).toList();
      }
      highestScore = savedHighest;
    });
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setStringList(
        'scoreHistory',
        scoreHistory.map((e) => e.toString()).toList());

    if (highestScore != null) {
      await prefs.setInt('highestScore', highestScore!);
    }
  }



  void _checkGuess() async {

    FocusScope.of(context).unfocus();

    if (_roundCompleted) return;

    int? guess = int.tryParse(_controller.text);

    if (guess == null) {
      setState(() {
        _message = "Enter valid number!";
      });

      if (_soundEnabled) {
        await AudioPlayer().play(
          AssetSource('error.mp3'),
        );
      }

      _shakeController.forward(from: 0);
      return;
    }

    setState(() {
      _attempts++;
    });

    if (guess > 100) {

      setState(() {
        _message =
        "Number should be less than or equal to 100.";
      });

      if (_soundEnabled) {
        await AudioPlayer().play(
          AssetSource('error.mp3'),
        );
      }

      return;
    }


    if (guess > _targetNumber) {
      setState(() {
        _message = "Oops! $guess is Too High, \n Try Lower.";
      });
      if (_soundEnabled) {
        //await _player.play(AssetSource('high.mp3'));
        await AudioPlayer().play(AssetSource('high.mp3'));
      }
    }
    else if (guess < _targetNumber) {
      setState(() {
        _message = "Oops! $guess is Too Low, \n Try Higher.";
      });
      if (_soundEnabled) {
        //await _player.play(AssetSource('low.mp3'));
        await AudioPlayer().play(AssetSource('low.mp3'));
      }
    }
    else {

      _completedRounds++;

      setState(() {
        _message = "Congrats! You guessed it in $_attempts attempt(s). 🎉";
        _roundCompleted = true;

        scoreHistory.insert(0, _attempts);

        if (scoreHistory.length > 20) {
          scoreHistory.removeLast();
        }

        if (highestScore == null || _attempts < highestScore!) {
          highestScore = _attempts;
        }
      });

      _confettiController.play();

      if (_soundEnabled) {
        // await _player.play(AssetSource('success.mp3'));
        await AudioPlayer().play(AssetSource('success.mp3'));
      }

      await _saveData();
    }
  }

  // Future<void> _nextRound() async {
  //
  //   if (_soundEnabled) {
  //     await AudioPlayer().play(
  //       AssetSource('restart.mp3'),
  //     );
  //   }
  //
  //   setState(() {
  //     _targetNumber = _random.nextInt(100) + 1;
  //     _attempts = 0;
  //     _message = "New Round! Guess again.";
  //     _controller.clear();
  //     _roundCompleted = false;
  //   });
  // }

  Future<void> _nextRound() async {

    if (_soundEnabled) {
      await AudioPlayer().play(
        AssetSource('restart.mp3'),
      );
    }

    // Every 3 completed games
    if (_completedRounds > 0 &&
        _completedRounds % 3 == 0) {
      _showInterstitialAd();
    }

    setState(() {
      _targetNumber = _random.nextInt(100) + 1;
      _attempts = 0;
      _message = "New Round! Guess again.";
      _controller.clear();
      _roundCompleted = false;
      _hintCount = 0;
    });
  }



  @override
  Widget build(BuildContext context) {
    bool isDark = widget.isDark;

    return Scaffold(

      appBar: AppBar(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor:
        isDark ? Colors.white : Colors.black,

        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness:
          isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness:
          isDark ? Brightness.dark : Brightness.light,
        ),

        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: 20,
              sigmaY: 20,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.white.withOpacity(0.18),

                border: Border(
                  bottom: BorderSide(
                    color: isDark
                        ? Colors.white.withOpacity(0.08)
                        : Colors.black.withOpacity(0.08),
                  ),
                ),
              ),
            ),
          ),
        ),

        //toolbarHeight: 65,

        title: Text(
          "Number Guess Challenge",
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.vt323(
            fontSize: 25,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white: const Color(0xE7052C3A),
          ),
        ),

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
                      : const Color(0xE70D698A).withOpacity(0.2),

                  highlightColor: Colors.transparent,

                  onTap: _openSettings,

                  child: Container(
                    padding: const EdgeInsets.all(10),
                    child: Icon(
                      Icons.more_vert_rounded,
                      size: 22,
                      color: isDark
                          ? Colors.white
                          : const Color(0xE70D698A),
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

      body: Container(
        decoration: BoxDecoration(
          gradient: isDark
              ? const LinearGradient(
            colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
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

                    if (_isTopBannerReady)
                      Center(
                        child: SizedBox(
                          width: _topBannerAd!.size.width.toDouble(),
                          height: _topBannerAd!.size.height.toDouble(),
                          child: AdWidget(ad: _topBannerAd!),
                        ),
                      ),

                    const SizedBox(height: 30),

                    /// 🎮 Main Card
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF16213E).withOpacity(0.9)
                            : const Color(0xFFDFFAF1),
                        borderRadius: BorderRadius.circular(25),

                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF0E4286).withOpacity(0.9)
                              : const Color(0xFF70C0AE),
                          width: 4,
                        ),

                        boxShadow: [
                          BoxShadow(
                            color: isDark
                                ? Colors.blueAccent.withOpacity(0.6)
                                : Colors.black.withOpacity(0.1),
                            blurRadius: 25,
                            spreadRadius: 2,
                          )
                        ],
                      ),
                      child: Column(
                        children: [

                          Text(
                            "Guess the Number",
                            style: GoogleFonts.orbitron(
                              color: isDark ? Colors.white: Colors.black,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 5),

                          Text(
                            "Enter a number (1-100)",
                            style: GoogleFonts.exo2(
                                fontSize: 13,
                              color: isDark ? Colors.white: Colors.black,
                            ),
                          ),

                          const SizedBox(height: 20),


                          AnimatedBuilder(
                            animation: _shakeController,
                            builder: (context, child) {
                              double shake = 8 *
                                  sin(_shakeController.value * 3 * 3.1416); // smooth sine shake

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
                                color: isDark
                                    ? Colors.white
                                    : Colors.black87,
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

                          // guess button start

                          GestureDetector(
                            onTap: _roundCompleted
                                ? null
                                : () async {
                              setState(() {
                                _clickAnim = true;
                              });

                              await Future.delayed(const Duration(milliseconds: 100));

                              setState(() {
                                _clickAnim = false;
                              });

                              _checkGuess();
                            },
                            child: AnimatedScale(
                              duration: const Duration(milliseconds: 100),
                              scale: _clickAnim ? 0.92 : 1.0,
                              child: Opacity(
                                opacity: _roundCompleted ? 0.5 : 1.0,
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 15),
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
                                            ? const Color(0xE70D698A).withOpacity(0.6)
                                            : const Color(0xFF15C2BD).withOpacity(0.5),
                                        blurRadius: 22,
                                        spreadRadius: 3,
                                      ),
                                    ],
                                  ),
                                  child: Center(
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

                          // guess button end

                          const SizedBox(height: 20),

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

                    /// Attempts + Restart
                    // Row(
                    //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    //   children: [
                    //     Text(
                    //       "Attempts: $_attempts",
                    //       style: TextStyle(
                    //         fontSize: 17,
                    //         color: isDark
                    //             ? Colors.white
                    //             : Colors.black,
                    //       ),
                    //     ),
                    //     TextButton.icon(
                    //       onPressed: () async {
                    //         if (_soundEnabled) {
                    //           await AudioPlayer().play(
                    //             AssetSource('restart.mp3'),
                    //           );
                    //         }
                    //         _nextRound();
                    //       },
                    //       icon: const Icon(Icons.refresh, size: 22),
                    //       label: const Text(
                    //         "Restart",
                    //         style: TextStyle(
                    //           fontSize: 17,
                    //           fontWeight: FontWeight.w600,
                    //         ),
                    //       ),
                    //     ),
                    //   ],
                    // ),


                    Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            if (_roundCompleted) {
                              Fluttertoast.showToast(
                                msg: "Round completed. Start a new round.",
                              );

                              return;
                            }

                            if (_hintCount >= 3) {
                              Fluttertoast.showToast(
                                msg: "You can get hints up to 3 times per round.",
                              );

                              return;
                            }

                            if (_rewardedAd == null) {
                              Fluttertoast.showToast(
                                msg: "Hint is loading. Please try again.",
                              );

                              _loadRewardedAd();

                              return;
                            }

                            _showRewardedAd();
                          },

                          child: Opacity(
                            opacity: _roundCompleted ? 0.5 : 1.0,
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

                                boxShadow: _roundCompleted || _hintCount >= 3
                                    ? []
                                    : [
                                  BoxShadow(
                                    color: isDark
                                        ? Colors.cyanAccent.withOpacity(0.45)
                                        : Colors.teal.withOpacity(0.35),
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



                        /// ATTEMPTS CENTER
                        Expanded(
                          child: Center(
                            child: Text(
                              "Attempts: $_attempts",
                              style: GoogleFonts.vt323(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? Colors.white
                                    : Colors.black,
                              ),
                            ),
                          ),
                        ),

                        /// RESTART BUTTON
                        GestureDetector(
                          onTap: () async {

                            if (_attempts == 0) {
                              Fluttertoast.showToast(
                                msg: "Make a guess before restarting.",
                              );
                              return;
                            }

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

                                boxShadow: _attempts == 0
                                    ? []
                                    : [
                                  BoxShadow(
                                    color: isDark
                                        ? Colors.cyanAccent.withOpacity(0.5)
                                        : Colors.teal.withOpacity(0.35),
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

                    if (highestScore != null)
                      // Center(
                      //   child: Container(
                      //     padding: const EdgeInsets.symmetric(
                      //         horizontal: 20, vertical: 12),
                      //     decoration: BoxDecoration(
                      //       color: isDark
                      //           ? Colors.transparent
                      //           : const Color(0xFFFFF3E0),
                      //       borderRadius: BorderRadius.circular(20),
                      //       // border: Border.all(
                      //       //   color: isDark
                      //       //       ? const Color(0xFF088D89)
                      //       //       : const Color(0xFFFF8F00),
                      //       //   width: 2,
                      //       // ),
                      //     ),
                      //     child: Text(
                      //       "🏆 Highest Score: $highestScore attempts",
                      //       style: GoogleFonts.electrolize(
                      //         fontSize: 15,
                      //         fontWeight: FontWeight.bold,
                      //         color: isDark
                      //             ? const Color(0xFFFFC107)
                      //             : const Color(0xFFFF8F00),
                      //       ),
                      //     ),
                      //   ),
                      // ),

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
                                color: (isDark
                                    ? const Color(0xFFFFC107)
                                    : const Color(0xFFFF8F00))
                                    .withOpacity(0.18),
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


                    /// Score History Section

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF0F172A).withOpacity(0.4)
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
                          Text(
                            "Round History",
                            style: GoogleFonts.exo2(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white: Colors.black,
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
                            color: isDark
                                ? Colors.white24
                                : Colors.black12,
                            thickness: 1,
                          ),

                          const SizedBox(height: 5),

                          // scoreHistory.isEmpty
                          //     ? Padding(
                          //   padding: const EdgeInsets.symmetric(vertical: 20),
                          //   child: Text(
                          //     "No rounds played yet",
                          //     style: TextStyle(
                          //       color: isDark ? Colors.grey : Colors.black54,
                          //     ),
                          //   ),
                          // )
                          //     : ListView.builder(
                          //   shrinkWrap: true,
                          //   physics: const NeverScrollableScrollPhysics(),
                          //   itemCount: scoreHistory.length,
                          //   itemBuilder: (context, index) {
                          //     int score = scoreHistory[index];
                          //     bool isHighest = score == highestScore;
                          //
                          //     return Card(
                          //       color: isHighest
                          //           ? (isDark
                          //           ? const Color(0xFFC4EBF5).withOpacity(0.4)
                          //           : const Color(0xFF3ABDA6).withOpacity(0.6))
                          //           : (isDark
                          //           ? const Color(0xFF1B263B).withOpacity(0.2)
                          //           : const Color(0xFFD2FCF6).withOpacity(0.6)),
                          //       child: ListTile(
                          //         leading: const Icon(Icons.emoji_events,
                          //             color: Colors.amber),
                          //         title: Text(
                          //           "Round ${scoreHistory.length - index}",
                          //           style: TextStyle(
                          //             fontWeight: isHighest
                          //                 ? FontWeight.bold
                          //                 : FontWeight.normal,
                          //           ),
                          //         ),
                          //         trailing: Text(
                          //           "$score attempts",
                          //           style: TextStyle(
                          //             fontWeight: isHighest
                          //                 ? FontWeight.bold
                          //                 : FontWeight.normal,
                          //           ),
                          //         ),
                          //       ),
                          //     );
                          //   },
                          // ),

                          scoreHistory.isEmpty
                              ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: Text(
                              "No rounds played yet",
                              style: GoogleFonts.exo2(
                                color: isDark ? Colors.grey : Colors.black54,
                              ),
                            ),
                          )
                              : Column(
                            children: [

                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),

                                itemCount: _showAllHistory
                                    ? scoreHistory.length
                                    : (scoreHistory.length > 5
                                    ? 5
                                    : scoreHistory.length),

                                itemBuilder: (context, index) {

                                  int score = scoreHistory[index];
                                  bool isHighest =
                                      score == highestScore;

                                  return Card(
                                    color: isHighest
                                        ? (isDark
                                        ? const Color(0xFF436E67)
                                        : const Color(0xFF9EE0D3)
                                        )
                                        : (isDark

                                        ? const Color(0xFFC4EBF5)
                                        .withOpacity(0.4)
                                        : const Color(0xFFD2FCF6)
                                        ),
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
                                              ? const Color(0xFFFFD54F)
                                              : const Color(0xFF423014))
                                              : (isDark
                                              ? Colors.white
                                              : Colors.black54),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),

                              if (scoreHistory.length > 5)
                                TextButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      _showAllHistory =
                                      !_showAllHistory;
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

                    // if (_isNativeAdLoaded)
                    //   SizedBox(
                    //     height: 350,
                    //     child: AdWidget(ad: _nativeAd!),
                    //   ),

                    if (_isNativeAdLoaded)
                      Container(
                        height: 350,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.red),
                        ),
                        child: AdWidget(ad: _nativeAd!),
                      ),

                    const SizedBox(height: 20),


                    // if (scoreHistory.isNotEmpty)
                    //   Center(
                    //     child: TextButton.icon(
                    //       onPressed: _showClearOptions,
                    //       icon: const Icon(Icons.delete, color: Colors.red),
                    //       label: const Text(
                    //         "Clear History",
                    //         style: TextStyle(
                    //           fontSize: 16,
                    //           fontWeight: FontWeight.w600,
                    //           color: Colors.red,
                    //         ),
                    //       ),
                    //     ),
                    //   ),

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

              ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality:
                BlastDirectionality.explosive,
                shouldLoop: false,
              ),

            ], // ✅ Stack children closed
          ),
        ),
      ),
    );
  }


  Future<void> _openSettings() async {
    FocusManager.instance.primaryFocus?.unfocus();
    await showGlassSettingsMenu(
      context: context,
      isDark: widget.isDark,

      items: [
        SettingsMenuItem(
          title: "Sound",
          value: _soundEnabled,

          iconBuilder: (value) =>
          value ? Icons.volume_up : Icons.volume_off,

          onChanged: (value) async {
            setState(() {
              _soundEnabled = value;
            });

            await _saveSoundSetting();
          },
        ),

        SettingsMenuItem(
          title: "Dark Mode",
          value: widget.isDark,

          affectsTheme: true,

          iconBuilder: (value) =>
          value ? Icons.dark_mode : Icons.light_mode,

          onChanged: (value) {
            widget.toggleTheme();
          },
        ),
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

  // void _showAboutDialog() {
  //   showAboutDialog(
  //     context: context,
  //     applicationName: 'Number Guess Challenge',
  //     applicationVersion: '1.0.0',
  //     applicationLegalese: '© SP Tech Studios',
  //   );
  // }

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

  void _openPrivacyPolicy() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const PrivacyPolicyPage(),
      ),
    );
  }

}///End GuessGameState Class