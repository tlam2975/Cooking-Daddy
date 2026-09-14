import 'package:cooking_daddy/data/models/quotes.dart';
import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:ui';
import '../data/repositories/recipe_repository.dart';
import '../data/models/recipe.dart';
// import 'package:cooking_daddy/main.dart';
import 'package:easy_localization/easy_localization.dart';
import '../data/models/list_categories.dart';
import 'dart:async';

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
      // theme: ThemeData(fontFamily: main.fontFamily),
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
  final TextEditingController _searchController = TextEditingController();

  bool isLoading = true;
  late String randomQuote;
  List<Recipe> recipes = [];
  List<Recipe> filteredRecipes = [];
  String? selectedCategoryFilter;

  List<String> get categories {
    return CategoryData.getDisplayNames(context.locale.languageCode);
  }

  Future<bool> _isSelectedCategory(String categoryDisplay) async {
    if (selectedCategoryFilter == null) return false;

    final key = CategoryData.getKeyFromDisplay(
      categoryDisplay,
      context.locale.languageCode,
    );

    return key == selectedCategoryFilter;
  }

  Future<List<String>> _loadCategories() async {
    return CategoryData.getDisplayNames(context.locale.languageCode);
  }

  void _showDeleteConfirmation(Recipe recipe) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('delete'.tr()),
          content: Text('delete_confirmation'.tr()),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('cancel'.tr()),
            ),
            TextButton(
              onPressed: () async {
                await _repository.deleteRecipe(recipe.id);
                Navigator.pop(context);
                _loadRecipes();
              },
              child: Text('delete'.tr(), style: TextStyle(color: Colors.red)),
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
    _debugCurrentCategories(); // ← Add this line
  }

  void _pickRandomQuote() {
    if (mounted) {
      setState(() {
        randomQuote = cookingQuotes[Random().nextInt(cookingQuotes.length)];
        print('Quote picked: $randomQuote');
      });
    }
  }

  // Add at the top of _HomeScreenState class
  Future<void> _debugCurrentCategories() async {
    final recipes = await _repository.getAllRecipes();

    print('=== DEBUG: CURRENT CATEGORIES IN DATABASE ===');
    for (var recipe in recipes) {
      print('Recipe: "${recipe.name}" → category: "${recipe.categoryKey}"');
    }
    print('=== END DEBUG ===');
  }

  Future<void> _loadRecipes() async {
    if (mounted) {
      setState(() {
        isLoading = true;
      });
    }

    final fetchedRecipes = await _repository.getAllRecipes();

    if (mounted) {
      setState(() {
        recipes = fetchedRecipes;
        filteredRecipes = fetchedRecipes;
        isLoading = false;
      });
    }
  }

  Future<void> _toggleFavorite(Recipe recipe) async {
    recipe.isFavorite = !recipe.isFavorite;
    recipe.updatedAt = DateTime.now();
    await _repository.updateRecipe(recipe);
    await _loadRecipes();
  }

  Future<void> _filterByCategory(String? categoryDisplay) async {
    if (categoryDisplay == null) {
      if (mounted) {
        setState(() {
          selectedCategoryFilter = null;
        });
      }
    } else {
      final key = CategoryData.getKeyFromDisplay(
        categoryDisplay,
        context.locale.languageCode,
      );

      if (mounted) {
        // ← Add this
        setState(() {
          selectedCategoryFilter = key;
        });
      }
    }

    _filterRecipes();

    if (mounted && (_scaffoldKey.currentState?.isDrawerOpen ?? false)) {
      // ← Add mounted check
      Navigator.pop(context);
    }
  }

  void _onSearchChanged() {
    _filterRecipes();
  }

  void _filterRecipes() {
    if (mounted) {
      // ← Add this
      setState(() {
        filteredRecipes = recipes.where((recipe) {
          final searchQuery = _searchController.text.toLowerCase();
          final ingredientText = recipe.ingredients
              .map(
                (ingredient) => [
                  ingredient.name,
                  ingredient.note,
                  ingredient.unit?.name,
                  ingredient.quantity?.toString(),
                ].whereType<String>().join(' '),
              )
              .join(' ')
              .toLowerCase();
          final toolText = recipe.tools
              .map(
                (tool) => [
                  tool.name,
                  tool.quantity?.toString(),
                ].whereType<String>().join(' '),
              )
              .join(' ')
              .toLowerCase();
          final tagText = recipe.tags.join(' ').toLowerCase();
          final matchesSearch =
              searchQuery.isEmpty ||
              recipe.name.toLowerCase().contains(searchQuery) ||
              ingredientText.contains(searchQuery) ||
              toolText.contains(searchQuery) ||
              tagText.contains(searchQuery);

          final matchesCategory =
              selectedCategoryFilter == null ||
              recipe.categoryKey == selectedCategoryFilter;

          return matchesSearch && matchesCategory;
        }).toList();
      });
    }
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
                    title: Text('profile'.tr(), style: TextStyle(fontSize: 20)),
                    onTap: () {
                      Navigator.pushNamed(context, '/profile');
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.settings, size: 28),
                    title: Text(
                      'settings'.tr(),
                      style: TextStyle(fontSize: 20),
                    ),
                    onTap: () {
                      Navigator.pushNamed(context, '/settings');
                    },
                  ),
                  const Divider(height: 32, thickness: 2),
                  const SizedBox(height: 24),
                  Text(
                    'category'.tr(),
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 32),
                  Expanded(
                    child: FutureBuilder<List<String>>(
                      future: _loadCategories(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        final categories = snapshot.data!;

                        return ListView.builder(
                          itemCount: categories.length,
                          itemBuilder: (context, index) {
                            final categoryDisplay = categories[index];

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                InkWell(
                                  onTap: () {
                                    _filterByCategory(categoryDisplay);
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12.0,
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          categoryDisplay,
                                          style: const TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        // Show checkmark if this category is selected
                                        FutureBuilder<bool>(
                                          future: _isSelectedCategory(
                                            categoryDisplay,
                                          ),
                                          builder: (context, checkSnapshot) {
                                            if (checkSnapshot.data == true) {
                                              return const Icon(
                                                Icons.check,
                                                color: Colors.black,
                                              );
                                            }
                                            return const SizedBox.shrink();
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
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
                  const Text(
                    'Cooking Daddy',
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w500,
                      color: Color.fromARGB(255, 255, 230, 0),
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
                          const SizedBox(
                            height: 80,
                          ), // Increased to accommodate the frosted bar
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
                                    controller: _searchController,
                                    decoration: InputDecoration(
                                      hintText: 'findSth'.tr(),
                                      border: InputBorder.none,
                                      hintStyle: TextStyle(color: Colors.grey),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
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
                                      CategoryData.getDisplayName(
                                        selectedCategoryFilter!,
                                        context.locale.languageCode,
                                      ),
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
                                      SizedBox(height: 40),
                                      Text(
                                        _searchController.text.isEmpty &&
                                                selectedCategoryFilter == null
                                            ? 'noRecipesYet'.tr()
                                            : 'noRecipesFound'.tr(),
                                        style: TextStyle(
                                          fontSize: 20,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        _searchController.text.isEmpty &&
                                                selectedCategoryFilter == null
                                            ? 'addRecipeDefault'.tr()
                                            : 'tryDifferentSearch'.tr(),
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
                                              if (recipe.imageUrl != null &&
                                                  recipe
                                                      .imageUrl!
                                                      .isNotEmpty) ...[
                                                ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  child: Image.network(
                                                    recipe.imageUrl!,
                                                    width: 72,
                                                    height: 72,
                                                    fit: BoxFit.cover,
                                                    errorBuilder:
                                                        (
                                                          context,
                                                          error,
                                                          stackTrace,
                                                        ) {
                                                          return Container(
                                                            width: 72,
                                                            height: 72,
                                                            color: const Color(
                                                              0xFFFFEAEA,
                                                            ),
                                                            child: const Icon(
                                                              Icons
                                                                  .image_not_supported_outlined,
                                                            ),
                                                          );
                                                        },
                                                  ),
                                                ),
                                                const SizedBox(width: 14),
                                              ],
                                              // Recipe info (tappable)
                                              Expanded(
                                                child: GestureDetector(
                                                  onTap: () async {
                                                    print(
                                                      'Tapping recipe: ${recipe.name}, ID: ${recipe.id}',
                                                    );
                                                    await Navigator.pushNamed(
                                                      context,
                                                      '/recipeDetail',
                                                      arguments: recipe.id,
                                                    );
                                                    _pickRandomQuote();
                                                    _loadRecipes();
                                                  },
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
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
                                                      Text(
                                                        '${CategoryData.getDisplayName(recipe.categoryKey, context.locale.languageCode)}, ${recipe.steps.length} ${'stepCounter'.tr()}',
                                                        style: TextStyle(
                                                          fontSize: 16,
                                                          color:
                                                              Colors.grey[500],
                                                        ),
                                                      ),
                                                      if (recipe
                                                          .tags
                                                          .isNotEmpty) ...[
                                                        const SizedBox(
                                                          height: 8,
                                                        ),
                                                        Wrap(
                                                          spacing: 6,
                                                          runSpacing: 6,
                                                          children: recipe.tags
                                                              .take(3)
                                                              .map(
                                                                (tag) => Chip(
                                                                  label: Text(
                                                                    tag,
                                                                  ),
                                                                  visualDensity:
                                                                      VisualDensity
                                                                          .compact,
                                                                  materialTapTargetSize:
                                                                      MaterialTapTargetSize
                                                                          .shrinkWrap,
                                                                ),
                                                              )
                                                              .toList(),
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              IconButton(
                                                tooltip: recipe.isFavorite
                                                    ? 'unfavorite'.tr()
                                                    : 'favorite'.tr(),
                                                onPressed: () =>
                                                    _toggleFavorite(recipe),
                                                icon: Icon(
                                                  recipe.isFavorite
                                                      ? Icons.favorite
                                                      : Icons.favorite_border,
                                                  color: recipe.isFavorite
                                                      ? const Color(0xFFFF6B6B)
                                                      : Colors.black,
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
                                                    await Navigator.pushNamed(
                                                      context,
                                                      '/recipeEditor',
                                                      arguments: recipe,
                                                    );
                                                    _loadRecipes();
                                                  } else if (value ==
                                                      'delete') {
                                                    _showDeleteConfirmation(
                                                      recipe,
                                                    );
                                                  }
                                                },
                                                itemBuilder:
                                                    (BuildContext context) => [
                                                      PopupMenuItem<String>(
                                                        value: 'edit',
                                                        child: Row(
                                                          children: [
                                                            Icon(
                                                              Icons.edit,
                                                              color:
                                                                  Colors.black,
                                                            ),
                                                            SizedBox(width: 12),
                                                            Text('edit'.tr()),
                                                          ],
                                                        ),
                                                      ),
                                                      PopupMenuItem<String>(
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
                                                              'delete'.tr(),
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
                            'copyright'.tr(),
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
                  // Gradient blur effect - gets blurrier toward the top
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: IgnorePointer(
                      ignoring: true,
                      child: ClipRect(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                          child: Container(
                            height: 100,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  const Color(0xFFFFEAEA).withOpacity(0.9),
                                  const Color(0xFFFFEAEA).withOpacity(0.7),
                                  const Color(0xFFFFEAEA).withOpacity(0.3),
                                  const Color(0xFFFFEAEA).withOpacity(0.0),
                                ],
                                stops: const [0.0, 0.4, 0.7, 1.0],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Menu and Add Recipe buttons (on top of blur)
                  Positioned(
                    top: 16,
                    left: 24,
                    right: 24,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Menu Button
                        IconButton(
                          icon: const Icon(
                            Icons.menu,
                            size: 40,
                            color: Colors.black,
                          ),
                          onPressed: () =>
                              _scaffoldKey.currentState?.openDrawer(),
                        ),
                        // Add Recipe Button
                        ElevatedButton(
                          onPressed: () async {
                            await Navigator.pushNamed(context, '/recipeEditor');
                            _pickRandomQuote();
                            _loadRecipes();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                          ),
                          child: Text(
                            'add_recipe'.tr(),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
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

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged); // ← Remove listener
    _searchController.dispose(); // ← Dispose controller
    super.dispose();
  }
}
