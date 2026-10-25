# Parallex Family

A private, invite-only Rails app a family uses to plan a reunion: the family tree, households, date voting,
RSVPs by household, a "what we need" list anyone can claim, and a message board. Rebuilt from the Streamlit
prototype at github.com/tmpearsall/genealogy.

- Accounts are issued by an administrator; no sign-up, no email. `bin/rails 'family:invite[email,Name,admin]'`
  prints a one-time set-password link (7 days). The admin page (Accounts) does the same from the browser.
- The tree stores two facts only: parent-of and partner-of. Siblings, cousins and the rest are derived.
- A child's date of birth, notes and email can be hidden from everyone but an administrator and the child.
- Production database: the Parallex Supabase project, schema `family_app`, a role that owns only that schema
  (`db/parallex_setup.sql`, not yet run). `DATABASE_URL` is the pooled connection string.
- Colors: two blocks at the top of `app/assets/stylesheets/application.css` (reddish purple; subject to change).

```
bin/setup   # or: bin/rails db:create db:migrate
bin/rails test
```
