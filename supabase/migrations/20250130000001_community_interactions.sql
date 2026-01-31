-- ============================================================
-- Phase 2: 社区互动功能（评论、点赞、收藏、关注）
-- 请在 Supabase Dashboard 的 SQL Editor 执行
-- ============================================================

-- 1. 评论表
CREATE TABLE IF NOT EXISTS public.community_post_comments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id uuid NOT NULL REFERENCES public.community_posts(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  parent_id uuid REFERENCES public.community_post_comments(id) ON DELETE CASCADE,
  content text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_comments_post ON public.community_post_comments(post_id);
CREATE INDEX IF NOT EXISTS idx_comments_user ON public.community_post_comments(user_id);
CREATE INDEX IF NOT EXISTS idx_comments_parent ON public.community_post_comments(parent_id);

-- RLS
ALTER TABLE public.community_post_comments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "comments_select_all"
  ON public.community_post_comments FOR SELECT
  USING (true);

CREATE POLICY "comments_insert_own"
  ON public.community_post_comments FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "comments_update_own"
  ON public.community_post_comments FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "comments_delete_own"
  ON public.community_post_comments FOR DELETE
  USING (auth.uid() = user_id);

-- 2. 点赞表
CREATE TABLE IF NOT EXISTS public.community_post_likes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id uuid NOT NULL REFERENCES public.community_posts(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(post_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_likes_post ON public.community_post_likes(post_id);
CREATE INDEX IF NOT EXISTS idx_likes_user ON public.community_post_likes(user_id);

-- RLS
ALTER TABLE public.community_post_likes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "likes_select_all"
  ON public.community_post_likes FOR SELECT
  USING (true);

CREATE POLICY "likes_insert_own"
  ON public.community_post_likes FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "likes_delete_own"
  ON public.community_post_likes FOR DELETE
  USING (auth.uid() = user_id);

-- 3. 收藏表
CREATE TABLE IF NOT EXISTS public.community_post_collections (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id uuid NOT NULL REFERENCES public.community_posts(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(post_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_collections_user ON public.community_post_collections(user_id);
CREATE INDEX IF NOT EXISTS idx_collections_post ON public.community_post_collections(post_id);

-- RLS
ALTER TABLE public.community_post_collections ENABLE ROW LEVEL SECURITY;

CREATE POLICY "collections_select_own"
  ON public.community_post_collections FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "collections_insert_own"
  ON public.community_post_collections FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "collections_delete_own"
  ON public.community_post_collections FOR DELETE
  USING (auth.uid() = user_id);

-- 4. 关注关系表
CREATE TABLE IF NOT EXISTS public.community_user_follows (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  follower_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  following_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(follower_id, following_id),
  CHECK (follower_id != following_id)
);

CREATE INDEX IF NOT EXISTS idx_follows_follower ON public.community_user_follows(follower_id);
CREATE INDEX IF NOT EXISTS idx_follows_following ON public.community_user_follows(following_id);

-- RLS
ALTER TABLE public.community_user_follows ENABLE ROW LEVEL SECURITY;

CREATE POLICY "follows_select_all"
  ON public.community_user_follows FOR SELECT
  USING (true);

CREATE POLICY "follows_insert_own"
  ON public.community_user_follows FOR INSERT
  WITH CHECK (auth.uid() = follower_id);

CREATE POLICY "follows_delete_own"
  ON public.community_user_follows FOR DELETE
  USING (auth.uid() = follower_id);

-- 5. 自动更新帖子点赞数和评论数的函数（可选，简化客户端逻辑）
CREATE OR REPLACE FUNCTION update_post_counts()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_TABLE_NAME = 'community_post_likes' THEN
    UPDATE public.community_posts
    SET like_count = (
      SELECT COUNT(*) FROM public.community_post_likes
      WHERE post_id = COALESCE(NEW.post_id, OLD.post_id)
    )
    WHERE id = COALESCE(NEW.post_id, OLD.post_id);
  ELSIF TG_TABLE_NAME = 'community_post_comments' THEN
    UPDATE public.community_posts
    SET comment_count = (
      SELECT COUNT(*) FROM public.community_post_comments
      WHERE post_id = COALESCE(NEW.post_id, OLD.post_id)
    )
    WHERE id = COALESCE(NEW.post_id, OLD.post_id);
  END IF;
  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- 触发器：点赞时更新计数
DROP TRIGGER IF EXISTS trigger_update_like_count ON public.community_post_likes;
CREATE TRIGGER trigger_update_like_count
  AFTER INSERT OR DELETE ON public.community_post_likes
  FOR EACH ROW EXECUTE FUNCTION update_post_counts();

-- 触发器：评论时更新计数
DROP TRIGGER IF EXISTS trigger_update_comment_count ON public.community_post_comments;
CREATE TRIGGER trigger_update_comment_count
  AFTER INSERT OR DELETE ON public.community_post_comments
  FOR EACH ROW EXECUTE FUNCTION update_post_counts();
