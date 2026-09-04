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
router.post('/stories', optionalProtect, createStory);

router.get('/posts', optionalProtect, getPosts);
router.post('/posts', optionalProtect, createPost);

router.post('/posts/:postId/like', optionalProtect, toggleLikePost);
router.post('/posts/:postId/comments', optionalProtect, addComment);

module.exports = router;

