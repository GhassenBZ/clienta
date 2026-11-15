#!/usr/bin/env python3
"""Create persistent demo accounts and shared Vikunja projects."""

import argparse
import datetime as dt
import json
import subprocess
import sys
import time
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode
from urllib.request import Request, urlopen


DEMO_PASSWORD = "VikunjaDemo2026"
DATA_PATH = Path(__file__).with_name("demo-data.json")
BUCKET_NAMES = ("To-Do", "Doing", "Done")


class ApiError(RuntimeError):
    def __init__(self, status, method, path, body):
        self.status = status
        super().__init__(f"Vikunja API {method} {path} returned {status}: {body}")


class VikunjaApi:
    def __init__(self, base_url, token=None):
        self.base_url = base_url.rstrip("/")
        self.token = token

    def request(self, method, path, payload=None):
        url = f"{self.base_url}/api/v1/{path.lstrip('/')}"
        data = None if payload is None else json.dumps(payload).encode("utf-8")
        headers = {"Accept": "application/json"}
        if data is not None:
            headers["Content-Type"] = "application/json"
        if self.token:
            headers["Authorization"] = f"Bearer {self.token}"
        request = Request(url, data=data, headers=headers, method=method)
        try:
            with urlopen(request, timeout=30) as response:
                body = response.read()
        except HTTPError as error:
            detail = error.read().decode("utf-8", errors="replace")
            raise ApiError(error.code, method, path, detail) from error
        except URLError as error:
            raise RuntimeError(f"Vikunja API {method} {path} failed: {error}") from error
        if not body:
            return None
        return json.loads(body)


def wait_for_api(base_url, timeout):
    deadline = time.monotonic() + timeout
    last_error = None
    while time.monotonic() < deadline:
        try:
            with urlopen(f"{base_url.rstrip('/')}/api/v1/info", timeout=5) as response:
                if response.status == 200:
                    return
                last_error = f"HTTP {response.status}"
        except (HTTPError, URLError) as error:
            last_error = str(error)
        time.sleep(5)
    raise RuntimeError(f"Vikunja API did not become ready in {timeout} seconds: {last_error}")


def login(api, username, password):
    try:
        response = api.request("POST", "login", {"username": username, "password": password})
    except ApiError as error:
        if error.status in (401, 403):
            return None
        raise
    token = response.get("token")
    if not token:
        raise RuntimeError(f"Login for {username} succeeded without returning a token.")
    return VikunjaApi(api.base_url, token)


def ensure_account(api, binary_path, config_path, account):
    authenticated = login(api, account["username"], DEMO_PASSWORD)
    if authenticated is None:
        result = subprocess.run(
            [
                binary_path,
                "user",
                "create",
                "-u",
                account["username"],
                "-e",
                account["email"],
                "-p",
                DEMO_PASSWORD,
                "--config",
                config_path,
            ],
            check=False,
            capture_output=True,
            text=True,
        )
        if result.returncode:
            detail = result.stderr.strip() or result.stdout.strip() or "no command output"
            raise RuntimeError(
                f"Could not create or log in as {account['username']}; "
                f"check the database and demo credentials. Vikunja CLI: {detail}"
            )
        authenticated = login(api, account["username"], DEMO_PASSWORD)
        if authenticated is None:
            raise RuntimeError(f"New Vikunja account {account['username']} could not log in.")
        print(f"Created account {account['username']}.")

    user = authenticated.request("GET", "user")
    settings = user.get("settings") or {}
    settings_payload = {
        "name": account["name"],
        "email_reminders_enabled": settings.get("email_reminders_enabled", False),
        "discoverable_by_name": settings.get("discoverable_by_name", False),
        "discoverable_by_email": settings.get("discoverable_by_email", False),
        "overdue_tasks_reminders_enabled": settings.get("overdue_tasks_reminders_enabled", False),
        "overdue_tasks_reminders_time": settings.get("overdue_tasks_reminders_time", "09:00"),
        "default_project_id": settings.get("default_project_id", 0),
        "week_start": settings.get("week_start", 1),
        "language": settings.get("language", "en"),
        "timezone": settings.get("timezone", "UTC"),
        "frontend_settings": settings.get("frontend_settings"),
    }
    authenticated.request("POST", "user/settings/general", settings_payload)
    user_id = user.get("id")
    if not user_id:
        raise RuntimeError(f"Vikunja did not return an ID for account {account['username']}.")
    return {"id": user_id, "username": account["username"], "api": authenticated}


def ensure_label(api, label, labels_by_title):
    if label["title"] in labels_by_title:
        return labels_by_title[label["title"]]
    created = api.request("PUT", "labels", label)
    labels_by_title[label["title"]] = created
    return created


def ensure_project(api, project, projects_by_identifier):
    existing = projects_by_identifier.get(project["identifier"])
    if existing:
        return existing
    created = api.request(
        "PUT",
        "projects",
        {
            "title": project["title"],
            "identifier": project["identifier"],
            "description": project["description"],
            "hex_color": project["hex_color"],
        },
    )
    projects_by_identifier[project["identifier"]] = created
    return created


def ensure_buckets(api, project_id, kanban_view):
    view_id = kanban_view["id"]
    buckets = api.request("GET", f"projects/{project_id}/views/{view_id}/buckets")
    buckets_by_title = {bucket["title"]: bucket for bucket in buckets}
    for position, title in enumerate(BUCKET_NAMES, start=1):
        if title not in buckets_by_title:
            bucket = api.request(
                "PUT",
                f"projects/{project_id}/views/{view_id}/buckets",
                {"title": title, "position": position * 100},
            )
            buckets_by_title[title] = bucket
    return buckets_by_title


def list_project_tasks(api, project_id):
    tasks_by_title = {}
    page = 1
    per_page = 50
    while True:
        query = urlencode({"page": page, "per_page": per_page})
        tasks = api.request("GET", f"tasks?{query}")
        if not isinstance(tasks, list):
            raise RuntimeError("Vikunja returned an invalid task list.")
        for task in tasks:
            if task.get("project_id") == project_id:
                tasks_by_title[task["title"]] = task
        if len(tasks) < per_page:
            break
        page += 1
    return tasks_by_title


def task_dates(task_data):
    today = dt.datetime.now(dt.timezone.utc).replace(hour=9, minute=0, second=0, microsecond=0)
    start = today + dt.timedelta(days=task_data["start_days"])
    end = start + dt.timedelta(days=task_data["duration_days"])
    return tuple(value.isoformat(timespec="seconds").replace("+00:00", "Z") for value in (start, end))


def ensure_task(api, project_id, task_data, tasks_by_title, users_by_name, labels_by_title, buckets, view_id):
    task = tasks_by_title.get(task_data["title"])
    if task is None:
        start, end = task_dates(task_data)
        done = task_data["status"] == "Done"
        task = api.request(
            "PUT",
            f"projects/{project_id}/tasks",
            {
                "project_id": project_id,
                "title": task_data["title"],
                "description": task_data.get("description", ""),
                "start_date": start,
                "end_date": end,
                "due_date": end,
                "priority": task_data["priority"],
                "percent_done": 1 if done else task_data.get("percent_done", 0),
                "done": done,
            },
        )
        tasks_by_title[task_data["title"]] = task

    bucket = buckets[task_data["status"]]
    api.request(
        "POST",
        f"projects/{project_id}/views/{view_id}/buckets/{bucket['id']}/tasks",
        {"task_id": task["id"], "bucket_id": bucket["id"], "project_view_id": view_id},
    )

    assigned = api.request("GET", f"tasks/{task['id']}/assignees")
    assigned_ids = {user.get("user_id") for user in assigned}
    for username in task_data.get("assignees", []):
        user = users_by_name[username]
        if user["id"] not in assigned_ids:
            api.request("PUT", f"tasks/{task['id']}/assignees", {"user_id": user["id"]})
            assigned_ids.add(user["id"])

    task_labels = api.request("GET", f"tasks/{task['id']}/labels")
    task_label_ids = {label.get("id") for label in task_labels}
    for title in task_data.get("labels", []):
        label = labels_by_title[title]
        if label["id"] not in task_label_ids:
            api.request("PUT", f"tasks/{task['id']}/labels", {"label_id": label["id"]})
            task_label_ids.add(label["id"])

    comments = api.request("GET", f"tasks/{task['id']}/comments")
    comment_texts = {comment.get("comment") for comment in comments}
    for comment in task_data.get("comments", []):
        if comment not in comment_texts:
            api.request("PUT", f"tasks/{task['id']}/comments", {"comment": comment})
            comment_texts.add(comment)


def ensure_project_members(api, project_id, member_names, users_by_name):
    existing = api.request("GET", f"projects/{project_id}/users")
    usernames = {member.get("username") for member in existing}
    for username in member_names:
        if username not in usernames:
            api.request("PUT", f"projects/{project_id}/users", {"username": username, "permission": 1})
            usernames.add(username)


def seed(base_url, binary_path, config_path, data_path, timeout):
    data = json.loads(Path(data_path).read_text(encoding="utf-8"))
    wait_for_api(base_url, timeout)
    unauthenticated_api = VikunjaApi(base_url)

    users_by_name = {}
    owner_api = None
    for account in data["accounts"]:
        user = ensure_account(unauthenticated_api, binary_path, config_path, account)
        users_by_name[user["username"]] = user
        if account["username"] == data["accounts"][0]["username"]:
            owner_api = user["api"]
    if owner_api is None:
        raise RuntimeError("The demo data must define at least one owner account.")

    labels_response = owner_api.request("GET", "labels?per_page=100")
    labels_by_title = {label["title"]: label for label in labels_response}
    for label in data["labels"]:
        ensure_label(owner_api, label, labels_by_title)

    projects_response = owner_api.request("GET", "projects")
    projects_by_identifier = {
        project.get("identifier"): project
        for project in projects_response
        if project.get("identifier")
    }
    created_count = 0
    for project_data in data["projects"]:
        project = ensure_project(owner_api, project_data, projects_by_identifier)
        project_id = project["id"]
        ensure_project_members(owner_api, project_id, project_data["members"], users_by_name)
        views = owner_api.request("GET", f"projects/{project_id}/views")
        kanban_view = next((view for view in views if view.get("view_kind") == "kanban"), None)
        if kanban_view is None:
            raise RuntimeError(f"Project {project_data['title']} has no Kanban view.")
        buckets = ensure_buckets(owner_api, project_id, kanban_view)
        tasks_by_title = list_project_tasks(owner_api, project_id)
        before = len(tasks_by_title)
        for task_data in project_data["tasks"]:
            ensure_task(
                owner_api,
                project_id,
                task_data,
                tasks_by_title,
                users_by_name,
                labels_by_title,
                buckets,
                kanban_view["id"],
            )
        created_count += len(tasks_by_title) - before
        print(f"Seeded {project_data['title']}: {len(project_data['tasks'])} tasks.")
    print(
        f"Vikunja demo seed complete: {len(users_by_name)} accounts, "
        f"{len(data['projects'])} projects, {created_count} new tasks."
    )


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--url", default="http://127.0.0.1:8080", help="Vikunja base URL")
    parser.add_argument("--binary", default="/opt/vikunja/vikunja/vikunja", help="Vikunja CLI binary")
    parser.add_argument("--config", default="/etc/vikunja/config.yml", help="Vikunja config file")
    parser.add_argument("--data", default=str(DATA_PATH), help="Path to demo-data.json")
    parser.add_argument("--timeout", type=int, default=300, help="Seconds to wait for the API")
    args = parser.parse_args()
    try:
        seed(args.url, args.binary, args.config, args.data, args.timeout)
    except Exception as error:
        print(f"Vikunja demo seeding failed: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
