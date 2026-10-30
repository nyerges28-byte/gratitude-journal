# Gratitude Journal

Write down ten things you're grateful for every day. Each entry is numbered, a lotus blooms as you reach ten, and the app echoes back how often you've been grateful for the people and things in your life.

- Web app: one page (`index.html`), no build step.
- Accounts and data: Supabase (email sign-in; every journal is private through row-level security).
- Database setup: `supabase/setup.sql`.

The Supabase key in `index.html` is the public "publishable" key. It's meant to be in the page; it can't read anyone's journal without that person's sign-in.
