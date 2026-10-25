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

## Email (invitations and reminders)

Mail goes out over any SMTP provider using the same variables as Parallex Advisory: `SMTP_ADDRESS`, `SMTP_PORT`
(587), `SMTP_USERNAME`, `SMTP_PASSWORD`, plus `MAIL_FROM`. With Resend: `smtp.resend.com`, username `resend`,
password = an API key, and a verified sending domain. With no `SMTP_ADDRESS` nothing is sent: the Members page shows
copyable links, and the reminder scheduler stays off.

- Invitations: tick "Email each person their link" on the Members page; Resend makes a fresh link.
- Reminders: one digest per member per day at most (13:00 UTC), run inside the web process
  (`config/initializers/reminder_scheduler.rb`; `REMINDER_SCHEDULER=off` disables it, `bin/rails reminders:send`
  runs it by hand). RSVP deadlines, dates to vote on, claimed tasks, the reunion at 30/7/1 days, events tomorrow.
  `email_deliveries` has a unique index so no one is reminded of the same thing twice. Every digest has an
  unsubscribe link and the one-click header; each member can also switch reminders off on Who's here.
