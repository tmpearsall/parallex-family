-- Run ONCE on the Parallex Supabase project (clpidvrselxkzuuptcxu) as the postgres owner. Not yet run.
-- Gives the family app its own schema and a role that can touch nothing else, the same pattern as the reviewer app.
-- Replace <PASSWORD> with a long random value; it goes only into the Render env var DATABASE_URL (pooled URL).
create schema if not exists family_app;
do $$ begin
  if not exists (select 1 from pg_roles where rolname = 'family_app') then
    create role family_app login password '<PASSWORD>' nosuperuser nocreatedb nocreaterole noinherit;
  end if;
end $$;
alter schema family_app owner to family_app;
alter role family_app set search_path = family_app, public;
revoke all on schema public from family_app;
revoke create on schema public from family_app;
grant usage on schema family_app to family_app;
-- Belt and braces: the app's tables are private; no API role may read them through PostgREST.
revoke all on schema family_app from anon, authenticated;
alter default privileges in schema family_app revoke all on tables from anon, authenticated;
