const { supabaseAdmin } = require('../config/supabase');

// Get all active stories
exports.getStories = async (req, res, next) => {
  try {
    const { data: stories, error } = await supabaseAdmin
      .from('community_stories')
      .select('*, user:users(id, full_name, avatar_url, role)')
      .order('created_at', { ascending: false });

    if (error) throw error;

    res.status(200).json({
      success: true,
      data: stories || []
    });
  } catch (error) {
    next(error);
  }
};

// Create a new story
exports.createStory = async (req, res, next) => {
  try {
    const { image_url, caption, title, author_name, author_avatar } = req.body;
    if (!req.user) {
      return res.status(401).json({ success: false, message: 'Harap login terlebih dahulu' });
    }
    const userId = req.user.id;

    if (!image_url) {
      return res.status(400).json({
        success: false,
        message: 'Image URL is required'
      });
    }

    const { data: story, error } = await supabaseAdmin
      .from('community_stories')
      .insert({
        user_id: userId,
        author_name: author_name || (req.user ? req.user.full_name : 'Mitra Temenin Ajaa'),
        author_avatar: author_avatar || (req.user ? req.user.avatar_url : 'https://images.unsplash.com/photo-1534528741775-53994a69daeb'),
        image_url,
        title: title || 'Story',
        caption: caption || '',
        views_count: 1
      })
      .select()
      .single();

    if (error) throw error;

    res.status(201).json({
      success: true,
      message: 'Story created successfully',
      data: story
    });
  } catch (error) {
    next(error);
  }
};

// Get all feed posts
exports.getPosts = async (req, res, next) => {
  try {
    const currentUserId = req.user ? req.user.id : null;

    // Get posts
    const { data: posts, error } = await supabaseAdmin
      .from('community_posts')
      .select('*, user:users(id, full_name, avatar_url, role)')
      .order('created_at', { ascending: false });

    if (error) throw error;

    // Fetch all comments for posts
    const { data: comments } = await supabaseAdmin
      .from('community_comments')
      .select('*')
      .order('created_at', { ascending: true });

    const commentsByPostId = {};
    if (comments) {
      for (const c of comments) {
        if (!commentsByPostId[c.post_id]) {
          commentsByPostId[c.post_id] = [];
        }
        commentsByPostId[c.post_id].push({
          id: c.id,
          author: c.author_name,
          text: c.comment_text,
          createdAt: c.created_at
        });
      }
    }

    // Fetch likes of current user to mark 'isLiked'
    let likedPostIds = new Set();
    if (currentUserId) {
      const { data: userLikes } = await supabaseAdmin
        .from('post_likes')
        .select('post_id')
        .eq('user_id', currentUserId);

      if (userLikes) {
        likedPostIds = new Set(userLikes.map(l => l.post_id));
      }
    }

    const postsWithDetails = (posts || []).map(post => ({
      ...post,
      isLiked: likedPostIds.has(post.id),
      commentsList: commentsByPostId[post.id] || []
    }));

    res.status(200).json({
      success: true,
      data: postsWithDetails
    });
  } catch (error) {
    next(error);
  }
};

// Create a new feed post
exports.createPost = async (req, res, next) => {
  try {
    const { image_url, caption, location, media_type, video_url, author_name, author_avatar } = req.body;
    if (!req.user) {
      return res.status(401).json({ success: false, message: 'Harap login terlebih dahulu' });
    }
    const userId = req.user.id;

    if (!image_url && !caption) {
      return res.status(400).json({
        success: false,
        message: 'Post must contain either an image or a caption'
      });
    }

    const { data: post, error } = await supabaseAdmin
      .from('community_posts')
      .insert({
        user_id: userId,
        author_name: author_name || (req.user ? req.user.full_name : 'Mitra Driver'),
        author_avatar: author_avatar || (req.user ? req.user.avatar_url : 'https://images.unsplash.com/photo-1534528741775-53994a69daeb'),
        image_url: image_url || '',
        media_type: media_type || 'image',
        video_url: video_url || '',
        caption: caption || '',
        location: location || 'Jakarta',
        likes_count: 0
      })
      .select()
      .single();

    if (error) throw error;

    res.status(201).json({
      success: true,
      message: 'Post created successfully',
      data: post
    });
  } catch (error) {
    next(error);
  }
};

// Like or Unlike a post
exports.toggleLikePost = async (req, res, next) => {
  try {
    const { postId } = req.params;
    if (!req.user) {
      return res.status(401).json({ success: false, message: 'Harap login terlebih dahulu' });
    }
    const userId = req.user.id;

    // Check if like exists
    const { data: existingLike } = await supabaseAdmin
      .from('post_likes')
      .select('*')
      .eq('post_id', postId)
      .eq('user_id', userId)
      .maybeSingle();

    let isLiked = false;

    if (existingLike) {
      // Unlike
      await supabaseAdmin
        .from('post_likes')
        .delete()
        .eq('post_id', postId)
        .eq('user_id', userId);

      // Decrement likes count
      const { data: post } = await supabaseAdmin
        .from('community_posts')
        .select('likes_count')
        .eq('id', postId)
        .single();

      const newLikesCount = Math.max(0, (post?.likes_count || 1) - 1);

      await supabaseAdmin
        .from('community_posts')
        .update({ likes_count: newLikesCount })
        .eq('id', postId);

      isLiked = false;
    } else {
      // Like
      await supabaseAdmin
        .from('post_likes')
        .insert({
          post_id: postId,
          user_id: userId
        });

      // Increment likes count
      const { data: post } = await supabaseAdmin
        .from('community_posts')
        .select('likes_count')
        .eq('id', postId)
        .single();

      const newLikesCount = (post?.likes_count || 0) + 1;

      await supabaseAdmin
        .from('community_posts')
        .update({ likes_count: newLikesCount })
        .eq('id', postId);

      isLiked = true;
    }

    res.status(200).json({
      success: true,
      message: isLiked ? 'Post liked' : 'Post unliked',
      isLiked
    });
  } catch (error) {
    next(error);
  }
};

// Add comment to a post
exports.addComment = async (req, res, next) => {
  try {
    const { postId } = req.params;
    const { comment_text, author_name } = req.body;
    if (!req.user) {
      return res.status(401).json({ success: false, message: 'Harap login terlebih dahulu' });
    }
    const userId = req.user.id;

    if (!comment_text) {
      return res.status(400).json({ success: false, message: 'Comment text is required' });
    }

    const { data: comment, error } = await supabaseAdmin
      .from('community_comments')
      .insert({
        post_id: postId,
        user_id: userId,
        author_name: author_name || (req.user ? req.user.full_name : 'Pengguna'),
        comment_text
      })
      .select()
      .single();

    if (error) throw error;

    res.status(201).json({
      success: true,
      message: 'Comment added',
      data: comment
    });
  } catch (error) {
    next(error);
  }
};
