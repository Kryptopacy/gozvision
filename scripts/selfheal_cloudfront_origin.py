"""Self-healing CloudFront origin monitor for the GozVision backend.

The production CloudFront distribution points at a single Fargate task's
public DNS. Every task replacement (redeploy, crash, OOM kill) orphans that
origin and takes https://d7icpdzxenshi.cloudfront.net down with 504s until
the origin is repointed. This script automates the repoint:

  1. Probe /health twice (consecutive failures required, to ride out blips).
  2. Discover the public DNS of the currently running task in
     gozvision-cluster.
  3. If it differs from the configured origin, repoint the distribution.

Usage:
  python scripts/selfheal_cloudfront_origin.py           # probe + heal
  python scripts/selfheal_cloudfront_origin.py --check   # probe only

Exit codes: 0 healthy (or healed and verified), 1 still unhealthy, 2 config error.
"""

import json
import subprocess
import sys
import time
import urllib.request

PROFILE = "pacy-labs-ci"
REGION = "eu-north-1"
CLUSTER = "gozvision-cluster"
SERVICE = "gozvision-backend-service"
DIST_ID = "E1GRK4O263U8SX"
HEALTH_URL = f"https://d7icpdzxenshi.cloudfront.net/health"


def aws(*args, capture=True):
    cmd = ["aws", *args, "--profile", PROFILE, "--region", REGION, "--output", "json"]
    res = subprocess.run(cmd, capture_output=capture, text=True)
    if res.returncode != 0:
        raise RuntimeError(f"aws {' '.join(args[:3])} failed: {res.stderr.strip()[:300]}")
    return json.loads(res.stdout) if capture else None


def probe_health(timeout=20):
    try:
        req = urllib.request.Request(HEALTH_URL, headers={"User-Agent": "gozvision-selfheal/1.0"})
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return resp.status == 200
    except Exception:
        return False


def current_origin_domain():
    data = aws("cloudfront", "get-distribution-config", "--id", DIST_ID)
    return data["DistributionConfig"]["Origins"]["Items"][0]["DomainName"], data["ETag"], data["DistributionConfig"]


def running_task_public_dns():
    arns = aws("ecs", "list-tasks", "--cluster", CLUSTER, "--service-name", SERVICE)["taskArns"]
    if not arns:
        return None
    detail = aws(
        "ecs", "describe-tasks", "--cluster", CLUSTER, "--tasks", arns[0],
    )["tasks"][0]
    if detail.get("lastStatus") != "RUNNING":
        return None
    for attachment in detail.get("attachments", []):
        pairs = {p["name"]: p["value"] for p in attachment["details"]}
        eni_id = pairs.get("networkInterfaceId")
        if not eni_id:
            continue
        eni = aws("ec2", "describe-network-interfaces", "--network-interface-ids", eni_id)
        dns = eni["NetworkInterfaces"][0].get("Association", {}).get("PublicDnsName")
        if dns:
            return dns
    return None


def repoint_origin(new_domain, etag, config):
    config["Origins"]["Items"][0]["DomainName"] = new_domain
    with open("cf-selfheal-config.json", "w", encoding="utf-8") as f:
        json.dump(config, f, indent=2)
    aws("cloudfront", "update-distribution", "--id", DIST_ID,
        "--distribution-config", "file://cf-selfheal-config.json", "--if-match", etag)


def main():
    check_only = "--check" in sys.argv

    if probe_health() and probe_health():
        print(f"HEALTHY: {HEALTH_URL} returned 200.")
        return 0

    print("UNHEALTHY: first probe failed; re-probing after 30s to rule out a blip...")
    time.sleep(30)
    if probe_health():
        print("HEALTHY on second probe: transient blip, no action taken.")
        return 0

    if check_only:
        print("STILL UNHEALTHY (check-only mode, no healing attempted).")
        return 1

    try:
        task_dns = running_task_public_dns()
        origin_dns, etag, config = current_origin_domain()
    except RuntimeError as e:
        print(f"ERROR: AWS API failure (credentials may be expired): {e}")
        return 2

    print(f"CloudFront origin : {origin_dns}")
    print(f"Running task DNS  : {task_dns}")

    if not task_dns:
        print("ERROR: no RUNNING task found in the cluster; the service itself is down.")
        return 1
    if task_dns == origin_dns:
        print("Origin already matches the running task; outage has another cause "
              "(container crash-looping, health endpoint broken in-app). Check ECS logs.")
        return 1

    print(f"Repointing origin {origin_dns} -> {task_dns} ...")
    repoint_origin(task_dns, etag, config)

    # CloudFront config changes propagate within ~1-2 minutes; poll for recovery.
    for attempt in range(10):
        time.sleep(45)
        if probe_health():
            print(f"HEALED: {HEALTH_URL} is 200 again after origin repoint "
                  f"(attempt {attempt + 1}).")
            return 0
        print(f"attempt {attempt + 1}: still down, waiting...")

    print("Repoint was applied but /health did not recover within the wait window; "
          "investigate manually.")
    return 1


if __name__ == "__main__":
    sys.exit(main())
