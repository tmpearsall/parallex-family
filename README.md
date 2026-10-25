# Parallex Family

A private, invite-only Rails app a family uses to plan a reunion: the family tree, households, date voting,
RSVPs by household, a "what we need" list anyone can claim, and a message board. Rebuilt from the Streamlit
prototype at github.com/tmpearsall/genealogy.

- Multi-tenant: many families, each with its own tree, households, reunions and board, under `/f/<family>/...`.
  One account can belong to several families. The family is found only through the signed-in user's own
  memberships, so a family you are not in is a 404. Roles per family: organizer and member.
- Joining is by invitation: an organizer pastes one or more emails on the Members page and copies a one-time link
  (7 days) for each; no email is sent yet. A platform administrator creates families (`/platform/families`, or
  `bin/rails 'family:create[Name,organizer@email,slug]'`) and can issue a password link; it sees no family's data.
- The tree stores two facts only: parent-of and partner-of. Siblings, cousins and the rest are derived.
- A child's date of birth, notes and email can be hidden from everyone but an administrator and the child.
- Production database: the Parallex Supabase project, schema `family_app`, a role that owns only that schema
  (`db/parallex_setup.sql`, not yet run). `DATABASE_URL` is the pooled connection string.
- Colors: two blocks at the top of `app/assets/stylesheets/application.css` (reddish purple; subject to change).

```
bin/setup   # or: bin/rails db:create db:migrate
bin/rails test
```
