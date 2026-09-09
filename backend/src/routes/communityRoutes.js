const express = require('express');
const router = express.Router();
const {
  getStories,
  createStory,
  getPosts,
  createPost,
  toggleLikePost,
  addComment
} = require('../controllers/communityController');
const { protect, optionalProtect } = require('../middleware/authMiddleware');

router.get('/stories', optionalProtect, getStories);
router.post('/stories', protect, createStory);

router.get('/posts', optionalProtect, getPosts);
router.post('/posts', protect, createPost);

router.post('/posts/:postId/like', protect, toggleLikePost);
router.post('/posts/:postId/comments', protect, addComment);

module.exports = router;

