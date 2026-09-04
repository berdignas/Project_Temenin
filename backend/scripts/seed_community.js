const { supabaseAdmin } = require('../src/config/supabase');

async function seed() {
  console.log('Seeding initial community stories and posts...');

  // Get users
  const { data: users } = await supabaseAdmin.from('users').select('id, full_name, avatar_url, role');
  console.log('Found users in db:', users?.length);

  const defaultUserId = users && users.length > 0 ? users[0].id : null;

  if (!defaultUserId) {
    console.error('No users found to attach community posts to!');
    process.exit(1);
  }

  // Sample Stories
  const sampleStories = [
    {
      user_id: defaultUserId,
      author_name: 'Ariel Noah',
      author_avatar: 'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?auto=format&fit=crop&w=150&q=80',
      image_url: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?auto=format&fit=crop&w=600&q=80',
      title: 'Konser Live',
      caption: 'Malam ini seru banget dampingi klien nonton konser musik live! 🎸🔥',
      views_count: 14
    },
    {
      user_id: defaultUserId,
      author_name: 'Siti Nurbaya',
      author_avatar: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=150&q=80',
      image_url: 'https://images.unsplash.com/photo-1511018556340-d1698661c194?auto=format&fit=crop&w=600&q=80',
      title: 'Senja Kopi',
      caption: 'Nongkrong santai sore-sore sambil minum kopi & curhat di senja yang indah. ☕️🌅︆',
      views_count: 28
    },
    {
      user_id: defaultUserId,
      author_name: 'Dian Sastro',
      author_avatar: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=150&q=80',
      image_url: 'https://images.unsplash.com/photo-1486406146926-c627a92ad1ab?auto=format&fit=crop&w=600&q=80',
      title: 'Gala Dinner',
      caption: 'Menghadiri gala dinner bisnis bersama klien. Sukses terus untuk project barunyg! 🐼𞢨',
      views_count: 42
    },
    {
      user_id: defaultUserId,
      author_name: 'Reza Rahadian',
      author_avatar: 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?auto=format&fit=crop&w=150&q=80',
      image_url: 'https://images.unsplash.com/photo-1502602898657-3e91760cbb34?auto=format&fit=crop&w=600&q=80',
      title: 'City Tour',
      caption: 'Nemenin jalan-jalan sore keliling tempat bersejarah di Jakarta. Seru banget sharing sejarah! 🍻🙶‍♂︆',
      views_count: 35
    }
  ];

  // Sample Posts
  const samplePosts = [
    {
      user_id: defaultUserId,
      author_name: 'Arief Wijaya',
      author_avatar: 'https://images.unsplash.com/photo-1599566150163-29194dcaad36?auto=format&fit=crop&w=150&q=80',
      image_url: 'https://images.unsplash.com/photo-1558981806-ec527fa84c39?auto=format&fit=crop&w=600&q=80',
      media_type: 'image',
      caption: 'Hari ini luar biasa bisa nemenin client jalan-jalan keliling kota pake vespa kesayangan. Cuaca juga mendukung banget! 🥵𞢨 #VespaTour #NemeninHangout',
      location: 'Senayan City, Jakarta Pusat',
      likes_count: 124
    },
    {
      user_id: defaultUserId,
      author_name: 'Siti Nurbaya',
      author_avatar: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=150&q=80',
      image_url: 'https://images.unsplash.com/photo-1511018556340-d1698661c194?auto=format&fit=crop&w=600&q=80',
      media_type: 'image',
      caption: 'Nemenin ngopi samjil curhat santai bareng client. Seneng banget bisa jadi pendengar yang jaik buat hari ini. ☕️🭍 #TemanCurhat #HangoutPartner',
      location: 'Kemang Pratama, Jakarta Selatan',
      likes_count: 89
    },
    {
      user_id: defaultUserId,
      author_name: 'Dian Sastrowardoyo',
      author_avatar: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=150&q=80',
      image_url: 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?auto=format&fit=crop&w=600&q=80',
      media_type: 'image',
      caption: 'Sukses mendampingi acara fine dining dan networking meeting malam ini. Pelayanan prima untuk-kepuasan klien VVIP!p���🥳 #EventCompanion #VVIPService',
      location: 'SCBD Sudirman, Jakarta Selatan',
      likes_count: 215
    }
  ];

  // Check if stories exist
  const { data: existingStories } = await supabaseAdmin.from('community_stories').select('id');
  if (!existingStories || existingStories.length === 0) {
    const { error: sErr } = await supabaseAdmin.from('community_stories').insert(sampleStories);
    if (sErr) console.error('Error inserting stories:', sErr);
    else console.log(' Successfully seeded community_stories!');
  } else {
    console.log('Stories already exist, count:', existingStories.length);
  }

  // Check if posts exist
  const { data: existingPosts } = await supabaseAdmin.from('community_posts').select('id');
  if (!existingPosts || existingPosts.length === 0) {
    const { data: insertedPosts, error: pErr } = await supabaseAdmin.from('community_posts').insert(samplePosts).select();
    if (pErr) {
      console.error('Error inserting posts:', pErr);
    } else {
      console.log(' Successfully seeded community_posts!');
      if (insertedPosts && insertedPosts.length > 0) {
        // Add sample comments
        await supabaseAdmin.from('community_comments').insert([
          {
            post_id: insertedPosts[0].id,
            user_id: defaultUserId,
            author_name: 'Rian Pratama',
            comment_text: 'Keren banget vespanya bang! Layanan top markotop!'
          },
          {
            post_id: insertedPosts[0].id,
            user_id: defaultUserId,
            author_name: 'Maya Putri',
            comment_text: 'Next time mau booking keliling Jakarta juga yaa 😊'
          }
        ]);
        console.log(' Successfully seeded sample comments!');
      }
    }
  } else {
    console.log('Posts already exist, count:', existingPosts.length);
  }

  console.log('Finished seeding!');
  process.exit(0);
}

seed();
