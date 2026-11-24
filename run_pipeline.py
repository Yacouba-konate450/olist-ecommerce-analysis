"""Run the SQL pipeline in DuckDB and export analysis tables to output/.

Usage:  python run_pipeline.py
"""
from pathlib import Path
import duckdb

ROOT = Path(__file__).parent
OUT = ROOT / "output"
OUT.mkdir(exist_ok=True)

con = duckdb.connect(str(ROOT / "olist.duckdb"))
for f in sorted((ROOT / "sql").glob("0[1-3]_*.sql")):
    print(f"running {f.name}")
    con.execute(f.read_text(encoding="utf-8"))

print("\nData quality checks")
print(con.sql((ROOT / "sql" / "04_quality_checks.sql").read_text(encoding="utf-8")))

print("running 05_analysis.sql")
con.execute((ROOT / "sql" / "05_analysis.sql").read_text(encoding="utf-8"))
for t in ["a_monthly", "a_categories", "a_states", "a_late_vs_review", "a_repeat", "a_payments", "a_heatmap"]:
    con.table(t).df().to_csv(OUT / f"{t}.csv", index=False)
con.table("fact_orders").df().to_csv(OUT / "fact_orders.csv", index=False)
print(f"exported tables to {OUT}/")
con.close()
