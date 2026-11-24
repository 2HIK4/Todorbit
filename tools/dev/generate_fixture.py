#!/usr/bin/env python3
"""
Todorbit Developer Automation Toolkit - Deterministic Synthetic Fixture Generator
Generates self-contained SQLite workspaces with fixed seeds in .buildlog/fixtures/<name>/
"""

import os
import sys
import json
import sqlite3
import random
from datetime import datetime, timedelta, timezone

CURRENT_SCHEMA_VERSION = 29

DDL_BASE = """
PRAGMA foreign_keys = ON;
PRAGMA journal_mode = WAL;

CREATE TABLE IF NOT EXISTS categories (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL COLLATE NOCASE UNIQUE,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  event_color INTEGER
);

CREATE TABLE IF NOT EXISTS projects (
  id TEXT PRIMARY KEY,
  category_id TEXT NOT NULL REFERENCES categories(id) ON DELETE RESTRICT,
  name TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  UNIQUE(category_id, name)
);

CREATE TABLE IF NOT EXISTS tasks (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL CHECK(length(trim(title)) > 0),
  notes TEXT NOT NULL DEFAULT '',
  status TEXT NOT NULL CHECK(status IN ('notStarted','inProgress','waiting','onHold','completed','cancelled')),
  priority INTEGER NOT NULL DEFAULT 0 CHECK(priority BETWEEN 0 AND 3),
  category_id TEXT REFERENCES categories(id) ON DELETE RESTRICT,
  project_id TEXT REFERENCES projects(id) ON DELETE RESTRICT,
  scheduled_date TEXT,
  deadline_date TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  completed_at TEXT,
  planned_duration_minutes INTEGER,
  remaining_work_minutes INTEGER,
  scheduling_locked INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS fixed_events (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  starts_at TEXT NOT NULL,
  ends_at TEXT NOT NULL,
  category_id TEXT REFERENCES categories(id) ON DELETE RESTRICT,
  project_id TEXT REFERENCES projects(id) ON DELETE RESTRICT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  details_json TEXT NOT NULL DEFAULT '[]',
  repeat_json TEXT
);

CREATE TABLE IF NOT EXISTS task_checklist_groups (
  id TEXT PRIMARY KEY,
  task_id TEXT NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  position INTEGER NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS task_checklist (
  id TEXT PRIMARY KEY,
  task_id TEXT NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
  group_id TEXT REFERENCES task_checklist_groups(id) ON DELETE RESTRICT,
  title TEXT NOT NULL,
  is_completed INTEGER NOT NULL DEFAULT 0,
  position INTEGER NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS habits (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  category_id TEXT REFERENCES categories(id) ON DELETE RESTRICT,
  repeat_rule TEXT NOT NULL,
  archived INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS goals (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  category_id TEXT REFERENCES categories(id) ON DELETE RESTRICT,
  target_date TEXT,
  archived INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS time_sessions (
  id TEXT PRIMARY KEY,
  task_id TEXT REFERENCES tasks(id) ON DELETE SET NULL,
  starts_at TEXT NOT NULL,
  ends_at TEXT NOT NULL,
  duration_seconds INTEGER NOT NULL,
  created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS sync_capture_context (
  id INTEGER PRIMARY KEY CHECK(id=1),
  workspace_id TEXT,
  account_id TEXT,
  device_id TEXT,
  mutation_group TEXT,
  capture_enabled INTEGER NOT NULL DEFAULT 0,
  applying_remote INTEGER NOT NULL DEFAULT 0,
  restore_quarantined INTEGER NOT NULL DEFAULT 0,
  device_sequence INTEGER NOT NULL DEFAULT 0
);
INSERT OR IGNORE INTO sync_capture_context(id, capture_enabled) VALUES(1, 0);
"""

def generate_fixture(name, out_dir, seed=42):
    random.seed(seed)
    os.makedirs(out_dir, exist_ok=True)
    db_path = os.path.join(out_dir, "life_manager.sqlite")
    if os.path.exists(db_path):
        os.remove(db_path)

    conn = sqlite3.connect(db_path)
    cur = conn.cursor()
    cur.executescript(DDL_BASE)

    schema_version = CURRENT_SCHEMA_VERSION
    if name == "migration":
        schema_version = 27

    cur.execute(f"PRAGMA user_version = {schema_version}")

    base_date = datetime(2026, 11, 25, 10, 0, tzinfo=timezone.utc)
    categories = []
    projects = []
    tasks_count = 0
    events_count = 0

    if name == "empty":
        pass

    elif name in ("small", "migration"):
        cats = [("cat-1", "Work", 0x2563EB), ("cat-2", "Personal", 0x16A34A), ("cat-3", "Study", 0xD97706)]
        for cid, cname, col in cats:
            cur.execute("INSERT INTO categories VALUES(?,?,?,?,?)",
                        (cid, cname, base_date.isoformat(), base_date.isoformat(), col))
            categories.append(cid)

        cur.execute("INSERT INTO projects VALUES(?,?,?,?,?)",
                    ("proj-1", "cat-1", "Q4 Roadmap", base_date.isoformat(), base_date.isoformat()))
        projects.append("proj-1")

        statuses = ['notStarted', 'inProgress', 'completed']
        for i in range(1, 11):
            tid = f"task-{i}"
            cur.execute("INSERT INTO tasks VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
                        (tid, f"Sample Task #{i}", f"Notes for sample task {i}",
                         statuses[i % len(statuses)], i % 4, categories[i % len(categories)],
                         "proj-1" if i % 2 == 0 else None,
                         (base_date + timedelta(days=i % 5)).strftime("%Y-%m-%d"),
                         (base_date + timedelta(days=10 + i)).strftime("%Y-%m-%d"),
                         base_date.isoformat(), base_date.isoformat(),
                         base_date.isoformat() if statuses[i % len(statuses)] == 'completed' else None,
                         30 * (i % 4 + 1), 30, 0))
            tasks_count += 1

        for i in range(1, 4):
            eid = f"event-{i}"
            st = base_date + timedelta(days=i, hours=2)
            en = st + timedelta(hours=1)
            cur.execute("INSERT INTO fixed_events VALUES(?,?,?,?,?,?,?,?,?,?)",
                        (eid, f"Calendar Event #{i}", st.isoformat(), en.isoformat(),
                         categories[i % len(categories)], None, base_date.isoformat(), base_date.isoformat(), '[]', None))
            events_count += 1

    elif name in ("typical", "calendar-stress", "large", "sync-conflict"):
        cat_names = [("Work", 0x2563EB), ("Personal", 0x16A34A), ("Health", 0xDC2626),
                     ("Finance", 0x059669), ("Study", 0xD97706), ("Projects", 0x7C3AED)]
        for idx, (cname, col) in enumerate(cat_names):
            cid = f"cat-{idx+1}"
            cur.execute("INSERT INTO categories VALUES(?,?,?,?,?)",
                        (cid, cname, base_date.isoformat(), base_date.isoformat(), col))
            categories.append(cid)

        for idx in range(1, 4):
            pid = f"proj-{idx}"
            cur.execute("INSERT INTO projects VALUES(?,?,?,?,?)",
                        (pid, categories[idx-1], f"Project {idx}", base_date.isoformat(), base_date.isoformat()))
            projects.append(pid)

        target_tasks = 50 if name != "large" else 550
        statuses = ['notStarted', 'inProgress', 'waiting', 'completed']
        for i in range(1, target_tasks + 1):
            tid = f"task-{i}"
            st_choice = statuses[random.randint(0, len(statuses) - 1)]
            cur.execute("INSERT INTO tasks VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
                        (tid, f"Productivity Task #{i}", f"Detailed context and checklist instructions for task {i}.",
                         st_choice, random.randint(0, 3), categories[random.randint(0, len(categories) - 1)],
                         projects[random.randint(0, len(projects) - 1)] if random.random() > 0.4 else None,
                         (base_date + timedelta(days=random.randint(0, 14))).strftime("%Y-%m-%d"),
                         (base_date + timedelta(days=random.randint(10, 30))).strftime("%Y-%m-%d"),
                         base_date.isoformat(), base_date.isoformat(),
                         base_date.isoformat() if st_choice == 'completed' else None,
                         random.choice([15, 30, 45, 60, 90, 120]), random.choice([0, 15, 30]), 0))
            tasks_count += 1

            if i % 3 == 0:
                gid = f"grp-{i}"
                cur.execute("INSERT INTO task_checklist_groups VALUES(?,?,?,?,?,?)",
                            (gid, tid, "Subtasks", 0, base_date.isoformat(), base_date.isoformat()))
                for cidx in range(1, 4):
                    cur.execute("INSERT INTO task_checklist VALUES(?,?,?,?,?,?,?,?)",
                                (f"chk-{i}-{cidx}", tid, gid, f"Step {cidx} for task {i}",
                                 1 if random.random() > 0.5 else 0, cidx,
                                 base_date.isoformat(), base_date.isoformat()))

        target_events = 25 if name == "typical" else (220 if name == "large" else 120)
        for i in range(1, target_events + 1):
            eid = f"event-{i}"
            if name == "calendar-stress":
                day_offset = random.randint(0, 4)
                hour_start = random.randint(8, 18)
                min_start = random.choice([0, 15, 30, 45])
                dur = random.choice([30, 45, 60, 90, 120])
                st = (base_date + timedelta(days=day_offset)).replace(hour=hour_start, minute=min_start, second=0)
                en = st + timedelta(minutes=dur)
            else:
                st = base_date + timedelta(days=random.randint(0, 30), hours=random.randint(1, 8))
                en = st + timedelta(hours=random.choice([1, 2]))

            cur.execute("INSERT INTO fixed_events VALUES(?,?,?,?,?,?,?,?,?,?)",
                        (eid, f"Meeting / Event #{i}", st.isoformat(), en.isoformat(),
                         categories[random.randint(0, len(categories) - 1)], None,
                         base_date.isoformat(), base_date.isoformat(), '[]', None))
            events_count += 1

        # Habits and goals
        cur.execute("INSERT INTO habits VALUES(?,?,?,?,?,?,?)",
                    ("habit-1", "Daily Standup Review", categories[0], '{"kind":"weekdays","interval":1,"weekdays":[1,2,3,4,5]}', 0, base_date.isoformat(), base_date.isoformat()))
        cur.execute("INSERT INTO habits VALUES(?,?,?,?,?,?,?)",
                    ("habit-2", "Evening Reflection", categories[1], '{"kind":"daily","interval":1}', 0, base_date.isoformat(), base_date.isoformat()))
        cur.execute("INSERT INTO goals VALUES(?,?,?,?,?,?,?)",
                    ("goal-1", "Ship Todorbit Developer Automation Toolkit", categories[0], "2026-12-31", 0, base_date.isoformat(), base_date.isoformat()))
        cur.execute("INSERT INTO goals VALUES(?,?,?,?,?,?,?)",
                    ("goal-2", "Complete 100 Focus Sessions", categories[0], "2026-12-15", 0, base_date.isoformat(), base_date.isoformat()))

    conn.commit()
    conn.close()

    result = {
        "Fixture": name,
        "Seed": seed,
        "DatabasePath": os.path.abspath(db_path),
        "DatabaseSizeBytes": os.path.getsize(db_path),
        "SchemaVersion": schema_version,
        "TaskCount": tasks_count,
        "EventCount": events_count,
        "GeneratedAt": datetime.now(timezone.utc).isoformat(),
    }
    return result

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: generate_fixture.py <name> <output_dir> [seed]")
        sys.exit(1)
    name = sys.argv[1]
    out_dir = sys.argv[2]
    seed = int(sys.argv[3]) if len(sys.argv) > 3 else 42
    res = generate_fixture(name, out_dir, seed)
    print(json.dumps(res, indent=2))
