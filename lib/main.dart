import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'splash_screen.dart';
import 'glass_settings_menu.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

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

  bool _roundCompleted = false;
  bool _soundEnabled = true; // ✅ Added
  bool _clickAnim = false;

  BannerAd? _topBannerAd;
  BannerAd? _bottomBannerAd;

  bool _isTopBannerReady = false;
  bool _isBottomBannerReady = false;

  @override
  void initState() {
    super.initState();
    _targetNumber = _random.nextInt(100) + 1;
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 2));

    _loadSavedData();
    _loadSoundSetting();

    _loadBannerAds();

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
    ///
  }

  void _loadBannerAds() {

    // Top Banner
    _topBannerAd = BannerAd(
      adUnitId: 'ca-app-pub-3940256099942544/6300978111',
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
      adUnitId: 'ca-app-pub-3940256099942544/6300978111',
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

  Future<void> _clearScoreHistoryOnly() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove('scoreHistory');

    setState(() {
      scoreHistory.clear();
    });
  }

  Future<void> _clearAllHistory() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove('scoreHistory');
    await prefs.remove('highestScore');

    setState(() {
      scoreHistory.clear();
      highestScore = null;
    });
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

              const SizedBox(height: 20),

              ListTile(
                leading: const Icon(Icons.history),
                title: const Text("Delete Score History Only."),
                onTap: () {
                  Navigator.pop(context);
                  _clearScoreHistoryOnly();
                },
              ),

              ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.red),
                title: const Text(
                  "Delete Highest Score Also.",
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
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

  void _nextRound() {
    setState(() {
      _targetNumber = _random.nextInt(100) + 1;
      _attempts = 0;
      _message = "New Round! Guess again.";
      _controller.clear();
      _roundCompleted = false;
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

        title: const Text(
          "Number Guess Challenge",
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),

        actions: [
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            onPressed: _openSettings,
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

                    const SizedBox(height: 10),

                    if (_isTopBannerReady)
                      SizedBox(
                        width: _topBannerAd!.size.width.toDouble(),
                        height: _topBannerAd!.size.height.toDouble(),
                        child: AdWidget(ad: _topBannerAd!),
                      ),

                    const SizedBox(height: 30),

                    /// 🎮 Main Card
                    Container(
                      padding: const EdgeInsets.all(25),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF16213E).withOpacity(0.9)
                            : const Color(0xFFDFFAF1),
                        borderRadius: BorderRadius.circular(25),

                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF0E4286).withOpacity(0.9)
                              : const Color(0xFFBAFDE6),
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

                          const Text(
                            "Guess the Number",
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 8),

                          const Text(
                            "Enter a number (1-100)",
                            style: TextStyle(fontSize: 15),
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
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                              decoration: InputDecoration(
                                hintText: "00",
                                hintStyle: TextStyle(
                                  color: isDark
                                      ? const Color(0xFFFFFFFF)
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
                                  ),
                                  child: Center(
                                    child: Text(
                                      _roundCompleted ? "COMPLETED" : "GUESS",
                                      style: const TextStyle(
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

                          const SizedBox(height: 15),

                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 400),
                            child: Text(
                              _message,
                              key: ValueKey(_message),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: isDark
                                    ? const Color(0xFFFD784F)
                                    : const Color(0xFFFF5B02),
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 25),

                    /// Attempts + Restart
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Attempts: $_attempts",
                          style: TextStyle(
                            fontSize: 17,
                            color: isDark
                                ? Colors.white
                                : Colors.black,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () async {
                            if (_soundEnabled) {
                              await AudioPlayer().play(
                                AssetSource('restart.mp3'),
                              );
                            }
                            _nextRound();
                          },
                          icon: const Icon(Icons.refresh, size: 22),
                          label: const Text(
                            "Restart",
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 15),

                    if (highestScore != null)
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF032B48)
                                : const Color(0xFFFFF3E0),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isDark
                                  ? const Color(0xFF088D89)
                                  : const Color(0xFFFF8F00),
                              width: 2,
                            ),
                          ),
                          child: Text(
                            "🏆 Highest Score: $highestScore attempts",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? const Color(0xFFFFC107)
                                  : const Color(0xFFFF8F00),
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
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [

                          const Text(
                            "Score History (Max 20)",
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 10),

                          scoreHistory.isEmpty
                              ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: Text(
                              "No rounds played yet",
                              style: TextStyle(
                                color: isDark ? Colors.grey : Colors.black54,
                              ),
                            ),
                          )
                              : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: scoreHistory.length,
                            itemBuilder: (context, index) {
                              int score = scoreHistory[index];
                              bool isHighest = score == highestScore;

                              return Card(
                                color: isHighest
                                    ? (isDark
                                    ? const Color(0xFFC4EBF5).withOpacity(0.4)
                                    : const Color(0xFF3ABDA6).withOpacity(0.6))
                                    : (isDark
                                    ? const Color(0xFF1B263B).withOpacity(0.2)
                                    : const Color(0xFFD2FCF6).withOpacity(0.6)),
                                child: ListTile(
                                  leading: const Icon(Icons.emoji_events,
                                      color: Colors.amber),
                                  title: Text(
                                    "Round ${scoreHistory.length - index}",
                                    style: TextStyle(
                                      fontWeight: isHighest
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                  trailing: Text(
                                    "$score attempts",
                                    style: TextStyle(
                                      fontWeight: isHighest
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    if (scoreHistory.isNotEmpty)
                      Center(
                        child: TextButton.icon(
                          onPressed: _showClearOptions,
                          icon: const Icon(Icons.delete, color: Colors.red),
                          label: const Text(
                            "Clear History",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.red,
                            ),
                          ),
                        ),
                      ),

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
      ],
    );
  }

}///End GuessGameState Class