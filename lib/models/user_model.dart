import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';

class UserModel {
  final String id;
  final String? email;
  final String? displayName;
  final bool isGuest;
  final bool isEmailVerified;
  final DateTime createdAt;
  final DateTime lastLoginAt;

  UserModel({
    required this.id,
    this.email,
    this.displayName,
    this.isGuest = false,
    this.isEmailVerified = false,
    DateTime? createdAt,
    DateTime? lastLoginAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        lastLoginAt = lastLoginAt ?? DateTime.now();

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      id: doc.id,
      email: data['email'],
      displayName: data['displayName'],
      isGuest: data['isGuest'] ?? false,
      isEmailVerified: data['isEmailVerified'] ?? false,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      lastLoginAt: (data['lastLoginAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'displayName': displayName,
      'isGuest': isGuest,
      'isEmailVerified': isEmailVerified,
      'createdAt': createdAt.toIso8601String(),
      'lastLoginAt': lastLoginAt.toIso8601String(),
    };
  }

  String toJson() {
    return json.encode(toMap());
  }

  factory UserModel.fromJson(String jsonString) {
    try {
      final Map<String, dynamic> data = json.decode(jsonString);
      return UserModel(
        id: data['id'] as String,
        email: data['email'] as String?,
        displayName: data['displayName'] as String?,
        isGuest: data['isGuest'] as bool? ?? false,
        isEmailVerified: data['isEmailVerified'] as bool? ?? false,
        createdAt: DateTime.parse(data['createdAt'] as String),
        lastLoginAt: DateTime.parse(data['lastLoginAt'] as String),
      );
    } catch (e) {
      throw FormatException('Failed to parse UserModel from JSON: $e');
    }
  }

  UserModel copyWith({
    String? id,
    String? email,
    String? displayName,
    bool? isGuest,
    bool? isEmailVerified,
    DateTime? createdAt,
    DateTime? lastLoginAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      isGuest: isGuest ?? this.isGuest,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
    );
  }
}
