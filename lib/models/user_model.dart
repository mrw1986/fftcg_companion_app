import 'package:cloud_firestore/cloud_firestore.dart';

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
      'email': email,
      'displayName': displayName,
      'isGuest': isGuest,
      'isEmailVerified': isEmailVerified,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastLoginAt': Timestamp.fromDate(lastLoginAt),
    };
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
