import importlib.util
import json
import unittest
from pathlib import Path
from unittest.mock import patch


MODULE_PATH = Path(__file__).with_name("seed-demo.py")
SPEC = importlib.util.spec_from_file_location("seed_demo", MODULE_PATH)
seed_demo = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(seed_demo)


class FakeApi:
    def __init__(self, *, existing=False):
        self.calls = []
        self.existing = existing

    def request(self, method, path, payload=None):
        self.calls.append((method, path, payload))
        if method == "PUT" and path == "projects/12/tasks":
            return {"id": 101, "title": "Plan the release"}
        if method == "GET" and path == "tasks/101/assignees":
            return [{"user_id": 7}] if self.existing else []
        if method == "GET" and path == "tasks/101/labels":
            return [{"id": 11}] if self.existing else []
        if method == "GET" and path == "tasks/101/comments":
            return [{"comment": "Review the launch checklist."}] if self.existing else []
        return None


class DemoSeedTests(unittest.TestCase):
    def test_seed_data_has_full_shared_projects(self):
        data = json.loads((MODULE_PATH.parent / "demo-data.json").read_text(encoding="utf-8"))
        self.assertEqual(len(data["accounts"]), 4)
        self.assertEqual(len(data["projects"]), 3)
        self.assertEqual(sum(len(project["tasks"]) for project in data["projects"]), 44)
        self.assertEqual(
            {task["status"] for project in data["projects"] for task in project["tasks"]},
            set(seed_demo.BUCKET_NAMES),
        )

    def test_task_creation_adds_bucket_assignments_labels_and_comments(self):
        api = FakeApi()
        task_data = {
            "title": "Plan the release",
            "status": "Doing",
            "start_days": 1,
            "duration_days": 2,
            "priority": 2,
            "assignees": ["lisa.chen"],
            "labels": ["IT"],
            "comments": ["Review the launch checklist."],
        }

        seed_demo.ensure_task(
            api,
            12,
            task_data,
            {},
            {"lisa.chen": {"id": 7}},
            {"IT": {"id": 11}},
            {"Doing": {"id": 3}},
            4,
        )

        self.assertIn(("PUT", "projects/12/tasks"), [(method, path) for method, path, _ in api.calls])
        self.assertIn(
            ("POST", "projects/12/views/4/buckets/3/tasks"),
            [(method, path) for method, path, _ in api.calls],
        )
        self.assertIn(("PUT", "tasks/101/assignees"), [(method, path) for method, path, _ in api.calls])
        self.assertIn(("PUT", "tasks/101/labels"), [(method, path) for method, path, _ in api.calls])
        self.assertIn(("PUT", "tasks/101/comments"), [(method, path) for method, path, _ in api.calls])

    def test_missing_account_is_created_with_the_pinned_vikunja_config(self):
        requests = []

        def fake_request(api, method, path, payload=None):
            requests.append((method, path, payload))
            if method == "POST" and path == "login" and len(requests) == 1:
                raise seed_demo.ApiError(403, method, path, "invalid credentials")
            if method == "POST" and path == "login":
                return {"token": "demo-token"}
            if method == "GET" and path == "user":
                return {"id": 7, "settings": {"default_project_id": 9, "language": "en"}}
            return {"message": "updated"}

        account = {
            "username": "lisa.chen",
            "email": "lisa.chen@example.test",
            "name": "Lisa Chen",
        }
        with patch.object(seed_demo.VikunjaApi, "request", new=fake_request), patch.object(
            seed_demo.subprocess,
            "run",
            return_value=type("Result", (), {"returncode": 0, "stderr": "", "stdout": ""})(),
        ) as create_user:
            user = seed_demo.ensure_account(
                seed_demo.VikunjaApi("http://localhost:8080"),
                "/opt/vikunja/vikunja",
                "/etc/vikunja/config.yml",
                account,
            )

        self.assertEqual(user["id"], 7)
        self.assertEqual(
            create_user.call_args.args[0],
            [
                "/opt/vikunja/vikunja",
                "user",
                "create",
                "-u",
                "lisa.chen",
                "-e",
                "lisa.chen@example.test",
                "-p",
                seed_demo.DEMO_PASSWORD,
                "--config",
                "/etc/vikunja/config.yml",
            ],
        )
        self.assertEqual(requests[-1][1], "user/settings/general")
        self.assertEqual(requests[-1][2]["default_project_id"], 9)

    def test_existing_task_does_not_duplicate_associations(self):
        api = FakeApi(existing=True)
        task_data = {
            "title": "Plan the release",
            "status": "Doing",
            "start_days": 1,
            "duration_days": 2,
            "priority": 2,
            "assignees": ["lisa.chen"],
            "labels": ["IT"],
            "comments": ["Review the launch checklist."],
        }

        seed_demo.ensure_task(
            api,
            12,
            task_data,
            {"Plan the release": {"id": 101}},
            {"lisa.chen": {"id": 7}},
            {"IT": {"id": 11}},
            {"Doing": {"id": 3}},
            4,
        )

        writes = [(method, path) for method, path, _ in api.calls if method == "PUT"]
        self.assertEqual(writes, [])
        self.assertEqual(
            [(method, path) for method, path, _ in api.calls if method == "POST"],
            [("POST", "projects/12/views/4/buckets/3/tasks")],
        )


if __name__ == "__main__":
    unittest.main()
