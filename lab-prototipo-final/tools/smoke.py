"""Deterministic HTTP client, NOT an AI agent. Run outside Kubernetes."""
import argparse
import json
import re
from urllib.error import HTTPError
from urllib.parse import urlsplit
from urllib.request import Request, urlopen


def run(base, ua):
    parsed = urlsplit(base)
    if parsed.scheme not in ('http', 'https') or not parsed.netloc or parsed.query or parsed.fragment:
        raise ValueError('base must be an HTTP(S) origin')
    base = base.rstrip('/')
    def get(path, expected=200):
        try:
            response = urlopen(Request(base + path, headers={'User-Agent': ua}), timeout=15)
        except HTTPError as exc:
            response = exc
        with response:
            text = response.read().decode()
            assert response.status == expected, (path, response.status, text)
            return text
    control = get('/experiment/control')
    assert '/probe/' not in control
    for variant in ('link', 'instruction', 'transform'):
        page = get('/experiment/' + variant)
        if variant == 'transform':
            # Test fixture reads experiment metadata, independently of any LLM.
            token = re.search(r'/probe/([A-Za-z0-9_-]{32})/reverse/', page).group(1)
            challenge = re.search(r'Challenge: <code>([a-f0-9]+)</code>', page).group(1)
            path = '/probe/' + token + '/reverse/' + challenge[::-1]
            get('/probe/' + token + '/reverse/wrong', 422)
        else:
            path = re.search(r'/probe/[A-Za-z0-9_-]{32}', page).group(0)
        get(path)
        get(path)  # A replay must not count as a second unique return.
    summary = json.loads(get('/api/summary'))
    metrics = get('/metrics')
    for name in ('lab_experiment_exposures_total', 'lab_challenges_returned_total',
                 'lab_callback_attempts_total', 'lab_callback_delay_seconds_count'):
        assert name in metrics, name
    print(json.dumps({'result': 'PASS', 'client': 'deterministic_script_not_ai',
                      'summary': summary}, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--base', default='http://127.0.0.1:18080')
    parser.add_argument('--user-agent', default='LabDeterministicClient/1.0')
    args = parser.parse_args()
    run(args.base, args.user_agent)
