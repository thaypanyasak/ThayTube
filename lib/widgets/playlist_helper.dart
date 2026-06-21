import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/download_item.dart';
import '../services/playlist_service.dart';
import '../services/language_service.dart';

void showPlaylistSelectionBottomSheet(BuildContext context, DownloadItem track) {
  showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF161622),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) {
      return Consumer<PlaylistService>(
        builder: (context, playlistService, _) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    child: Text(
                      context.tr('add_to_playlist'),
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const Divider(color: Colors.white10),
                  ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFFF2A5F),
                      child: Icon(Icons.add, color: Colors.white),
                    ),
                    title: Text(context.tr('create_new_playlist'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    onTap: () {
                      Navigator.pop(context);
                      showCreatePlaylistDialog(context, trackToAdd: track);
                    },
                  ),
                  if (playlistService.playlists.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                      child: Text(context.tr('no_playlists_create'), style: const TextStyle(color: Colors.white38)),
                    )
                  else
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: playlistService.playlists.length,
                        itemBuilder: (context, index) {
                          final playlist = playlistService.playlists[index];
                          final isAlreadyAdded = playlist.trackIds.contains(track.id);
                          return ListTile(
                            leading: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFFFF2A5F).withOpacity(0.6),
                                    const Color(0xFFFF7E40).withOpacity(0.6),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: const Icon(Icons.music_note, color: Colors.white70),
                            ),
                            title: Text(playlist.name, style: const TextStyle(color: Colors.white)),
                            subtitle: Text('${playlist.trackIds.length} ${context.tr('songs')}', style: const TextStyle(color: Colors.white38)),
                            trailing: isAlreadyAdded
                                ? const Icon(Icons.check_circle, color: Color(0xFFFF2A5F))
                                : null,
                            onTap: () async {
                              if (isAlreadyAdded) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(context.tr('song_already_in_playlist'))),
                                );
                              } else {
                                await playlistService.addTrackToPlaylist(playlist.id, track.id);
                                if (context.mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('${context.tr('added_to_playlist')} ${playlist.name}')),
                                  );
                                }
                              }
                            },
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

void showCreatePlaylistDialog(BuildContext context, {DownloadItem? trackToAdd}) {
  final playlistService = Provider.of<PlaylistService>(context, listen: false);
  final nameController = TextEditingController();
  final descController = TextEditingController();
  showDialog(
    context: context,
    builder: (context) {
      return AlertThemeDialog(
        nameController: nameController,
        descController: descController,
        playlistService: playlistService,
        trackToAdd: trackToAdd,
      );
    },
  );
}

class AlertThemeDialog extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController descController;
  final PlaylistService playlistService;
  final DownloadItem? trackToAdd;

  const AlertThemeDialog({
    super.key,
    required this.nameController,
    required this.descController,
    required this.playlistService,
    this.trackToAdd,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1F1F35),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(context.tr('create_new_playlist'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nameController,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: context.tr('playlist_name'),
              labelStyle: const TextStyle(color: Colors.white38),
              focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFFF2A5F))),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: descController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: context.tr('playlist_description'),
              labelStyle: const TextStyle(color: Colors.white38),
              focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFFF2A5F))),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.tr('cancel'), style: const TextStyle(color: Colors.white38)),
        ),
        TextButton(
          onPressed: () async {
            final name = nameController.text.trim();
            if (name.isNotEmpty) {
              await playlistService.createPlaylist(name, descController.text.trim());
              if (trackToAdd != null && playlistService.playlists.isNotEmpty) {
                final newPlaylist = playlistService.playlists.last;
                await playlistService.addTrackToPlaylist(newPlaylist.id, trackToAdd!.id);
              }
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${context.tr('playlist_created')} $name')),
                );
              }
            }
          },
          child: Text(context.tr('create'), style: const TextStyle(color: Color(0xFFFF2A5F), fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
