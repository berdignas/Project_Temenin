import 'dart:io';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:math' as dart_math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import '../core/constants/api_constants.dart';

class CommunityProvider extends ChangeNotifier {
  static const String _postsCacheKey = 'customer_community_posts_cache_v2';
  static const String _storiesCacheKey = 'customer_community_stories_cache_v2';

  final List<Map<String, dynamic>> _posts = [];
  final List<Map<String, dynamic>> _stories = [];
  bool _isLoading = false;

  List<Map<String, dynamic>> get posts => List.unmodifiable(_posts);
  List<Map<String, dynamic>> get stories => List.unmodifiable(_stories);
  bool get isLoading => _isLoading;

  CommunityProvider() {
    _initCommunityData();
  }

  Future<void> _initCommunityData() async {
    await _loadFromLocalStorage();
    await fetchCommunityData();
  }

  Future<void> _loadFromLocalStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final cachedPostsJson = prefs.getString(_postsCacheKey);
      if (cachedPostsJson != null && cachedPostsJson.isNotEmpty) {
        final List decoded = jsonDecode(cachedPostsJson);
        _posts.clear();
        for (final item in decoded) {
          _posts.add(Map<String, dynamic>.from(item));
        }
      }

      final cachedStoriesJson = prefs.getString(_storiesCacheKey);
      if (cachedStoriesJson != null && cachedStoriesJson.isNotEmpty) {
        final List decoded = jsonDecode(cachedStoriesJson);
        _stories.clear();
        for (final item in decoded) {
          _stories.add(Map<String, dynamic>.from(item));
        }
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading customer community cache: $e');
    }
  }

  Future<void> _saveToLocalStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_postsCacheKey, jsonEncode(_posts));
      await prefs.setString(_storiesCacheKey, jsonEncode(_stories));
    } catch (e) {
      debugPrint('Error saving customer community cache: $e');
    }
  }

  Future<String?> _uploadFileToSupabaseStorage(String localFilePath, {required String folder}) async {
    try {
      final file = File(localFilePath);
      if (kIsWeb || !file.existsSync()) return null;

      final extension = localFilePath.split('.').last.toLowerCase();
      final fileName = '${folder}_${DateTime.now().millisecondsSinceEpoch}_${dart_math.Random().nextInt(9999)}.$extension';
      final storagePath = '$folder/$fileName';

      final bytes = await file.readAsBytes();

      try {
        await Supabase.instance.client.storage
            .from('community-media')
            .uploadBinary(storagePath, bytes, fileOptions: const FileOptions(cacheControl: '3600', upsert: true));

        final publicUrl = Supabase.instance.client.storage.from('community-media').getPublicUrl(storagePath);
        debugPrint('Uploaded file to Supabase Storage (community-media): $publicUrl');
        return publicUrl;
      } catch (bucketErr) {
        try {
          await Supabase.instance.client.storage
              .from('public')
              .uploadBinary(storagePath, bytes, fileOptions: const FileOptions(cacheControl: '3600', upsert: true));

          final publicUrl = Supabase.instance.client.storage.from('public').getPublicUrl(storagePath);
          return publicUrl;
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Storage upload error: $e');
    }
    return null;
  }

  Future<String?> _getSavedUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userDataStr = prefs.getString('user_data');
      if (userDataStr != null) {
        final Map<String, dynamic> data = jsonDecode(userDataStr);
        return data['id'];
      }
    } catch (_) {}
    return null;
  }

  // =========================================================================
  // SYNC FROM DATABASE
  // =========================================================================
  Future<void> fetchCommunityData() async {
    _isLoading = true;
    notifyListeners();

    try {
      // 1. Fetch Posts from Backend / Supabase
      List<Map<String, dynamic>> remotePosts = [];
      try {
        final candidateUrls = [
          '${ApiConstants.baseUrl}/api/community/posts',
          'http://127.0.0.1:3002/api/community/posts',
          'http://localhost:3002/api/community/posts',
        ];
        for (final url in candidateUrls) {
          try {
            final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 3));
            if (res.statusCode == 200) {
              final json = jsonDecode(res.body);
              if (json['success'] == true && json['data'] is List) {
                for (final item in json['data']) {
                  remotePosts.add({
                    'id': item['id'].toString(),
                    'partnerName': item['author_name'] ?? (item['user'] != null ? item['user']['full_name'] : 'Mitra Temenin Ajaa'),
                    'avatar': item['author_avatar'] ?? (item['user'] != null ? item['user']['avatar_url'] : 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=300'),
                    'image': item['image_url'] ?? '',
                    'mediaType': item['media_type'] ?? 'image',
                    'videoUrl': item['video_url'] ?? '',
                    'caption': item['caption'] ?? '',
                    'location': item['location'] ?? 'Jakarta',
                    'likes': item['likes_count'] ?? 0,
                    'isLiked': item['isLiked'] ?? false,
                    'comments': (item['commentsList'] as List? ?? []).length,
                    'commentsList': item['commentsList'] ?? <Map<String, dynamic>>[],
                    'time': 'Baru saja',
                    'rating': 4.9,
                  });
                }
                break;
              }
            }
          } catch (_) {}
        }
      } catch (_) {}

      // Fallback direct Supabase
      if (remotePosts.isEmpty) {
        try {
          final postsResponse = await Supabase.instance.client
              .from('community_posts')
              .select()
              .order('created_at', ascending: false)
              .timeout(const Duration(seconds: 4));

          for (final item in postsResponse) {
            remotePosts.add({
              'id': item['id'].toString(),
              'partnerName': item['author_name'] ?? 'Mitra Temenin Ajaa',
              'avatar': item['author_avatar'] ?? 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=300',
              'image': item['image_url'] ?? '',
              'mediaType': item['media_type'] ?? 'image',
              'videoUrl': item['video_url'] ?? '',
              'caption': item['caption'] ?? '',
              'location': item['location'] ?? 'Jakarta',
              'likes': item['likes_count'] ?? 0,
              'isLiked': false,
              'comments': 0,
              'commentsList': <Map<String, dynamic>>[],
              'time': 'Baru saja',
              'rating': 4.9,
            });
          }
        } catch (_) {}
      }

      if (remotePosts.isNotEmpty) {
        _posts.clear();
        _posts.addAll(remotePosts);
        await _saveToLocalStorage();
      }

      // 2. Fetch Stories from Backend / Supabase
      List<Map<String, dynamic>> remoteStories = [];
      try {
        final candidateUrls = [
          '${ApiConstants.baseUrl}/api/community/stories',
          'http://127.0.0.1:3002/api/community/stories',
          'http://localhost:3002/api/community/stories',
        ];
        for (final url in candidateUrls) {
          try {
            final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 3));
            if (res.statusCode == 200) {
              final json = jsonDecode(res.body);
              if (json['success'] == true && json['data'] is List) {
                for (final item in json['data']) {
                  remoteStories.add({
                    'id': item['id'].toString(),
                    'name': item['author_name'] ?? (item['user'] != null ? item['user']['full_name'] : 'Mitra Driver'),
                    'avatar': item['author_avatar'] ?? (item['user'] != null ? item['user']['avatar_url'] : 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=300'),
                    'storyImage': item['image_url'] ?? '',
                    'videoUrl': item['video_url'] ?? '',
                    'title': item['title'] ?? 'Story',
                    'caption': item['caption'] ?? '',
                    'rating': 4.9,
                    'time': 'Baru saja',
                  });
                }
                break;
              }
            }
          } catch (_) {}
        }
      } catch (_) {}

      if (remoteStories.isEmpty) {
        try {
          final storiesResponse = await Supabase.instance.client
              .from('community_stories')
              .select()
              .order('created_at', ascending: false)
              .timeout(const Duration(seconds: 4));

          for (final item in storiesResponse) {
            remoteStories.add({
              'id': item['id'].toString(),
              'name': item['author_name'] ?? 'Mitra Driver',
              'avatar': item['author_avatar'] ?? 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=300',
              'storyImage': item['image_url'] ?? '',
              'videoUrl': '',
              'title': item['title'] ?? 'Story',
              'caption': item['caption'] ?? '',
              'rating': 4.9,
              'time': 'Baru saja',
            });
          }
        } catch (_) {}
      }

      if (remoteStories.isNotEmpty) {
        _stories.clear();
        _stories.addAll(remoteStories);
        await _saveToLocalStorage();
      }
    } catch (e) {
      debugPrint('Customer community fetch info: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // =========================================================================
  // ACTIONS
  // =========================================================================

  Future<void> addPost({
    required String partnerName,
    required String avatar,
    required String image,
    required String caption,
    String? location,
    String mediaType = 'image',
    String? localFilePath,
    String? userId,
  }) async {
    final newPost = {
      'id': 'post_${DateTime.now().millisecondsSinceEpoch}',
      'partnerName': partnerName,
      'avatar': avatar,
      'image': image,
      'mediaType': mediaType,
      'caption': caption,
      'location': location ?? 'Jakarta',
      'likes': 0,
      'isLiked': false,
      'comments': 0,
      'commentsList': <Map<String, dynamic>>[],
      'time': 'Baru saja',
      'rating': 5.0,
      'createdAt': DateTime.now().toIso8601String(),
    };

    _posts.insert(0, newPost);
    notifyListeners();
    await _saveToLocalStorage();

    String finalImageUrl = image;
    if (!kIsWeb && localFilePath != null && File(localFilePath).existsSync()) {
      final publicCloudUrl = await _uploadFileToSupabaseStorage(localFilePath, folder: 'posts');
      if (publicCloudUrl != null) {
        finalImageUrl = publicCloudUrl;
        newPost['image'] = publicCloudUrl;
        await _saveToLocalStorage();
        notifyListeners();
      }
    }

    final effectiveUserId = userId ?? await _getSavedUserId();

    bool savedToBackend = false;
    try {
      final candidateUrls = [
        'http://192.168.1.4:3002/api/community/posts',
        'http://10.0.2.2:3002/api/community/posts',
        '${ApiConstants.baseUrl}/api/community/posts',
        'http://127.0.0.1:3002/api/community/posts',
        'http://localhost:3002/api/community/posts',
      ];
      for (final url in candidateUrls) {
        try {
          final res = await http.post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'user_id': effectiveUserId,
              'author_name': partnerName,
              'author_avatar': avatar,
              'image_url': finalImageUrl,
              'media_type': mediaType,
              'caption': caption,
              'location': location ?? 'Jakarta',
            }),
          ).timeout(const Duration(seconds: 4));

          if (res.statusCode == 200 || res.statusCode == 201) {
            debugPrint('Customer post successfully stored to database');
            savedToBackend = true;
            break;
          }
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Customer post insert info: $e');
    }

    if (!savedToBackend) {
      try {
        final supabase = Supabase.instance.client;
        String? dbUserId = effectiveUserId;
        if (dbUserId == null || dbUserId.isEmpty || !RegExp(r'^[0-9a-fA-F\-]{36}$').hasMatch(dbUserId)) {
          try {
            final firstUser = await supabase.from('users').select('id').limit(1).maybeSingle();
            if (firstUser != null && firstUser['id'] != null) {
              dbUserId = firstUser['id'].toString();
            }
          } catch (_) {}
        }

        if (dbUserId != null) {
          await supabase.from('community_posts').insert({
            'user_id': dbUserId,
            'author_name': partnerName,
            'author_avatar': avatar,
            'image_url': finalImageUrl,
            'media_type': mediaType,
            'caption': caption,
            'location': location ?? 'Jakarta',
            'likes_count': 0,
          });
          debugPrint('✅ Customer post successfully inserted directly to Supabase DB');
        }
      } catch (supaErr) {
        debugPrint('⚠️ Direct Supabase post insert failed: $supaErr');
      }
    }
  }

  Future<void> addStory({
    required String name,
    required String avatar,
    required String image,
    required String title,
    String? caption,
    String? localFilePath,
    String? userId,
  }) async {
    final newStory = {
      'id': 'story_${DateTime.now().millisecondsSinceEpoch}',
      'name': name,
      'avatar': avatar,
      'storyImage': image,
      'title': title,
      'caption': caption ?? '',
      'rating': 5.0,
      'time': 'Baru saja',
      'createdAt': DateTime.now().toIso8601String(),
    };

    _stories.insert(0, newStory);
    notifyListeners();
    await _saveToLocalStorage();

    String finalImageUrl = image;
    if (!kIsWeb && localFilePath != null && File(localFilePath).existsSync()) {
      final publicCloudUrl = await _uploadFileToSupabaseStorage(localFilePath, folder: 'stories');
      if (publicCloudUrl != null) {
        finalImageUrl = publicCloudUrl;
        newStory['storyImage'] = publicCloudUrl;
        await _saveToLocalStorage();
        notifyListeners();
      }
    }

    final effectiveUserId = userId ?? await _getSavedUserId();

    try {
      final candidateUrls = [
        '${ApiConstants.baseUrl}/api/community/stories',
        'http://127.0.0.1:3002/api/community/stories',
        'http://localhost:3002/api/community/stories',
      ];
      for (final url in candidateUrls) {
        try {
          final res = await http.post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'user_id': effectiveUserId,
              'author_name': name,
              'author_avatar': avatar,
              'image_url': finalImageUrl,
              'title': title,
              'caption': caption ?? '',
            }),
          ).timeout(const Duration(seconds: 4));

          if (res.statusCode == 200 || res.statusCode == 201) {
            debugPrint('Customer story successfully stored to database');
            break;
          }
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Customer story insert info: $e');
    }
  }

  Future<void> toggleLike(String postId) async {
    final index = _posts.indexWhere((p) => p['id'] == postId);
    if (index != -1) {
      final isLiked = _posts[index]['isLiked'] as bool? ?? false;
      final currentLikes = _posts[index]['likes'] as int? ?? 0;

      _posts[index]['isLiked'] = !isLiked;
      _posts[index]['likes'] = isLiked ? (currentLikes > 0 ? currentLikes - 1 : 0) : currentLikes + 1;

      notifyListeners();
      await _saveToLocalStorage();

      final userId = await _getSavedUserId();
      try {
        final url = '${ApiConstants.baseUrl}/api/community/posts/$postId/like';
        await http.post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'user_id': userId}),
        ).timeout(const Duration(seconds: 3));
      } catch (_) {}
    }
  }

  Future<void> addComment(String postId, String authorName, String commentText) async {
    final index = _posts.indexWhere((p) => p['id'] == postId);
    if (index != -1) {
      final comments = List<Map<String, dynamic>>.from(
        (_posts[index]['commentsList'] as List? ?? []).map((c) => Map<String, dynamic>.from(c)),
      );
      comments.add({
        'author': authorName,
        'text': commentText,
      });
      _posts[index]['commentsList'] = comments;
      _posts[index]['comments'] = comments.length;
      notifyListeners();
      await _saveToLocalStorage();

      final userId = await _getSavedUserId();
      try {
        final url = '${ApiConstants.baseUrl}/api/community/posts/$postId/comments';
        await http.post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'user_id': userId,
            'author_name': authorName,
            'comment_text': commentText,
          }),
        ).timeout(const Duration(seconds: 3));
      } catch (_) {}
    }
  }
}
