-- 修复：选择「不透露」时报 invalid input value for enum gender: "confidential" (22P02)
-- 说明：当前库中 users_profiles.gender 使用的枚举类型名为 public.gender，且未包含 confidential / other。
-- 若执行时报 type "gender" does not exist，请在 SQL Editor 中把下面两行里的 gender 改成 user_gender 再执行。

alter type public.gender add value if not exists 'other';
alter type public.gender add value if not exists 'confidential';

notify pgrst, 'reload schema';
