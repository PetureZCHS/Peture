DO $$
BEGIN
  INSERT INTO storage.buckets (id, name, public)
  VALUES ('avatars-temp', 'avatars-temp', false)
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO storage.buckets (id, name, public)
  VALUES ('avatars', 'avatars', true)
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO storage.buckets (id, name, public)
  VALUES ('ai-images-temp', 'ai-images-temp', false)
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO storage.buckets (id, name, public)
  VALUES ('ai-images', 'ai-images', true)
  ON CONFLICT (id) DO NOTHING;
END $$;

DROP POLICY IF EXISTS "avatars_temp_owner_read" ON storage.objects;
CREATE POLICY "avatars_temp_owner_read"
ON storage.objects FOR SELECT
TO authenticated
USING (bucket_id = 'avatars-temp' AND owner = auth.uid());

DROP POLICY IF EXISTS "avatars_temp_owner_write" ON storage.objects;
CREATE POLICY "avatars_temp_owner_write"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'avatars-temp' AND owner = auth.uid());

DROP POLICY IF EXISTS "avatars_temp_owner_update" ON storage.objects;
CREATE POLICY "avatars_temp_owner_update"
ON storage.objects FOR UPDATE
TO authenticated
USING (bucket_id = 'avatars-temp' AND owner = auth.uid())
WITH CHECK (bucket_id = 'avatars-temp' AND owner = auth.uid());

DROP POLICY IF EXISTS "avatars_temp_owner_delete" ON storage.objects;
CREATE POLICY "avatars_temp_owner_delete"
ON storage.objects FOR DELETE
TO authenticated
USING (bucket_id = 'avatars-temp' AND owner = auth.uid());

DROP POLICY IF EXISTS "ai_images_temp_owner_read" ON storage.objects;
CREATE POLICY "ai_images_temp_owner_read"
ON storage.objects FOR SELECT
TO authenticated
USING (bucket_id = 'ai-images-temp' AND owner = auth.uid());

DROP POLICY IF EXISTS "ai_images_temp_owner_write" ON storage.objects;
CREATE POLICY "ai_images_temp_owner_write"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'ai-images-temp' AND owner = auth.uid());

DROP POLICY IF EXISTS "ai_images_temp_owner_update" ON storage.objects;
CREATE POLICY "ai_images_temp_owner_update"
ON storage.objects FOR UPDATE
TO authenticated
USING (bucket_id = 'ai-images-temp' AND owner = auth.uid())
WITH CHECK (bucket_id = 'ai-images-temp' AND owner = auth.uid());

DROP POLICY IF EXISTS "ai_images_temp_owner_delete" ON storage.objects;
CREATE POLICY "ai_images_temp_owner_delete"
ON storage.objects FOR DELETE
TO authenticated
USING (bucket_id = 'ai-images-temp' AND owner = auth.uid());

-- 正式桶读取策略按当前产品需求默认开放读取，写入仍限制登录用户
DROP POLICY IF EXISTS "avatars_public_read" ON storage.objects;
CREATE POLICY "avatars_public_read"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'avatars');

DROP POLICY IF EXISTS "avatars_auth_write" ON storage.objects;
CREATE POLICY "avatars_auth_write"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'avatars');

DROP POLICY IF EXISTS "ai_images_public_read" ON storage.objects;
CREATE POLICY "ai_images_public_read"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'ai-images');

DROP POLICY IF EXISTS "ai_images_auth_write" ON storage.objects;
CREATE POLICY "ai_images_auth_write"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'ai-images');

