import 'package:flutter/material.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _controller = PageController();
  int _pageIndex = 0;

  final List<Map<String, String>> pages = [
    {
      "title": "Welcome to Food4Need",
      "subtitle": "Connecting restaurants and NGOs to reduce food waste.",
    },
    {
      "title": "Join the Community",
      "subtitle": "Restaurants donate food. NGOs distribute to those in need.",
    },
    {
      "title": "Make an Impact",
      "subtitle": "Together we help reduce hunger and food waste.",
    },
    {
      "title": "Get Started",
      "subtitle": "Create an account or login to continue.",
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfffefae0),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _controller,
              onPageChanged: (index) {
                setState(() => _pageIndex = index);
              },
              itemCount: pages.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 25),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.restaurant,
                        size: 120,
                        color: Colors.brown[300],
                      ),
                      const SizedBox(height: 30),
                      Text(
                        pages[index]["title"]!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Color(0xffd4a373),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        pages[index]["subtitle"]!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 18,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Dot indicators
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              pages.length,
              (index) => Container(
                margin: const EdgeInsets.all(4),
                width: _pageIndex == index ? 14 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _pageIndex == index
                      ? const Color(0xffd4a373)
                      : Colors.grey,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Buttons (Next / Done / Skip)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 25),
            child: _pageIndex == pages.length - 1
                ? Column(
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xffd4a373),
                          minimumSize: const Size(double.infinity, 50),
                        ),
                        onPressed: () {
                          Navigator.pushReplacementNamed(context, "/register");
                        },
                        child: const Text(
                          "Get Started",
                          style: TextStyle(color: Colors.white, fontSize: 18),
                        ),
                      ),
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: () {
                          Navigator.pushReplacementNamed(context, "/login");
                        },
                        child: const Text(
                          "Already have an account? Login",
                          style: TextStyle(
                            color: Colors.black87,
                            fontSize: 16,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                      const SizedBox(height: 25),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Skip
                      TextButton(
                        onPressed: () {
                          _controller.jumpToPage(pages.length - 1);
                        },
                        child: const Text(
                          "Skip",
                          style: TextStyle(color: Colors.black, fontSize: 16),
                        ),
                      ),

                      // Next
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xffd4a373),
                        ),
                        onPressed: () {
                          _controller.nextPage(
                            duration: const Duration(milliseconds: 300),
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
    );
  }
}
