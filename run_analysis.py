"""Build the dbt project, check the projections against the truth and print the readouts.

Run from the repository root after `python data/generate.py`:
    python run_analysis.py
"""
import shutil
import subprocess
import sys
from pathlib import Path

import duckdb
import pandas as pd

DB = "acquisition.duckdb"


def build():
    """dbt build: seeds, models and every data test. Stops if a test fails."""
    dbt = shutil.which("dbt") or str(Path(sys.executable).with_name("dbt"))
    result = subprocess.run([dbt, "build", "--profiles-dir", "."], capture_output=True, text=True)
    if result.returncode != 0:
        print(result.stdout[-3000:])
        sys.exit("dbt build failed")


def projection_accuracy(con, scenario, cohorts_from):
    """Projected 24-month value against each member's true 24-month value (only synthetic data has it)."""
    proj = con.sql(f"""
        select channel, member_id, projected_value_24m
        from member_projected_value
        where scenario = '{scenario}' and cohort_month >= date '{cohorts_from}'
    """).df()
    truth = pd.read_csv("data/raw/truth_member_value_24m.csv")
    df = proj.merge(truth, on="member_id")
    out = df.groupby("channel")[["projected_value_24m", "true_value_24m"]].sum()
    out["error"] = out.projected_value_24m / out.true_value_24m - 1
    return out.reset_index()


def main():
    build()
    con = duckdb.connect(DB, read_only=True)
    pd.set_option("display.width", 160)
    pct = "{:.1%}".format

    print("\n=== 1. Signup funnel (eligible starts only) ===")
    f = con.sql("select * from funnel_by_channel").df()
    print(f.to_string(index=False, formatters={c: pct for c in f.columns if c.endswith("rate")}))
    w = con.sql("select * from funnel_weekly order by start_week desc limit 4").df()
    print("\nLast weeks, finished within 7 days:")
    print(w.to_string(index=False, formatters={"finished_7d_rate_naive": pct, "finished_7d_rate": pct}))
    ls = con.sql("""
        select channel, last_step_reached, share_of_abandoned
        from funnel_last_step
        qualify row_number() over (partition by channel order by share_of_abandoned desc) = 1
    """).df()
    print("\nMost common last step for people who never finished:")
    print(ls.to_string(index=False, formatters={"share_of_abandoned": pct}))

    print("\n=== 2. UTM cleanup ===")
    u = con.sql("select * from utm_audit").df()
    print(f"{len(u)} raw source/medium pairs mapped to {u.channel.nunique()} channels; "
          f"unmapped starts: {u.loc[u.channel == 'unmapped', 'starts'].sum()}")

    print("\n=== 3. ROAS by channel, Jan to Aug 2026 cohorts ===")
    r = con.sql("select * from channel_roas_summary").df()
    print(r.round(3).to_string(index=False))

    print("\n=== 4. Is the projection right? ===")
    bt = projection_accuracy(con, "backtest", "2023-11-01")
    print("Backtest: projected on 2024-10-31 for the Nov 2023 to Oct 2024 cohorts, against what they really paid:")
    print(bt.round(3).to_string(index=False, formatters={"error": "{:+.1%}".format}))
    cu = projection_accuracy(con, "current", "2025-11-01")
    print("\nToday's projection for the Nov 2025 to Oct 2026 cohorts, against the generator's truth:")
    print(cu.round(3).to_string(index=False, formatters={"error": "{:+.1%}".format}))


if __name__ == "__main__":
    main()
