import os
import pathlib
import sys
import tempfile
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))


class BrokerFlowTests(unittest.TestCase):
    def test_end_to_end_allows_comment_with_tokenreview_and_opa(self):
        from phase0_broker import demo_run

        with tempfile.TemporaryDirectory() as td:
            token_path = os.path.join(td, "broker-token")
            result = demo_run.run_demo_once(token_path=token_path)

        self.assertEqual(result["broker_response"]["status"], "ok")
        self.assertEqual(result["broker_response"]["request_id"], "req-phase0-1")
        self.assertIn("issuecomment", result["broker_response"]["result"]["url"])
        self.assertTrue(any("request_id=req-phase0-1" in line for line in result["broker_logs"]))
        self.assertTrue(any("persona=reviewer" in line for line in result["broker_logs"]))
        self.assertTrue(any("token_source=projected_file" in line for line in result["broker_logs"]))
        self.assertTrue(any("allow=true" in line for line in result["opa_logs"]))
        self.assertTrue(any("github_app_id=12345" in line for line in result["github_logs"]))

    def test_policy_deny_returns_policy_error_and_no_mutation(self):
        from phase0_broker import demo_run

        with tempfile.TemporaryDirectory() as td:
            token_path = os.path.join(td, "broker-token")
            result = demo_run.run_demo_once(persona="blocked-persona", token_path=token_path)

        self.assertEqual(result["broker_response"]["status"], "error")
        self.assertEqual(result["broker_response"]["error"]["code"], "POLICY_DENY")
        self.assertTrue(any("allow=false" in line for line in result["opa_logs"]))
        self.assertFalse(any("posted_comment" in line for line in result["github_logs"]))


if __name__ == "__main__":
    unittest.main()
