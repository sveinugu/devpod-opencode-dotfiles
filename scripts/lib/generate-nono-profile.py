#!/usr/bin/env python3
import argparse
import json
import os
import tempfile


def _fail(message: str) -> None:
    raise SystemExit(message)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument('--template', required=True)
    parser.add_argument('--runtime', required=True)
    parser.add_argument('--output-dir', required=True)
    args = parser.parse_args()

    with open(args.template, 'r', encoding='utf-8') as fh:
        profile = json.load(fh)

    with open(args.runtime, 'r', encoding='utf-8') as fh:
        runtime = json.load(fh)

    if not isinstance(profile, dict):
        _fail('refused: secure nono profile template must be a JSON object')

    enabled = runtime.get('enabled_providers')
    if not isinstance(enabled, list):
        _fail('refused: generated provider runtime output must define enabled_providers as a list')

    for provider in enabled:
        if not isinstance(provider, str) or not provider.strip():
            _fail('refused: generated provider runtime output has invalid enabled_providers entry')

    provider_to_credential = {
        'openai-chatgpt': 'openai-chatgpt',
        'anthropic': 'anthropic',
        'github-copilot': 'github-copilot',
        'gpt-uio-yellow': 'gpt-uio-yellow',
        'gpt-uio-red': 'gpt-uio-red',
    }

    unknown = sorted(provider for provider in enabled if provider not in provider_to_credential)
    if unknown:
        _fail(f'refused: unknown providers in generated provider runtime output: {", ".join(unknown)}')

    managed_credential_names = set(provider_to_credential.values())
    enabled_credential_names = {provider_to_credential[provider] for provider in enabled}
    # The ChatGPT route needs a session in the supervisor environment; the wrapper
    # passes OPENAI_CHATGPT_SESSION only for a valid login.
    if not os.environ.get('OPENAI_CHATGPT_SESSION'):
        enabled_credential_names.discard('openai-chatgpt')

    network = profile.get('network')
    if not isinstance(network, dict):
        _fail('refused: secure nono profile template must define network object')

    credentials = network.get('credentials')
    if not isinstance(credentials, list):
        _fail('refused: secure nono profile template must define network.credentials list')

    custom_credentials = network.get('custom_credentials')
    if not isinstance(custom_credentials, dict):
        _fail('refused: secure nono profile template must define network.custom_credentials object')

    filtered_credentials = []
    for route_name in credentials:
        if not isinstance(route_name, str):
            _fail('refused: secure nono profile template has invalid network.credentials entry')
        if route_name in managed_credential_names and route_name not in enabled_credential_names:
            continue
        filtered_credentials.append(route_name)

    filtered_custom_credentials = {}
    for route_name, route_config in custom_credentials.items():
        if route_name in managed_credential_names and route_name not in enabled_credential_names:
            continue
        filtered_custom_credentials[route_name] = route_config

    network['credentials'] = filtered_credentials
    network['custom_credentials'] = filtered_custom_credentials

    capture = profile.get('credential_capture', {})
    if not isinstance(capture, dict):
        _fail('refused: secure nono profile template has invalid credential_capture object')
    # A capture entry belongs to the route whose cmd:// key names it. nono
    # requires that name to use only letters, digits and underscores, so it
    # cannot reuse a hyphenated route name. Drop entries of removed routes.
    def cmd_names(routes):
        return {
            config['credential_key'][len('cmd://'):]
            for config in routes.values()
            if isinstance(config, dict) and str(config.get('credential_key', '')).startswith('cmd://')
        }

    template_cmd_names = cmd_names(custom_credentials)
    kept_cmd_names = cmd_names(filtered_custom_credentials)
    capture = {
        name: entry
        for name, entry in capture.items()
        if name not in template_cmd_names or name in kept_cmd_names
    }
    if capture:
        profile['credential_capture'] = capture
    else:
        profile.pop('credential_capture', None)

    if not os.path.isdir(args.output_dir):
        _fail(f'refused: generated nono profile directory not found at {args.output_dir}')

    fd, generated_path = tempfile.mkstemp(prefix='opencode-nono-profile-', suffix='.json', dir=args.output_dir)
    os.close(fd)

    with open(generated_path, 'w', encoding='utf-8') as fh:
        json.dump(profile, fh, indent=2)
        fh.write('\n')

    os.chmod(generated_path, 0o644)
    print(generated_path)


if __name__ == '__main__':
    main()
