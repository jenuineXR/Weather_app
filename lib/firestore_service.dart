import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // READ user's favorite cities from Firestore
  Future<List<String>> getFavoriteCities(String userId) async {
    try {
      final doc = await _db.collection('users').doc(userId).get();
      if (doc.exists && doc.data()!.containsKey('favorites')) {
        return List<String>.from(doc.data()!['favorites']);
      }
      return [];
    } catch (e) {
      print("Error getting favorites: $e");
      return [];
    }
  }

  // CREATE/UPDATE: Add a favorite city to Firestore
  Future<void> addFavoriteCity(String userId, String city) async {
    try {
      await _db.collection('users').doc(userId).set({
        'favorites': FieldValue.arrayUnion([city])
      }, SetOptions(merge: true));
    } catch (e) {
      print("Error adding favorite: $e");
    }
  }

  // DELETE: Remove a favorite city from Firestore
  Future<void> removeFavoriteCity(String userId, String city) async {
    try {
      await _db.collection('users').doc(userId).update({
        'favorites': FieldValue.arrayRemove([city])
      });
    } catch (e) {
      print("Error removing favorite: $e");
    }
  }
}