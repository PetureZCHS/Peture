-- 添加 reply_to_nickname 字段到评论表
ALTER TABLE community_post_comments
ADD COLUMN IF NOT EXISTS reply_to_nickname TEXT;

COMMENT ON COLUMN community_post_comments.reply_to_nickname IS '被回复人的昵称';