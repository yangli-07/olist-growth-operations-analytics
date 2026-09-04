# PostgreSQL Database Setup

## Overview

The cleaned Olist datasets are stored in a PostgreSQL database named
`olist_analytics`. All project tables are organised inside the `olist`
schema.

The database setup is reproducible through the SQL scripts in the
`sql/` directory.

## Requirements

- PostgreSQL 18
- Nine cleaned CSV files in `data/processed/`
- A local database named `olist_analytics`

## Build Process

Run the following commands from the project root:

```bash
createdb olist_analytics

psql -d olist_analytics \
  -f sql/01_create_tables.sql

psql -d olist_analytics \
  -f sql/02_load_data.sql

psql -d olist_analytics \
  -f sql/03_constraints_indexes.sql

psql -d olist_analytics \
  -f sql/04_validate_database.sql
