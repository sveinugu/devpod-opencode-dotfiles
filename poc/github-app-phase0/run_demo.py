import json
import tempfile

from phase0_broker.demo_run import run_demo_once


def main():
    with tempfile.TemporaryDirectory() as td:
        result = run_demo_once(token_path=f"{td}/broker-token")
    print("=== Broker Response ===")
    print(json.dumps(result["broker_response"], indent=2))
    print("\n=== Broker Logs ===")
    for line in result["broker_logs"]:
        print(line)
    print("\n=== OPA Logs ===")
    for line in result["opa_logs"]:
        print(line)
    print("\n=== Simulated GitHub Logs ===")
    for line in result["github_logs"]:
        print(line)


if __name__ == "__main__":
    main()
