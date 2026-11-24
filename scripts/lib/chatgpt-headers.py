#!/usr/bin/env python3
"""ChatGPT request headers for nono's openai-chatgpt credential route.

nono runs this helper as a cmd:// credential command outside the sandbox. It
reads the session from OPENAI_CHATGPT_SESSION, which the launch path passes to
the nono supervisor and the profile keeps out of the sandbox.

Without arguments it prints {"headers": {...}} for a valid session. On any
problem it exits non-zero and prints nothing, so nono injects nothing.

With --state it prints only the session state for the launcher:
valid, expiring, expired, invalid or missing. It never prints session values.
"""

import json
import os
import sys
import time

EXPIRING_SECONDS = 24 * 3600


def _text(value):
    return isinstance(value, str) and value != '' and '\r' not in value and '\n' not in value


def load_session(raw):
    """Returns (state, session). session is set only for valid or expiring states."""
    if raw is None or raw == '':
        return 'missing', None
    try:
        session = json.loads(raw)
    except ValueError:
        return 'invalid', None
    if not isinstance(session, dict):
        return 'invalid', None
    expires_at = session.get('expires_at')
    if isinstance(expires_at, bool) or not isinstance(expires_at, (int, float)):
        return 'invalid', None
    if not _text(session.get('access')) or not _text(session.get('account_id')):
        return 'invalid', None
    if 'residency' in session and not _text(session['residency']):
        return 'invalid', None
    remaining = expires_at - time.time()
    if remaining <= 0:
        return 'expired', None
    return ('expiring' if remaining < EXPIRING_SECONDS else 'valid'), session


def main(argv):
    state, session = load_session(os.environ.get('OPENAI_CHATGPT_SESSION'))
    if argv == ['--state']:
        print(state)
        return 0
    if argv or session is None:
        return 1
    headers = {
        'Authorization': 'Bearer ' + session['access'],
        'ChatGPT-Account-Id': session['account_id'],
    }
    if 'residency' in session:
        headers['x-openai-internal-codex-residency'] = session['residency']
    print(json.dumps({'headers': headers}))
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main(sys.argv[1:]))
    except Exception:  # Never let a traceback print session content.
        sys.exit(1)
