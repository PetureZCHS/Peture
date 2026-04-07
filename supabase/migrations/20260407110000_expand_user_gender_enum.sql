do $$
begin
  if not exists (select 1 from pg_type where typname = 'user_gender') then
    create type public.user_gender as enum ('male', 'female', 'other', 'confidential');
  end if;
end
$$;

alter type public.user_gender add value if not exists 'other';

alter table public.users_profiles
alter column gender type public.user_gender
using (
  case
    when gender in ('男', 'male') then 'male'::public.user_gender
    when gender in ('女', 'female') then 'female'::public.user_gender
    when gender in ('其他', 'other') then 'other'::public.user_gender
    when gender in ('不透露', '保密', 'unknown', 'confidential') then 'confidential'::public.user_gender
    else 'confidential'::public.user_gender
  end
);
