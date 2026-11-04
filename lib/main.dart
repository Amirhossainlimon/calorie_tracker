import 'package:flutter/material.dart';
import 'splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CalorieTrackerApp());
}

const green = Color(0xFF75B82A);
const darkGreen = Color(0xFF397B19);
const ink = Color(0xFF20251D);
const muted = Color(0xFF858B80);
const bg = Color(0xFFF7F8F2);

class CalorieTrackerApp extends StatelessWidget {
  const CalorieTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CalorieSnap',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: bg,
        colorScheme: ColorScheme.fromSeed(seedColor: green),
      ),
      home: const SplashScreen(),
    );
  }
}

class FoodEntry {
  String name;
  double calories;
  String category;
  final DateTime addedAt;

  FoodEntry({
    required this.name,
    required this.calories,
    required this.category,
    required this.addedAt,
  });
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final List<FoodEntry> foods = [];
  final TextEditingController searchController = TextEditingController();

  final List<String> categories = const [
    'All',
    'Breakfast',
    'Lunch',
    'Dinner',
    'Snack',
  ];

  double dailyGoal = 2000;
  String selectedCategory = 'All';
  String searchQuery = '';

  double get total =>
      foods.fold<double>(0, (sum, food) => sum + food.calories);

  double get remaining => dailyGoal - total;

  double get progress =>
      dailyGoal <= 0 ? 0 : (total / dailyGoal).clamp(0.0, 1.0);

  String format(double value) {
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
  }

  String get today {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    final now = DateTime.now();
    return '${now.day} ${months[now.month - 1]} ${now.year}';
  }

  List<FoodEntry> get filteredFoods {
    return foods.where((food) {
      final matchesCategory =
          selectedCategory == 'All' || food.category == selectedCategory;
      final matchesSearch =
      food.name.toLowerCase().contains(searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  InputDecoration inputStyle(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: darkGreen),
      filled: true,
      fillColor: const Color(0xFFF7F9F4),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Color(0xFFEBEFE7)),
      ),
    );
  }

  Future<void> showFoodForm({FoodEntry? food}) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FoodFormSheet(
        food: food,
        categories: categories.skip(1).toList(),
        inputStyle: inputStyle,
        onSave: (savedFood) {
          if (!mounted) return;

          setState(() {
            if (food == null) {
              foods.insert(0, savedFood);
            } else {
              food.name = savedFood.name;
              food.calories = savedFood.calories;
              food.category = savedFood.category;
            }
          });
        },
      ),
    );
  }

  void deleteFood(FoodEntry food) {
    final index = foods.indexOf(food);
    if (index == -1) return;

    setState(() => foods.removeAt(index));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${food.name} deleted'),
        action: SnackBarAction(
          label: 'UNDO',
          onPressed: () {
            if (!mounted) return;
            setState(() {
              final safeIndex = index > foods.length ? foods.length : index;
              foods.insert(safeIndex, food);
            });
          },
        ),
      ),
    );
  }

  Future<void> changeGoal() async {
    final result = await showDialog<double>(
      context: context,
      builder: (_) => ChangeGoalDialog(
        initialGoal: dailyGoal,
        formatCallback: format,
      ),
    );

    if (!mounted || result == null) return;

    setState(() => dailyGoal = result);
  }

  @override
  Widget build(BuildContext context) {
    final visibleFoods = filteredFoods;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showFoodForm(),
        backgroundColor: green,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Food'),
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 15),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  header(),
                  const SizedBox(height: 24),
                  calorieCard(),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Daily Summary',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                            color: ink,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: changeGoal,
                        icon: const Icon(Icons.tune, size: 18),
                        label: const Text('Edit Goal'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  summaryCards(),
                  const SizedBox(height: 25),
                  mealBreakdown(),
                  const SizedBox(height: 25),
                  const Text(
                    "Today's Meals",
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: ink,
                    ),
                  ),
                  const SizedBox(height: 14),
                  searchField(),
                  const SizedBox(height: 12),
                  categoryFilters(),
                ]),
              ),
            ),
            if (visibleFoods.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 120),
                  child: emptyState(),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                        (context, index) => foodTile(visibleFoods[index]),
                    childCount: visibleFoods.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget header() {
    return Row(
      children: [
        Container(
          height: 48,
          width: 48,
          decoration: BoxDecoration(
            color: const Color(0xFFEAF4DD),
            borderRadius: BorderRadius.circular(15),
          ),
          child: const Icon(Icons.spa_rounded, color: darkGreen, size: 27),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CalorieSnap',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: ink,
                ),
              ),
              Text(
                'Eat well. Feel great.',
                style: TextStyle(color: muted, fontSize: 12),
              ),
            ],
          ),
        ),
        const Icon(Icons.calendar_month_rounded, color: ink, size: 26),
      ],
    );
  }

  Widget calorieCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEDF7D9), Color(0xFFE4F0C9)],
        ),
        borderRadius: BorderRadius.circular(27),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'DAILY INTAKE',
                  style: TextStyle(
                    color: darkGreen,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                    fontSize: 12,
                  ),
                ),
              ),
              Text(
                today,
                style: const TextStyle(color: darkGreen, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 190,
            width: 190,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  height: 175,
                  width: 175,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 13,
                    strokeCap: StrokeCap.round,
                    backgroundColor: const Color(0xFFDDE2D7),
                    valueColor: const AlwaysStoppedAnimation<Color>(green),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.eco, color: darkGreen),
                    const SizedBox(height: 5),
                    const Text(
                      'Consumed Today',
                      style: TextStyle(color: muted, fontSize: 12),
                    ),
                    Text(
                      format(total),
                      style: const TextStyle(
                        fontSize: 38,
                        fontWeight: FontWeight.bold,
                        color: ink,
                      ),
                    ),
                    const Text(
                      'kcal',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Goal ${format(dailyGoal)} kcal',
                      style: const TextStyle(
                        color: darkGreen,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                Icons.check_circle_outline,
                color: darkGreen,
                size: 18,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  remaining >= 0
                      ? '${format(remaining)} kcal remaining'
                      : '${format(remaining.abs())} kcal over goal',
                  style: const TextStyle(
                    color: darkGreen,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
              Text(
                '${(progress * 100).round()}%',
                style: const TextStyle(
                  color: darkGreen,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget summaryCards() {
    return Row(
      children: [
        Expanded(
          child: summaryCard(
            'Total',
            format(total),
            'kcal eaten',
            Icons.local_fire_department,
            Colors.orange,
            const Color(0xFFFFF2E4),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: summaryCard(
            'Daily Goal',
            format(dailyGoal),
            'kcal target',
            Icons.flag,
            Colors.blue,
            const Color(0xFFEAF5FC),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: summaryCard(
            'Remaining',
            format(remaining.abs()),
            remaining >= 0 ? 'kcal left' : 'kcal over',
            Icons.bolt,
            darkGreen,
            const Color(0xFFEDF6E2),
          ),
        ),
      ],
    );
  }

  Widget summaryCard(
      String title,
      String value,
      String subtitle,
      IconData icon,
      Color iconColor,
      Color cardColor,
      ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 17,
            backgroundColor: cardColor,
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(color: muted, fontSize: 10)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: ink,
              ),
            ),
          ),
          Text(
            subtitle,
            style: const TextStyle(color: muted, fontSize: 9),
          ),
        ],
      ),
    );
  }

  Widget mealBreakdown() {
    const mealCategories = ['Breakfast', 'Lunch', 'Dinner', 'Snack'];

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(21),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Calories by Meal',
            style: TextStyle(
              color: ink,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 15),
          ...mealCategories.map((category) {
            final amount = foods
                .where((food) => food.category == category)
                .fold<double>(0, (sum, food) => sum + food.calories);
            final fraction = total <= 0 ? 0.0 : (amount / total).clamp(0.0, 1.0);

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          category,
                          style: const TextStyle(
                            color: ink,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Text(
                        '${format(amount)} kcal',
                        style: const TextStyle(color: muted, fontSize: 11),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: LinearProgressIndicator(
                      value: fraction,
                      minHeight: 7,
                      backgroundColor: const Color(0xFFEEF1E9),
                      valueColor: const AlwaysStoppedAnimation<Color>(green),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget searchField() {
    return TextField(
      controller: searchController,
      onChanged: (value) => setState(() => searchQuery = value),
      decoration: InputDecoration(
        hintText: 'Search food...',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: searchQuery.isEmpty
            ? null
            : IconButton(
          onPressed: () {
            searchController.clear();
            setState(() => searchQuery = '');
          },
          icon: const Icon(Icons.close),
        ),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget categoryFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: categories.map((category) {
          final selected = selectedCategory == category;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(category),
              selected: selected,
              onSelected: (_) {
                setState(() => selectedCategory = category);
              },
              selectedColor: green,
              backgroundColor: Colors.white,
              side: BorderSide.none,
              showCheckmark: false,
              labelStyle: TextStyle(
                color: selected ? Colors.white : ink,
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget emptyState() {
    final searching = searchQuery.isNotEmpty || selectedCategory != 'All';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Icon(Icons.restaurant_menu, size: 43, color: green),
          const SizedBox(height: 10),
          Text(
            searching ? 'No matching food found' : 'No meals logged yet',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: ink,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            searching
                ? 'Try another search or category.'
                : 'Tap Add Food to track your first meal.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: muted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget foodTile(FoodEntry food) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 11, 5, 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(19),
      ),
      child: Row(
        children: [
          Container(
            height: 49,
            width: 49,
            decoration: BoxDecoration(
              color: const Color(0xFFEDF6E2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.lunch_dining, color: darkGreen),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  food.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: ink,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  food.category,
                  style: const TextStyle(color: muted, fontSize: 11),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                format(food.calories),
                style: const TextStyle(
                  color: darkGreen,
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
              ),
              const Text(
                'kcal',
                style: TextStyle(color: muted, fontSize: 10),
              ),
            ],
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') {
                showFoodForm(food: food);
              } else if (value == 'delete') {
                deleteFood(food);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined, size: 19),
                    SizedBox(width: 9),
                    Text('Edit'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, color: Colors.red, size: 19),
                    SizedBox(width: 9),
                    Text('Delete'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class FoodFormSheet extends StatefulWidget {
  final FoodEntry? food;
  final List<String> categories;
  final InputDecoration Function(String, IconData) inputStyle;
  final ValueChanged<FoodEntry> onSave;

  const FoodFormSheet({
    super.key,
    this.food,
    required this.categories,
    required this.inputStyle,
    required this.onSave,
  });

  @override
  State<FoodFormSheet> createState() => _FoodFormSheetState();
}

class _FoodFormSheetState extends State<FoodFormSheet> {
  late final TextEditingController nameController;
  late final TextEditingController calorieController;
  late String category;

  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();

    nameController = TextEditingController(text: widget.food?.name ?? '');
    calorieController = TextEditingController(
      text: widget.food == null ? '' : _format(widget.food!.calories),
    );
    category = widget.food?.category ?? 'Breakfast';
  }

  String _format(double value) {
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
  }

  @override
  void dispose() {
    nameController.dispose();
    calorieController.dispose();
    super.dispose();
  }

  void saveFood() {
    if (!(formKey.currentState?.validate() ?? false)) return;

    final calories = double.tryParse(calorieController.text.trim());
    if (calories == null || !calories.isFinite || calories <= 0) return;

    final savedFood = FoodEntry(
      name: nameController.text.trim(),
      calories: calories,
      category: category,
      addedAt: widget.food?.addedAt ?? DateTime.now(),
    );

    widget.onSave(savedFood);

    // The sheet owns its controllers. They are disposed by this State
    // when Flutter removes the sheet after its closing transition.
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.food == null ? 'Add Your Food' : 'Edit Food',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: ink,
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration:
                  widget.inputStyle('Food Name', Icons.restaurant),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter food name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 15),
                TextFormField(
                  controller: calorieController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: widget.inputStyle(
                    'Calories (kcal)',
                    Icons.local_fire_department,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter calorie amount';
                    }

                    final number = double.tryParse(value.trim());
                    if (number == null ||
                        !number.isFinite ||
                        number <= 0) {
                      return 'Enter a valid positive number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 15),
                DropdownButtonFormField<String>(
                  value: category,
                  decoration: widget.inputStyle(
                    'Meal Category',
                    Icons.category_outlined,
                  ),
                  items: widget.categories.map((item) {
                    return DropdownMenuItem<String>(
                      value: item,
                      child: Text(item),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => category = value);
                    }
                  },
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: green,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: saveFood,
                    child: Text(
                      widget.food == null ? 'Add Food' : 'Save Changes',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ChangeGoalDialog extends StatefulWidget {
  final double initialGoal;
  final String Function(double) formatCallback;

  const ChangeGoalDialog({
    super.key,
    required this.initialGoal,
    required this.formatCallback,
  });

  @override
  State<ChangeGoalDialog> createState() => _ChangeGoalDialogState();
}

class _ChangeGoalDialogState extends State<ChangeGoalDialog> {
  late final TextEditingController controller;
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(
      text: widget.formatCallback(widget.initialGoal),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void saveGoal() {
    if (!(formKey.currentState?.validate() ?? false)) return;

    final value = double.tryParse(controller.text.trim());
    if (value == null || !value.isFinite || value <= 0) return;

    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Change Daily Goal'),
      content: Form(
        key: formKey,
        child: TextFormField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Daily Goal (kcal)',
            border: OutlineInputBorder(),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Enter daily goal';
            }

            final number = double.tryParse(value.trim());
            if (number == null || !number.isFinite || number <= 0) {
              return 'Enter a valid positive number';
            }
            return null;
          },
          onFieldSubmitted: (_) => saveGoal(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: saveGoal,
          child: const Text('Save'),
        ),
      ],
    );
  }
}