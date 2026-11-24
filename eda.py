"""Exploratory data analysis charts for the Olist e-commerce project.

Run `python run_pipeline.py` first, then `python eda.py`.
Charts are saved as PNG files in images/ (ready for the GitHub README).
"""
from pathlib import Path

import matplotlib.pyplot as plt
import matplotlib.ticker as mtick
import numpy as np
import pandas as pd

OUT = Path("output")
IMG = Path("images")
IMG.mkdir(exist_ok=True)

# Palette: one main hue, one highlight, neutral grey (colorblind-safe pair)
BLUE, ORANGE, GREY = "#2a78d6", "#eb6834", "#b4b2a9"
INK, INK2 = "#0b0b0b", "#52514e"
plt.rcParams.update({
    "figure.facecolor": "#fcfcfb", "axes.facecolor": "#fcfcfb", "savefig.facecolor": "#fcfcfb",
    "axes.edgecolor": "#d6d5ce", "axes.labelcolor": INK2, "xtick.color": INK2, "ytick.color": INK2,
    "axes.spines.top": False, "axes.spines.right": False, "axes.grid": True, "grid.color": "#ebeae4",
    "grid.linewidth": 0.8, "axes.axisbelow": True, "font.size": 10.5, "axes.titlesize": 13,
    "axes.titleweight": "bold", "axes.titlelocation": "left", "axes.titlecolor": INK,
})


def save(fig, name, source="Source: Olist Brazilian E-Commerce Public Dataset (Kaggle). Delivered orders, Jan 2017 – Aug 2018."):
    fig.text(0.01, 0.01, source, fontsize=8, color=INK2)
    fig.tight_layout(rect=(0, 0.03, 1, 1))
    fig.savefig(IMG / name, dpi=150)
    plt.close(fig)
    print("saved", IMG / name)


monthly = pd.read_csv(OUT / "a_monthly.csv", parse_dates=["order_month"])
cats = pd.read_csv(OUT / "a_categories.csv")
states = pd.read_csv(OUT / "a_states.csv")
late = pd.read_csv(OUT / "a_late_vs_review.csv")
pay = pd.read_csv(OUT / "a_payments.csv")
heat = pd.read_csv(OUT / "a_heatmap.csv")
orders = pd.read_csv(OUT / "fact_orders.csv", parse_dates=["purchased_at", "order_month"])
delivered = orders[orders.is_complete_month & (orders.order_status == "delivered")]

# ---------------------------------------------------------------- 1. monthly GMV trend
fig, ax = plt.subplots(figsize=(10, 4.8))
ax.plot(monthly.order_month, monthly.gmv / 1e6, color=BLUE, lw=2, marker="o", ms=4)
peak = monthly.loc[monthly.gmv.idxmax()]
ax.plot(peak.order_month, peak.gmv / 1e6, "o", ms=9, color=ORANGE, mec="#fcfcfb", mew=2)
ax.annotate(f"Nov 2017 (Black Friday)\n{peak.gmv/1e6:.2f}M BRL, +{peak.gmv_mom_pct:.0f}% vs Oct",
            (peak.order_month, peak.gmv / 1e6), xytext=(-210, -45), textcoords="offset points",
            fontsize=9, color=INK, arrowprops=dict(arrowstyle="-", color=INK2))
ax.axvspan(pd.Timestamp("2018-01-01"), pd.Timestamp("2018-08-31"), color=GREY, alpha=0.15, lw=0)
ax.text(pd.Timestamp("2018-01-10"), 0.15, "2018: growth stalls\n(≈1.0–1.1M BRL / month)", fontsize=9, color=INK2)
ax.set_title("Monthly revenue (GMV) grew ~8x in a year, then plateaued in 2018")
ax.set_ylabel("GMV (million BRL)")
ax.set_ylim(0, None)
save(fig, "01_monthly_gmv.png")

# ---------------------------------------------------------------- 2. top categories
top = cats.head(10).iloc[::-1]
fig, ax = plt.subplots(figsize=(9, 5))
ax.barh(top.category.str.replace("_", " "), top.product_revenue / 1e6, color=BLUE, height=0.65)
for y, (v, s) in enumerate(zip(top.product_revenue / 1e6, top.revenue_share_pct)):
    ax.text(v + 0.02, y, f"{v:.2f}M  ({s:.1f}%)", va="center", fontsize=9, color=INK)
ax.set_title(f"Top 10 of {(cats.category != "unknown").sum()} categories = {cats.revenue_share_pct.head(10).sum():.0f}% of product revenue")
ax.set_xlabel("Product revenue (million BRL)")
ax.grid(axis="y", visible=False)
ax.set_xlim(0, top.product_revenue.max() / 1e6 * 1.3)
save(fig, "02_top_categories.png")

# ---------------------------------------------------------------- 3. delivery by state
st = states[states.orders >= 500].sort_values("median_delivery_days")
fig, axes = plt.subplots(1, 2, figsize=(11, 6), sharey=True)
colors = [ORANGE if s in ("RJ",) else BLUE for s in st.customer_state]
axes[0].barh(st.customer_state, st.median_delivery_days, color=BLUE, height=0.65)
axes[0].set_title("Median delivery time (days)")
axes[1].barh(st.customer_state, st.late_pct, color=colors, height=0.65)
axes[1].set_title("Orders delivered late (%)")
axes[1].annotate("RJ: next to SP but 12% late", xy=(st.set_index("customer_state").late_pct["RJ"],
                 list(st.customer_state).index("RJ")), xytext=(8, -4), textcoords="offset points", fontsize=9)
for a in axes:
    a.grid(axis="y", visible=False)
fig.suptitle("Delivery is fastest in São Paulo (SP) and slowest in the North and North-East", x=0.01, ha="left",
             fontsize=13, fontweight="bold", color=INK)
save(fig, "03_delivery_by_state.png", "States with ≥ 500 delivered orders. Source: Olist dataset, Jan 2017 – Aug 2018.")

# ---------------------------------------------------------------- 4. lateness vs reviews
fig, ax = plt.subplots(figsize=(9, 4.8))
lbl = late.delivery_bucket.str[3:]
cols = [BLUE, BLUE, ORANGE, ORANGE, ORANGE]
ax.bar(lbl, late.avg_review, color=cols, width=0.6)
for x, (v, n) in enumerate(zip(late.avg_review, late.orders)):
    ax.text(x, v + 0.07, f"{v:.2f}★", ha="center", fontsize=10, color=INK, fontweight="bold")
    ax.text(x, 0.12, f"n={n:,}", ha="center", fontsize=8.5, color="#fcfcfb")
ax.set_ylim(0, 5)
ax.set_ylabel("Average review score (1–5)")
ax.set_title("A late delivery cuts the average review from 4.3 to under 2 stars")
ax.grid(axis="x", visible=False)
save(fig, "04_late_vs_review.png")

# ---------------------------------------------------------------- 5. late rate by month
ok = orders[orders.is_complete_month & orders.delivery_data_ok]
lr = ok.groupby("order_month").agg(late=("is_late", "mean"), n=("is_late", "size")).reset_index()
fig, ax = plt.subplots(figsize=(10, 4.5))
ax.plot(lr.order_month, lr.late * 100, color=BLUE, lw=2, marker="o", ms=4)
for m in ["2017-11-01", "2018-03-01"]:
    r = lr[lr.order_month == m].iloc[0]
    ax.plot(r.order_month, r.late * 100, "o", ms=9, color=ORANGE, mec="#fcfcfb", mew=2)
    ax.annotate(f"{r.order_month:%b %Y}: {r.late*100:.0f}%", (r.order_month, r.late * 100),
                xytext=(8, 4), textcoords="offset points", fontsize=9)
ax.axhline(ok.is_late.mean() * 100, color=INK2, lw=1, ls="--")
ax.text(lr.order_month.iloc[0], ok.is_late.mean() * 100 + 0.5, f"average {ok.is_late.mean()*100:.1f}%", fontsize=9, color=INK2)
ax.yaxis.set_major_formatter(mtick.PercentFormatter(decimals=0))
ax.yaxis.set_major_locator(mtick.MultipleLocator(4))
ax.set_ylim(0, None)
ax.set_title("Late deliveries spiked in Nov 2017 (Black Friday) and in Feb–Mar 2018")
ax.set_ylabel("Share of orders delivered late")
save(fig, "05_late_rate_by_month.png", "Month of purchase. Source: Olist dataset, Jan 2017 – Aug 2018.")

# ---------------------------------------------------------------- 6. order value distribution
fig, ax = plt.subplots(figsize=(9, 4.5))
bins = np.logspace(np.log10(5), np.log10(delivered.gmv.max()), 60)
ax.hist(delivered.gmv.dropna(), bins=bins, color=BLUE, edgecolor="#fcfcfb", linewidth=0.6)
ax.set_xscale("log")
ax.xaxis.set_major_formatter(mtick.FuncFormatter(lambda v, _: f"{v:,.0f}"))
med, mean = delivered.gmv.median(), delivered.gmv.mean()
for v, lab, c, ha, k in [(med, f"median {med:.0f} BRL ", INK, "right", 0.97), (mean, f" mean {mean:.0f} BRL", ORANGE, "left", 1.03)]:
    ax.axvline(v, color=c, lw=1.5, ls="--")
    ax.text(v * k, ax.get_ylim()[1] * 0.95, lab, color=c, fontsize=9, ha=ha)
ax.set_title("Order values are right-skewed: most orders are small, a few are large")
ax.set_xlabel("Order value incl. freight (BRL, log scale)")
ax.set_ylabel("Orders")
save(fig, "06_order_value_distribution.png")

# ---------------------------------------------------------------- 7. day x hour heatmap
days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
grid = heat.pivot(index="iso_dow", columns="hour", values="orders").reindex(range(1, 8)).fillna(0)
fig, ax = plt.subplots(figsize=(11, 3.8))
im = ax.imshow(grid, aspect="auto", cmap="Blues")
ax.set_yticks(range(7), days)
ax.set_xticks(range(0, 24, 2), [f"{h}h" for h in range(0, 24, 2)])
ax.grid(False)
cb = fig.colorbar(im, ax=ax, pad=0.01)
cb.set_label("Orders", color=INK2)
ax.set_title("Orders run from 10h to 22h, Monday is busiest, and weekends are ~25% quieter")
save(fig, "07_orders_heatmap.png", "Purchase time (local, Brazil). Source: Olist dataset, Jan 2017 – Aug 2018.")

# ---------------------------------------------------------------- 8. payment mix
p = pay.iloc[::-1]
fig, ax = plt.subplots(figsize=(9, 3.6))
ax.barh(p.main_payment_type.str.replace("_", " "), p.share_pct, color=BLUE, height=0.6)
for y, (s, inst, aov) in enumerate(zip(p.share_pct, p.avg_installments, p.avg_order_value)):
    ax.text(s + 0.8, y, f"{s:.1f}%  · avg {inst:.1f} instalments · AOV {aov:.0f} BRL", va="center", fontsize=9)
ax.set_xlim(0, 115)
ax.xaxis.set_major_formatter(mtick.PercentFormatter(decimals=0))
ax.grid(axis="y", visible=False)
ax.set_title("Three orders in four are paid by credit card, often in instalments")
save(fig, "08_payment_mix.png")
