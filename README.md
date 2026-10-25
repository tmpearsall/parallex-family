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

## Two ways to run it

One codebase, two deployments. **Multi-tenant** (default, the commercial product): many families under `/f/<family>`,
a platform administrator, a family picker. **Dedicated** (`INSTANCE_MODE=dedicated`,
`DEDICATED_FAMILY_SLUG=<slug>`): one family's own site at the root (`/tree`, `/people`, ...), no `/f/` in any
address, no picker, no platform pages. Routes are built at boot, so the dedicated tests run separately:
`INSTANCE_MODE=dedicated DEDICATED_FAMILY_SLUG=rowe bin/rails test test/dedicated`.
`FAMILY_HOST` (comma-separated) locks the site to those hostnames; `MAIL_HOST` sets the host used in email links.

## Email (invitations and reminders)

Mail goes out over any SMTP provider using the same variables as Parallex Advisory: `SMTP_ADDRESS`, `SMTP_PORT`
(587; or 465 with `SMTP_TLS=true`), `SMTP_USERNAME`, `SMTP_PASSWORD`, plus `MAIL_FROM`. Cloudflare Email Service: `smtp.mx.cloudflare.net`, port 465, `SMTP_TLS=true`, username `api_token`, password a Cloudflare API token with Email Sending: Edit. With Resend: `smtp.resend.com`, username `resend`,
password = an API key, and a verified sending domain. With no `SMTP_ADDRESS` nothing is sent: the Members page shows
copyable links, and the reminder scheduler stays off.

- Invitations: tick "Email each person their link" on the Members page; Resend makes a fresh link.
- Reminders: one digest per member per day at most (13:00 UTC), run inside the web process
  (`config/initializers/reminder_scheduler.rb`; `REMINDER_SCHEDULER=off` disables it, `bin/rails reminders:send`
  runs it by hand). RSVP deadlines, dates to vote on, claimed tasks, the reunion at 30/7/1 days, events tomorrow.
  `email_deliveries` has a unique index so no one is reminded of the same thing twice. Every digest has an
  unsubscribe link and the one-click header; each member can also switch reminders off on Who's here.

## Contacts, messages and spreadsheets (2026-10-26)

- A person has a mailing address (street 1 and 2, city, state, zip) and a second phone number. The address belongs to
  the person, not the household, so a student on campus has their own. A person marked private hides these from
  everyone but an organizer and themselves, like the rest of their details.
- Access page, invite form: "Not in the list? Add them here" creates the person and, in a family workspace, records
  how they are related to someone already in the tree (child, parent or partner).
- Organizers can send a reminder (`/announcements`): everyone, households that have not answered an RSVP, or people
  with an unfinished task. A preview shows who gets it; nothing sends until confirmed; people who turned reminders off
  are skipped; 60 emails a day per family; every send is recorded.
- Organizers can export the list as a CSV and import one (`/people/import`): ten columns (First name, Last name, Phone,
  Email, Phone 2, Street 1, Street 2, City, State, Zip), only First name required. Import previews first, only adds
  (a matching email or name is skipped), makes no accounts and sends no email. Files over 1 MB or 500 rows are refused.

## Surveys (2026-10-26)

Organizers (Access page, or `/surveys`) write a survey of up to eight questions (pick one, pick any, short answer, long
answer, suggest dates), preview exactly who gets it, and email it. Audiences: everyone with an account, everyone on the
list who has an email, both, or only people who have not answered yet (a reminder). Everyone gets a personal link
(`/s/<token>`, no login); only the SHA-256 digest of the token is stored, a reminder issues a fresh link and the old one
stops working. Answers can be changed until the survey closes (a closing date, or Close now). Results show counts and
written answers; "hide names" hides names in the results (the site still knows who answered, so reminders go only to those
who have not). Suggested dates can be turned into proposed dates on a reunion. Anyone can stop surveys from the link in the
email (`/s/<token>/stop`; stored per family and email, applies to people with or without accounts). Surveys and reminder
messages share a cap of 60 emails a day per family. Questions cannot change after a survey is sent.
