import 'package:cooking_daddy/data/models/quotes.dart';
import 'package:flutter/material.dart';
import 'dart:math';
import '../data/repositories/recipe_repository.dart';
import '../data/models/recipe.dart';

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
  final RecipeRepository _repository = RecipeRepository();
  final TextEditingController _searchController =
      TextEditingController(); // Add this

  bool isLoading = true;
  late String randomQuote;
  List<Recipe> recipes = [];
  List<Recipe> filteredRecipes =
      []; // Add this - for displaying filtered results
  String? selectedCategoryFilter; // Add this - tracks selected category

  // List of categories
  final List<String> categories = [
    'Breakfast',
    'Lunch',
    'Dinner',
    'Lazy meals',
    'Dessert',
    'Drinks',
  ];

  // final List<String> quotes = [
  //   'just like how ur mom makes it',
  //   'oui chef!',
  //   'cause dads can cook too',
  //   'fuiyoooooooo',
  //   'please don\'t mess it up',
  //   'about to be an influencer',
  // ];

  void _showDeleteConfirmation(Recipe recipe) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Recipe'),
          content: Text('Are you sure you want to delete "${recipe.name}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                // Delete the recipe
                await _repository.deleteRecipe(recipe.id);
                Navigator.pop(context); // Close dialog
                _loadRecipes(); // Reload the list
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _pickRandomQuote();
    Future.delayed(Duration(milliseconds: 100));
    _loadRecipes();
    _searchController.addListener(_onSearchChanged);
  }

  // This one is used to pick a random quote from the list as user opens the screen
  void _pickRandomQuote() {
    setState(() {
      randomQuote = cookingQuotes[Random().nextInt(cookingQuotes.length)];
      print('Quote picked: $randomQuote');
    });
  }

  Future<void> _loadRecipes() async {
    setState(() {
      isLoading = true;
    });

    final fetchedRecipes = await _repository.getAllRecipes();

    setState(() {
      recipes = fetchedRecipes;
      filteredRecipes = fetchedRecipes; // Initialize filtered list
      isLoading = false;
    });
  }

  void _filterByCategory(String? category) {
    setState(() {
      selectedCategoryFilter = category;
    });
    _filterRecipes(); // Move outside setState

    // Only close drawer if it's actually open
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.pop(context);
    }
  }

  void _onSearchChanged() {
    _filterRecipes();
  }

  void _filterRecipes() {
    setState(() {
      filteredRecipes = recipes.where((recipe) {
        final searchQuery = _searchController.text.toLowerCase();
        // Filter by search text - includes name AND ingredients
        final matchesSearch =
            searchQuery.isEmpty ||
            recipe.name.toLowerCase().contains(searchQuery) ||
            (recipe.ingredients.toLowerCase().contains(searchQuery)) ||
            (recipe.tools.toLowerCase().contains(searchQuery));

        // Filter by category
        final matchesCategory =
            selectedCategoryFilter == null ||
            recipe.category == selectedCategoryFilter;

        return matchesSearch && matchesCategory;
      }).toList();
    });
  }

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
                  ListTile(
                    leading: const Icon(Icons.person, size: 28),
                    title: const Text(
                      'Profile',
                      style: TextStyle(fontSize: 20),
                    ),
                    onTap: () {
                      Navigator.pushNamed(context, '/profile');
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.settings, size: 28),
                    title: const Text(
                      'Settings',
                      style: TextStyle(fontSize: 20),
                    ),
                    onTap: () {
                      Navigator.pushNamed(context, '/settings');
                    },
                  ),
                  const Divider(height: 32, thickness: 2),
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
                                _filterByCategory(
                                  categories[index],
                                ); // Changed - now filters by category
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12.0,
                                ),
                                child: Row(
                                  // Changed from Text to Row to add checkmark
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      categories[index],
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    // Show checkmark if this category is selected
                                    if (selectedCategoryFilter ==
                                        categories[index])
                                      const Icon(
                                        Icons.check,
                                        color: Colors.black,
                                      ),
                                  ],
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
                  Text(
                    randomQuote,
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
                                  child: TextField(
                                    controller:
                                        _searchController, // Connect controller
                                    decoration: const InputDecoration(
                                      hintText: 'Find something?',
                                      border: InputBorder.none,
                                      hintStyle: TextStyle(color: Colors.grey),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Clear search button
                              if (_searchController.text.isNotEmpty)
                                IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                  },
                                ),
                            ],
                          ),
                          // Show active filter indicator
                          if (selectedCategoryFilter != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: Row(
                                children: [
                                  Chip(
                                    label: Text(
                                      'Category: $selectedCategoryFilter',
                                    ),
                                    onDeleted: () => _filterByCategory(null),
                                    deleteIcon: const Icon(
                                      Icons.close,
                                      size: 18,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 32),
                          // Recipe Cards
                          isLoading
                              ? const Center(child: CircularProgressIndicator())
                              : recipes.isEmpty
                              ? Center(
                                  child: Column(
                                    children: [
                                      const SizedBox(height: 40),
                                      Text(
                                        _searchController.text.isEmpty &&
                                                selectedCategoryFilter == null
                                            ? 'No recipes yet!'
                                            : 'No recipes found',
                                        style: TextStyle(
                                          fontSize: 20,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        _searchController.text.isEmpty &&
                                                selectedCategoryFilter == null
                                            ? 'Tap "Add recipe!" to create your first recipe'
                                            : 'Try a different search or category',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[500],
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : Column(
                                  children: filteredRecipes.map((recipe) {
                                    return Center(
                                      child: Container(
                                        width:
                                            MediaQuery.of(context).size.width *
                                            0.9,
                                        margin: const EdgeInsets.only(
                                          bottom: 24.0,
                                        ),
                                        child: Container(
                                          padding: const EdgeInsets.all(20),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(
                                              24,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(
                                                  0.1,
                                                ),
                                                blurRadius: 10,
                                                offset: const Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                          child: Row(
                                            children: [
                                              // Recipe info (tappable)
                                              Expanded(
                                                child: GestureDetector(
                                                  onTap: () async {
                                                    print(
                                                      'Tapping recipe: ${recipe.name}, ID: ${recipe.id}',
                                                    ); //DEBUG LOG
                                                    await Navigator.pushNamed(
                                                      context,
                                                      '/recipeDetail',
                                                      arguments: recipe.id,
                                                    );
                                                    _pickRandomQuote();
                                                  },
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      // Recipe Name (Row 1)
                                                      Text(
                                                        recipe.name,
                                                        style: const TextStyle(
                                                          fontSize: 24,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: Colors.black,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 8),
                                                      // Category and steps (Row 2)
                                                      Text(
                                                        '${recipe.category}, ${recipe.steps.length} steps',
                                                        style: TextStyle(
                                                          fontSize: 16,
                                                          color:
                                                              Colors.grey[500],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              // Edit menu button
                                              PopupMenuButton<String>(
                                                icon: const Icon(
                                                  Icons.more_vert,
                                                  size: 28,
                                                  color: Colors.black,
                                                ),
                                                onSelected: (value) async {
                                                  if (value == 'edit') {
                                                    // Navigate to recipe editor with recipe data
                                                    await Navigator.pushNamed(
                                                      context,
                                                      '/recipeEditor',
                                                      arguments: recipe,
                                                    );
                                                    // Reload recipes after editing
                                                    _loadRecipes();
                                                  } else if (value ==
                                                      'delete') {
                                                    // Show delete confirmation
                                                    _showDeleteConfirmation(
                                                      recipe,
                                                    );
                                                  }
                                                },
                                                itemBuilder:
                                                    (BuildContext context) => [
                                                      const PopupMenuItem<
                                                        String
                                                      >(
                                                        value: 'edit',
                                                        child: Row(
                                                          children: [
                                                            Icon(
                                                              Icons.edit,
                                                              color:
                                                                  Colors.black,
                                                            ),
                                                            SizedBox(width: 12),
                                                            Text('Edit'),
                                                          ],
                                                        ),
                                                      ),
                                                      const PopupMenuItem<
                                                        String
                                                      >(
                                                        value: 'delete',
                                                        enabled: true,
                                                        child: Row(
                                                          children: [
                                                            Icon(
                                                              Icons.delete,
                                                              color: Colors.red,
                                                            ),
                                                            SizedBox(width: 12),
                                                            Text(
                                                              'Delete',
                                                              style: TextStyle(
                                                                color:
                                                                    Colors.red,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
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
                      onPressed: () async {
                        await Navigator.pushNamed(context, '/recipeEditor');
                        _pickRandomQuote();
                        _loadRecipes();
                      },
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
