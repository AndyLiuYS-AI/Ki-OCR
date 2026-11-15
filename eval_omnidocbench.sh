#!/usr/bin/env bash
# Run from the Ki-OCR repository; start the inference service first.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"

export DATA="${DATA:-$PWD/datasets/OmniDocBench}"
export API_URL="${API_URL:-http://127.0.0.1:18000/v1/parse/sync}"
export RUN="$(mktemp -d "$PWD/omnidocbench_eval_XXXXXX")"
mkdir -p "$RUN/markdown" "$RUN/result"
printf '[RUN] %s\n' "$RUN"

python - <<'PY'
import json
import os
import shutil
import subprocess
import time
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor

data = Path(os.environ['DATA']).resolve()
run = Path(os.environ['RUN'])
gt = data / 'OmniDocBench.json'
pages = json.loads(gt.read_text(encoding='utf-8'))
assert len(pages) == 1651, f'Expected 1651 pages, got {len(pages)}'
shutil.copyfile(gt, run / 'gt_full.json')
names = [Path(p['page_info']['image_path']).name for p in pages]
assert len({Path(n).stem for n in names}) == len(names), 'Duplicate page names'
assert all((data / 'images' / n).is_file() for n in names), 'Missing source images'


def nonempty(path):
    try:
        return path.is_file() and bool(path.read_text(encoding='utf-8').strip())
    except (OSError, UnicodeError):
        return False


# Reuse only valid, nonempty predictions from the same model and data.
resume_from = os.environ.get('RESUME_FROM')
if resume_from:
    source = Path(resume_from).resolve() / 'markdown'
    assert source.is_dir(), f'Missing directory: {source}'
    previous_gt = source.parent / 'gt_full.json'
    if previous_gt.is_file():
        assert json.loads(previous_gt.read_text(encoding='utf-8')) == pages, 'Resume dataset differs from current GT'
    copied = 0
    for name in names:
        md_name = Path(name).stem + '.md'
        if nonempty(source / md_name):
            shutil.copyfile(source / md_name, run / 'markdown' / md_name)
            copied += 1
    print(f'[RESUME] Copied {copied}/1651 predictions', flush=True)


def infer(name):
    image = data / 'images' / name
    out = run / 'markdown' / (Path(name).stem + '.md')
    if nonempty(out):
        return name, 'SKIP'

    # curl -F requires quoting paths containing commas and semicolons.
    escaped = str(image).replace('\\', '\\\\').replace('"', '\\"')
    upload = f'file=@"{escaped}"'
    for attempt in range(3):
        try:
            raw = subprocess.check_output([
                'curl', '--noproxy', '*', '-sS', '--fail-with-body',
                '--max-time', '900', os.environ['API_URL'],
                '-F', upload, '-F', 'api_key=dummy',
                '-F', 'output_formats=markdown', '-F', 'output_formats=json',
            ])
            result = json.loads(raw)
            if result['code'] != 0:
                raise RuntimeError(result)
            md = result['data']['result']['outputs']['markdown']
            if not isinstance(md, str):
                raise RuntimeError('Invalid Markdown response')

            # Preserve genuine model output, including empty Markdown.
            tmp = out.with_suffix('.md.tmp')
            tmp.write_text(md, encoding='utf-8')
            tmp.replace(out)
            return name, 'OK' if md.strip() else 'EMPTY'
        except Exception as exc:
            error = str(exc)
            if attempt < 2:
                time.sleep(2)
    return name, 'FAILED: ' + error


failed = []
with ThreadPoolExecutor(max_workers=4) as pool:
    for i, (name, status) in enumerate(pool.map(infer, names), 1):
        print(f'[{i}/{len(names)}] {name}: {status}', flush=True)
        if status.startswith('FAILED'):
            failed.append({'image': name, 'error': status})

(run / 'failed_pages.json').write_text(
    json.dumps(failed, indent=2, ensure_ascii=False), encoding='utf-8'
)

expected = {Path(name).stem + '.md' for name in names}
actual = {p.name for p in (run / 'markdown').glob('*.md') if p.is_file()}
missing = sorted(expected - actual)
extras = sorted(actual - expected)
empty = []
invalid = []
for name in sorted(expected & actual):
    try:
        if not (run / 'markdown' / name).read_text(encoding='utf-8').strip():
            empty.append(name)
    except (OSError, UnicodeError):
        invalid.append(name)

audit = {
    'expected': len(expected), 'generated': len(actual),
    'failed': len(failed), 'missing': missing, 'empty': empty,
    'invalid': invalid, 'extras': extras,
}
(run / 'inference_audit.json').write_text(
    json.dumps(audit, indent=2, ensure_ascii=False), encoding='utf-8'
)
print(f'[CHECK] Expected: {len(expected)}, Generated: {len(actual)}, '
      f'Failed: {len(failed)}, Missing: {len(missing)}, Empty: {len(empty)}, '
      f'Invalid: {len(invalid)}, Extras: {len(extras)}', flush=True)
for name in empty:
    print(f'[EMPTY_PREDICTION] {name}', flush=True)
if failed or missing or invalid or extras:
    raise RuntimeError(f'Incomplete inference; see {run}/inference_audit.json')
print('[SUCCESS] 1651/1651 Markdown files generated', flush=True)
PY

cat > "$RUN/end2end.yaml" <<'YAML'
end2end_eval:
  metrics:
    text_block:
      metric: [Edit_dist]
    display_formula:
      metric: [Edit_dist, CDM]
      cdm_workers: 8
    table:
      metric: [TEDS, Edit_dist]
      teds_workers: 8
    reading_order:
      metric: [Edit_dist]
  dataset:
    dataset_name: end2end_dataset
    ground_truth:
      data_path: /workspace/full_eval/gt_full.json
    prediction:
      data_path: /workspace/full_eval/markdown
    match_method: quick_match
    match_workers: 8
YAML

docker run --rm --entrypoint bash \
  -v "$RUN:/workspace/full_eval:ro" \
  -v "$RUN/result:/workspace/result" \
  ghcr.io/zeng-weijun/omnidocbench-eval:repro-ubuntu2204 \
  -lc 'cd /workspace && python pdf_validation.py --config /workspace/full_eval/end2end.yaml'

python - <<'PY'
import json
import os
from pathlib import Path

run = Path(os.environ['RUN'])
files = list((run / 'result').glob('*_metric_result.json'))
assert len(files) == 1, f'Expected one official metric result, got {files}'
r = json.loads(files[0].read_text(encoding='utf-8'))
text = r['text_block']['all']['Edit_dist']['ALL_page_avg']
cdm = r['display_formula']['page']['CDM']['ALL'] * 100
teds = r['table']['page']['TEDS']['ALL'] * 100
teds_s = r['table']['page']['TEDS_structure_only']['ALL'] * 100
order = r['reading_order']['all']['Edit_dist']['ALL_page_avg']
summary = {
    'Overall': ((1 - text) * 100 + cdm + teds) / 3,
    'Text Edit': text, 'Formula CDM': cdm,
    'Table TEDS': teds, 'Table TEDS-S': teds_s, 'Reading Order Edit': order,
}
(run / 'summary.json').write_text(json.dumps(summary, indent=2), encoding='utf-8')
print(json.dumps(summary, indent=2))
print(f'Results: {run}')
PY
