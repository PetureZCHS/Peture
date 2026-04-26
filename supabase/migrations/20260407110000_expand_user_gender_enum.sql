do $$
begin
  if not exists (select 1 from pg_type where typname = 'user_gender') then
    create type public.user_gender as enum ('male', 'female', 'other', 'confidential');
  end if;
end
$$;

-- 在已有库上 gender 列通常已是 user_gender枚举，不能写 gender in ('男')（会把 '男' 当成枚举字面量而报错）
alter type public.user_gender add value if not exists 'other';

alter table public.users_profiles
alter column gender type public.user_gender
using (
  case
    when gender is null then null::public.user_gender
    else
      case trim(both from gender::text)
        when 'male' then 'male'::public.user_gender
        when 'female' then 'female'::public.user_gender
        when 'other' then 'other'::public.user_gender
        when 'confidential' then 'confidential'::public.user_gender
        when '男' then 'male'::public.user_gender
        when '女' then 'female'::public.user_gender
        when '其他' then 'other'::public.user_gender
        when '不透露' then 'confidential'::public.user_gender
        when '保密' then 'confidential'::public.user_gender
        when 'unknown' then 'confidential'::public.user_gender
        else 'confidential'::public.user_gender
      end
  end
);

comment on column public.users_profiles.gender is '用户性别枚举：male, female, other, confidential';
