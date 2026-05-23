#!/usr/bin/env python3
"""
Produce a service actual-vs-expected version report.

Primary version source: tmp/{REPO}.diun_cache.json written by diun_collect.py.
Fallback: direct registry manifest queries (may hit Docker Hub rate limits).

Run from the repository root after diun_collect.py and the docker inspect
collection steps have completed:
    python3 .claude/skills/verify-services/scripts/diun_collect.py
    python3 .claude/skills/verify-services/scripts/registry_version_report.py
"""
import json, re, urllib.request, urllib.parse, urllib.error
from pathlib import Path

REPO='hwhl_vancouver'

def normalize_ref(ref):
    ref=(ref or '').strip()
    ref=re.sub(r'\$\{[^}:]+:-([^}]+)\}', r'\1', ref)
    ref=ref.split('@',1)[0]
    if not ref: return None
    parts=ref.split('/')
    # A registry is only present if there is a slash before the image name.
    # Examples without registry: traefik:latest, postgres:16-alpine.
    if len(parts) > 1 and ('.' in parts[0] or ':' in parts[0] or parts[0]=='localhost'):
        registry=parts[0]; rest='/'.join(parts[1:])
        if registry == 'docker.io':
            registry = 'registry-1.docker.io'
    else:
        registry='registry-1.docker.io'; rest=ref
    last=rest.rsplit('/',1)[-1]
    if ':' in last:
        repo, tag = rest.rsplit(':',1)
    else:
        repo, tag = rest, 'latest'
    if registry=='registry-1.docker.io' and '/' not in repo:
        repo='library/'+repo
    return registry, repo, tag

def req(url, headers=None):
    r=urllib.request.Request(url, headers=headers or {})
    with urllib.request.urlopen(r, timeout=30) as resp:
        return resp.status, dict(resp.headers), resp.read()

def bearer_for(www, registry, repo):
    # Bearer realm="...",service="...",scope="..."
    m=re.match(r'Bearer\s+(.*)', www or '', re.I)
    if not m: return None
    params={}
    for k,v in re.findall(r'(\w+)="([^"]*)"', m.group(1)):
        params[k]=v
    realm=params.get('realm')
    if not realm: return None
    q={}
    if params.get('service'): q['service']=params['service']
    q['scope']=params.get('scope') or f'repository:{repo}:pull'
    url=realm+'?'+urllib.parse.urlencode(q)
    try:
        _,_,body=req(url)
        data=json.loads(body)
        return data.get('token') or data.get('access_token')
    except Exception:
        return None

def registry_get(registry, path, repo):
    url=f'https://{registry}/v2/{path}'
    headers={'Accept': 'application/vnd.docker.distribution.manifest.v2+json, application/vnd.docker.distribution.manifest.list.v2+json, application/vnd.oci.image.manifest.v1+json, application/vnd.oci.image.index.v1+json, application/vnd.docker.container.image.v1+json'}
    try:
        return req(url, headers)
    except urllib.error.HTTPError as e:
        if e.code==401:
            token=bearer_for(e.headers.get('WWW-Authenticate'), registry, repo)
            if token:
                headers['Authorization']='Bearer '+token
                return req(url, headers)
        raise

def version_from_labels(labels, fallback_tag):
    labels=labels or {}
    keys=['org.opencontainers.image.version','org.label-schema.version','version','VERSION','build_version','org.opencontainers.image.ref.name','org.opencontainers.image.revision','vcs-ref','git_commit']
    for k in keys:
        v=labels.get(k)
        if v:
            s=str(v)
            if k=='build_version':
                m=re.search(r'version:-\s*([^\s]+)', s, re.I)
                if m: return m.group(1)
            if k in ('org.opencontainers.image.revision','vcs-ref') and len(s)>12:
                return s[:12]
            return s
    return fallback_tag

def _diun_cache_key(registry, repo, tag):
    return f'{registry}/{repo}:{tag}'

def remote_info(ref):
    norm=normalize_ref(ref)
    if not norm: return {'ok':False,'version':'unknown','error':'empty ref'}
    registry, repo, tag=norm

    # Prefer Diun cache — avoids registry rate limits and uses already-fetched data
    key=_diun_cache_key(registry, repo, tag)
    if key in diun_cache:
        return diun_cache[key]

    # Fallback: query the registry directly
    try:
        _,h,b=registry_get(registry, f'{repo}/manifests/{tag}', repo)
        man=json.loads(b)
        media=man.get('mediaType','')
        if 'manifest.list' in media or 'image.index' in media or 'manifests' in man:
            chosen=None
            for m in man.get('manifests',[]):
                p=m.get('platform',{})
                if p.get('os')=='linux' and p.get('architecture')=='amd64':
                    chosen=m; break
            chosen=chosen or (man.get('manifests') or [None])[0]
            if not chosen: raise RuntimeError('no manifest in index')
            digest=chosen['digest']
            _,h,b=registry_get(registry, f'{repo}/manifests/{digest}', repo)
            man=json.loads(b)
        config_digest=man.get('config',{}).get('digest')
        if not config_digest: raise RuntimeError('no config digest')
        _,h,b=registry_get(registry, f'{repo}/blobs/{config_digest}', repo)
        cfg=json.loads(b)
        labels=cfg.get('config',{}).get('Labels') or {}
        return {'ok':True,'version':version_from_labels(labels, tag),'labels':labels,'registry':registry,'repo':repo,'tag':tag,'config_digest':config_digest,'source':'registry'}
    except Exception as e:
        return {'ok':False,'version':tag,'error':str(e),'registry':registry,'repo':repo,'tag':tag,'source':'registry-failed'}

def parse_actual():
    actual={}; cur=None
    for line in Path(f'tmp/{REPO}.docker_inspect.txt').read_text().splitlines():
        m=re.match(r'([^ |]+) \| CHANGED \| rc=0 >>', line)
        if m: cur=m.group(1); actual[cur]={}; continue
        if cur and line.startswith('/'):
            parts=line.split('|',5)
            if len(parts)==6:
                name=parts[0].lstrip('/'); img=parts[1]; state=parts[3]; health=parts[4]
                try: labels=json.loads(parts[5])
                except Exception: labels={}
                actual[cur][name]={'image':img,'state':state,'health':health,'version':version_from_labels(labels, normalize_ref(img)[2] if normalize_ref(img) else 'unknown')}
    return actual

# Load Diun cache (written by diun_collect.py) as primary version source
_diun_cache_path=Path(f'tmp/{REPO}.diun_cache.json')
diun_cache=json.loads(_diun_cache_path.read_text()) if _diun_cache_path.exists() else {}
if diun_cache:
    print(f'Using Diun cache ({len(diun_cache)} images) as primary version source.', flush=True)
else:
    print('No Diun cache found — falling back to registry queries (may hit rate limits).', flush=True)
    print('Run diun_collect.py first to populate the cache.', flush=True)

expected=json.load(open(f'tmp/{REPO}.expected_map.json'))
actual=parse_actual()
unique=sorted({img for cmap in expected.values() for img in cmap.values() if img and 'unknown' not in img})
web={img:remote_info(img) for img in unique}
Path(f'tmp/{REPO}.web_expected_versions.json').write_text(json.dumps(web,indent=2))

lines=[f'# Service actual vs web-expected version report: {REPO}','', 'Format: `<host>: <service> (<actual version>; <state/health>) -> <expected image tag> (<web expected version>)`','', 'Expected versions are fetched from the remote container registry config/OCI labels for the configured image tag where available. If the registry/image has no version label or cannot be queried, this falls back to tag and records the limitation.','']
for h in sorted(expected):
    lines.append(f'## {h}')
    act=actual.get(h,{})
    for svc,img in sorted(expected[h].items()):
        info=web.get(img) or remote_info(img)
        expver=info.get('version','unknown')
        src=info.get('source','')
        if not info.get('ok'):
            suffix=f' [registry fallback failed: {info.get("error","unknown")}]'
        elif src and src.startswith('diun@'):
            suffix=''  # Diun data is reliable; no annotation needed
        elif src=='registry':
            suffix=' [registry fallback]'
        else:
            suffix=''
        if svc in act:
            a=act[svc]; sh=a['state'] if a['health']=='no-health' else f"{a['state']}/{a['health']}"
            lines.append(f'- {h}: {svc} ({a["version"]}; {sh}) -> {img or "unknown"} ({expver}){suffix}')
        else:
            lines.append(f'- {h}: {svc} (missing) -> {img or "unknown"} ({expver}){suffix}')
    extras=sorted(set(act)-set(expected[h]))
    if extras:
        lines += ['', '  Unexpected/stale containers:']
        for svc in extras:
            a=act[svc]; sh=a['state'] if a['health']=='no-health' else f"{a['state']}/{a['health']}"
            lines.append(f'  - {h}: {svc} ({a["version"]}; {sh}) -> unexpected')
    lines.append('')
report = '\n'.join(lines)
Path(f'tmp/{REPO}.web-expected-version-report.md').write_text(report)
print(report)
print(f'\nWrote tmp/{REPO}.web-expected-version-report.md')
