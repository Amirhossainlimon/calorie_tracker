import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'splash_screen.dart';

const Color primaryGreen = Color(0xFF65B51B);
const Color darkGreen = Color(0xFF173D27);
const Color lightGreen = Color(0xFFEAF5DE);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final isDark = prefs.getBool('darkMode') ?? false;

  runApp(CalorieSnapApp(initialDark: isDark));
}

class CalorieSnapApp extends StatefulWidget {
  final bool initialDark;

  const CalorieSnapApp({
    super.key,
    required this.initialDark,
  });

  @override
  State<CalorieSnapApp> createState() => _CalorieSnapAppState();
}

class _CalorieSnapAppState extends State<CalorieSnapApp> {
  late bool isDark;

  @override
  void initState() {
    super.initState();
    isDark = widget.initialDark;
  }

  Future<void> toggleTheme() async {
    setState(() {
      isDark = !isDark;
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('darkMode', isDark);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CalorieSnap',
      debugShowCheckedModeBanner: false,
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryGreen,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF8FFF2),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF8FFF2),
          surfaceTintColor: Colors.transparent,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryGreen,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF11150F),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF11150F),
          surfaceTintColor: Colors.transparent,
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF1D241A),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
      home: SplashScreen(
        onFinished: (context) => DashboardScreen(
          onToggleTheme: toggleTheme,
          isDark: isDark,
        ),
      ),
    );
  }
}

// ============================================================
// FOOD MODEL
// ============================================================

class FoodEntry {
  String id;
  String name;
  double calories;
  String category;
  DateTime addedAt;
  bool isFavorite;

  FoodEntry({
    required this.id,
    required this.name,
    required this.calories,
    required this.category,
    required this.addedAt,
    this.isFavorite = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'calories': calories,
      'category': category,
      'addedAt': addedAt.toIso8601String(),
      'isFavorite': isFavorite,
    };
  }

  factory FoodEntry.fromJson(Map<String, dynamic> json) {
    return FoodEntry(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      calories: (json['calories'] as num).toDouble(),
      category: json['category'] ?? 'Snack',
      addedAt: DateTime.tryParse(json['addedAt'] ?? '') ?? DateTime.now(),
      isFavorite: json['isFavorite'] ?? false,
    );
  }
}

// ============================================================
// DASHBOARD
// ============================================================

class DashboardScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final bool isDark;

  const DashboardScreen({
    super.key,
    required this.onToggleTheme,
    required this.isDark,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final List<FoodEntry> foods = [];

  final TextEditingController searchController =
  TextEditingController();

  final List<String> categories = [
    'All',
    'Breakfast',
    'Lunch',
    'Dinner',
    'Snack',
  ];

  double dailyGoal = 2000;

  String selectedCategory = 'All';
  String searchQuery = '';

  DateTime selectedDate = DateUtils.dateOnly(DateTime.now());

  bool showFavoritesOnly = false;
  bool isLoading = true;

  bool sameDay(DateTime a, DateTime b) {
    return a.year == b.year &&
        a.month == b.month &&
        a.day == b.day;
  }

  List<FoodEntry> get selectedDayFoods {
    return foods
        .where((food) => sameDay(food.addedAt, selectedDate))
        .toList()
      ..sort(
            (a, b) => b.addedAt.compareTo(a.addedAt),
      );
  }

  double get total {
    return selectedDayFoods.fold<double>(
      0,
          (sum, food) => sum + food.calories,
    );
  }

  double get remaining => dailyGoal - total;

  double get progress {
    if (dailyGoal <= 0) return 0;
    return (total / dailyGoal).clamp(0.0, 1.0);
  }

  String formatCalories(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(1);
  }

  String get dateLabel {
    if (sameDay(selectedDate, DateTime.now())) {
      return 'Today, ${DateFormat('d MMM yyyy').format(selectedDate)}';
    }

    return DateFormat('EEE, d MMM yyyy').format(selectedDate);
  }

  List<FoodEntry> get filteredFoods {
    return selectedDayFoods.where((food) {
      final categoryMatch = selectedCategory == 'All' ||
          food.category == selectedCategory;

      final searchMatch = food.name
          .toLowerCase()
          .contains(searchQuery.toLowerCase());

      final favoriteMatch =
          !showFavoritesOnly || food.isFavorite;

      return categoryMatch && searchMatch && favoriteMatch;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    loadData();
  }

  // ==========================================================
  // LOCAL DATA
  // ==========================================================

  Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();

    final savedFoods = prefs.getString('foods');

    if (savedFoods != null) {
      try {
        final decoded = jsonDecode(savedFoods) as List;

        foods.addAll(
          decoded.map(
                (item) => FoodEntry.fromJson(
              Map<String, dynamic>.from(item),
            ),
          ),
        );
      } catch (e) {
        debugPrint('Food loading error: $e');
      }
    }

    dailyGoal = prefs.getDouble('dailyGoal') ?? 2000;

    if (mounted) {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> saveData() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      'foods',
      jsonEncode(
        foods.map((food) => food.toJson()).toList(),
      ),
    );

    await prefs.setDouble('dailyGoal', dailyGoal);
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  // ==========================================================
  // ADD / EDIT FOOD
  // ==========================================================

  Future<void> openFoodForm({
    FoodEntry? existing,
    FoodEntry? quickFood,
  }) async {
    final result = await showModalBottomSheet<FoodEntry>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FoodFormSheet(
        existing: existing,
        initial: quickFood,
        categories: categories.skip(1).toList(),
      ),
    );

    if (result == null) return;

    setState(() {
      if (existing == null) {
        result.addedAt = selectedDate.add(
          Duration(
            hours: DateTime.now().hour,
            minutes: DateTime.now().minute,
          ),
        );

        foods.insert(0, result);
      } else {
        final index = foods.indexWhere(
              (food) => food.id == existing.id,
        );

        if (index >= 0) {
          foods[index] = result;
        }
      }
    });

    await saveData();
  }

  // ==========================================================
  // DELETE FOOD + UNDO
  // ==========================================================

  Future<void> deleteFood(FoodEntry food) async {
    final index = foods.indexOf(food);

    if (index < 0) return;

    setState(() {
      foods.removeAt(index);
    });

    await saveData();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${food.name} deleted'),
        action: SnackBarAction(
          label: 'UNDO',
          onPressed: () async {
            setState(() {
              foods.insert(
                index.clamp(0, foods.length),
                food,
              );
            });

            await saveData();
          },
        ),
      ),
    );
  }

  // ==========================================================
  // FAVORITES
  // ==========================================================

  Future<void> toggleFavorite(FoodEntry food) async {
    setState(() {
      food.isFavorite = !food.isFavorite;
    });

    await saveData();
  }

  // ==========================================================
  // CUSTOM CALORIE GOAL
  // ==========================================================

  Future<void> editGoal() async {
    final result = await showDialog<double>(
      context: context,
      builder: (_) => GoalDialog(
        initialGoal: dailyGoal,
      ),
    );

    if (result == null) return;

    setState(() {
      dailyGoal = result;
    });

    await saveData();
  }

  // ==========================================================
  // CLEAR DAY
  // ==========================================================

  Future<void> clearSelectedDay() async {
    final dayFoods = selectedDayFoods;

    if (dayFoods.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear this day?'),
        content: Text(
          'Remove all ${dayFoods.length} food entries?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      foods.removeWhere(
            (food) => sameDay(food.addedAt, selectedDate),
      );
    });

    await saveData();
  }

  double totalForDay(DateTime day) {
    return foods
        .where((food) => sameDay(food.addedAt, day))
        .fold<double>(
      0,
          (sum, food) => sum + food.calories,
    );
  }

  // ==========================================================
  // MAIN UI
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    final visibleFoods = filteredFoods;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => openFoodForm(),
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Food'),
      ),
      body: SafeArea(
        child: isLoading
            ? const Center(
          child: CircularProgressIndicator(),
        )
            : CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                18,
                12,
                18,
                14,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  header(),
                  const SizedBox(height: 22),
                  dateSelector(),
                  const SizedBox(height: 14),
                  calorieHero(),
                  const SizedBox(height: 22),
                  summaryHeader(),
                  const SizedBox(height: 10),
                  summaryCards(),
                  const SizedBox(height: 22),
                  mealBreakdown(),
                  const SizedBox(height: 24),
                  weeklyChart(),
                  const SizedBox(height: 24),
                  foodHeader(),
                  const SizedBox(height: 12),
                  searchAndFavorites(),
                  const SizedBox(height: 12),
                  categoryFilters(),
                ]),
              ),
            ),
            if (visibleFoods.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    18,
                    0,
                    18,
                    110,
                  ),
                  child: emptyState(),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  18,
                  0,
                  18,
                  110,
                ),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                        (context, index) {
                      return foodTile(visibleFoods[index]);
                    },
                    childCount: visibleFoods.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // HEADER
  // ==========================================================

  Widget header() {
    return Row(
      children: [
        Container(
          width: 47,
          height: 47,
          decoration: BoxDecoration(
            color: const Color(0xFFEAF4DD),
            borderRadius: BorderRadius.circular(15),
          ),
          child: const Icon(
            Icons.eco_rounded,
            color: darkGreen,
            size: 26,
          ),
        ),
        const SizedBox(width: 11),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CalorieSnap',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Eat well. Feel great.',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Settings',
          onPressed: () {
            showModalBottomSheet<void>(
              context: context,
              showDragHandle: true,
              builder: (_) => SettingsSheet(
                isDark: widget.isDark,
                onToggleTheme: widget.onToggleTheme,
                onEditGoal: editGoal,
                onClearDay: clearSelectedDay,
              ),
            );
          },
          icon: const Icon(Icons.settings_outlined),
        ),
      ],
    );
  }

  // ==========================================================
  // DATE SELECTOR
  // ==========================================================

  Widget dateSelector() {
    final isToday = sameDay(selectedDate, DateTime.now());

    return Row(
      children: [
        IconButton(
          onPressed: () {
            setState(() {
              selectedDate = selectedDate.subtract(
                const Duration(days: 1),
              );
            });
          },
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        Expanded(
          child: Center(
            child: Text(
              dateLabel,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        IconButton(
          onPressed: isToday
              ? null
              : () {
            setState(() {
              selectedDate = selectedDate.add(
                const Duration(days: 1),
              );
            });
          },
          icon: const Icon(Icons.chevron_right_rounded),
        ),
        IconButton(
          tooltip: 'Jump to today',
          onPressed: () {
            setState(() {
              selectedDate = DateUtils.dateOnly(DateTime.now());
            });
          },
          icon: const Icon(
            Icons.today_rounded,
            color: darkGreen,
          ),
        ),
      ],
    );
  }

  // ==========================================================
  // CALORIE HERO
  // ==========================================================

  Widget calorieHero() {
    return Container(
      padding: const EdgeInsets.all(21),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFEDF7D9),
            Color(0xFFE2F0C5),
          ],
        ),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        children: [
          const Row(
            children: [
              Expanded(
                child: Text(
                  'DAILY INTAKE',
                  style: TextStyle(
                    color: darkGreen,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          SizedBox(
            height: 184,
            width: 184,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  height: 170,
                  width: 170,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 13,
                    strokeCap: StrokeCap.round,
                    backgroundColor: const Color(0xFFDDE2D7),
                    valueColor:
                    const AlwaysStoppedAnimation<Color>(primaryGreen),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.eco_rounded,
                      color: darkGreen,
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Consumed',
                      style: TextStyle(
                        color: Color(0xFF747C6C),
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      formatCalories(total),
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF20251D),
                      ),
                    ),
                    const Text(
                      'kcal',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF20251D),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Goal ${formatCalories(dailyGoal)} kcal',
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
                Icons.info_outline,
                color: darkGreen,
                size: 17,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  remaining >= 0
                      ? '${formatCalories(remaining)} kcal remaining'
                      : '${formatCalories(remaining.abs())} kcal over goal',
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

  // ==========================================================
  // SUMMARY
  // ==========================================================

  Widget summaryHeader() {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'Daily Summary',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        TextButton.icon(
          onPressed: editGoal,
          icon: const Icon(Icons.tune, size: 17),
          label: const Text('Edit Goal'),
        ),
      ],
    );
  }

  Widget summaryCards() {
    return Row(
      children: [
        Expanded(
          child: summaryCard(
            'Total',
            formatCalories(total),
            'kcal eaten',
            Icons.local_fire_department,
            Colors.orange,
            const Color(0xFFFFF2E4),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: summaryCard(
            'Goal',
            formatCalories(dailyGoal),
            'kcal target',
            Icons.flag_rounded,
            Colors.blue,
            const Color(0xFFEAF5FC),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: summaryCard(
            'Remaining',
            formatCalories(remaining.abs()),
            remaining >= 0 ? 'kcal left' : 'kcal over',
            Icons.bolt_rounded,
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
      Color bgColor,
      ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: bgColor,
              child: Icon(
                icon,
                color: iconColor,
                size: 17,
              ),
            ),
            const SizedBox(height: 9),
            Text(
              title,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 10,
              ),
            ),
            const SizedBox(height: 3),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Text(
              subtitle,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 9,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // MEAL BREAKDOWN
  // ==========================================================

  Widget mealBreakdown() {
    const meals = [
      'Breakfast',
      'Lunch',
      'Dinner',
      'Snack',
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Calories by Meal',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 15),
            ...meals.map((meal) {
              final amount = selectedDayFoods
                  .where((food) => food.category == meal)
                  .fold<double>(
                0,
                    (sum, food) => sum + food.calories,
              );

              final ratio = total == 0
                  ? 0.0
                  : (amount / total).clamp(0.0, 1.0);

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            meal,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Text(
                          '${formatCalories(amount)} kcal',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: 7,
                        backgroundColor: Colors.black12,
                        valueColor:
                        const AlwaysStoppedAnimation<Color>(primaryGreen),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // WEEKLY CHART
  // ==========================================================

  Widget weeklyChart() {
    final today = DateUtils.dateOnly(DateTime.now());

    final days = List.generate(
      7,
          (index) => today.subtract(
        Duration(days: 6 - index),
      ),
    );

    final maxValue = days
        .map(totalForDay)
        .fold<double>(
      dailyGoal,
          (a, b) => a > b ? a : b,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(15, 16, 15, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Last 7 Days',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Daily calorie intake (kcal)',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 155,
              child: BarChart(
                BarChartData(
                  maxY: maxValue * 1.15,
                  minY: 0,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: maxValue <= 0
                        ? 500
                        : maxValue / 4,
                  ),
                  borderData: FlBorderData(show: false),
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem:
                          (group, groupIndex, rod, rodIndex) {
                        return BarTooltipItem(
                          '${formatCalories(rod.toY)} kcal',
                          const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value >= 1000
                                ? '${(value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1)}k'
                                : value.toInt().toString(),
                            style: const TextStyle(
                              fontSize: 9,
                              color: Colors.grey,
                            ),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();

                          if (index < 0 || index > 6) {
                            return const SizedBox.shrink();
                          }

                          return Padding(
                            padding: const EdgeInsets.only(top: 7),
                            child: Text(
                              DateFormat('E').format(days[index]),
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.grey,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: List.generate(
                    7,
                        (index) {
                      return BarChartGroupData(
                        x: index,
                        barRods: [
                          BarChartRodData(
                            toY: totalForDay(days[index]),
                            width: 13,
                            borderRadius: BorderRadius.circular(4),
                            color: sameDay(days[index], today)
                                ? darkGreen
                                : primaryGreen,
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // FOOD LIST
  // ==========================================================

  Widget foodHeader() {
    return Row(
      children: [
        Expanded(
          child: Text(
            sameDay(selectedDate, DateTime.now())
                ? "Today's Meals"
                : "Meals",
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        if (selectedDayFoods.isNotEmpty)
          IconButton(
            tooltip: 'Clear this day',
            onPressed: clearSelectedDay,
            icon: const Icon(
              Icons.delete_sweep_outlined,
              color: Colors.redAccent,
            ),
          ),
      ],
    );
  }

  Widget searchAndFavorites() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: searchController,
            onChanged: (value) {
              setState(() => searchQuery = value);
            },
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
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filledTonal(
          tooltip: 'Favorites only',
          onPressed: () {
            setState(() {
              showFavoritesOnly = !showFavoritesOnly;
            });
          },
          style: IconButton.styleFrom(
            backgroundColor: showFavoritesOnly ? primaryGreen : null,
            foregroundColor: showFavoritesOnly ? Colors.white : null,
          ),
          icon: const Icon(Icons.favorite_rounded),
        ),
      ],
    );
  }

  Widget categoryFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: categories.map((category) {
          final selected = selectedCategory == category;

          return Padding(
            padding: const EdgeInsets.only(right: 7),
            child: ChoiceChip(
              label: Text(category),
              selected: selected,
              onSelected: (_) {
                setState(() => selectedCategory = category);
              },
              selectedColor: primaryGreen,
              backgroundColor: Theme.of(context).cardColor,
              side: BorderSide.none,
              showCheckmark: false,
              labelStyle: TextStyle(
                color: selected ? Colors.white : null,
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget emptyState() {
    final filtered = searchQuery.isNotEmpty ||
        selectedCategory != 'All' ||
        showFavoritesOnly;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(
              Icons.restaurant_menu_rounded,
              size: 42,
              color: primaryGreen,
            ),
            const SizedBox(height: 10),
            Text(
              filtered
                  ? 'No matching food found'
                  : 'No meals logged yet',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),
            Text(
              filtered
                  ? 'Try a different search or filter.'
                  : 'Tap Add Food to track your first meal.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget foodTile(FoodEntry food) {
    return Card(
      margin: const EdgeInsets.only(bottom: 9),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(11, 9, 3, 9),
        child: Row(
          children: [
            Container(
              width: 45,
              height: 45,
              decoration: BoxDecoration(
                color: const Color(0xFFEDF6E2),
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(
                Icons.lunch_dining_rounded,
                color: darkGreen,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    food.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    food.category,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatCalories(food.calories),
                  style: const TextStyle(
                    color: darkGreen,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const Text(
                  'kcal',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
            IconButton(
              tooltip: food.isFavorite
                  ? 'Remove favorite'
                  : 'Add favorite',
              onPressed: () => toggleFavorite(food),
              icon: Icon(
                food.isFavorite
                    ? Icons.favorite
                    : Icons.favorite_border,
                color: food.isFavorite ? Colors.pink : Colors.grey,
                size: 20,
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') {
                  openFoodForm(existing: food);
                }

                if (value == 'quick') {
                  openFoodForm(quickFood: food);
                }

                if (value == 'delete') {
                  deleteFood(food);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'edit',
                  child: Text('Edit'),
                ),
                PopupMenuItem(
                  value: 'quick',
                  child: Text('Add again'),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// ADD / EDIT FOOD FORM
// ============================================================

class FoodFormSheet extends StatefulWidget {
  final FoodEntry? existing;
  final FoodEntry? initial;
  final List<String> categories;

  const FoodFormSheet({
    super.key,
    this.existing,
    this.initial,
    required this.categories,
  });

  @override
  State<FoodFormSheet> createState() => _FoodFormSheetState();
}

class _FoodFormSheetState extends State<FoodFormSheet> {
  final formKey = GlobalKey<FormState>();

  late final TextEditingController nameController;
  late final TextEditingController calorieController;

  late String category;

  @override
  void initState() {
    super.initState();

    final source = widget.existing ?? widget.initial;

    nameController = TextEditingController(
      text: source?.name ?? '',
    );

    calorieController = TextEditingController(
      text: source == null
          ? ''
          : source.calories.toStringAsFixed(
        source.calories == source.calories.roundToDouble() ? 0 : 1,
      ),
    );

    category = source?.category ?? 'Breakfast';
  }

  @override
  void dispose() {
    nameController.dispose();
    calorieController.dispose();
    super.dispose();
  }

  void save() {
    if (!(formKey.currentState?.validate() ?? false)) {
      return;
    }

    final calories = double.tryParse(calorieController.text.trim());

    if (calories == null ||
        !calories.isFinite ||
        calories <= 0) {
      return;
    }

    final old = widget.existing ?? widget.initial;

    Navigator.pop(
      context,
      FoodEntry(
        id: widget.existing?.id ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        name: nameController.text.trim(),
        calories: calories,
        category: category,
        addedAt: widget.existing?.addedAt ?? DateTime.now(),
        isFavorite: old?.isFavorite ?? false,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(27),
          ),
        ),
        child: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.existing == null
                      ? 'Add Your Food'
                      : 'Edit Food',
                  style: const TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Food Name',
                    prefixIcon: Icon(Icons.restaurant_rounded),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter food name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 13),
                TextFormField(
                  controller: calorieController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Calories (kcal)',
                    prefixIcon: Icon(
                      Icons.local_fire_department_rounded,
                    ),
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
                const SizedBox(height: 13),
                DropdownButtonFormField<String>(
                  value: category,
                  decoration: const InputDecoration(
                    labelText: 'Meal Category',
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  items: widget.categories.map((item) {
                    return DropdownMenuItem(
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
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 51,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: primaryGreen,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: save,
                    child: Text(
                      widget.existing == null
                          ? 'Add Food'
                          : 'Save Changes',
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

// ============================================================
// CALORIE GOAL DIALOG
// ============================================================

class GoalDialog extends StatefulWidget {
  final double initialGoal;

  const GoalDialog({
    super.key,
    required this.initialGoal,
  });

  @override
  State<GoalDialog> createState() => _GoalDialogState();
}

class _GoalDialogState extends State<GoalDialog> {
  final key = GlobalKey<FormState>();

  late final TextEditingController controller;

  @override
  void initState() {
    super.initState();

    controller = TextEditingController(
      text: widget.initialGoal.toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void save() {
    if (!(key.currentState?.validate() ?? false)) {
      return;
    }

    final value = double.tryParse(controller.text.trim());

    if (value != null &&
        value.isFinite &&
        value > 0) {
      Navigator.pop(context, value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Daily Calorie Goal'),
      content: Form(
        key: key,
        child: TextFormField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
          ),
          decoration: const InputDecoration(
            labelText: 'Goal (kcal)',
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Enter a goal';
            }

            final number = double.tryParse(value.trim());

            if (number == null ||
                !number.isFinite ||
                number <= 0) {
              return 'Enter a positive number';
            }

            return null;
          },
          onFieldSubmitted: (_) => save(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}


// ============================================================
// SETTINGS
// ============================================================

class SettingsSheet extends StatelessWidget {
  final bool isDark;
  final VoidCallback onToggleTheme;
  final VoidCallback onEditGoal;
  final VoidCallback onClearDay;

  const SettingsSheet({
    super.key,
    required this.isDark,
    required this.onToggleTheme,
    required this.onEditGoal,
    required this.onClearDay,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Settings',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: const Text('Daily calorie goal'),
              subtitle: const Text('Change your daily target'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(context);
                onEditGoal();
              },
            ),
            SwitchListTile(
              secondary: Icon(
                isDark ? Icons.dark_mode : Icons.light_mode,
              ),
              title: const Text('Dark mode'),
              value: isDark,
              onChanged: (_) {
                Navigator.pop(context);
                onToggleTheme();
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.delete_sweep_outlined,
                color: Colors.red,
              ),
              title: const Text('Clear selected day'),
              onTap: () {
                Navigator.pop(context);
                onClearDay();
              },
            ),
          ],
        ),
      ),
    );
  }
}

