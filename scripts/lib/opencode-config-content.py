#!/usr/bin/env python3
"""Build the OPENCODE_CONFIG_CONTENT payload for the secure OpenCode wrapper.

Combines the generated provider runtime with the optional host-local model
overrides file (see docs/superpowers/specs/2026-11-19-opencode-host-local-model-overrides-design.md).
Prints the JSON payload on stdout and override notices on stderr. Exits with a
"refused: ..." message when either input is invalid.
"""

import argparse
import datetime
import json
import os
import re
import sys

BUILTIN_AGENTS = {'build', 'plan', 'general', 'explore', 'title', 'summary', 'compaction'}
DEFAULT_KEYS = {'model', 'small_model'}
ENTRY_KEYS = {'model', 'reason', 'until'}
DATE_PATTERN = re.compile(r'^\d{4}-\d{2}-\d{2}$')
# Literal provider/model id; model ids may contain namespace slashes. No whitespace or {env:}/{file:} placeholders.
MODEL_PATTERN = re.compile(r'^[A-Za-z0-9._-]+/[^\s{}]+$')


def refuse(message):
    raise SystemExit(f'refused: {message}')


def load_runtime(path):
    with open(path, 'r', encoding='utf-8') as fh:
        runtime = json.load(fh)

    if not isinstance(runtime, dict):
        refuse('generated provider runtime output must be a JSON object')
    if set(runtime.keys()) != {'enabled_providers', 'provider'}:
        refuse('generated provider runtime output contains unsupported keys')

    enabled = runtime['enabled_providers']
    if not isinstance(enabled, list):
        refuse('generated provider runtime output must define enabled_providers as a list')
    for provider in enabled:
        if not isinstance(provider, str) or not provider.strip():
            refuse('generated provider runtime output has invalid enabled_providers entry')

    provider_payload = runtime['provider']
    if not isinstance(provider_payload, dict):
        refuse('generated provider runtime output must define provider as an object')
    for provider_name, provider_config in provider_payload.items():
        if not isinstance(provider_name, str) or not provider_name.strip():
            refuse('generated provider runtime output has invalid provider key')
        if not isinstance(provider_config, dict):
            refuse('generated provider runtime output provider entries must be objects')

    return {'enabled_providers': enabled, 'provider': provider_payload}


def known_agents(agents_dir):
    names = set(BUILTIN_AGENTS)
    if os.path.isdir(agents_dir):
        names.update(
            name[:-3] for name in os.listdir(agents_dir)
            if name.endswith('.md') and os.path.isfile(os.path.join(agents_dir, name))
        )
    return names


def check_entry(label, entry, runtime, fail):
    if not isinstance(entry, dict):
        fail(f'{label}: entry must be an object')
    for key in entry:
        if key not in ENTRY_KEYS:
            fail(f'{label}: unknown key: {key}')
    for key in ('model', 'reason'):
        if not isinstance(entry.get(key), str) or not entry[key].strip():
            fail(f'{label}: missing {key}')

    if 'until' in entry:
        until = entry['until']
        if not isinstance(until, str) or not DATE_PATTERN.fullmatch(until):
            fail(f'{label}: until must be YYYY-MM-DD')
        try:
            datetime.date.fromisoformat(until)
        except ValueError:
            fail(f'{label}: until must be YYYY-MM-DD')

    if not MODEL_PATTERN.fullmatch(entry["model"]):
        fail(f'{label}: model must be a literal provider/model id')
    provider, _, model_id = entry['model'].partition('/')
    if provider not in runtime['enabled_providers']:
        fail(f'{label}: provider not enabled: {provider}')
    listed = runtime['provider'].get(provider, {}).get('models')
    if isinstance(listed, dict) and model_id not in listed:
        fail(f'{label}: model not listed for {provider}: {model_id}')


def active(name, entry, today):
    until = entry.get('until')
    if until is not None and today >= until:
        print(f'warning: model override for {name} expired on {until}; ignored', file=sys.stderr)
        return False
    reason = ' '.join(entry['reason'].split())
    detail = reason + (f'; until {until}' if until else '')
    print(f'model override: {name} -> {entry["model"]} ({detail})', file=sys.stderr)
    return True


def apply_overrides(payload, overrides_path, runtime, agents_dir, today):
    if not os.path.exists(overrides_path):
        return payload

    def fail(message):
        refuse(f'model overrides {overrides_path}: {message}')

    def reject_duplicates(pairs):
        obj = {}
        for key, value in pairs:
            if key in obj:
                fail(f'duplicate key: {key}')
            obj[key] = value
        return obj

    try:
        with open(overrides_path, 'r', encoding='utf-8') as fh:
            overrides = json.load(fh, object_pairs_hook=reject_duplicates)
    except json.JSONDecodeError:
        fail('not valid JSON')

    if not isinstance(overrides, dict):
        fail('must be a JSON object')
    for key in overrides:
        if key not in ('agents', 'defaults'):
            fail(f'unknown top-level key: {key}')

    agents = overrides.get('agents', {})
    defaults = overrides.get('defaults', {})
    if not isinstance(agents, dict):
        fail('agents must be an object')
    if not isinstance(defaults, dict):
        fail('defaults must be an object')

    agent_names = known_agents(agents_dir)
    for name, entry in agents.items():
        if name not in agent_names:
            fail(f'unknown agent: {name}')
        check_entry(f'agents.{name}', entry, runtime, fail)
    for name, entry in defaults.items():
        if name not in DEFAULT_KEYS:
            fail(f'unknown default: {name}')
        check_entry(f'defaults.{name}', entry, runtime, fail)

    agent_models = {name: {'model': e['model']} for name, e in agents.items() if active(name, e, today)}
    if agent_models:
        payload['agent'] = agent_models
    for name, entry in defaults.items():
        if active(name, entry, today):
            payload[name] = entry['model']
    return payload


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--runtime', required=True)
    parser.add_argument('--overrides', required=True)
    parser.add_argument('--agents-dir', required=True)
    parser.add_argument('--today', help='UTC date override for tests (YYYY-MM-DD)')
    args = parser.parse_args()

    today = args.today or datetime.datetime.now(datetime.timezone.utc).date().isoformat()
    runtime = load_runtime(args.runtime)
    payload = apply_overrides(dict(runtime), args.overrides, runtime, args.agents_dir, today)
    print(json.dumps(payload))


if __name__ == '__main__':
    main()
