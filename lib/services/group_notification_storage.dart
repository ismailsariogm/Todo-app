import 'package:shared_preferences/shared_preferences.dart';

String _key(String userId, String groupId, String type) =>
    'group_notif_${type}_${userId}_$groupId';

Future<int> getLastViewedTaskCount(String userId, String groupId) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getInt(_key(userId, groupId, 'tasks')) ?? 0;
}

Future<void> setLastViewedTaskCount(
    String userId, String groupId, int count) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt(_key(userId, groupId, 'tasks'), count);
}

Future<int> getLastViewedMessageCount(String userId, String groupId) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getInt(_key(userId, groupId, 'msgs')) ?? 0;
}

Future<void> setLastViewedMessageCount(
    String userId, String groupId, int count) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt(_key(userId, groupId, 'msgs'), count);
}
