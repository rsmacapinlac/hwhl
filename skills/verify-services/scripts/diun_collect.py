#!/usr/bin/env python3
"""
Collect Diun image-list data from all homelab hosts via Ansible ad-hoc.
Writes tmp/{REPO}.diun_cache.json keyed by normalised image ref so that
registry_version_report.py can use it as the primary version source and
avoid Docker Hub rate limits.

Run from the repository root:
    python3 .claude/skills/verify-services/scripts/diun_collect.py
"""

import json, re, subprocess, sys
from pathlib import Path

REPO = 'hwhl_vancouver'
INVENTORY = '../homelab_config/ansible/inventory/'
# All groups that should have a running diun container
DIUN_GROUPS = 'diun:containers'
ANSIBLE_DIR = 'ansible'


def normalize_ref(ref):
    """Return (registry, repo, tag) in canonical form, matching registry_version_report.py."""
    ref = (ref or '').strip()
    ref = re.sub(r'\$\{[^}:]+:-([^}]+)\}', r'\1', ref)
    ref = ref.split('@', 1)[0]
    if not ref:
        return None
    parts = ref.split('/')
    if len(parts) > 1 and ('.' in parts[0] or ':' in parts[0] or parts[0] == 'localhost'):
        registry = parts[0]
        rest = '/'.join(parts[1:])
        if registry == 'docker.io':
            registry = 'registry-1.docker.io'
    else:
        registry = 'registry-1.docker.io'
        rest = ref
    last = rest.rsplit('/', 1)[-1]
    if ':' in last:
        repo, tag = rest.rsplit(':', 1)
    else:
        repo, tag = rest, 'latest'
    if registry == 'registry-1.docker.io' and '/' not in repo:
        repo = 'library/' + repo
    return registry, repo, tag


def cache_key(registry, repo, tag):
    return f'{registry}/{repo}:{tag}'


def version_from_labels(labels, fallback_tag):
    labels = labels or {}
    keys = [
        'org.opencontainers.image.version',
        'org.label-schema.version',
        'version',
        'VERSION',
        'build_version',
        'org.opencontainers.image.ref.name',
    ]
    for k in keys:
        v = labels.get(k)
        if v:
            s = str(v)
            if k == 'build_version':
                m = re.search(r'version:-\s*([^\s]+)', s, re.I)
                if m:
                    return m.group(1)
            return s
    return fallback_tag


def _parse_host_block(host, text, cache):
    """Parse one host's JSON block and merge into cache (first host wins per image)."""
    start = text.find('{')
    if start == -1:
        return
    try:
        data = json.loads(text[start:])
    except json.JSONDecodeError as exc:
        print(f'  warning: JSON parse error from {host}: {exc}', file=sys.stderr)
        return

    for entry in data.get('images', []):
        name = entry.get('name', '')
        latest = entry.get('latest') or {}
        tag = latest.get('tag', 'latest')
        norm = normalize_ref(f'{name}:{tag}')
        if not norm:
            continue
        key = cache_key(*norm)
        if key in cache:
            continue  # deduplicate — first host wins
        labels = latest.get('labels') or {}
        cache[key] = {
            'ok': True,
            'version': version_from_labels(labels, norm[2]),
            'digest': latest.get('digest', ''),
            'created': latest.get('created', ''),
            'labels': labels,
            'registry': norm[0],
            'repo': norm[1],
            'tag': norm[2],
            'source': f'diun@{host}',
        }


def collect():
    print(f'Running: ansible {DIUN_GROUPS} docker exec diun diun image list --raw', file=sys.stderr)
    result = subprocess.run(
        [
            'ansible', '-i', INVENTORY, DIUN_GROUPS,
            '-m', 'shell',
            '-a', 'docker exec diun diun image list --raw',
            '-b',
        ],
        capture_output=True,
        text=True,
        cwd=ANSIBLE_DIR,
    )

    cache = {}
    cur_host = None
    buf = []

    for line in result.stdout.splitlines():
        m = re.match(r'^([^ |]+) \| (?:CHANGED|SUCCESS) \| rc=0 >>', line)
        if m:
            if cur_host and buf:
                _parse_host_block(cur_host, '\n'.join(buf), cache)
            cur_host = m.group(1)
            buf = []
            continue
        # Failure lines — skip host's buffer
        if re.match(r'^([^ |]+) \| (?:FAILED|UNREACHABLE)', line):
            if cur_host and buf:
                _parse_host_block(cur_host, '\n'.join(buf), cache)
            cur_host = None
            buf = []
            continue
        if cur_host is not None:
            buf.append(line)

    if cur_host and buf:
        _parse_host_block(cur_host, '\n'.join(buf), cache)

    # Print any stderr warnings
    for line in result.stderr.splitlines():
        if line.strip() and not line.startswith('[WARNING]'):
            print(f'  ansible: {line}', file=sys.stderr)

    return cache


if __name__ == '__main__':
    cache = collect()
    out = Path(f'tmp/{REPO}.diun_cache.json')
    out.write_text(json.dumps(cache, indent=2))
    print(f'Collected {len(cache)} unique images from Diun across all hosts.', file=sys.stderr)
    print(f'Wrote {out}', file=sys.stderr)
