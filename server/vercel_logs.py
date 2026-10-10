"""Read a short, bounded sample from Vercel's deployment runtime-log stream."""

import json
import time

import requests


class LogProviderError(Exception):
    pass


def _event_to_row(event):
    if not isinstance(event, dict):
        return None
    payload = event.get('payload') if isinstance(event.get('payload'), dict) else {}
    message = event.get('message') or event.get('text') or payload.get('text') or ''
    row = {
        'id': str(event.get('rowId') or event.get('id') or ''),
        'timestamp': event.get('timestampInMs') or event.get('created') or event.get('timestamp'),
        'level': str(event.get('level') or event.get('type') or 'info'),
        'method': str(event.get('requestMethod') or ''),
        'path': str(event.get('requestPath') or ''),
        'status': event.get('responseStatusCode'),
        'message': str(message)[:8000],
    }
    return row if row['message'] or row['path'] else None


def _decode_line(line):
    if isinstance(line, bytes):
        line = line.decode('utf-8', errors='replace')
    line = line.strip()
    if line.startswith('data:'):
        line = line[5:].strip()
    if not line or line == '[DONE]':
        return []
    try:
        value = json.loads(line)
    except json.JSONDecodeError:
        return []
    events = value if isinstance(value, list) else [value]
    return [row for event in events if (row := _event_to_row(event))]


def read_runtime_logs(token, project_id, deployment_id, team_id=None):
    """Return at most 100 rows without leaving a live upstream stream open."""
    url = (f'https://api.vercel.com/v1/projects/{project_id}'
           f'/deployments/{deployment_id}/runtime-logs')
    params = {'teamId': team_id} if team_id else None
    response = None
    rows = []
    deadline = time.monotonic() + 8
    try:
        response = requests.get(
            url,
            headers={'Authorization': f'Bearer {token}', 'Accept': 'application/json'},
            params=params,
            stream=True,
            timeout=(3, 6),
        )
        if response.status_code in (401, 403):
            raise LogProviderError('Vercel rejected the log access token or project scope.')
        if response.status_code == 404:
            raise LogProviderError('Vercel could not find this project or deployment.')
        response.raise_for_status()
        for line in response.iter_lines(chunk_size=4096):
            rows.extend(_decode_line(line))
            if len(rows) >= 100 or time.monotonic() >= deadline:
                break
    except LogProviderError:
        raise
    except requests.RequestException as error:
        if response is None or response.status_code != 200:
            raise LogProviderError('Vercel logs are temporarily unavailable.') from error
    finally:
        if response is not None:
            response.close()
    return [row for row in rows[-100:] if not row['path'].startswith('/admin/logs')]
