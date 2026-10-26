"""Generate the synthetic data for the acquisition case study.

A language learning app with a free tier and a monthly subscription. People land on the signup page
from paid search, paid social, affiliates, organic search or invites, go through a 5-step signup,
and some of them pay. Data is "as of" 2026-10-25: payments after that date are not published,
but the generator also writes each member's true 24-month value so projections can be checked.

Run from the repository root: python data/generate.py
"""
from pathlib import Path

import numpy as np
import pandas as pd

rng = np.random.default_rng(23)
OUT = Path("data/raw")
OUT.mkdir(parents=True, exist_ok=True)

AS_OF = pd.Timestamp("2026-10-25")
START = pd.Timestamp("2022-01-01")
PRICE = 12.99
days = pd.date_range(START, AS_OF, freq="D")
t = np.arange(len(days))
in_2026 = np.clip((days - pd.Timestamp("2026-01-01")).days.to_numpy() / 120, 0, 1)

# ---- Channels: volume, cost and how members pay -----------------------------------------------
# p_first: pays in the first days; late: monthly chance a free member starts paying; keep: monthly retention of payers
CHANNELS = {
    #                 starts/day             cost/start  finish  p_first late   keep
    "paid_search":   (lambda: 26 + 0 * t,         9.0,  0.55,   0.20, 0.015, 0.90),
    "paid_social":   (lambda: 14 + 30 * in_2026,  6.0,  0.40,   0.28, 0.005, 0.72),  # scaled up in 2026
    "affiliate":     (lambda: 12 + 0 * t,         8.0,  0.50,   0.10, 0.030, 0.93),
    "organic_search": (lambda: 20 + 0 * t,        0.0,  0.60,   0.15, 0.020, 0.90),
    "referral":      (lambda: 8 + 0 * t,          0.0,  0.65,   0.22, 0.020, 0.92),
}

# Messy UTM values, the way they arrive from ad platforms and partners
UTM = {
    "paid_search": [("google", "cpc", 0.55), ("Google", "cpc", 0.20), ("google ", "CPC", 0.10), ("bing", "cpc", 0.15)],
    "paid_social": [("facebook", "paid_social", 0.35), ("Facebook", "paid", 0.20), ("fb", "paid_social", 0.15),
                    ("instagram", "paid_social", 0.20), ("ig", "Paid_Social", 0.10)],
    "affiliate": [("lingopartners", "affiliate", 0.5), ("studyhub", "affiliate", 0.3), ("StudyHub", "Affiliate", 0.2)],
    "organic_search": [(None, None, 1.0)],
    "referral": [("invite", "referral", 0.9), ("Invite", "referral", 0.1)],
}
CAMPAIGNS = {"paid_search": ["brand", "generic_spanish", "generic_english"], "paid_social": ["spring_promo", "always_on", "video_lessons"],
             "affiliate": ["partner_feed"], "organic_search": [None], "referral": ["invite_a_friend"]}
PLATFORM = {"paid_search": "google_ads", "paid_social": "meta_ads", "affiliate": "partner_network"}
STEPS = ["email", "profile", "level_test", "goal", "plan_choice"]  # finishing plan_choice completes signup
# Where non-finishers stop, by channel (shares over the 5 steps)
STOP = {"paid_search": [0.35, 0.20, 0.25, 0.10, 0.10], "paid_social": [0.25, 0.15, 0.45, 0.10, 0.05],
        "affiliate": [0.30, 0.20, 0.30, 0.10, 0.10], "organic_search": [0.35, 0.25, 0.20, 0.10, 0.10],
        "referral": [0.30, 0.25, 0.20, 0.15, 0.10]}

starts, spend, members, payments, truth = [], [], [], [], []
next_id = 1

for ch, (vol, cost, finish, p_first, late, keep) in CHANNELS.items():
    n_day = rng.poisson(vol())
    n = n_day.sum()
    day_idx = np.repeat(t, n_day)
    started_at = days[day_idx] + pd.to_timedelta(rng.integers(0, 86400, n), unit="s")
    vid = np.arange(next_id, next_id + n)
    next_id += n

    # Landing URL with UTM parameters
    opts = UTM[ch]
    pick = rng.choice(len(opts), n, p=[o[2] for o in opts])
    camp = rng.choice(CAMPAIGNS[ch], n)
    urls = []
    for k, c in zip(pick, camp):
        src, med, _ = opts[k]
        if src is None:
            urls.append("https://app.example.com/signup")
        else:
            urls.append(f"https://app.example.com/signup?utm_source={src.replace(' ', '%20')}&utm_medium={med}&utm_campaign={c}")

    # Signup: finish or stop at a step. Finishers take a while, some finish days later
    finishes = rng.random(n) < finish
    delay_days = np.where(finishes, rng.lognormal(-0.6, 1.7, n), np.nan)
    delay_days = np.where(delay_days > 30, np.nan, delay_days)  # after 30 days the attempt is abandoned
    finishes &= ~np.isnan(delay_days)
    finished_at = started_at + pd.to_timedelta(np.nan_to_num(delay_days) * 86400, unit="s")
    finished_at = pd.DatetimeIndex(np.where(finishes & (finished_at < AS_OF + pd.Timedelta(days=1)), finished_at, pd.NaT)).floor("s")
    finishes = ~finished_at.isna()
    last_step = np.where(finishes, len(STEPS) - 1, rng.choice(len(STEPS), n, p=STOP[ch]))
    starts.append(pd.DataFrame({
        "visitor_id": [f"v{x}" for x in vid], "started_at": started_at, "landing_url": urls,
        "last_step_reached": np.array(STEPS)[last_step], "finished_signup_at": finished_at,
    }))

    # Spend: daily, proportional to the starts it bought, with noise
    if cost > 0:
        spend.append(pd.DataFrame({"date": days.date, "ad_platform": PLATFORM[ch],
                                   "spend_usd": np.round(n_day * cost * rng.normal(1, 0.08, len(days)), 2)}))

    # Members and their payments over 24 months (monthly billing from registration)
    reg = finished_at[finishes]
    m = len(reg)
    mid = [f"u{x}" for x in vid[finishes]]
    paying = np.zeros((m, 24), dtype=bool)
    paying[:, 0] = rng.random(m) < p_first
    for k in range(1, 24):
        stay = paying[:, k - 1] & (rng.random(m) < keep)
        start = ~paying[:, k - 1] & (rng.random(m) < late)
        paying[:, k] = stay | start
    first_pay_lag = rng.integers(0, 6, m)  # first payment a few days after signup
    members.append(pd.DataFrame({"member_id": mid, "visitor_id": [f"v{x}" for x in vid[finishes]], "registered_at": reg}))
    truth.append(pd.DataFrame({"member_id": mid, "true_value_24m": paying.sum(axis=1) * PRICE}))
    ii, kk = np.nonzero(paying)
    paid_on = reg[ii] + pd.to_timedelta(kk * 30 + first_pay_lag[ii], unit="D")
    keep_rows = paid_on <= AS_OF
    payments.append(pd.DataFrame({"member_id": np.array(mid)[ii][keep_rows], "paid_on": paid_on[keep_rows].date,
                                  "amount_usd": PRICE}))

pd.concat(starts).sort_values("started_at").to_csv(OUT / "signup_starts.csv", index=False)
pd.concat(members).to_csv(OUT / "members.csv", index=False)
pd.concat(payments).to_csv(OUT / "payments.csv", index=False)
pd.concat(spend).to_csv(OUT / "ad_spend.csv", index=False)
# Not something a real company has: each member's full 24-month value, used only to check projections
pd.concat(truth).to_csv(OUT / "truth_member_value_24m.csv", index=False)

n_starts = sum(len(s) for s in starts)
n_members = sum(len(s) for s in members)
print(f"starts: {n_starts:,}  members: {n_members:,}  payments: {sum(len(p) for p in payments):,}")
