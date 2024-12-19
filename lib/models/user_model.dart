import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';

class UserModel {
  final String id;
  final String? email;
  final String? displayName;
  final String? photoURL;
  final bool isGuest;
  final bool isEmailVerified;
  final DateTime createdAt;
  final DateTime lastLoginAt;

  UserModel({
    required this.id,
    this.email,
    this.displayName,
    this.photoURL,
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
      photoURL: data['photoURL'],
      isGuest: data['isGuest'] ?? false,
      isEmailVerified: data['isEmailVerified'] ?? false,
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : data['createdAt'] is String
              ? DateTime.parse(data['createdAt'])
              : DateTime.now(),
      lastLoginAt: data['lastLoginAt'] is Timestamp
          ? (data['lastLoginAt'] as Timestamp).toDate()
          : data['lastLoginAt'] is String
              ? DateTime.parse(data['lastLoginAt'])
              : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'displayName': displayName,
      'photoURL': photoURL,
      'isGuest': isGuest,
      'isEmailVerified': isEmailVerified,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastLoginAt': Timestamp.fromDate(lastLoginAt),
    };
  }

  factory UserModel.fromJson(String jsonString) {
    final Map<String, dynamic> data = json.decode(jsonString);
    return UserModel(
      id: data['id'],
      email: data['email'],
      displayName: data['displayName'],
      photoURL: data['photoURL'],
      isGuest: data['isGuest'] ?? false,
      isEmailVerified: data['isEmailVerified'] ?? false,
      createdAt: data['createdAt'] != null
          ? DateTime.parse(data['createdAt'])
          : DateTime.now(),
      lastLoginAt: data['lastLoginAt'] != null
          ? DateTime.parse(data['lastLoginAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'displayName': displayName,
      'photoURL': photoURL,
      'isGuest': isGuest,
      'isEmailVerified': isEmailVerified,
      'createdAt': createdAt.toIso8601String(),
      'lastLoginAt': lastLoginAt.toIso8601String(),
    };
  }
}
