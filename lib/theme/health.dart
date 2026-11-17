import 'package:cupertino_ui/cupertino_ui.dart';

import '../models/task.dart';

/// Paletă medicală, sobră: roșu închis (crimson) ca accent principal,
/// bleumarin și albastru medical ca a doua culoare.
abstract final class HealthColors {
  /// Accentul principal: butoane, linkuri, inimă.
  static const crimson = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFA51C30),
    darkColor: Color(0xFFE5484D),
  );

  /// Albastru medical: elemente secundare, comutatoare.
  static const medicalBlue = CupertinoDynamicColor.withBrightness(
    color: Color(0xFF1D5FA8),
    darkColor: Color(0xFF4C8FDB),
  );

  static const navy = Color(0xFF0B2545);
  static const heartTop = Color(0xFFD7263D);
  static const heartBottom = Color(0xFF8E1328);
  static const ecgBlue = Color(0xFF8EC5FF);

  /// Gradientul inimii / al insignei.
  static const crimsonGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFD7263D), Color(0xFFA51C30), Color(0xFF7A0F22)],
  );

  /// Gradientul cardurilor mari și al ecranului de intrare.
  static const navyGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0B2545), Color(0xFF13315C), Color(0xFF1D4E89)],
  );
}

/// Aspectul fiecărei categorii: nume, pictogramă, culoare și texte ajutătoare.
extension TaskCategoryStyle on TaskCategory {
  String get label => switch (this) {
    TaskCategory.medication => 'Medication',
    TaskCategory.hydration => 'Hydration',
    TaskCategory.activity => 'Activity',
    TaskCategory.sleep => 'Sleep',
    TaskCategory.appointment => 'Appointment',
    TaskCategory.general => 'General',
  };

  IconData get icon => switch (this) {
    TaskCategory.medication => CupertinoIcons.capsule_fill,
    TaskCategory.hydration => CupertinoIcons.drop_fill,
    TaskCategory.activity => CupertinoIcons.flame_fill,
    TaskCategory.sleep => CupertinoIcons.bed_double_fill,
    TaskCategory.appointment => CupertinoIcons.staroflife_fill,
    TaskCategory.general => CupertinoIcons.heart_fill,
  };

  CupertinoDynamicColor get color => switch (this) {
    TaskCategory.medication => HealthColors.crimson,
    TaskCategory.hydration => HealthColors.medicalBlue,
    TaskCategory.activity => const CupertinoDynamicColor.withBrightness(
      color: Color(0xFF0E7C7B),
      darkColor: Color(0xFF2BB3A8),
    ),
    TaskCategory.sleep => const CupertinoDynamicColor.withBrightness(
      color: Color(0xFF3D3B8E),
      darkColor: Color(0xFF8B88E8),
    ),
    TaskCategory.appointment => const CupertinoDynamicColor.withBrightness(
      color: Color(0xFF13315C),
      darkColor: Color(0xFF7FA8DA),
    ),
    TaskCategory.general => const CupertinoDynamicColor.withBrightness(
      color: Color(0xFF5B6B7F),
      darkColor: Color(0xFF9AA8B9),
    ),
  };

  String get placeholder => switch (this) {
    TaskCategory.medication => 'e.g. Vitamin D, 1 capsule',
    TaskCategory.hydration => 'e.g. Drink a glass of water',
    TaskCategory.activity => 'e.g. 30-minute walk',
    TaskCategory.sleep => 'e.g. No phone before bed',
    TaskCategory.appointment => 'e.g. Check-up with the family doctor',
    TaskCategory.general => 'Title',
  };

  /// Textul notificării când sarcina nu are notițe.
  String get reminderBody => switch (this) {
    TaskCategory.medication => 'Time for your medication.',
    TaskCategory.hydration => 'Take a break and drink some water.',
    TaskCategory.activity => 'Time to move a little!',
    TaskCategory.sleep => 'Get ready for a restful sleep.',
    TaskCategory.appointment => 'You have a medical appointment.',
    TaskCategory.general => 'Time for this task.',
  };
}

/// Pictograma categoriei (capsula e înclinată ca o pastilă).
class CategoryIcon extends StatelessWidget {
  const CategoryIcon(
    this.category, {
    super.key,
    required this.size,
    required this.color,
  });

  final TaskCategory category;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final icon = Icon(category.icon, size: size, color: color);
    return category == TaskCategory.medication
        ? Transform.rotate(angle: -0.785, child: icon)
        : icon;
  }
}
