#!/usr/bin/env python3
"""Validate a least-trust Virtual WAN topology and render Bicep parameters."""

from __future__ import annotations

import argparse
import datetime as dt
import ipaddress
import json
from pathlib import Path
from typing import Any


class TopologyError(ValueError):
    """The topology would weaken routing or firewall guarantees."""


def load(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise TopologyError(f"cannot load {path}: {exc}") from exc
    if not isinstance(value, dict):
        raise TopologyError("topology must be an object")
    return value


def parse_time(raw: str, field: str) -> dt.datetime:
    try:
        value = dt.datetime.fromisoformat(raw.replace("Z", "+00:00"))
    except (ValueError, AttributeError) as exc:
        raise TopologyError(f"{field} must be ISO-8601") from exc
    if value.tzinfo is None:
        raise TopologyError(f"{field} requires timezone")
    return value.astimezone(dt.timezone.utc)


def validate(config: dict[str, Any]) -> dict[str, Any]:
    if config.get("schemaVersion") != "1.0":
        raise TopologyError("unsupported schemaVersion")
    if config.get("deployTopology") is not False:
        raise TopologyError("checked configuration must default deployment to false")
    if config.get("virtualWan", {}).get("type") != "Standard":
        raise TopologyError("routing intent requires Standard Virtual WAN")
    hubs = config.get("hubs")
    if not isinstance(hubs, list) or len(hubs) != 2:
        raise TopologyError("exactly two hubs are required")
    now = parse_time(config.get("asOf", ""), "asOf")
    names: set[str] = set()
    locations: set[str] = set()
    networks: list[tuple[str, ipaddress.IPv4Network]] = []
    for hub in hubs:
        required = {"name", "location", "addressPrefix", "spokePrefix", "firewall", "routingIntent"}
        if not isinstance(hub, dict) or required - hub.keys():
            raise TopologyError("hub configuration is incomplete")
        name = str(hub["name"])
        location = str(hub["location"]).lower()
        if name in names or location in locations:
            raise TopologyError("hub names and regions must be unique")
        names.add(name)
        locations.add(location)
        for field in ("addressPrefix", "spokePrefix"):
            try:
                network = ipaddress.ip_network(hub[field], strict=True)
            except ValueError as exc:
                raise TopologyError(f"{name}.{field} must be canonical CIDR") from exc
            if network.version != 4 or not network.is_private:
                raise TopologyError(f"{name}.{field} must use private IPv4")
            networks.append((f"{name}.{field}", network))
        firewall = hub["firewall"]
        if (
            firewall.get("tier") != "Premium"
            or firewall.get("threatIntelMode") != "Deny"
            or firewall.get("intrusionDetectionMode") != "Deny"
            or firewall.get("dnsProxy") is not True
            or firewall.get("tlsInspection") is not True
        ):
            raise TopologyError(f"{name} firewall must enforce all premium controls")
        intent = hub["routingIntent"]
        if intent.get("privateTraffic") is not True or intent.get("internetTraffic") is not True:
            raise TopologyError(f"{name} must inspect private and internet traffic")
    for index, (left_name, left) in enumerate(networks):
        for right_name, right in networks[index + 1 :]:
            if left.overlaps(right):
                raise TopologyError(f"address overlap: {left_name} and {right_name}")
    domains = config.get("approvedEgressFqdns")
    if not isinstance(domains, list) or not domains:
        raise TopologyError("approvedEgressFqdns must be non-empty")
    for domain in domains:
        if (
            not isinstance(domain, str)
            or "*" in domain
            or domain.startswith(".")
            or "." not in domain
            or len(domain) > 253
        ):
            raise TopologyError(f"unsafe egress FQDN: {domain}")
    if len(set(domains)) != len(domains):
        raise TopologyError("approved egress FQDNs must be unique")
    exceptions = config.get("tlsInspectionExceptions")
    if not isinstance(exceptions, list):
        raise TopologyError("tlsInspectionExceptions must be a list")
    for item in exceptions:
        required = {"fqdn", "owner", "justification", "expiresAt"}
        if not isinstance(item, dict) or required - item.keys():
            raise TopologyError("TLS inspection exception metadata is incomplete")
        if item["fqdn"] not in domains or len(str(item["justification"]).strip()) < 20:
            raise TopologyError("TLS exception must be scoped and justified")
        if parse_time(item["expiresAt"], "expiresAt") <= now:
            raise TopologyError(f"expired TLS inspection exception: {item['fqdn']}")
    return config


def parameters(config: dict[str, Any]) -> dict[str, Any]:
    valid = validate(config)
    return {
        "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
        "contentVersion": "1.0.0.0",
        "parameters": {
            "deployTopology": {"value": False},
            "namePrefix": {"value": valid["namePrefix"]},
            "hubs": {"value": valid["hubs"]},
            "approvedEgressFqdns": {"value": valid["approvedEgressFqdns"]},
        },
    }


def run_validate(args: argparse.Namespace) -> int:
    config = validate(load(Path(args.config)))
    print(
        f"hubs={len(config['hubs'])} regions={len({x['location'] for x in config['hubs']})} "
        f"egress_fqdns={len(config['approvedEgressFqdns'])} topology=valid"
    )
    return 0


def run_render(args: argparse.Namespace) -> int:
    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(
        json.dumps(parameters(load(Path(args.config))), indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    print(f"parameters={output}")
    return 0


def parser() -> argparse.ArgumentParser:
    value = argparse.ArgumentParser(description=__doc__)
    commands = value.add_subparsers(dest="command", required=True)
    check = commands.add_parser("validate")
    check.add_argument("--config", required=True)
    check.set_defaults(handler=run_validate)
    render = commands.add_parser("render")
    render.add_argument("--config", required=True)
    render.add_argument("--output", required=True)
    render.set_defaults(handler=run_render)
    return value


if __name__ == "__main__":
    try:
        arguments = parser().parse_args()
        raise SystemExit(arguments.handler(arguments))
    except TopologyError as exc:
        print(f"error: {exc}")
        raise SystemExit(1) from exc
