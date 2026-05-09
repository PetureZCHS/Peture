-- 用户头像桶 user-avatars：公开读 + 仅本人可写入自己目录（路径首段 = auth.uid()）
-- 修复「头像已保存，但同步失败」：多为 Storage 无桶、未公开读、或 RLS 未允许 authenticated 上传。

insert into storage.buckets (id, name, public)
values ('user-avatars', 'user-avatars', true)
on conflict (id) do update
set public = excluded.public;

drop policy if exists "user_avatars_select_public_v1" on storage.objects;
drop policy if exists "user_avatars_insert_own_v1" on storage.objects;
drop policy if exists "user_avatars_update_own_v1" on storage.objects;
drop policy if exists "user_avatars_delete_own_v1" on storage.objects;

create policy "user_avatars_select_public_v1"
  on storage.objects for select
  to public
  using (bucket_id = 'user-avatars');

create policy "user_avatars_insert_own_v1"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'user-avatars'
    and split_part(name, '/', 1) = (select auth.uid()::text)
  );

create policy "user_avatars_update_own_v1"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'user-avatars'
    and split_part(name, '/', 1) = (select auth.uid()::text)
  )
  with check (
    bucket_id = 'user-avatars'
    and split_part(name, '/', 1) = (select auth.uid()::text)
  );

create policy "user_avatars_delete_own_v1"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'user-avatars'
    and split_part(name, '/', 1) = (select auth.uid()::text)
  );
