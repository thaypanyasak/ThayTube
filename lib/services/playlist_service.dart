import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/playlist.dart';

class PlaylistService extends ChangeNotifier {
  List<Playlist> _playlists = [];

  List<Playlist> get playlists => _playlists;

  PlaylistService() {
    _loadPlaylists();
  }

  Future<void> _loadPlaylists() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonString = prefs.getString('user_playlists');
      if (jsonString != null) {
        final List<dynamic> decoded = json.decode(jsonString);
        _playlists = decoded.map((map) => Playlist.fromMap(map)).toList();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading playlists: $e');
    }
  }

  Future<void> _savePlaylists() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String jsonString = json.encode(_playlists.map((p) => p.toMap()).toList());
      await prefs.setString('user_playlists', jsonString);
    } catch (e) {
      debugPrint('Error saving playlists: $e');
    }
  }

  Future<void> createPlaylist(String name, String description) async {
    final newPlaylist = Playlist(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      description: description,
      trackIds: [],
      createdAt: DateTime.now(),
    );
    _playlists.add(newPlaylist);
    await _savePlaylists();
    notifyListeners();
  }

  Future<void> deletePlaylist(String playlistId) async {
    _playlists.removeWhere((p) => p.id == playlistId);
    await _savePlaylists();
    notifyListeners();
  }

  Future<void> addTrackToPlaylist(String playlistId, String trackId) async {
    final index = _playlists.indexWhere((p) => p.id == playlistId);
    if (index != -1) {
      final playlist = _playlists[index];
      if (!playlist.trackIds.contains(trackId)) {
        playlist.trackIds.add(trackId);
        await _savePlaylists();
        notifyListeners();
      }
    }
  }

  Future<void> removeTrackFromPlaylist(String playlistId, String trackId) async {
    final index = _playlists.indexWhere((p) => p.id == playlistId);
    if (index != -1) {
      final playlist = _playlists[index];
      playlist.trackIds.remove(trackId);
      await _savePlaylists();
      notifyListeners();
    }
  }
}
