import React, { useState, useEffect } from 'react';
import { MessageSquare, Trash2, Heart, ShieldAlert, CheckCircle2, Image as ImageIcon } from 'lucide-react';
import { adminApi } from '../services/api';

export const Community = () => {
  const [posts, setPosts] = useState([]);
  const [loading, setLoading] = useState(true);
  const [message, setMessage] = useState('');

  const fetchPosts = async () => {
    setLoading(true);
    const data = await adminApi.getPosts();
    setPosts(data);
    setLoading(false);
  };

  useEffect(() => {
    fetchPosts();
  }, []);

  const handleDelete = async (id) => {
    if (window.confirm('Apakah Anda yakin ingin menghapus postingan ini dari platform?')) {
      const res = await adminApi.deletePost(id);
      setMessage(res.message);
      fetchPosts();
      setTimeout(() => setMessage(''), 3000);
    }
  };

  return (
    <div className="space-y-6">
      {/* Alert */}
      {message && (
        <div className="p-4 bg-emerald-500/10 border border-emerald-500/30 rounded-2xl text-sm font-semibold text-emerald-400 flex items-center gap-2 animate-in fade-in">
          <CheckCircle2 className="w-5 h-5" />
          <span>{message}</span>
        </div>
      )}

      {/* Header */}
      <div>
        <h2 className="text-2xl font-extrabold text-white tracking-tight">Komunitas & Moderasi Konten</h2>
        <p className="text-sm text-slate-400">Pantau dan bersihkan foto/postingan publik dari pengguna atau mitra yang melanggar ketentuan</p>
      </div>

      {/* Grid Posts */}
      {loading ? (
        <div className="py-12 text-center text-slate-500 font-semibold">
          Memuat postingan komunitas...
        </div>
      ) : posts.length === 0 ? (
        <div className="py-12 text-center text-slate-500 font-semibold bg-slate-800/30 border border-slate-700/50 rounded-2xl">
          Tidak ada postingan komunitas.
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {posts.map((post) => (
            <div
              key={post.id}
              className="bg-slate-800/40 border border-slate-700/50 rounded-2xl overflow-hidden backdrop-blur-md flex flex-col justify-between"
            >
              {/* User Header */}
              <div className="p-4 flex items-center justify-between border-b border-slate-800">
                <div className="flex items-center gap-3">
                  <div className="w-9 h-9 rounded-full bg-indigo-500/20 text-indigo-400 font-bold text-sm flex items-center justify-center border border-indigo-500/30">
                    {post.users?.full_name?.charAt(0) || 'U'}
                  </div>
                  <div>
                    <h4 className="font-bold text-white text-xs">{post.users?.full_name || 'Pengguna'}</h4>
                    <p className="text-[10px] text-slate-400">{new Date(post.created_at).toLocaleDateString('id-ID')}</p>
                  </div>
                </div>
                <button
                  onClick={() => handleDelete(post.id)}
                  className="p-2 text-rose-400 hover:bg-rose-500/10 rounded-lg transition-colors border border-rose-500/20"
                  title="Hapus Postingan Ini"
                >
                  <Trash2 className="w-4 h-4" />
                </button>
              </div>

              {/* Image Preview */}
              {post.image_url && (
                <div className="relative h-48 bg-slate-950 overflow-hidden">
                  <img
                    src={post.image_url}
                    alt="Post media"
                    className="w-full h-full object-cover hover:scale-105 transition-transform duration-300"
                  />
                </div>
              )}

              {/* Content & Likes */}
              <div className="p-4 space-y-3">
                <p className="text-xs text-slate-200 leading-relaxed font-medium">
                  {post.caption}
                </p>

                <div className="flex items-center gap-1.5 text-rose-400 text-xs font-semibold pt-2 border-t border-slate-800">
                  <Heart className="w-4 h-4 fill-rose-400" />
                  <span>{post.likes_count || 0} Menyukai</span>
                </div>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
};
