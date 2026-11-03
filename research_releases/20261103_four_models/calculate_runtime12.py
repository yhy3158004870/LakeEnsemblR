"""Planning estimates only: no model runs and no production-file changes."""
from pathlib import Path
import csv
from collections import defaultdict

HERE = Path(__file__).resolve().parent
SOURCE = Path('/workspace/recovery/analysis-new-zips-20261102/estimate_4510360d2a89/med.csv')
MODELS = ('FLake', 'GLM', 'GOTM', 'Simstrat')
SELECTED = ('akesaiqin', 'namco')
rows = list(csv.DictReader(SOURCE.open(newline='')))
by_lake = defaultdict(float)
by_model = defaultdict(float)
for row in rows:
    if row['model'] in MODELS:
        value = float(row['seconds'])
        by_lake[row['name']] += value
        if row['name'] not in SELECTED:
            by_model[row['model']] += value
assert len(by_lake) == 69
s_two = sum(by_lake[name] for name in SELECTED)
s_remaining = sum(v for k, v in by_lake.items() if k not in SELECTED)
actual_two_seconds = (6 * 60 + 45) * 60
two_analytic_seconds = (500 / 10 + 1) * s_two
factor = actual_two_seconds / two_analytic_seconds
estimates = []
for n in (500, 2000):
    for cores in (10, 12):
        base = (n / cores + 1) * s_remaining
        estimates.append(dict(
            remaining_lakes=67, models=4, lhc_per_model=n, workers=cores,
            summed_case_median_seconds=s_remaining,
            analytical_days=base / 86400,
            analytical_plus30pct_days=base * 1.3 / 86400,
            two_lake_empirical_factor=factor,
            empirically_scaled_days=base * factor / 86400,
            note='Planning estimate; new two-lake phase times not supplied; excludes delta/S1 bootstrap',
        ))
with (HERE/'runtime_remaining67_n10_n12.csv').open('w', newline='', encoding='utf-8-sig') as f:
    writer = csv.DictWriter(f, estimates[0].keys()); writer.writeheader(); writer.writerows(estimates)
with (HERE/'runtime_model_work_remaining67.csv').open('w', newline='', encoding='utf-8-sig') as f:
    writer = csv.DictWriter(f, ['model','summed_case_median_seconds','share_of_four_model_work'])
    writer.writeheader()
    writer.writerows(dict(model=m, summed_case_median_seconds=by_model[m],
                         share_of_four_model_work=by_model[m]/s_remaining) for m in MODELS)
print('Sum of old single-case medians:', s_remaining)
print('Two-lake observed/analytic factor:', factor)
for row in estimates:
    print(row)
