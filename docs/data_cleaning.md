# Data Cleaning Methodology

## Objective

The cleaning process standardises the Olist datasets while preserving the original raw files. All transformations are reproducible in `notebooks/03_data_cleaning.ipynb`.

## Cleaning Principles

- Raw CSV files are never modified.
- Main business records are retained unless a row is an exact duplicate.
- Invalid values are corrected only when there is a clear business interpretation.
- Uncertain values are converted to missing values rather than estimated.
- Data-quality issues are documented and flagged.
- Row counts and key uniqueness are validated after cleaning.

## Cleaning Rules

| Area | Issue | Treatment |
|---|---|---|
| Dates | Eight timestamp columns were stored as text | Converted to `datetime64[ns]` |
| Date parsing | Potential invalid date strings | Checked with `errors="coerce"`; no parsing failures were found |
| ZIP codes | ZIP-code prefixes were stored as integers | Converted to five-character strings with leading zeros |
| Text | Inconsistent text types and surrounding spaces | Converted to string type and stripped |
| Missing categories | 610 products had no category | Labelled as `unknown` |
| Missing translations | 13 products belonged to two untranslated categories | Added two manual English translations |
| Geolocation duplicates | The geolocation table contained exact duplicate rows | Removed before aggregation |
| Geolocation grain | ZIP-code prefixes appeared multiple times | Aggregated to one row per ZIP-code prefix |
| Coordinates | Multiple coordinates existed for a ZIP code | Used median latitude and longitude |
| City and state | Multiple labels existed for a ZIP code | Used the most frequent value |
| Payment installments | Two credit-card payments had zero installments | Changed from 0 to 1 |
| Product weight | Four products had zero weight | Converted to missing values |
| Timestamp anomalies | Some orders had inconsistent timestamp sequences | Preserved and flagged |
| Status/date mismatch | Some order statuses disagreed with delivery timestamps | Preserved and flagged |

## Category Translation Additions

| Portuguese category | English category | Products |
|---|---|---:|
| `portateis_cozinha_e_preparadores_de_alimentos` | `portable_kitchen_and_food_preparation_appliances` | 10 |
| `pc_gamer` | `gaming_pc` | 3 |

## Order-Quality Flags

The cleaned orders table contains three additional fields:

- `has_timestamp_anomaly`: identifies an invalid timestamp sequence.
- `has_status_date_mismatch`: identifies disagreement between order status and delivery date.
- `is_valid_delivery_record`: identifies records suitable for delivery-performance analysis.

## Geolocation Coverage

After aggregation, the geolocation table contains 19,015 unique ZIP-code prefixes.

- Customer ZIP-code coverage: 99.72%.
- Seller ZIP-code coverage: 99.77%.
- Unmatched customers and sellers are retained for later left joins.

## Output

Nine cleaned datasets are written to `data/processed/`. Processed data files remain local and are excluded from GitHub. Cleaning summaries and validation results are stored in `reports/`.

## Validation

The final validation confirms that:

- all candidate primary keys remain valid;
- no date-parsing failures were introduced;
- every product has an English category;
- geolocation contains one row per ZIP-code prefix;
- payment installments are at least one;
- non-missing product weights are positive;
- main business-table row counts remain unchanged.