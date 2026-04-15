-- 用户内容反馈：举报 / 不感兴趣（审计与合规）
CREATE TABLE IF NOT EXISTS public.user_content_feedback (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  feedback_type text NOT NULL CHECK (feedback_type IN ('report', 'not_interested')),
  surface text NOT NULL CHECK (surface IN ('pet_diary', 'pet_diary_detail', 'ai_image', 'chat_ai')),
  ref jsonb NOT NULL DEFAULT '{}'::jsonb,
  reason_code text,
  note text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_user_content_feedback_user_created
  ON public.user_content_feedback(user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_user_content_feedback_surface_created
  ON public.user_content_feedback(surface, created_at DESC);

ALTER TABLE public.user_content_feedback ENABLE ROW LEVEL SECURITY;

-- 仅本人可插入
CREATE POLICY "user_content_feedback_insert_own"
  ON public.user_content_feedback FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- 仅本人可查看自己的反馈记录
CREATE POLICY "user_content_feedback_select_own"
  ON public.user_content_feedback FOR SELECT
  USING (auth.uid() = user_id);
