"""Focused, deterministic orchestration tests; all GitHub traffic is replaced in memory."""

import copy
import importlib.util
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import Mock, patch
from urllib.error import HTTPError


MODULE_PATH = Path(__file__).resolve().parents[1] / "orchestrator.py"
SPEC = importlib.util.spec_from_file_location("orchestrator", MODULE_PATH)
orch = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = orch
SPEC.loader.exec_module(orch)

KINDS = ("DOC-001", "BE-001", "BE-PHASE-2", "FE-001", "FE-PHASE-2", "INT-001")
STAMP = "2026-09-15T00:00:00+00:00"
REVISION = "a" * 40


def fixture(completed=0, stage=8, status="Approved", overrides=None, extra_columns=False, closure=False):
    """Small index using the actual Stage 7 column/dependency conventions."""
    overrides = overrides or {}
    metadata = f"""| Field | Value |
|---|---|
| Stage status | `{status}` |
| Decomposition status | `Approved / Delivered` |

"""
    headers = ["Order", "Task ID", "Area", "Short outcome", "Depends on"]
    if extra_columns:
        headers += ["Historical planning-package contract status", "Completed readiness/review status", "Delivery/execution status"]
    else:
        headers += ["Status"]
    headers += ["Contract file"]
    rows = ["| " + " | ".join(headers) + " |", "|" + "|".join("---" for _ in headers) + "|"]
    expressions = (
        f"Stage {stage - 1} closed + Stage {stage} decomposition approved",
        "DOC-001 Accepted / Delivered", "BE-001…001", "Backend Phase 2 PASS",
        "FE-001…001", "Both Phase 2 checkpoints PASS",
    )
    for position, kind in enumerate(KINDS):
        checkpoint = kind.endswith("PHASE-2")
        complete = position < completed
        outcome = "PASS" if complete and checkpoint else "Accepted / Delivered / PASS" if complete and kind.startswith("INT") else "Accepted / Delivered" if complete else "Prepared" if checkpoint else "Approved"
        row = {"Order": str(position), "Task ID": f"S{stage:02d}-{kind}", "Area": kind.split("-")[0],
               "Short outcome": "Fixture outcome", "Depends on": expressions[position], "Status": outcome,
               "Historical planning-package contract status": "Prepared" if checkpoint else "Approved",
               "Completed readiness/review status": ("PASS — checkpoint executed at audited revision" if checkpoint else "PASS — implemented and accepted") if complete else "Prepared",
               "Delivery/execution status": outcome,
               "Contract file": f"tasks/S{stage:02d}-{kind}.md"}
        row.update(overrides.get(kind, {}))
        if not row.pop("omit", False):
            rows.append("| " + " | ".join(f"`{row[header]}`" for header in headers) + " |")
    if closure:
        row = {header: "Prepared" for header in headers}
        row.update({"Order": "6", "Task ID": f"STAGE_{stage:02d}_CLOSURE_REVIEW", "Area": "Closure",
                    "Depends on": "Integration PASS + required fixes/delivery",
                    "Contract file": f"tasks/STAGE_{stage:02d}_CLOSURE_REVIEW.md"})
        rows.append("| " + " | ".join(f"`{row[header]}`" for header in headers) + " |")
    return metadata + "\n".join(rows)


def decision(completed=0, approvals=(), **kwargs):
    return orch.evaluate(8, fixture(completed, **kwargs), set(approvals), lambda contract: True)


class StateMachineTests(unittest.TestCase):
    def test_missing_index_waits_for_saved_planning_files(self):
        result = orch.evaluate(8, None, set(), lambda contract: False)
        self.assertEqual(result.state, "WAITING_FOR_STAGE_INDEX")
        self.assertIn("Save/merge", result.action)

    def test_draft_or_unapproved_stage_does_not_authorize_implementation(self):
        for status in ("Draft", "Not approved"):
            with self.subTest(status=status):
                self.assertEqual(decision(status=status).state, "WAITING_FOR_STAGE_APPROVAL")

    def test_documentation_entry_precedes_backend(self):
        result = decision()
        self.assertEqual((result.state, result.task), ("TASK_READY", "S08-DOC-001"))

    def test_backend_candidate_handoff_contains_only_exact_contract(self):
        result = decision(1)
        self.assertEqual((result.state, result.task), ("TASK_READY", "S08-BE-001"))
        self.assertEqual(result.action, "Next implementation candidate: S08-BE-001\nContract: tasks/S08-BE-001.md\nGive this exact contract to Codex.")

    def test_missing_backend_contract_blocks_handoff(self):
        result = orch.evaluate(8, fixture(1), set(), lambda contract: False)
        self.assertEqual(result.state, "WAITING_FOR_TASK_CONTRACT")
        self.assertEqual(result.contract, "tasks/S08-BE-001.md")

    def test_empty_contract_path_waits(self):
        self.assertEqual(decision(1, overrides={"BE-001": {"Contract file": "TBD"}}).state, "WAITING_FOR_TASK_CONTRACT")

    def test_backend_checkpoint_remains_a_chatgpt_review(self):
        result = decision(2)
        self.assertEqual(result.state, "BACKEND_PHASE_2_READY")
        self.assertIn("ChatGPT", result.action)
        self.assertNotIn("Give this exact contract to Codex", result.action)

    def test_backend_pass_stops_at_owner_frontend_gate(self):
        self.assertEqual(decision(3).state, "OWNER_FRONTEND_APPROVAL_REQUIRED")

    def test_frontend_approval_releases_first_valid_frontend_task(self):
        approvals, _ = orch.apply_command("/approve frontend", "owner", "owner", set(), "OWNER_FRONTEND_APPROVAL_REQUIRED")
        result = decision(3, approvals)
        self.assertEqual((result.state, result.task), ("FRONTEND_TASK_READY", "S08-FE-001"))

    def test_reject_frontend_removes_only_its_approval(self):
        approvals, _ = orch.apply_command("/reject frontend", "owner", "owner", set(orch.GATES))
        self.assertEqual(approvals, {"integration", "closure"})
        self.assertEqual(decision(3, approvals).state, "OWNER_FRONTEND_APPROVAL_REQUIRED")

    def test_frontend_completion_releases_frontend_checkpoint(self):
        self.assertEqual(decision(4, {"frontend"}).state, "FRONTEND_PHASE_2_READY")

    def test_frontend_pass_stops_at_owner_integration_gate(self):
        self.assertEqual(decision(5, {"frontend"}).state, "OWNER_INTEGRATION_APPROVAL_REQUIRED")

    def test_integration_approval_releases_integration(self):
        approvals, _ = orch.apply_command("/approve integration", "owner", "owner", {"frontend"}, "OWNER_INTEGRATION_APPROVAL_REQUIRED")
        result = decision(5, approvals)
        self.assertEqual((result.state, result.task), ("INTEGRATION_TASK_READY", "S08-INT-001"))

    def test_reject_integration_removes_only_its_approval(self):
        approvals, _ = orch.apply_command("/reject integration", "owner", "owner", set(orch.GATES))
        self.assertEqual(approvals, {"frontend", "closure"})

    def test_integration_pass_stops_at_closure_gate(self):
        self.assertEqual(decision(6, {"frontend", "integration"}).state, "OWNER_CLOSURE_APPROVAL_REQUIRED")

    def test_closure_approval_only_releases_chatgpt_review(self):
        approvals, _ = orch.apply_command("/approve closure", "owner", "owner", {"frontend", "integration"}, "OWNER_CLOSURE_APPROVAL_REQUIRED")
        result = decision(6, approvals, closure=True)
        self.assertEqual(result.state, "CLOSURE_REVIEW_READY")
        self.assertIn("ChatGPT Stage Closure Review", result.action)
        self.assertEqual(result.contract, "tasks/STAGE_08_CLOSURE_REVIEW.md")
        self.assertNotEqual(result.state, "STAGE_CLOSED")

    def test_reject_closure_preserves_other_approvals(self):
        approvals, _ = orch.apply_command("/reject closure", "owner", "owner", set(orch.GATES))
        self.assertEqual(approvals, {"frontend", "integration"})

    def test_missing_closure_contract_does_not_release_review(self):
        result = orch.evaluate(8, fixture(6, closure=True), set(orch.GATES), lambda path: False)
        self.assertEqual(result.state, "WAITING_FOR_TASK_CONTRACT")
        self.assertEqual(result.checkpoint, "STAGE_08_CLOSURE_REVIEW")

    def test_only_authoritative_closure_can_close_stage(self):
        self.assertEqual(decision(6, status="Closed / PASS").state, "STAGE_CLOSED")
        self.assertEqual(decision(6, set(orch.GATES)).state, "CLOSURE_REVIEW_READY")

    def test_nonfinal_task_statuses_do_not_count_as_acceptance(self):
        for status in ("Approved", "Prepared", "Implementation complete", "PR merged", "Not accepted", "PASS", "Awaiting PASS", "Unaccepted"):
            with self.subTest(status=status):
                result = decision(1, overrides={"BE-001": {"Status": status}})
                if status == "Approved":
                    self.assertEqual((result.state, result.task), ("TASK_READY", "S08-BE-001"))
                else:
                    self.assertEqual(result.state, "BLOCKED")
                    self.assertIn("S08-BE-001", result.reason)

    def test_supported_acceptance_wording(self):
        for status in ("Accepted", "Accepted / Delivered", "Accepted / Delivered / PASS", "PASS — implemented and accepted"):
            with self.subTest(status=status):
                self.assertEqual(decision(1, overrides={"BE-001": {"Status": status}}).state, "BACKEND_PHASE_2_READY")

    def test_incomplete_delivery_does_not_make_past_review_a_current_approval(self):
        result = decision(2, extra_columns=True, overrides={"BE-001": {"Delivery/execution status": "PR merged"}})
        self.assertEqual(result.state, "BLOCKED")
        self.assertIn("S08-BE-001", result.reason)

    def test_checkpoint_requires_authoritative_pass(self):
        for status in ("Accepted / Delivered", "Approved", "PASS pending", "Not PASS"):
            with self.subTest(status=status):
                self.assertEqual(decision(2, overrides={"BE-PHASE-2": {"Status": status}}).state, "BACKEND_PHASE_2_READY")

    def test_integration_cannot_complete_without_pass(self):
        result = decision(6, {"frontend", "integration"}, overrides={"INT-001": {"Status": "Accepted / Delivered"}})
        self.assertEqual(result.state, "BLOCKED")
        self.assertIn("S08-INT-001", result.reason)

    def test_early_owner_approvals_never_bypass_checkpoints(self):
        self.assertEqual(decision(2, orch.GATES).state, "BACKEND_PHASE_2_READY")
        self.assertEqual(decision(4, orch.GATES).state, "FRONTEND_PHASE_2_READY")

    def test_multiple_integration_tasks_follow_index_order(self):
        markdown = fixture(5) + "\n| 6 | S08-INT-002 | INT | Next integration | INT-001 | Approved | tasks/S08-INT-002.md |"
        result = orch.evaluate(8, markdown, set(orch.GATES), lambda path: True)
        self.assertEqual(result.task, "S08-INT-001")
        markdown = fixture(6) + "\n| 6 | S08-INT-002 | INT | Next integration | INT-001 | Approved | tasks/S08-INT-002.md |"
        self.assertEqual(orch.evaluate(8, markdown, set(orch.GATES), lambda path: True).task, "S08-INT-002")


class ParserSafetyTests(unittest.TestCase):
    def assert_blocked(self, markdown, reason):
        result = orch.evaluate(8, markdown, set(), lambda path: True)
        self.assertEqual(result.state, "BLOCKED")
        self.assertIn(reason, result.reason)

    def test_malformed_table_is_blocked(self):
        self.assert_blocked(fixture().replace("| `0` |", "|"), "Malformed task table")

    def test_missing_table_is_blocked(self):
        self.assert_blocked("# Stage 8\nApproved", "Malformed task table")

    def test_duplicate_task_id_is_blocked(self):
        self.assert_blocked(fixture().replace("`S08-BE-001`", "`S08-DOC-001`"), "Duplicate Task ID")

    def test_wrong_stage_task_is_blocked(self):
        self.assert_blocked(fixture().replace("`S08-BE-001`", "`S09-BE-001`"), "wrong Stage")

    def test_unknown_task_forms_are_blocked(self):
        for identity in ("S8-BE-001", "S08-OPS-001", "S08-BE-PHASE-3", "S08-BE-001-suffix"):
            with self.subTest(identity=identity):
                self.assert_blocked(fixture().replace("`S08-BE-001`", "`" + identity + "`"), "invalid Task ID")

    def test_missing_backend_phase_two_is_blocked(self):
        self.assert_blocked(fixture(overrides={"BE-PHASE-2": {"omit": True}, "FE-001": {"Depends on": "None"}, "INT-001": {"Depends on": "None"}}), "Missing mandatory backend")

    def test_missing_frontend_phase_two_is_blocked(self):
        self.assert_blocked(fixture(overrides={"FE-PHASE-2": {"omit": True}, "INT-001": {"Depends on": "None"}}), "Missing mandatory frontend")

    def test_unknown_dependency_is_blocked(self):
        self.assert_blocked(fixture(overrides={"BE-001": {"Depends on": "S08-DOC-999"}}), "unknown task")

    def test_dependency_prose_is_not_silently_ignored(self):
        self.assert_blocked(fixture(overrides={"BE-001": {"Depends on": "DOC-001 + arbitrary requirement"}}), "unrecognized dependency")

    def test_wrong_stage_dependency_is_blocked(self):
        self.assert_blocked(fixture(overrides={"BE-001": {"Depends on": "S09-DOC-001"}}), "wrong Stage")

    def test_future_dependency_is_impossible_order(self):
        self.assert_blocked(fixture(overrides={"BE-001": {"Depends on": "FE-001"}}), "impossible task order")

    def test_nonincreasing_order_is_blocked(self):
        self.assert_blocked(fixture(overrides={"BE-001": {"Order": "0"}}), "Impossible task order")

    def test_frontend_ready_before_backend_pass_is_blocked(self):
        self.assert_blocked(fixture(2, overrides={"FE-001": {"Status": "Ready"}}), "frontend marked ready")

    def test_integration_ready_before_both_passes_is_blocked(self):
        self.assert_blocked(fixture(3, overrides={"INT-001": {"Status": "Ready"}}), "integration ready")

    def test_contradictory_stage_statuses_are_blocked(self):
        self.assert_blocked(fixture().replace("| Stage status | `Approved` |", "| Stage status | `Approved` |\n| Stage status | Draft |"), "conflicting Stage statuses")

    def test_closure_cannot_override_active_stage_status(self):
        self.assert_blocked(fixture(6).replace("| Stage status | `Approved` |", "| Stage status | `Approved` |\n| Closure | STAGE CLOSED |"), "conflicting Stage statuses")

    def test_closed_stage_with_incomplete_tasks_is_blocked(self):
        self.assert_blocked(fixture(status="Closed / PASS"), "incomplete")

    def test_closed_pending_text_is_not_authoritative_closure(self):
        self.assert_blocked(fixture(6, status="Closed pending review"), "Unrecognized Stage")

    def test_closed_with_fail_is_conflicting_stage_bookkeeping(self):
        self.assert_blocked(fixture(6, status="Closed / FAIL"), "conflicting Stage statuses")

    def test_contradictory_checkpoint_results_are_blocked(self):
        self.assert_blocked(fixture(3, overrides={"BE-PHASE-2": {"Status": "PASS / FAIL"}}), "conflicting acceptance/checkpoint")

    def test_frontend_checkpoint_alone_cannot_bypass_backend_checkpoint(self):
        markdown = fixture(overrides={kind: {"omit": True} for kind in KINDS if kind != "FE-PHASE-2"})
        markdown = markdown.replace("FE-001…001", "None")
        self.assert_blocked(markdown, "Missing mandatory backend")

    def test_conflicting_closure_metadata_is_blocked(self):
        markdown = fixture(6, status="Closed / PASS").replace("| Stage status |", "| Closure | STAGE CLOSED |\n| Closure | Pending |\n| Stage status |")
        self.assert_blocked(markdown, "closure records disagree")

    def test_stage_seven_style_extra_columns_and_closure_bookkeeping(self):
        markdown = fixture(6, stage=7, status="Closed / PASS", extra_columns=True, closure=True)
        index = orch.parse_index(markdown, 7)
        self.assertEqual(len(index.tasks), 6)
        self.assertTrue(all(task.complete for task in index.tasks))
        self.assertEqual(index.tasks[2].dependencies, ("S07-BE-001",))
        self.assertEqual(index.tasks[5].dependencies, ("S07-BE-PHASE-2", "S07-FE-PHASE-2"))
        self.assertEqual(orch.evaluate(7, markdown, set(), lambda path: True).state, "STAGE_CLOSED")

    def test_stage_eight_doc_backend_frontend_and_integration_forms(self):
        parsed = orch.parse_index(fixture(), 8)
        self.assertEqual([task.task_id for task in parsed.tasks], ["S08-" + kind for kind in KINDS])

    def test_dependency_range_expands_each_existing_task(self):
        tasks = {f"S08-BE-{number:03d}": orch.Task(f"S08-BE-{number:03d}", f"BE-{number:03d}", number, None, "", (), ()) for number in range(1, 4)}
        checkpoint = orch.Task("S08-BE-PHASE-2", "BE-PHASE-2", 4, None, "BE-001…003", (), ())
        self.assertEqual(orch.dependencies(checkpoint, 8, tasks), tuple(tasks))

    def test_markdown_links_are_validated_as_paths(self):
        self.assertEqual(orch.relative_path("[Contract](tasks/S08-BE-001.md)"), "tasks/S08-BE-001.md")

    def test_unsafe_paths_are_blocked(self):
        for path in ("../secret.md", "/etc/secret.md", "C:/secret.md", "tasks/../secret.md", "tasks\\secret.md", "https://evil.invalid/a.md", "tasks/a.md$(echo token)"):
            with self.subTest(path=path):
                self.assert_blocked(fixture(overrides={"BE-001": {"Contract file": path}}), "Unsafe repository-relative")

    def test_missing_integration_cannot_bypass_review(self):
        self.assert_blocked(fixture(5, overrides={"INT-001": {"omit": True}}), "integration")

    def test_invalid_stage_number_is_blocked(self):
        for stage in (0, -1, True, "08", "8; echo token", "1.5", ""):
            with self.subTest(stage=stage):
                self.assertEqual(orch.evaluate(stage, None, set(), lambda path: True).state, "BLOCKED")


class ReadinessAndOutcomeTests(unittest.TestCase):
    def test_every_normal_task_requires_current_readiness_approval(self):
        for kind in ("DOC-001", "BE-001", "FE-001", "INT-001"):
            for status in ("Draft", "Blocked", "Prepared", "NOT ACCEPTED", "Rejected", "Not started", "Implementation complete", "PR merged", "Unknown readiness"):
                with self.subTest(kind=kind, status=status):
                    result = decision(KINDS.index(kind), orch.GATES, overrides={kind: {"Status": status}})
                    self.assertEqual(result.state, "BLOCKED")
                    self.assertIn("S08-" + kind, result.reason)
                    self.assertIn("ChatGPT must perform/re-record", result.reason)

    def test_current_approved_status_allows_each_normal_task(self):
        for kind, state in (("DOC-001", "TASK_READY"), ("BE-001", "TASK_READY"),
                            ("FE-001", "FRONTEND_TASK_READY"), ("INT-001", "INTEGRATION_TASK_READY")):
            with self.subTest(kind=kind):
                result = decision(KINDS.index(kind), orch.GATES, overrides={kind: {"Status": "Approved"}})
                self.assertEqual((result.state, result.task), (state, "S08-" + kind))

    def test_historical_planning_approval_does_not_authorize_current_execution(self):
        result = decision(1, extra_columns=True)
        self.assertEqual(result.state, "BLOCKED")
        self.assertIn("current authoritative readiness/review status is not Approved", result.reason)

    def test_explicit_current_review_approval_authorizes_execution(self):
        result = decision(1, extra_columns=True, overrides={"BE-001": {"Completed readiness/review status": "Approved"}})
        self.assertEqual((result.state, result.task), ("TASK_READY", "S08-BE-001"))

    def test_mixed_approved_and_pending_readiness_cannot_authorize_execution(self):
        for status in ("Approved / Draft", "Approved / Prepared", "Approved / Implementation complete"):
            with self.subTest(status=status):
                self.assertEqual(decision(1, overrides={"BE-001": {"Status": status}}).state, "BLOCKED")

    def test_contract_existence_cannot_override_blocked_readiness(self):
        result = orch.evaluate(8, fixture(1, overrides={"BE-001": {"Status": "Blocked"}}), set(), lambda path: True)
        self.assertEqual(result.state, "BLOCKED")
        self.assertIn("Implementation Readiness", result.reason)

    def test_prepared_phase_two_remains_a_review_candidate(self):
        self.assertEqual(decision(2, extra_columns=True).state, "BACKEND_PHASE_2_READY")
        self.assertEqual(decision(4, {"frontend"}, extra_columns=True).state, "FRONTEND_PHASE_2_READY")

    def test_negative_review_and_positive_final_evidence_always_conflict(self):
        for kind in ("BE-001", "BE-PHASE-2", "FE-PHASE-2", "INT-001"):
            for negative in ("NOT ACCEPTED", "REJECTED", "FAIL", "FAILED", "NOT PASS", "BLOCKED", "NOT DELIVERED"):
                with self.subTest(kind=kind, negative=negative):
                    result = decision(KINDS.index(kind) + 1, orch.GATES, extra_columns=True,
                                      overrides={kind: {"Completed readiness/review status": negative}})
                    self.assertEqual(result.state, "BLOCKED")
                    self.assertIn("S08-" + kind, result.reason)
                    self.assertIn("positive and negative", result.reason)

    def test_not_delivered_conflicts_even_when_final_completion_is_false(self):
        result = decision(2, extra_columns=True, overrides={"BE-001": {"Delivery/execution status": "NOT DELIVERED"}})
        self.assertEqual(result.state, "BLOCKED")
        self.assertIn("S08-BE-001", result.reason)
        self.assertIn("positive and negative", result.reason)

    def test_unknown_review_cannot_be_overridden_by_delivered_column(self):
        result = decision(2, extra_columns=True, overrides={"BE-001": {"Completed readiness/review status": "Unrecognized result"}})
        self.assertEqual(result.state, "BLOCKED")
        self.assertIn("unknown authoritative status", result.reason)


class MetadataAndCommandTests(unittest.TestCase):
    def test_metadata_contains_only_stage_and_approvals(self):
        body = orch.render_body(8, decision(), {"frontend"}, REVISION, STAMP)
        self.assertEqual(orch.read_metadata(body, 8), {"frontend"})
        self.assertIn('{"stage":8,"approvals":["frontend"]}', body)

    def test_invalid_hidden_metadata_is_rejected(self):
        payloads = ('{"stage":8,"approvals":["frontend","frontend"]}', '{"stage":8,"approvals":["unknown"]}',
                    '{"stage":7,"approvals":[]}', '{"stage":true,"approvals":[]}',
                    '{"stage":8,"approvals":[],"status":"PASS"}', '{"stage":8,"stage":8,"approvals":[]}',
                    '{"stage":8,"approvals":"frontend"}', "not JSON", "[]")
        for payload in payloads:
            with self.subTest(payload=payload), self.assertRaises(orch.Blocked):
                orch.read_metadata("<!-- TESTLABUZ_ORCHESTRATOR\n" + payload + "\n-->", 8)

    def test_missing_and_duplicate_markers_are_rejected(self):
        body = orch.render_body(8, decision(), set(), REVISION, STAMP)
        for invalid in ("", body + body):
            with self.assertRaises(orch.Blocked):
                orch.read_metadata(invalid, 8)

    def test_authorization_uses_exact_repository_owner_login(self):
        for actor in ("contributor", "Owner", "github-actions[bot]"):
            with self.subTest(actor=actor):
                approvals, message = orch.apply_command("/approve frontend", actor, "owner", {"closure"})
                self.assertEqual(approvals, {"closure"})
                self.assertIn("Denied", message)

    def test_status_and_unsupported_commands_never_mutate_approvals(self):
        for command in ("/status", "/approve all", "/approve Frontend", "/approve frontend\n/approve closure"):
            with self.subTest(command=command):
                self.assertEqual(orch.apply_command(command, "owner", "owner", {"closure"}), ({"closure"}, None))

    def test_approval_set_operations_are_idempotent(self):
        for command in ("/approve frontend", "/reject frontend"):
            approvals, _ = orch.apply_command(command, "owner", "owner", {"integration"}, "OWNER_FRONTEND_APPROVAL_REQUIRED")
            repeated, _ = orch.apply_command(command, "owner", "owner", approvals, "OWNER_FRONTEND_APPROVAL_REQUIRED")
            self.assertEqual(approvals, repeated)

    def test_rendered_input_cannot_inject_markdown_or_mentions(self):
        result = orch.Decision("BLOCKED", "@owner [click](https://evil.invalid) <!-- injected -->")
        body = orch.render_body(8, result, set(), REVISION, STAMP)
        self.assertNotIn("@owner", body)
        self.assertNotIn("[click](https://evil.invalid)", body)
        self.assertNotIn("<!-- injected -->", body)


def comment(identity, command, actor="owner"):
    return {"id": identity, "body": command, "user": {"login": actor},
            "created_at": "2026-09-15T00:00:00Z", "updated_at": "2026-09-15T00:00:00Z"}


class MemoryGitHub:
    owner = "owner"

    def __init__(self):
        self.issue = None
        self.log = []
        self.created = 0
        self.updates = 0
        self.fail_comment_once = False
        self.fail_body_once = False

    def find_issue(self, stage):
        return copy.deepcopy(self.issue)

    def create_issue(self, stage, body):
        self.created += 1
        self.issue = {"number": 1, "title": f"[Orchestrator] Stage {stage} Control", "body": body,
                      "state": "open", "user": {"login": orch.BOT}}
        return copy.deepcopy(self.issue)

    def update_issue(self, number, body, close=False):
        if self.fail_body_once:
            self.fail_body_once = False
            raise orch.Blocked("Simulated body update failure.")
        self.updates += 1
        self.issue["body"] = body
        if close:
            self.issue["state"] = "closed"

    def comments(self, number):
        return copy.deepcopy(self.log)

    def add_comment(self, number, body):
        if self.fail_comment_once:
            self.fail_comment_once = False
            raise orch.Blocked("Simulated API failure.")
        self.log.append(comment(max([item["id"] for item in self.log], default=0) + 1, body, orch.BOT))
        return copy.deepcopy(self.log[-1])


class EventRefreshTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        (self.root / "tasks").mkdir()
        self.index = self.root / "tasks/STAGE_08_TASK_INDEX.md"
        self.index.write_text(fixture(3), encoding="utf-8")
        for kind in KINDS:
            (self.root / f"tasks/S08-{kind}.md").write_text("Approved contract", encoding="utf-8")
        self.api = MemoryGitHub()
        self.refresh()

    def refresh(self, event=None):
        return orch.refresh_stage(self.api, self.root, 8, REVISION, STAMP, event)

    def owner_event(self, identity, command, actor="owner"):
        record = comment(identity, command, actor)
        self.api.log.append(record)
        return {"action": "created", "issue": copy.deepcopy(self.api.issue), "comment": record}

    def receipts_for(self, source_id):
        return [payload for item in self.api.log if (payload := orch.read_receipt(item, 8)) is not None
                and payload["source_comment_id"] == source_id]

    def test_rerun_push_and_merge_refreshes_reuse_same_issue(self):
        initial_body = self.api.issue["body"]
        for _ in range(3):
            self.assertEqual(self.refresh().state, "OWNER_FRONTEND_APPROVAL_REQUIRED")
        self.assertEqual(self.api.created, 1)
        self.assertEqual(self.api.updates, 0)
        self.assertEqual(self.api.issue["body"], initial_body)

    def test_duplicate_owner_event_has_one_receipt_and_one_approval(self):
        event = self.owner_event(10, "/approve frontend")
        self.assertEqual(self.refresh(event).state, "FRONTEND_TASK_READY")
        self.refresh(event)
        self.assertEqual(orch.read_metadata(self.api.issue["body"], 8), {"frontend"})
        self.assertEqual(len(self.receipts_for(10)), 1)

    def test_duplicate_unauthorized_event_denies_once_without_any_state_change(self):
        event = self.owner_event(10, "/approve frontend", "contributor")
        event["comment"]["author_association"] = "OWNER"
        before = copy.deepcopy(self.api.issue)
        self.refresh(event)
        self.refresh(event)
        self.assertEqual(self.api.issue, before)
        self.assertEqual(sum("Denied" in item["body"] for item in self.api.log), 1)

    def test_older_approval_cannot_undo_later_rejection(self):
        approval = self.owner_event(10, "/approve frontend")
        rejection = self.owner_event(20, "/reject frontend")
        self.refresh(rejection)
        self.refresh(approval)
        self.assertEqual(orch.read_metadata(self.api.issue["body"], 8), set())

    def test_older_rejection_cannot_remove_later_approval(self):
        rejection = self.owner_event(10, "/reject frontend")
        approval = self.owner_event(20, "/approve frontend")
        self.refresh(approval)
        self.refresh(rejection)
        self.assertEqual(orch.read_metadata(self.api.issue["body"], 8), {"frontend"})

    def test_receipt_failure_does_not_create_marker_only_approval(self):
        event = self.owner_event(10, "/approve frontend")
        self.api.fail_comment_once = True
        with self.assertRaises(orch.Blocked):
            self.refresh(event)
        self.assertEqual(orch.read_metadata(self.api.issue["body"], 8), set())
        self.refresh(event)
        self.assertEqual(orch.read_metadata(self.api.issue["body"], 8), {"frontend"})
        self.assertEqual(len(self.receipts_for(10)), 1)

    def test_status_does_not_apply_unprocessed_approval_comments(self):
        self.owner_event(10, "/approve frontend")
        status = self.owner_event(20, "/status", "reader")
        self.refresh(status)
        self.assertEqual(orch.read_metadata(self.api.issue["body"], 8), set())

    def test_invalid_metadata_is_preserved_and_blocked(self):
        self.api.issue["body"] = "<!-- TESTLABUZ_ORCHESTRATOR\ninvalid\n-->"
        invalid = self.api.issue["body"]
        with self.assertRaises(orch.Blocked):
            self.refresh()
        first = self.api.issue["body"]
        self.assertIn("BLOCKED", first)
        self.assertTrue(first.endswith(invalid))
        with self.assertRaises(orch.Blocked):
            self.refresh()
        self.assertEqual(self.api.issue["body"], first)

    def test_authoritative_closure_closes_control_issue_and_reuses_it(self):
        self.index.write_text(fixture(6, status="Closed / PASS"), encoding="utf-8")
        self.assertEqual(self.refresh().state, "STAGE_CLOSED")
        self.assertEqual(self.api.issue["state"], "closed")
        self.refresh()
        self.assertEqual(self.api.created, 1)

    def test_first_observation_of_closed_stage_closes_new_control_issue(self):
        self.api = MemoryGitHub()
        self.index.write_text(fixture(6, status="Closed / PASS"), encoding="utf-8")
        self.refresh()
        self.assertEqual(self.api.issue["state"], "closed")
        self.assertEqual(self.api.created, 1)

    def test_manually_closed_active_issue_does_not_create_duplicate(self):
        self.api.issue["state"] = "closed"
        self.assertEqual(self.refresh().state, "BLOCKED")
        self.assertEqual(self.api.created, 1)

    def test_refresh_never_modifies_index_or_contracts(self):
        before = {path: path.read_bytes() for path in (self.root / "tasks").iterdir()}
        self.refresh(self.owner_event(10, "/approve frontend"))
        self.assertEqual(before, {path: path.read_bytes() for path in (self.root / "tasks").iterdir()})

    def test_noncanonical_issue_comment_is_rejected(self):
        event = self.owner_event(10, "/approve frontend")
        event["issue"]["number"] = 99
        with self.assertRaisesRegex(orch.Blocked, "canonical"):
            self.refresh(event)

    def test_early_frontend_approval_is_consumed_without_skipping_later_gate(self):
        self.index.write_text(fixture(2), encoding="utf-8")
        event = self.owner_event(10, "/approve frontend")
        self.assertEqual(self.refresh(event).state, "BACKEND_PHASE_2_READY")
        self.assertEqual(orch.read_metadata(self.api.issue["body"], 8), set())
        self.assertEqual(self.receipts_for(10)[0]["result"], "not_applicable")
        self.index.write_text(fixture(3), encoding="utf-8")
        self.assertEqual(self.refresh().state, "OWNER_FRONTEND_APPROVAL_REQUIRED")
        self.assertEqual(self.refresh(event).state, "OWNER_FRONTEND_APPROVAL_REQUIRED")
        self.assertEqual(len(self.receipts_for(10)), 1)

    def test_early_integration_and_closure_approvals_are_not_persisted(self):
        for identity, gate in ((10, "integration"), (20, "closure")):
            with self.subTest(gate=gate):
                self.assertEqual(self.refresh(self.owner_event(identity, f"/approve {gate}")).state, "OWNER_FRONTEND_APPROVAL_REQUIRED")
                self.assertEqual(orch.read_metadata(self.api.issue["body"], 8), set())
                self.assertEqual(self.receipts_for(identity)[0]["result"], "not_applicable")

    def test_matching_owner_commands_advance_exactly_one_gate_at_a_time(self):
        self.assertEqual(self.refresh(self.owner_event(10, "/approve frontend")).state, "FRONTEND_TASK_READY")
        self.assertEqual(orch.read_metadata(self.api.issue["body"], 8), {"frontend"})
        self.index.write_text(fixture(5), encoding="utf-8")
        self.assertEqual(self.refresh().state, "OWNER_INTEGRATION_APPROVAL_REQUIRED")
        self.assertEqual(self.refresh(self.owner_event(20, "/approve integration")).state, "INTEGRATION_TASK_READY")
        self.assertEqual(orch.read_metadata(self.api.issue["body"], 8), {"frontend", "integration"})
        self.index.write_text(fixture(6), encoding="utf-8")
        self.assertEqual(self.refresh().state, "OWNER_CLOSURE_APPROVAL_REQUIRED")
        self.assertEqual(self.refresh(self.owner_event(30, "/approve closure")).state, "CLOSURE_REVIEW_READY")
        self.assertEqual(self.api.issue["state"], "open")

    def test_late_approval_records_not_applicable_and_preserves_state(self):
        self.refresh(self.owner_event(10, "/approve frontend"))
        self.assertEqual(self.refresh(self.owner_event(20, "/approve frontend")).state, "FRONTEND_TASK_READY")
        self.assertEqual(self.receipts_for(20)[0]["result"], "not_applicable")
        self.assertEqual(orch.read_metadata(self.api.issue["body"], 8), {"frontend"})

    def test_rejection_removes_only_named_receipt_backed_approval(self):
        self.refresh(self.owner_event(10, "/approve frontend"))
        self.index.write_text(fixture(5), encoding="utf-8")
        self.refresh(self.owner_event(20, "/approve integration"))
        self.refresh(self.owner_event(30, "/reject frontend"))
        self.assertEqual(orch.read_metadata(self.api.issue["body"], 8), {"integration"})

    def test_forged_hidden_approval_cannot_authorize_refresh(self):
        self.api.issue["body"] = self.api.issue["body"].replace('"approvals":[]', '"approvals":["frontend"]')
        with self.assertRaisesRegex(orch.Blocked, "cache disagrees"):
            self.refresh()
        self.assertIn("Current state: BLOCKED", self.api.issue["body"])
        self.assertEqual(orch.reconstruct_approvals(self.api.log, 8, "owner")[0], set())

    def test_owner_comment_without_bot_receipt_cannot_support_marker_approval(self):
        self.owner_event(10, "/approve frontend")
        self.api.issue["body"] = self.api.issue["body"].replace('"approvals":[]', '"approvals":["frontend"]')
        with self.assertRaisesRegex(orch.Blocked, "cache disagrees"):
            self.refresh(self.owner_event(20, "/status", "reader"))

    def test_nonowner_fake_receipt_cannot_support_marker_approval(self):
        self.owner_event(10, "/approve frontend")
        self.api.log.append(comment(11, orch.receipt_body(8, 10, "/approve frontend", "applied", "OWNER_FRONTEND_APPROVAL_REQUIRED"), "collaborator"))
        self.api.issue["body"] = self.api.issue["body"].replace('"approvals":[]', '"approvals":["frontend"]')
        with self.assertRaisesRegex(orch.Blocked, "cache disagrees"):
            self.refresh()

    def test_edited_owner_command_cannot_originate_approval(self):
        event = copy.deepcopy(self.owner_event(10, "/approve frontend"))
        self.api.log[0]["updated_at"] = "2026-09-15T00:00:01Z"
        with self.assertRaisesRegex(orch.Blocked, "edited"):
            self.refresh(event)
        self.assertEqual(self.receipts_for(10), [])

    def test_edited_event_is_not_an_authorized_creation_event(self):
        event = self.owner_event(10, "/approve frontend")
        event["action"] = "edited"
        with self.assertRaisesRegex(orch.Blocked, "created issue_comment"):
            self.refresh(event)

    def test_edited_owner_source_invalidates_existing_approval(self):
        self.refresh(self.owner_event(10, "/approve frontend"))
        self.api.log[0]["updated_at"] = "2026-09-15T00:00:01Z"
        with self.assertRaisesRegex(orch.Blocked, "edited"):
            self.refresh()

    def test_changed_owner_source_cannot_reuse_existing_receipt(self):
        self.refresh(self.owner_event(10, "/approve frontend"))
        self.api.log[0]["body"] = "/approve closure"
        self.api.log[0]["updated_at"] = "2026-09-15T00:00:01Z"
        with self.assertRaisesRegex(orch.Blocked, "mismatched command evidence"):
            self.refresh()

    def test_edited_bot_receipt_invalidates_existing_approval(self):
        self.refresh(self.owner_event(10, "/approve frontend"))
        self.api.log[-1]["updated_at"] = "2026-09-15T00:00:01Z"
        with self.assertRaisesRegex(orch.Blocked, "Edited orchestrator receipt"):
            self.refresh()

    def test_missing_owner_source_invalidates_existing_approval(self):
        self.refresh(self.owner_event(10, "/approve frontend"))
        self.api.log = [item for item in self.api.log if item["id"] != 10]
        with self.assertRaisesRegex(orch.Blocked, "missing"):
            self.refresh()

    def test_missing_bot_receipt_cannot_preserve_cached_approval(self):
        self.refresh(self.owner_event(10, "/approve frontend"))
        self.api.log = [item for item in self.api.log if item["user"]["login"] != orch.BOT]
        with self.assertRaisesRegex(orch.Blocked, "cache disagrees"):
            self.refresh()

    def test_deleted_rejection_receipt_cannot_resurrect_prior_approval(self):
        self.refresh(self.owner_event(10, "/approve frontend"))
        self.refresh(self.owner_event(20, "/reject frontend"))
        self.api.log.pop()
        with self.assertRaisesRegex(orch.Blocked, "no valid receipt"):
            self.refresh()

    def test_deleted_rejection_receipt_and_forged_cache_cannot_retain_approval(self):
        self.refresh(self.owner_event(10, "/approve frontend"))
        self.refresh(self.owner_event(20, "/reject frontend"))
        self.api.log.pop()
        self.api.issue["body"] = self.api.issue["body"].replace('"approvals":[]', '"approvals":["frontend"]')
        with self.assertRaisesRegex(orch.Blocked, "no valid receipt"):
            self.refresh()

    def test_later_inapplicable_approval_cannot_cancel_valid_rejection(self):
        self.refresh(self.owner_event(10, "/approve frontend"))
        rejection = self.owner_event(20, "/reject frontend")
        late_approval = self.owner_event(30, "/approve frontend")
        with self.assertRaisesRegex(orch.Blocked, "no valid receipt"):
            self.refresh(late_approval)
        self.assertEqual(self.refresh(rejection).state, "OWNER_FRONTEND_APPROVAL_REQUIRED")
        self.assertEqual(orch.read_metadata(self.api.issue["body"], 8), set())

    def test_owner_rejection_safely_resolves_interrupted_approval_body_write(self):
        approval = self.owner_event(10, "/approve frontend")
        self.api.fail_body_once = True
        with self.assertRaises(orch.Blocked):
            self.refresh(approval)
        self.assertEqual(self.refresh(self.owner_event(20, "/reject frontend")).state, "OWNER_FRONTEND_APPROVAL_REQUIRED")
        self.assertEqual(orch.read_metadata(self.api.issue["body"], 8), set())

    def test_duplicate_valid_bot_receipt_does_not_duplicate_approval(self):
        self.refresh(self.owner_event(10, "/approve frontend"))
        duplicate = copy.deepcopy(self.api.log[-1])
        duplicate["id"] += 1
        self.api.log.append(duplicate)
        self.assertEqual(self.refresh().state, "FRONTEND_TASK_READY")
        self.assertEqual(orch.read_metadata(self.api.issue["body"], 8), {"frontend"})

    def test_receipt_body_failure_can_retry_without_marker_authority(self):
        event = self.owner_event(10, "/approve frontend")
        self.api.fail_body_once = True
        with self.assertRaisesRegex(orch.Blocked, "body update"):
            self.refresh(event)
        self.assertEqual(orch.read_metadata(self.api.issue["body"], 8), set())
        self.assertEqual(orch.reconstruct_approvals(self.api.log, 8, "owner")[0], {"frontend"})
        self.assertEqual(len(self.receipts_for(10)), 1)
        self.assertEqual(self.refresh(event).state, "FRONTEND_TASK_READY")
        self.assertEqual(len(self.receipts_for(10)), 1)
        self.assertEqual(orch.read_metadata(self.api.issue["body"], 8), {"frontend"})

    def test_status_cannot_repair_unmatched_receipt_cache_by_granting(self):
        event = self.owner_event(10, "/approve frontend")
        self.api.fail_body_once = True
        with self.assertRaises(orch.Blocked):
            self.refresh(event)
        with self.assertRaisesRegex(orch.Blocked, "cache disagrees"):
            self.refresh(self.owner_event(20, "/status", "reader"))


class TriggerAndApiTests(unittest.TestCase):
    def test_comment_validation_requires_valid_created_and_updated_timestamps(self):
        for field, value in (("created_at", None), ("updated_at", "not a timestamp"),
                             ("created_at", "2026-02-30T00:00:00Z"), ("updated_at", "2026-09-14T00:00:00Z")):
            with self.subTest(field=field, value=value), self.assertRaises(orch.Blocked):
                orch.comment_record({**comment(1, "/approve frontend"), field: value})

    def test_dispatch_validates_stage(self):
        self.assertEqual(orch.event_stages("workflow_dispatch", {"inputs": {"stage": "8"}}), [8])
        with self.assertRaises(orch.Blocked):
            orch.event_stages("workflow_dispatch", {"inputs": {"stage": "0"}})

    def test_push_detects_only_canonical_index_paths_and_deduplicates(self):
        paths = ["tasks/STAGE_08_TASK_INDEX.md", "tasks/STAGE_07_TASK_INDEX.md", "tasks/STAGE_08_TASK_INDEX.md", "tasks/S08-BE-001.md", "../tasks/STAGE_09_TASK_INDEX.md"]
        self.assertEqual(orch.event_stages("push", {"ref": "refs/heads/main"}, paths), [7, 8])
        self.assertEqual(orch.event_stages("push", {"ref": "refs/heads/other"}, paths), [])

    def test_comment_trigger_requires_exact_control_title(self):
        event = {"action": "created", "issue": {"title": "[Orchestrator] Stage 8 Control"}, "comment": comment(1, "/status")}
        self.assertEqual(orch.event_stages("issue_comment", event), [8])
        event["issue"]["title"] += " suffix"
        self.assertEqual(orch.event_stages("issue_comment", event), [])

    def test_pr_comment_is_not_a_control_issue(self):
        event = {"action": "created", "issue": {"title": "[Orchestrator] Stage 8 Control", "pull_request": {}}, "comment": comment(1, "/approve frontend")}
        self.assertEqual(orch.event_stages("issue_comment", event), [])

    def test_merged_pr_detects_task_ids_from_each_field_but_never_sets_status(self):
        event = {"action": "closed", "pull_request": {"merged": True, "title": "S08-BE-001 implementation",
                 "body": "S07-INT-001 and S08-UNKNOWN-001", "head": {"ref": "codex/S09-DOC-001-docs"}, "base": {"ref": "main"}}}
        self.assertEqual(orch.event_stages("pull_request_target", event), [7, 8, 9])
        event["pull_request"]["merged"] = False
        self.assertEqual(orch.event_stages("pull_request_target", event), [])

    def test_push_git_arguments_are_separate_validated_revisions(self):
        with patch.object(orch, "git_output", return_value="tasks/STAGE_08_TASK_INDEX.md\0") as git:
            self.assertEqual(orch.changed_index_paths("root", "a" * 40, "b" * 40), ["tasks/STAGE_08_TASK_INDEX.md"])
            self.assertEqual(git.call_args.args[1], ["diff", "--name-only", "--no-renames", "-z", "a" * 40, "b" * 40, "--", "tasks/"])
        with self.assertRaises(orch.Blocked):
            orch.changed_index_paths("root", "a; echo token", "b" * 40)

    def test_repository_cannot_control_api_origin(self):
        for repository in ("https://evil.invalid/repo", "owner/repo/../../x", "owner/..", "owner/repo?token=x"):
            with self.subTest(repository=repository), self.assertRaises(orch.Blocked):
                orch.GitHub(repository, "test-token")

    def test_api_has_no_repository_mutation_or_arbitrary_endpoint(self):
        api = orch.GitHub("owner/repo", "test-token")
        api.opener = Mock()
        for method, endpoint, payload in (("PUT", "/pulls/1/merge", {}), ("POST", "https://evil.invalid", {}),
                                          ("PATCH", "/issues/1", {"state": "open", "body": "x"}),
                                          ("POST", "/issues", {"title": "x", "body": "x", "assignees": ["owner"]})):
            with self.subTest(endpoint=endpoint), self.assertRaises(orch.Blocked):
                api.request(method, endpoint, payload)
        api.opener.open.assert_not_called()

    def test_api_failure_never_exposes_token_or_response_body(self):
        api = orch.GitHub("owner/repo", "secret-test-token")
        api.opener = Mock()
        api.opener.open.side_effect = HTTPError("url", 403, "secret-test-token", {}, None)
        with self.assertRaises(orch.Blocked) as caught:
            api.request("GET", "/issues?state=all&per_page=100&page=1")
        self.assertEqual(str(caught.exception), "GitHub API request failed (HTTP 403).")

    def test_api_redirect_is_refused(self):
        with self.assertRaises(orch.Blocked):
            orch.NoRedirects().redirect_request(None, None, 302, "redirect", {}, "https://evil.invalid")

    def test_unsafe_api_response_and_duplicate_control_issues_are_blocked(self):
        api = orch.GitHub("owner/repo", "test-token")
        with patch.object(api, "request", return_value={"unexpected": "object"}):
            with self.assertRaisesRegex(orch.Blocked, "invalid page"):
                api.find_issue(8)
        issue = {"number": 1, "title": "[Orchestrator] Stage 8 Control", "state": "open", "body": "", "user": {"login": orch.BOT}}
        with patch.object(api, "pages", return_value=[issue, {**issue, "number": 2}]):
            with self.assertRaisesRegex(orch.Blocked, "Multiple open"):
                api.find_issue(8)

    def test_forged_control_issue_cannot_supply_approvals(self):
        api = orch.GitHub("owner/repo", "test-token")
        issue = {"number": 1, "title": "[Orchestrator] Stage 8 Control", "state": "open", "body": "", "user": {"login": "attacker"}}
        with patch.object(api, "pages", return_value=[issue]):
            with self.assertRaisesRegex(orch.Blocked, "issue author"):
                api.find_issue(8)

    def test_boolean_api_identifier_is_rejected(self):
        with self.assertRaises(orch.Blocked):
            orch.positive_id(True)


if __name__ == "__main__":
    unittest.main()
