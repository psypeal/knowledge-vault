#!/bin/bash
# knowledge-vault: Detect available research MCP servers.
# Checks settings.json permissions and local .{claude|codex}.json mcpServers.
# Output: JSON listing detected and available-but-not-configured servers.

# Resolve plugin root so we can probe the vendored PageIndex install state.
PLUGIN_DIR="$(cd "$(dirname "$0")/.." && pwd)"
export PLUGIN_DIR

python3 -c "
import json, os, shutil, subprocess

detected = []
available = []
plugin_dir = os.environ.get('PLUGIN_DIR', '')
pageindex_dir = os.path.join(plugin_dir, 'vendor', 'PageIndex') if plugin_dir else ''

# Check settings.json for allowed MCP tools (built-in AI-hosted research tools)
for settings_path in [
    os.path.expanduser('~/.claude/settings.json'),
    os.path.expanduser('~/.codex/settings.json')
]:
    if os.path.exists(settings_path):
        with open(settings_path) as f:
            settings = json.load(f)
        allowed = settings.get('permissions', {}).get('allow', [])

        # PubMed (built-in)
        if any('PubMed' in str(p) for p in allowed):
            detected.append({
                'id': 'pubmed-builtin',
                'name': 'PubMed (AI-hosted)',
                'type': 'builtin',
                'enabled': True,
                'tools': [p for p in allowed if 'PubMed' in str(p)],
                'add_command': None
            })

        # Scholar Gateway (built-in)
        if any('Scholar_Gateway' in str(p) or 'scholar-gateway' in str(p) for p in allowed):
            detected.append({
                'id': 'scholar-gateway',
                'name': 'Scholar Gateway (AI-hosted)',
                'type': 'builtin',
                'enabled': True,
                'tools': [p for p in allowed if 'Scholar' in str(p) or 'scholar' in str(p)],
                'add_command': None
            })

# Check local JSON config for configured MCP servers
for mcp_json_path in ['.claude.json', os.path.expanduser('~/.claude.json'), '.codex.json', os.path.expanduser('~/.codex.json')]:
    if os.path.exists(mcp_json_path):
        with open(mcp_json_path) as f:
            cj = json.load(f)
        servers = cj.get('mcpServers', {})
        for name, config in servers.items():
            if any(kw in name.lower() for kw in ['arxiv', 'pubmed', 'scholar', 'consensus', 'paper-search', 'zotero', 'scihub', 'sci-hub']):
                detected.append({
                    'id': name,
                    'name': name,
                    'type': 'stdio',
                    'enabled': True,
                    'tools': [f'mcp__{name}__*'],
                    'add_command': None
                })

# Check for Unpaywall (not an MCP; just an email env var)
if os.environ.get('UNPAYWALL_EMAIL'):
    detected.append({
        'id': 'unpaywall',
        'name': 'Unpaywall',
        'type': 'env-api',
        'enabled': True,
        'tools': ['(HTTP API; enables /knowledge-vault:enrich-references)'],
        'add_command': None
    })

# Check for PageIndex (bundled python tool; not an MCP)
def _pageindex_status():
    if not pageindex_dir or not os.path.isfile(os.path.join(pageindex_dir, 'run_pageindex.py')):
        return None  # not vendored
    has_python = shutil.which('python3') is not None
    has_deps = False
    if has_python:
        try:
            r = subprocess.run(
                ['python3', '-c', 'import litellm, pymupdf, dotenv, yaml'],
                capture_output=True
            )
            has_deps = (r.returncode == 0)
        except Exception:
            has_deps = False
    has_key = bool(os.environ.get('ANTHROPIC_API_KEY')) or os.path.isfile(os.path.join(pageindex_dir, '.env'))
    return {'python': has_python, 'deps': has_deps, 'key': has_key}

pi = _pageindex_status()
if pi is not None:
    if pi['python'] and pi['deps'] and pi['key']:
        detected.append({
            'id': 'pageindex',
            'name': 'PageIndex (tree indexing)',
            'type': 'bundled-py',
            'enabled': True,
            'tools': ['(local Python; auto-runs on every PDF ingest)'],
            'add_command': None
        })
    else:
        missing = []
        if not pi['python']:
            missing.append('python3')
        if not pi['deps']:
            missing.append('pip deps')
        if not pi['key']:
            missing.append('ANTHROPIC_API_KEY')
        available.append({
            'id': 'pageindex',
            'name': 'PageIndex (tree indexing)',
            'type': 'bundled-py',
            'note': f'Bundled at vendor/PageIndex; missing: {\", \".join(missing)}. When set up, every ingested PDF gets a hierarchical tree index for finer-grained query routing.',
            'add_command': 'See /knowledge-vault:setup-sources → PageIndex',
            'api_key': True
        })

# Available servers (not yet detected)
recommended = [
    {
        'id': 'consensus',
        'name': 'Consensus',
        'type': 'http',
        'note': 'Academic research consensus engine',
        'add_command': 'claude mcp add --transport http consensus https://mcp.consensus.app/mcp',
        'api_key': False
    },
    {
        'id': 'arxiv-mcp-server',
        'name': 'arXiv',
        'type': 'stdio',
        'note': 'Search and download arXiv papers (2.5k stars)',
        'add_command': 'claude mcp add arxiv-mcp-server -- uvx arxiv-mcp-server --storage-path .vault/raw/arxiv-papers',
        'api_key': False
    },
    {
        'id': 'paper-search',
        'name': 'Paper Search (14 databases)',
        'type': 'stdio',
        'note': 'arXiv, PubMed, Semantic Scholar, bioRxiv, medRxiv, Crossref + more',
        'add_command': 'claude mcp add paper-search -- npx -y paper-search-mcp-nodejs',
        'api_key': False
    },
    {
        'id': 'zotero',
        'name': 'Zotero',
        'type': 'stdio',
        'note': 'Read your local Zotero library — collections, metadata, PDF fulltext, annotations (enables /knowledge-vault:ingest-zotero)',
        'add_command': 'uv tool install zotero-mcp-server && zotero-mcp setup',
        'api_key': False
    },
    {
        'id': 'unpaywall',
        'name': 'Unpaywall',
        'type': 'env-api',
        'note': 'Find open-access PDFs for reference-only items by DOI (enables /knowledge-vault:enrich-references). Free, no signup — just an email for polite API use.',
        'add_command': 'export UNPAYWALL_EMAIL=you@example.com  # add to ~/.bashrc or ~/.zshrc to persist',
        'api_key': False
    }
]

detected_ids = {d['id'] for d in detected}
for server in recommended:
    # Skip if already detected by name match
    if server['id'] not in detected_ids and not any(server['id'] in d.get('id','') for d in detected):
        available.append(server)

result = {'detected': detected, 'available': available}
print(json.dumps(result, indent=2))
"
