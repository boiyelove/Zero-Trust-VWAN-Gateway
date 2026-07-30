import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]


class RepositoryTests(unittest.TestCase):
    def test_goal_and_build_are_ignored(self):
        ignored = (ROOT / ".gitignore").read_text(encoding="utf-8")
        self.assertIn("goal.md", ignored)
        self.assertIn("build/", ignored)

    def test_iac_is_explicit_and_deny_oriented(self):
        main = (ROOT / "infra/main.bicep").read_text(encoding="utf-8")
        hub = (ROOT / "infra/modules/secured-hub.bicep").read_text(encoding="utf-8")
        self.assertIn("param deployTopology bool = false", main)
        self.assertIn("tlsInspectionCertificateSecretId", main)
        self.assertIn("threatIntelMode: 'Deny'", hub)
        self.assertIn("intrusionDetection:", hub)
        self.assertIn("name: 'PrivateTraffic'", hub)
        self.assertIn("name: 'InternetTraffic'", hub)

    def test_ci_uses_read_only_permissions_and_security_scans(self):
        workflow = (ROOT / ".github/workflows/ci.yml").read_text(encoding="utf-8")
        self.assertIn("contents: read", workflow)
        self.assertIn("trivy-action@0.28.0", workflow)
        self.assertIn("gitleaks-action@v2", workflow)


if __name__ == "__main__":
    unittest.main()
