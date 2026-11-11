-- Scam Watch BW: run this whole file once in the Supabase SQL Editor.

-- 1. Admins (the first admin is seeded below; add more from the Admins tab)
create table if not exists admins(email text primary key);
insert into admins(email) values ('mofenyi157@gmail.com') on conflict do nothing;

create or replace function is_admin() returns boolean
language sql stable security definer set search_path=public as $$
  select exists(select 1 from admins where lower(email)=lower(coalesce(auth.jwt()->>'email','')))
$$;
grant execute on function is_admin() to anon, authenticated;

-- 2. Normalise numbers, handles and websites so repeat reports match
create or replace function norm_ident(t text) returns text language sql immutable as $$
  select regexp_replace(regexp_replace(regexp_replace(regexp_replace(lower(t),'^https?://',''),'^www[.]',''),'[ ().-]','','g'),'^[+]?267|/$','','g')
$$;

-- 3. Tables
create table if not exists reports(
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  category text not null, channel text not null,
  identifier text not null check (char_length(identifier) between 1 and 300),
  identifier_norm text not null,
  claim text not null check (char_length(claim) between 1 and 1000),
  amount text check (char_length(amount)<=50), happened_on date,
  evidence text check (char_length(evidence)<=2000),
  is_dispute boolean not null default false,
  status text not null default 'received' check (status in ('received','review','reported','confirmed','rejected','resolved')),
  created_at timestamptz not null default now()
);
create table if not exists alerts(
  id uuid primary key default gen_random_uuid(),
  identifier_norm text unique not null, identifier text not null,
  category text not null, channel text not null,
  status text not null check (status in ('reported','confirmed')),
  report_count int not null default 0, summary text check (char_length(summary)<=300),
  updated_at timestamptz not null default now()
);
create table if not exists messages(
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  body text not null check (char_length(body) between 1 and 500),
  created_at timestamptz not null default now()
);

-- 4. Guards that run on the server, so they cannot be bypassed from the browser
create or replace function reports_guard() returns trigger language plpgsql security definer set search_path=public as $$
begin
  new.user_id:=auth.uid(); new.status:='received'; new.identifier_norm:=norm_ident(new.identifier);
  if (select count(*) from reports where user_id=new.user_id and created_at>now()-interval '1 day')>=20
    then raise exception 'Daily report limit reached. Please try again tomorrow.'; end if;
  return new;
end $$;
drop trigger if exists reports_guard on reports;
create trigger reports_guard before insert on reports for each row execute function reports_guard();

create or replace function chat_guard() returns trigger language plpgsql security definer set search_path=public as $$
begin
  new.user_id:=auth.uid();
  if exists(select 1 from messages where user_id=new.user_id and created_at>now()-interval '2 seconds')
    then raise exception 'Slow down a little.'; end if;
  if regexp_replace(new.body,'[ ().-]','','g') ~ '[0-9]{7,}'
    then raise exception 'Please don’t share phone, ID or account numbers. Put scam numbers in a report instead.'; end if;
  if new.body ~* '[a-z0-9._+-]+@[a-z0-9-]+[.][a-z]'
    then raise exception 'Please don’t share email addresses.'; end if;
  if new.body ~* '(https?://|www[.])'
    then raise exception 'Please don’t post links. Use a report so reviewers can check it.'; end if;
  if new.body ~* '(my (address|omang|pin|phone number|number is)|i live (in|at)|plot ?[0-9]|p[.]?o[.]? ?box|call me|whatsapp me|dm me|text me)'
    then raise exception 'That looks like personal information. Please keep it out of the chat.'; end if;
  return new;
end $$;
drop trigger if exists chat_guard on messages;
create trigger chat_guard before insert on messages for each row execute function chat_guard();

-- 5. Chat view: members see anonymous handles, never user ids
create or replace view chat_view as
  select id, 'Member '||right(replace(user_id::text,'-',''),4) as handle, (user_id=auth.uid()) as mine, body, created_at from messages;
revoke all on chat_view from anon; grant select on chat_view to authenticated;

-- 6. Row level security
alter table admins enable row level security;
alter table reports enable row level security;
alter table alerts enable row level security;
alter table messages enable row level security;

create policy admins_admin on admins for all to authenticated using (is_admin()) with check (is_admin());
create policy alerts_read on alerts for select to anon, authenticated using (true);
create policy alerts_admin on alerts for all to authenticated using (is_admin()) with check (is_admin());
create policy reports_insert on reports for insert to authenticated with check (user_id=auth.uid());
create policy reports_admin on reports for all to authenticated using (is_admin()) with check (is_admin());
create policy messages_insert on messages for insert to authenticated with check (user_id=auth.uid());
create policy messages_admin on messages for all to authenticated using (is_admin()) with check (is_admin());

-- 7. Publishing an alert (enforces the 3-independent-reporters rule on the server)
create or replace function publish_alert(p_report uuid, p_status text, p_summary text, p_category text) returns void
language plpgsql security definer set search_path=public as $$
declare r reports%rowtype; n int;
begin
  if not is_admin() then raise exception 'Not allowed'; end if;
  if p_status not in ('reported','confirmed') then raise exception 'Bad status'; end if;
  select * into r from reports where id=p_report;
  if not found or r.is_dispute then raise exception 'This report cannot be published'; end if;
  select count(distinct user_id) into n from reports where identifier_norm=r.identifier_norm and not is_dispute and status<>'rejected';
  if p_status='reported' and n<3 then raise exception 'Reported needs 3 independent reporters'; end if;
  insert into alerts(identifier_norm,identifier,category,channel,status,report_count,summary)
    values(r.identifier_norm,r.identifier,p_category,r.channel,p_status,n,p_summary)
  on conflict(identifier_norm) do update set identifier=excluded.identifier,category=excluded.category,channel=excluded.channel,
    status=excluded.status,report_count=excluded.report_count,summary=excluded.summary,updated_at=now();
  update reports set status=p_status where id=p_report;
end $$;
revoke execute on function publish_alert(uuid,text,text,text) from public, anon;
grant execute on function publish_alert(uuid,text,text,text) to authenticated;
