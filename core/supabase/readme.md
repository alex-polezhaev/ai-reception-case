# Supabase (database)

This folder holds the Supabase project for the backend: the database schema as ordered SQL
migrations plus a seed file for local development.

## Layout

- `config.toml`: Supabase CLI project configuration.
- `migrations/`: timestamped SQL migrations (the source of truth for the schema).
- `seed.sql`: sample data loaded into a fresh local database.

## Apply

Requires the [Supabase CLI](https://supabase.com/docs/guides/cli).

```bash
# Start the local stack (applies migrations + seed.sql)
supabase start

# Compare local schema against the migrations
supabase db diff

# Generate a new migration from local changes
supabase db diff -f <name>

# Push migrations to the linked remote project
supabase db push
```
