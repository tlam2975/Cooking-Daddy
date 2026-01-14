import 'package:flutter/material.dart';

void main() {
  runApp(const CookingDaddyApp());
}

class CookingDaddyApp extends StatelessWidget {
  const CookingDaddyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const HomePage(),
      theme: ThemeData(fontFamily: 'PixelifySans'),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // List of categories
  final List<String> categories = [
    'Homecook',
    'Lazy meals',
    'Breakfast',
    'Lunch',
    'Dinner',
    'Dessert',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFFFEAEA),
      drawer: Drawer(
        width: MediaQuery.of(context).size.width * 0.7,
        child: Container(
          color: const Color(0xFFFFEAEA),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close, size: 32),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Categories',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 32),
                  // Categories List
                  Expanded(
                    child: ListView.builder(
                      itemCount: categories.length,
                      itemBuilder: (context, index) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            InkWell(
                              onTap: () {
                                // Handle category selection
                                Navigator.pop(context);
                                // TODO: Filter recipes by category
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12.0,
                                ),
                                child: Text(
                                  categories[index],
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                            // Lines under each category
                            ...List.generate(
                              3,
                              (lineIndex) => Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                height: 2,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        bottom: false,
        left: false,
        right: false,
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              color: const Color(0xFFFFA4A4),
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  Text(
                    'Cooking Daddy',
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w500,
                      color: const Color.fromARGB(255, 255, 230, 0),
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'just like how ur mom makes it',
                    style: TextStyle(fontSize: 20, color: Colors.black),
                  ),
                ],
              ),
            ),
            // Main Content
            Expanded(
              child: Stack(
                children: [
                  // Scrollable Content
                  SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        children: [
                          const SizedBox(height: 60),
                          // Search Bar
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  decoration: const BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(
                                        color: Colors.black,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                  child: const TextField(
                                    decoration: InputDecoration(
                                      hintText: 'Find something?',
                                      border: InputBorder.none,
                                      hintStyle: TextStyle(color: Colors.grey),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton(
                                onPressed: () {},
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.black,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                                child: const Text('Search'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),
                          // Recipe Cards
                          ...List.generate(
                            6,
                            (index) => Padding(
                              padding: const EdgeInsets.only(bottom: 24.0),
                              child: GestureDetector(
                                onTap: () {
                                  // Navigate to cooking session
                                  Navigator.pushNamed(
                                    context,
                                    '/cookingSession',
                                  );
                                },
                                child: Container(
                                  height: 120,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(24),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Recipe ${index + 1}',
                                      style: const TextStyle(fontSize: 18),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // Footer
                          const SizedBox(height: 24),
                          Text(
                            '©2026 Tung Lam created',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[400],
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                  // Menu Button
                  Positioned(
                    top: 24,
                    left: 24,
                    child: IconButton(
                      icon: const Icon(
                        Icons.menu,
                        size: 40,
                        color: Colors.black,
                      ),
                      onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                    ),
                  ),
                  // Add Recipe Button
                  Positioned(
                    top: 24,
                    right: 24,
                    child: ElevatedButton(
                      onPressed: () =>
                          Navigator.pushNamed(context, '/recipeEditor'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                      child: const Text('Add recipe!'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
