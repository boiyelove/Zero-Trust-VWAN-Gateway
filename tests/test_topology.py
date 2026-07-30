import copy
import pathlib
import sys
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "src"))

from topology import TopologyError, load, parameters, validate  # noqa: E402


class TopologyTests(unittest.TestCase):
    def setUp(self):
        self.value = load(ROOT / "config/topology.json")

    def test_reference_topology_is_valid(self):
        self.assertEqual(self.value, validate(self.value))

    def test_requires_two_unique_regions(self):
        broken = copy.deepcopy(self.value)
        broken["hubs"][1]["location"] = broken["hubs"][0]["location"]
        with self.assertRaisesRegex(TopologyError, "unique"):
            validate(broken)

    def test_rejects_overlapping_networks(self):
        broken = copy.deepcopy(self.value)
        broken["hubs"][1]["spokePrefix"] = "10.10.0.0/24"
        with self.assertRaisesRegex(TopologyError, "overlap"):
            validate(broken)

    def test_requires_firewall_premium_deny_controls(self):
        for field, unsafe in (
            ("tier", "Standard"),
            ("threatIntelMode", "Alert"),
            ("intrusionDetectionMode", "Alert"),
            ("dnsProxy", False),
            ("tlsInspection", False),
        ):
            with self.subTest(field=field):
                broken = copy.deepcopy(self.value)
                broken["hubs"][0]["firewall"][field] = unsafe
                with self.assertRaisesRegex(TopologyError, "premium controls"):
                    validate(broken)

    def test_requires_both_routing_intents(self):
        broken = copy.deepcopy(self.value)
        broken["hubs"][0]["routingIntent"]["privateTraffic"] = False
        with self.assertRaisesRegex(TopologyError, "private and internet"):
            validate(broken)

    def test_rejects_wildcard_egress(self):
        broken = copy.deepcopy(self.value)
        broken["approvedEgressFqdns"] = ["*.example.com"]
        with self.assertRaisesRegex(TopologyError, "unsafe egress"):
            validate(broken)

    def test_rejects_expired_tls_exception(self):
        broken = copy.deepcopy(self.value)
        broken["tlsInspectionExceptions"] = [
            {
                "fqdn": "management.azure.com",
                "owner": "network-security",
                "justification": "Synthetic incompatibility evidence for testing.",
                "expiresAt": "2026-07-01T00:00:00Z",
            }
        ]
        with self.assertRaisesRegex(TopologyError, "expired"):
            validate(broken)

    def test_render_never_opts_in_to_deployment(self):
        rendered = parameters(self.value)
        self.assertIs(rendered["parameters"]["deployTopology"]["value"], False)


if __name__ == "__main__":
    unittest.main()
