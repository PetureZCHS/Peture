-- 宠物头像桶 pet-avatars：公开读 + 仅本人可写入自己目录（路径首段 = auth.uid()）
-- 与 lib/services/supabase_service.dart 中路径 {userId}/{petId}/avatar_*.jpg 一致

insert into storage.buckets (id, name, public)
values ('pet-avatars', 'pet-avatars', true)
on conflict (id) do update
set public = excluded.public;

drop policy if exists "pet_avatars_select_public_v1" on storage.objects;
drop policy if exists "pet_avatars_insert_own_v1" on storage.objects;
drop policy if exists "pet_avatars_update_own_v1" on storage.objects;
drop policy if exists "pet_avatars_delete_own_v1" on storage.objects;

create policy "pet_avatars_select_public_v1"
  on storage.objects for select
  to public
  using (bucket_id = 'pet-avatars');

create policy "pet_avatars_insert_own_v1"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'pet-avatars'
    and split_part(name, '/', 1) = (select auth.uid()::text)
  );

create policy "pet_avatars_update_own_v1"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'pet-avatars'
    and split_part(name, '/', 1) = (select auth.uid()::text)
  )
  with check (
    bucket_id = 'pet-avatars'
    and split_part(name, '/', 1) = (select auth.uid()::text)
  );

create policy "pet_avatars_delete_own_v1"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'pet-avatars'
    and split_part(name, '/', 1) = (select auth.uid()::text)
  );
