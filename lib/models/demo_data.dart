import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class DemoUser {
  static const String name = 'Arjun';
  static const String fullName = 'Arjun Mehta';
  static const int age = 26;
  static const double weight = 78.5;
  static const double height = 178;
  static const double bodyFat = 18.4;
  static const String goal = 'Body Recomposition';
  static const int streak = 12;
  static const int weeklyWorkouts = 4;
  static const String level = 'Intermediate';
}

class NutritionData {
  static const int caloriesGoal = 2400;
  static const int caloriesConsumed = 1680;
  static const int proteinGoal = 145;
  static const int proteinConsumed = 98;
  static const int carbsGoal = 260;
  static const int carbsConsumed = 195;
  static const int fatGoal = 70;
  static const int fatConsumed = 52;

  static int get caloriesRemaining => caloriesGoal - caloriesConsumed;
  static int get proteinRemaining => proteinGoal - proteinConsumed;
}

class WorkoutSession {
  final String name;
  final String category;
  final int duration; // minutes
  final int calories;
  final String difficulty;
  final IconData icon;
  final Color color;
  final List<Exercise> exercises;

  const WorkoutSession({
    required this.name,
    required this.category,
    required this.duration,
    required this.calories,
    required this.difficulty,
    required this.icon,
    required this.color,
    required this.exercises,
  });
}

class Exercise {
  final String name;
  final String sets;
  final String reps;
  final int restSeconds;
  bool isCompleted;

  Exercise({
    required this.name,
    required this.sets,
    required this.reps,
    required this.restSeconds,
    this.isCompleted = false,
  });
}

class DemoWorkouts {
  static List<WorkoutSession> get sessions => [
        WorkoutSession(
          name: 'Upper Body Power',
          category: 'Strength',
          duration: 55,
          calories: 420,
          difficulty: 'Hard',
          icon: Icons.fitness_center,
          color: AppColors.orange,
          exercises: [
            Exercise(name: 'Barbell Bench Press', sets: '4', reps: '8-10', restSeconds: 90, isCompleted: true),
            Exercise(name: 'Incline Dumbbell Press', sets: '3', reps: '10-12', restSeconds: 75, isCompleted: true),
            Exercise(name: 'Cable Flyes', sets: '3', reps: '12-15', restSeconds: 60, isCompleted: false),
            Exercise(name: 'Overhead Press', sets: '4', reps: '8-10', restSeconds: 90, isCompleted: false),
            Exercise(name: 'Lateral Raises', sets: '3', reps: '15', restSeconds: 45, isCompleted: false),
            Exercise(name: 'Tricep Dips', sets: '3', reps: '12', restSeconds: 60, isCompleted: false),
          ],
        ),
        WorkoutSession(
          name: 'HIIT Cardio Blast',
          category: 'Cardio',
          duration: 30,
          calories: 310,
          difficulty: 'Medium',
          icon: Icons.directions_run,
          color: AppColors.info,
          exercises: [
            Exercise(name: 'Jump Squats', sets: '4', reps: '20', restSeconds: 30),
            Exercise(name: 'Burpees', sets: '3', reps: '15', restSeconds: 30),
            Exercise(name: 'Mountain Climbers', sets: '4', reps: '30s', restSeconds: 20),
            Exercise(name: 'Box Jumps', sets: '3', reps: '12', restSeconds: 45),
          ],
        ),
        WorkoutSession(
          name: 'Leg Day',
          category: 'Strength',
          duration: 60,
          calories: 480,
          difficulty: 'Hard',
          icon: Icons.sports_gymnastics,
          color: AppColors.success,
          exercises: [
            Exercise(name: 'Back Squat', sets: '5', reps: '5', restSeconds: 120),
            Exercise(name: 'Romanian Deadlift', sets: '4', reps: '8-10', restSeconds: 90),
            Exercise(name: 'Leg Press', sets: '3', reps: '12-15', restSeconds: 75),
            Exercise(name: 'Walking Lunges', sets: '3', reps: '20', restSeconds: 60),
            Exercise(name: 'Calf Raises', sets: '4', reps: '20', restSeconds: 45),
          ],
        ),
        WorkoutSession(
          name: 'Core & Mobility',
          category: 'Flexibility',
          duration: 25,
          calories: 180,
          difficulty: 'Easy',
          icon: Icons.self_improvement,
          color: AppColors.warning,
          exercises: [
            Exercise(name: 'Plank', sets: '3', reps: '60s', restSeconds: 45),
            Exercise(name: 'Dead Bug', sets: '3', reps: '10', restSeconds: 30),
            Exercise(name: 'Bird Dog', sets: '3', reps: '10', restSeconds: 30),
            Exercise(name: 'Hip Flexor Stretch', sets: '2', reps: '45s', restSeconds: 15),
          ],
        ),
      ];
}

class MealData {
  final String name;
  final String time;
  final int calories;
  final int protein;
  final int carbs;
  final int fat;
  final String emoji;

  const MealData({
    required this.name,
    required this.time,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.emoji,
  });
}

class DemoMeals {
  static List<MealData> get today => [
        const MealData(
          name: 'Oats & Protein Shake',
          time: '7:30 AM',
          calories: 480,
          protein: 35,
          carbs: 58,
          fat: 10,
          emoji: '🥣',
        ),
        const MealData(
          name: 'Grilled Chicken Bowl',
          time: '1:00 PM',
          calories: 620,
          protein: 45,
          carbs: 62,
          fat: 18,
          emoji: '🍗',
        ),
        const MealData(
          name: 'Greek Yogurt + Almonds',
          time: '4:00 PM',
          calories: 280,
          protein: 18,
          carbs: 20,
          fat: 14,
          emoji: '🥛',
        ),
        const MealData(
          name: 'Dinner (Pending)',
          time: '8:00 PM',
          calories: 0,
          protein: 0,
          carbs: 0,
          fat: 0,
          emoji: '🍽️',
        ),
      ];
}

class FriendChallenge {
  final String name;
  final String avatar;
  final String challengeType;
  final double myProgress;
  final double theirProgress;
  final int daysLeft;

  const FriendChallenge({
    required this.name,
    required this.avatar,
    required this.challengeType,
    required this.myProgress,
    required this.theirProgress,
    required this.daysLeft,
  });
}

class DemoChallenges {
  static List<FriendChallenge> get active => [
        const FriendChallenge(
          name: 'Rahul K.',
          avatar: 'R',
          challengeType: '10k Run Week',
          myProgress: 0.72,
          theirProgress: 0.58,
          daysLeft: 3,
        ),
        const FriendChallenge(
          name: 'Priya S.',
          avatar: 'P',
          challengeType: 'Fat % Reduction',
          myProgress: 0.45,
          theirProgress: 0.61,
          daysLeft: 18,
        ),
        const FriendChallenge(
          name: 'Dev M.',
          avatar: 'D',
          challengeType: 'Cycling 50km',
          myProgress: 0.33,
          theirProgress: 0.28,
          daysLeft: 7,
        ),
      ];
}

class WeeklyStats {
  static const List<double> caloriesBurned = [320, 450, 0, 510, 420, 390, 310];
  static const List<double> proteinHit = [85, 100, 60, 95, 90, 88, 70];
  static const List<String> days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  static const int totalCaloriesBurned = 2400;
  static const double avgWorkoutDuration = 48.5;
  static const int restDaySuggestion = 3; // Wednesday (index)
}

class BodyMetrics {
  static const List<double> weightHistory = [82.0, 81.2, 80.8, 80.1, 79.6, 79.1, 78.5];
  static const List<double> bodyFatHistory = [21.2, 20.8, 20.3, 19.8, 19.4, 18.9, 18.4];
  static const List<String> weeks = ['W1', 'W2', 'W3', 'W4', 'W5', 'W6', 'W7'];
  static const double muscleMass = 63.9;
  static const double boneMass = 3.2;
  static const double waterPercentage = 58.4;
  static const int metabolicAge = 23;
  static const int visceralFat = 6;
  static const double bmi = 24.7;
}
