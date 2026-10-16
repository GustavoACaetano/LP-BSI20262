"""Check scrapes and provisioned dashboard queries, without rendering the UI."""
import argparse
import json
from urllib.parse import urlencode
from urllib.request import urlopen


def check(prometheus, grafana):
    def get(url):
        with urlopen(url, timeout=15) as response:
            return json.load(response)
    targets = get(prometheus + '/api/v1/targets')['data']['activeTargets']
    for job in ('trap', 'cilium-agent', 'prometheus'):
        matching = [t for t in targets if t['labels']['job'] == job]
        assert matching and all(t['health'] == 'up' for t in matching), (job, matching)
    dashboard = get(grafana + '/api/dashboards/uid/agent-trap-lab')['dashboard']
    assert len(dashboard['panels']) == 16
    results = []
    for panel in dashboard['panels']:
        for target in panel['targets']:
            expr = target['expr'].replace('$__rate_interval', '1m')
            response = get(prometheus + '/api/v1/query?' + urlencode({'query': expr}))
            assert response['status'] == 'success', response
            results.append({'panel': panel['id'], 'series': len(response['data']['result'])})
    print(json.dumps({'result': 'PASS', 'targets_up': 3, 'panels': 16,
                      'queries': results, 'scope': 'APIs; visual rendering not checked'}, indent=2))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--prometheus', default='http://127.0.0.1:19090')
    parser.add_argument('--grafana', default='http://127.0.0.1:13000')
    args = parser.parse_args()
    check(args.prometheus.rstrip('/'), args.grafana.rstrip('/'))
