import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _controller = PageController();
  int _pageIndex = 0;

  final List<Map<String, dynamic>> pages = [
    {
      "title": "Welcome to Food4Need",
      "subtitle": "Connecting restaurants and NGOs to reduce food waste.",
      "icon": Icons.restaurant,
    },
    {
      "title": "Join the Community",
      "subtitle": "Restaurants donate food. NGOs distribute to those in need.",
      "icon": Icons.volunteer_activism,
    },
    {
      "title": "Make an Impact",
      "subtitle": "Together we help reduce hunger and food waste.",
      "icon": Icons.favorite,
    },
    {
      "title": "Get Started",
      "subtitle": "Create an account or login to continue.",
      "icon": Icons.rocket_launch,
    },
  ];

  Future<void> _completeOnboarding(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool("onboarding_done", true);
    Navigator.pushReplacementNamed(context, "/login");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xfffefae0), Color(0xfffaedcd)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: pages.length,
                onPageChanged: (index) {
                  setState(() => _pageIndex = index);
                },
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 500),
                      transitionBuilder: (child, animation) {
                        return SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0.3, 0),
                            end: Offset.zero,
                          ).animate(animation),
                          child: FadeTransition(
                            opacity: animation,
                            child: child,
                          ),
                        );
                      },
                      child: Column(
                        key: ValueKey(index),
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // ICON CONTAINER
                          Container(
                            padding: const EdgeInsets.all(32),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.brown.withOpacity(0.25),
                                  blurRadius: 25,
                                  offset: const Offset(0, 12),
                                ),
                              ],
                            ),
                            child: Icon(
                              pages[index]["icon"],
                              size: 90,
                              color: const Color(0xffd4a373),
                            ),
                          ),

                          const SizedBox(height: 40),

                          // TEXT CARD
                          Container(
                            padding: const EdgeInsets.all(26),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(22),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.06),
                                  blurRadius: 18,
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Text(
                                  pages[index]["title"],
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xffd4a373),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  pages[index]["subtitle"],
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // DOT INDICATORS
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                pages.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.all(4),
                  width: _pageIndex == index ? 22 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _pageIndex == index
                        ? const Color(0xffd4a373)
                        : Colors.grey[400],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // BUTTONS
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _pageIndex == pages.length - 1
                  ? Column(
                      children: [
                        // REGISTER
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xffd4a373),
                            minimumSize: const Size(double.infinity, 54),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: () async {
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setBool("onboarding_done", true);
                            Navigator.pushReplacementNamed(
                              context,
                              "/register",
                            );
                          },
                          child: const Text(
                            "Create Account",
                            style: TextStyle(color: Colors.white, fontSize: 18),
                          ),
                        ),

                        const SizedBox(height: 14),

                        // LOGIN
                        TextButton(
                          onPressed: () async {
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setBool("onboarding_done", true);
                            Navigator.pushReplacementNamed(context, "/login");
                          },
                          child: const Text(
                            "Already have an account? Login",
                            style: TextStyle(fontSize: 16),
                          ),
                        ),

                        const SizedBox(height: 30),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: () {
                            _controller.jumpToPage(pages.length - 1);
                          },
                          child: const Text(
                            "Skip",
                            style: TextStyle(color: Colors.black, fontSize: 16),
                          ),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xffd4a373),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: () {
                            _controller.nextPage(
                              duration: const Duration(milliseconds: 400),
                              curve: Curves.easeInOut,
                            );
                          },
                          child: const Text(
                            "Next",
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
