import urllib.request


def fetch_bytes(url: str, timeout_seconds: int) -> bytes:
    req = urllib.request.Request(
        url,
        headers={
            "User-Agent": "Mozilla/5.0 (compatible; GTFSRTAudit/1.0)",
            "Accept": "*/*",
            "Accept-Encoding": "identity",
        },
        method="GET",
    )
    with urllib.request.urlopen(req, timeout=timeout_seconds) as response:
        return response.read()