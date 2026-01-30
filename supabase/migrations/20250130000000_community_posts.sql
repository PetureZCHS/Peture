-- ============================================================
-- Phase 1: 社区帖子表（发帖 + 信息流）
-- 请在 Supabase Dashboard 执行本文件；Storage 需在 Dashboard 手动建桶
-- ============================================================

-- 帖子表
CREATE TABLE IF NOT EXISTS public.community_posts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  author_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  content text NOT NULL,
  image_urls text[] NOT NULL DEFAULT '{}',
  topic_ids text[] NOT NULL DEFAULT '{}',
  source_type text NOT NULL DEFAULT 'normal',
  like_count int NOT NULL DEFAULT 0,
  comment_count int NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_community_posts_author ON public.community_posts(author_id);
CREATE INDEX IF NOT EXISTS idx_community_posts_created_at ON public.community_posts(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_community_posts_source_type ON public.community_posts(source_type);

-- RLS
ALTER TABLE public.community_posts ENABLE ROW LEVEL SECURITY;

-- 所有人可读
CREATE POLICY "community_posts_select_all"
  ON public.community_posts FOR SELECT
  USING (true);

-- 仅登录用户可插入，且 author_id = 当前用户
CREATE POLICY "community_posts_insert_own"
  ON public.community_posts FOR INSERT
  WITH CHECK (auth.uid() = author_id);

-- 仅作者可更新/删除
CREATE POLICY "community_posts_update_own"
  ON public.community_posts FOR UPDATE
  USING (auth.uid() = author_id)
  WITH CHECK (auth.uid() = author_id);

CREATE POLICY "community_posts_delete_own"
  ON public.community_posts FOR DELETE
  USING (auth.uid() = author_id);

-- ============================================================
-- Storage 桶需在 Dashboard 手动创建：
-- 1. Storage -> New bucket -> 名称: post-images
-- 2. Public bucket: 勾选（允许公开读）
-- 3. Policies: 新增 Policy
--    - Policy name: 允许登录用户上传
--    - Allowed operation: INSERT, UPDATE
--    - Target roles: authenticated
--    - USING expression: true
--    - WITH CHECK expression: true
-- 4. 可选：再建一条 SELECT policy，USING (true)，允许所有人读
-- ============================================================
