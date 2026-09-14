"""GitHub-native Stage control. Markdown is input data, never executable code."""

import argparse
from dataclasses import dataclass
from datetime import datetime, timezone
import html
import json
import os
from pathlib import Path, PurePosixPath
import re
import subprocess
import sys
from urllib.error import HTTPError, URLError
from urllib.request import HTTPRedirectHandler, Request, build_opener


TASK_PATTERN = r"S(?P<stage>[0-9]{2,})-(?P<kind>DOC-[0-9]+|BE-(?:[0-9]+|PHASE-2)|FE-(?:[0-9]+|PHASE-2)|INT-[0-9]+)"
TASK_ID = re.compile(TASK_PATTERN)
TASK_MENTION = re.compile(r"(?<![A-Za-z0-9])" + TASK_PATTERN + r"(?![A-Za-z0-9]|-[0-9])")
INDEX_PATH = re.compile(r"tasks/STAGE_([0-9]{2,})_TASK_INDEX\.md")
CONTROL_TITLE = re.compile(r"\[Orchestrator\] Stage ([1-9][0-9]*) Control")
CLOSURE_ID = re.compile(r"STAGE_([0-9]{2,})_CLOSURE_REVIEW")
REPOSITORY = re.compile(r"[A-Za-z0-9][A-Za-z0-9-]*/[A-Za-z0-9_.-]+")
SHA = re.compile(r"[0-9a-f]{40}")
GATES = ("frontend", "integration", "closure")
APPROVAL_STATES = {gate: f"OWNER_{gate.upper()}_APPROVAL_REQUIRED" for gate in GATES}
COMMANDS = frozenset({"/status"} | {f"/{verb} {gate}" for verb in ("approve", "reject") for gate in GATES})
STATES = frozenset({
    "WAITING_FOR_STAGE_INDEX", "WAITING_FOR_STAGE_APPROVAL", "WAITING_FOR_TASK_CONTRACT",
    "TASK_READY", "BACKEND_PHASE_2_READY", "OWNER_FRONTEND_APPROVAL_REQUIRED",
    "FRONTEND_TASK_READY", "FRONTEND_PHASE_2_READY", "OWNER_INTEGRATION_APPROVAL_REQUIRED",
    "INTEGRATION_TASK_READY", "OWNER_CLOSURE_APPROVAL_REQUIRED", "CLOSURE_REVIEW_READY",
    "BLOCKED", "STAGE_CLOSED",
})
MARKER = "TESTLABUZ_ORCHESTRATOR"
BOT = "github-actions[bot]"
RECEIPT_MARKER = "STAGE_CONTROL_RECEIPT"
NEGATIVE_OUTCOMES = frozenset({"not accepted", "rejected", "fail", "failed", "not pass", "blocked", "not delivered"})
READY_OUTCOMES = frozenset({"approved", "ready", "implementation ready"})
PENDING_OUTCOMES = frozenset({"draft", "prepared", "not started", "implementation complete", "pr merged",
                              "in progress", "pending", "pass pending", "awaiting pass", "unaccepted", "", "-", "—", "n/a"})


class Blocked(ValueError):
    """A safe, non-secret reason that may be shown in the control issue."""


def stage_number(value):
    if isinstance(value, bool) or not re.fullmatch(r"[1-9][0-9]*", str(value)):
        raise Blocked("Invalid Stage number: expected a positive integer.")
    try:
        return int(value)
    except ValueError:
        raise Blocked("Invalid Stage number: integer is too large.") from None


def index_path(stage):
    return f"tasks/STAGE_{stage_number(stage):02d}_TASK_INDEX.md"


def plain(value):
    return value.strip().replace("`", "").replace("**", "").strip()


def key(value):
    return re.sub(r"\s+", " ", plain(value).lower())


def relative_path(value):
    value = plain(value)
    link = re.fullmatch(r"\[[^\]]+\]\(([^)]+)\)", value)
    if link:
        value = link[1]
    if value in ("", "-", "—", "TBD", "Pending"):
        return None
    if (not re.fullmatch(r"[A-Za-z0-9_./-]+\.md", value)
            or PurePosixPath(value).is_absolute()
            or any(part in ("", ".", "..") for part in value.split("/"))):
        raise Blocked("Unsafe repository-relative contract path.")
    return value


def local_path(root, relative):
    resolved_root = Path(root).resolve()
    resolved = (resolved_root / relative).resolve()
    if not resolved.is_relative_to(resolved_root):
        raise Blocked("Repository path resolves outside the checkout.")
    return resolved


def terminal_word(value, word):
    # Outcome prefixes only: 'not accepted', 'awaiting PASS', and prose are not evidence.
    prefix = re.split(r"\s+[—–-]\s+|;", plain(value), maxsplit=1)[0]
    return any(key(part) == word for part in prefix.split("/"))


def passed(value):
    return terminal_word(value, "pass")


def accepted(value):
    return terminal_word(value, "accepted") or (
        passed(value) and re.search(r"\b(?:implemented and accepted|accepted and delivered)\b", key(value)) is not None
    )


@dataclass(frozen=True)
class Outcome:
    positive: frozenset
    negative: frozenset
    ready: bool
    known: bool


def classify_outcome(value):
    prefix = re.split(r"\s+[—–-]\s+|;", plain(value), maxsplit=1)[0]
    terms = frozenset(key(part) for part in prefix.split("/"))
    positive = terms & {"accepted", "delivered", "pass", "completed"}
    negative = terms & NEGATIVE_OUTCOMES
    known = terms <= (READY_OUTCOMES | PENDING_OUTCOMES | NEGATIVE_OUTCOMES | {"accepted", "delivered", "pass", "completed"})
    return Outcome(positive, negative, bool(terms) and terms <= READY_OUTCOMES, known)


@dataclass
class Task:
    task_id: str
    kind: str
    order: int
    contract: str | None
    dependency_text: str
    outcomes: tuple
    delivery: tuple
    dependencies: tuple = ()
    readiness: tuple = ()

    @property
    def checkpoint(self):
        return self.kind.endswith("PHASE-2")

    @property
    def complete(self):
        if self.checkpoint:
            return any(passed(value) for value in self.outcomes + self.delivery)
        evidence = self.outcomes + self.delivery
        if self.kind.startswith("INT-"):
            complete = any(passed(value) for value in evidence)
        else:
            complete = any(accepted(value) for value in evidence)
        if self.delivery:
            complete = complete and any(terminal_word(value, "delivered") for value in self.delivery)
        return complete

    @property
    def started(self):
        return self.complete or any(
            re.match(r"^(?:ready|implementation ready|in progress|implementation complete)\b", key(value))
            for value in self.outcomes + self.delivery
        )

    @property
    def currently_approved(self):
        return bool(self.readiness) and all(classify_outcome(value).ready for value in self.readiness)

    def validate_outcomes(self):
        outcomes = [classify_outcome(value) for value in self.outcomes + self.delivery]
        if any(outcome.positive for outcome in outcomes) and any(outcome.negative for outcome in outcomes):
            raise Blocked(f"{self.task_id}: conflicting acceptance/checkpoint results: positive and negative authoritative evidence coexist.")
        if any(not outcome.known for outcome in outcomes):
            raise Blocked(f"{self.task_id}: unknown authoritative status; Project Owner: ChatGPT must perform/re-record the Implementation Readiness or fix/review decision.")


@dataclass
class StageIndex:
    stage: int
    status: str
    approved: bool
    closed: bool
    tasks: list
    closure_contract: str | None = None
    closure_id: str | None = None


@dataclass
class Decision:
    state: str
    action: str
    status: str = "Unavailable"
    task: str = "None"
    checkpoint: str = "None"
    dependency: str = "Not evaluated"
    contract: str | None = None
    reason: str = "None"


def table_rows(markdown):
    """Yield only Markdown tables; prose, code fences, and task descriptions have no authority."""
    tables = []
    current = []
    fenced = False
    for line in markdown.splitlines() + [""]:
        if re.match(r"^\s*(```|~~~)", line):
            fenced = not fenced
        if not fenced and line.strip().startswith("|"):
            current.append([cell.strip() for cell in re.split(r"(?<!\\)\|", line.strip().strip("|"))])
        elif current:
            tables.append(current)
            current = []
    return tables


def status_category(value, decomposition=False):
    normalized = key(value)
    if (any(terminal_word(value, word) for word in ("closed", "stage closed", "approved"))
            and any(terminal_word(value, word) for word in ("fail", "rejected", "draft", "not approved"))):
        raise Blocked("Multiple conflicting Stage statuses in one metadata value.")
    if terminal_word(value, "closed") or terminal_word(value, "stage closed"):
        return "closed"
    if re.match(r"^(?:draft|not[ -]approved|prepared|pending|awaiting approval)\b", normalized):
        return "draft"
    if re.match(r"^approved\b", normalized):
        return "approved"
    if not decomposition and re.match(r"^(?:open|active|in progress|implementation|ready)\b", normalized):
        return "active"
    raise Blocked("Unrecognized Stage/decomposition status.")


def stage_status(metadata):
    statuses = metadata.get("stage status", [])
    decompositions = metadata.get("decomposition status", [])
    closures = metadata.get("closure", [])
    categories = {status_category(value) for value in statuses}
    decomposition_categories = {status_category(value, True) for value in decompositions}
    if len(categories) > 1 or len(decomposition_categories) > 1:
        raise Blocked("Multiple conflicting Stage statuses.")
    closure_recorded = any(re.fullmatch(r"(?:stage )?closed(?:\s*/\s*pass)?", key(value)) for value in closures)
    if closure_recorded and any(not re.fullmatch(r"(?:stage )?closed(?:\s*/\s*pass)?", key(value)) for value in closures):
        raise Blocked("Multiple conflicting Stage statuses: closure records disagree.")
    if closure_recorded and categories and categories != {"closed"}:
        raise Blocked("Multiple conflicting Stage statuses: closure and Stage status disagree.")
    closed = categories == {"closed"} or closure_recorded
    if "draft" in decomposition_categories and (closed or "approved" in categories):
        raise Blocked("Multiple conflicting Stage statuses: decomposition is not approved.")
    approved = ("approved" in categories or "approved" in decomposition_categories) and "draft" not in categories
    observed = "; ".join(f"{label}: {value}" for label, values in (
        ("Stage", statuses), ("Decomposition", decompositions), ("Closure", closures)
    ) for value in dict.fromkeys(values)) or "Not recorded"
    return observed, approved, closed


def dependencies(task, stage, tasks):
    expression = plain(task.dependency_text)
    if key(expression) in ("", "-", "—", "none", "n/a"):
        return ()
    references = []

    def add(task_id):
        if task_id not in tasks:
            raise Blocked(f"{task.task_id}: dependency references unknown task {task_id}.")
        if tasks[task_id].order >= task.order:
            raise Blocked(f"{task.task_id}: impossible task order; dependency {task_id} is not earlier.")
        references.append(task_id)

    aliases = (
        (r"\bBoth Phase 2 checkpoints(?: PASS)?\b", ("BE-PHASE-2", "FE-PHASE-2")),
        (r"\bBackend Phase 2(?: PASS)?\b", ("BE-PHASE-2",)),
        (r"\bFrontend Phase 2(?: PASS)?\b", ("FE-PHASE-2",)),
    )
    for pattern, kinds in aliases:
        if re.search(pattern, expression, re.I):
            for kind in kinds:
                add(f"S{stage:02d}-{kind}")
            expression = re.sub(pattern, "", expression, flags=re.I)

    reference = re.compile(
        r"(?<![A-Za-z0-9-])(?:S(?P<stage>[0-9]{2,})-)?"
        r"(?P<area>DOC|BE|FE|INT)-(?P<number>PHASE-2|[0-9]+)"
        r"(?:(?:…|\.\.\.|[–-])(?P<end>[0-9]+))?(?![A-Za-z0-9-])"
    )

    def replace(match):
        referenced_stage = int(match["stage"]) if match["stage"] else stage
        if referenced_stage != stage or (match["stage"] and match["stage"] != f"{stage:02d}"):
            raise Blocked(f"{task.task_id}: dependency belongs to wrong Stage.")
        number, end = match["number"], match["end"]
        if end:
            if number == "PHASE-2" or not (int(number) <= int(end) <= int(number) + 1000):
                raise Blocked(f"{task.task_id}: invalid dependency range.")
            numbers = [str(item).zfill(len(number)) for item in range(int(number), int(end) + 1)]
        else:
            numbers = [number]
        for item in numbers:
            add(f"S{stage:02d}-{match['area']}-{item}")
        return ""

    expression = reference.sub(replace, expression)
    # Entry declarations are already part of this authoritative index, not another Stage database.
    expression = re.sub(rf"\bStage {stage - 1} closed\b|\bStage {stage} decomposition approved\b", "", expression, flags=re.I)
    expression = re.sub(r"\b(?:Accepted|Delivered|PASS|and)\b|[\s+,;/]", "", expression, flags=re.I)
    if expression:
        raise Blocked(f"{task.task_id}: unrecognized dependency expression.")
    return tuple(dict.fromkeys(references))


def parse_index(markdown, stage):
    stage = stage_number(stage)
    metadata = {}
    tasks = []
    closure_contract = None
    closure_seen = False
    task_tables = 0
    for rows in table_rows(markdown):
        headers = [key(cell) for cell in rows[0]]
        if "task id" not in headers:
            for row in rows[2:]:
                if len(row) == 2 and key(row[0]) in ("stage status", "decomposition status", "closure"):
                    metadata.setdefault(key(row[0]), []).append(plain(row[1]))
            continue
        task_tables += 1
        if (len(set(headers)) != len(headers) or len(rows) < 3
                or len(rows[1]) != len(headers)
                or not all(re.fullmatch(r":?-{3,}:?", cell.strip()) for cell in rows[1])):
            raise Blocked("Malformed task table: invalid header/separator or no tasks.")

        def column(names, required=True):
            matches = [position for position, name in enumerate(headers) if name in names]
            if len(matches) > 1 or (required and not matches):
                raise Blocked("Malformed task table: missing or ambiguous required columns.")
            return matches[0] if matches else None

        identity = headers.index("task id")
        order = column({"order", "#"}, False)
        contract = column({"contract", "contract file", "contract path"})
        depends = column({"depends on", "dependencies", "dependency"})
        outcome_columns = [i for i, name in enumerate(headers) if any(
            word in name for word in ("status", "result", "review", "acceptance")
        ) and not any(word in name for word in ("historical", "planning", "contract", "delivery", "execution"))]
        delivery_columns = [i for i, name in enumerate(headers) if "delivery" in name or "execution" in name]
        readiness_columns = [i for i in outcome_columns if "readiness" in headers[i] or "review" in headers[i]]
        if not readiness_columns:
            readiness_columns = outcome_columns
        if not outcome_columns and not delivery_columns:
            raise Blocked("Malformed task table: no authoritative status columns.")
        for row in rows[2:]:
            if len(row) != len(headers):
                raise Blocked("Malformed task table: row width differs from header.")
            task_id = plain(row[identity])
            closure = CLOSURE_ID.fullmatch(task_id)
            if closure:
                if closure_seen or closure[1] != f"{stage:02d}":
                    raise Blocked("Duplicate or wrong-Stage closure bookkeeping row.")
                if order is not None and (not plain(row[order]).isdigit() or (tasks and int(plain(row[order])) <= tasks[-1].order)):
                    raise Blocked("Impossible task order: invalid closure bookkeeping order.")
                closure_seen = True
                closure_contract = relative_path(row[contract])
                continue
            match = TASK_ID.fullmatch(task_id)
            if not match:
                raise Blocked("Malformed task table: invalid Task ID.")
            if match["stage"] != f"{stage:02d}":
                raise Blocked(f"{task_id}: task belongs to wrong Stage.")
            if closure_seen:
                raise Blocked("Impossible task order: task follows closure bookkeeping.")
            position = plain(row[order]) if order is not None else str(len(tasks))
            if not re.fullmatch(r"[0-9]+", position):
                raise Blocked("Malformed task table: invalid order.")
            tasks.append(Task(task_id, match["kind"], int(position), relative_path(row[contract]),
                              row[depends], tuple(row[i] for i in outcome_columns),
                              tuple(row[i] for i in delivery_columns), readiness=tuple(row[i] for i in readiness_columns)))
    if task_tables != 1 or not tasks:
        raise Blocked("Malformed task table: expected exactly one authoritative Task ID table.")
    by_id = {task.task_id: task for task in tasks}
    if len(by_id) != len(tasks):
        raise Blocked("Duplicate Task ID.")
    if any(left.order >= right.order for left, right in zip(tasks, tasks[1:])):
        raise Blocked("Impossible task order: order values must increase.")
    ranks = {"DOC": 0, "BE": 1, "BE-PHASE-2": 2, "FE": 3, "FE-PHASE-2": 4, "INT": 5}
    order_ranks = [ranks[task.kind if task.checkpoint else task.kind.split("-")[0]] for task in tasks]
    if order_ranks != sorted(order_ranks):
        raise Blocked("Impossible task order: workflow blocks/checkpoints are out of sequence.")
    for task in tasks:
        task.dependencies = dependencies(task, stage, by_id)
    observed, approved, closed = stage_status(metadata)
    return StageIndex(stage, observed, approved, closed, tasks, closure_contract,
                      f"STAGE_{stage:02d}_CLOSURE_REVIEW" if closure_seen else None)


def evaluate(stage, markdown, approvals, contract_exists):
    observed = "Unavailable"
    try:
        stage = stage_number(stage)
        validate_approvals(approvals)
        if markdown is None:
            return Decision("WAITING_FOR_STAGE_INDEX", f"Save/merge Stage planning files, starting with {index_path(stage)}.")
        index = parse_index(markdown, stage)
        observed = index.status
        by_id = {task.task_id: task for task in index.tasks}
        backend = [task for task in index.tasks if task.kind.startswith("BE-") and not task.checkpoint]
        frontend = [task for task in index.tasks if task.kind.startswith("FE-") and not task.checkpoint]
        integration = [task for task in index.tasks if task.kind.startswith("INT-")]
        backend_phase = by_id.get(f"S{stage:02d}-BE-PHASE-2")
        frontend_phase = by_id.get(f"S{stage:02d}-FE-PHASE-2")
        if (backend or frontend or frontend_phase or integration) and backend_phase is None:
            raise Blocked("Missing mandatory backend Phase 2 checkpoint.")
        if (frontend or integration) and frontend_phase is None:
            raise Blocked("Missing mandatory frontend Phase 2 checkpoint.")
        for task in index.tasks:
            task.validate_outcomes()
            if task.started and task.kind.startswith("FE-") and not backend_phase.complete:
                raise Blocked(f"{task.task_id}: frontend marked ready before backend Phase 2 PASS.")
            if task.started and task.kind.startswith("INT-") and not (backend_phase.complete and frontend_phase.complete):
                raise Blocked(f"{task.task_id}: integration ready before both checkpoints PASS.")
            if task.complete and any(not by_id[dependency].complete for dependency in task.dependencies):
                raise Blocked(f"{task.task_id}: completed before its dependencies.")
        first_pending = next((i for i, task in enumerate(index.tasks) if not task.complete), len(index.tasks))
        if any(task.complete for task in index.tasks[first_pending:]):
            raise Blocked("Impossible task order: a later task is complete before an earlier task.")
        if backend_phase and backend_phase.complete and any(not task.complete for task in backend):
            raise Blocked("Backend Phase 2 PASS before backend tasks are complete.")
        if frontend_phase and frontend_phase.complete and any(not task.complete for task in frontend):
            raise Blocked("Frontend Phase 2 PASS before frontend tasks are complete.")
        if index.closed:
            if any(not task.complete for task in index.tasks):
                raise Blocked("Stage is closed but authoritative tasks/checkpoints are incomplete.")
            return Decision("STAGE_CLOSED", "Authoritative Stage bookkeeping already records closure; close the control issue.", observed, dependency="Satisfied")
        if not index.approved:
            return Decision("WAITING_FOR_STAGE_APPROVAL", "Obtain ChatGPT planning/decomposition approval and record it in the Stage index.", observed)
        if not integration and all(task.complete for task in index.tasks):
            raise Blocked("No required integration task is recorded; integration cannot be bypassed.")

        def candidate(task, state):
            pending = [dependency for dependency in task.dependencies if not by_id[dependency].complete]
            if pending:
                raise Blocked(f"{task.task_id}: incomplete dependencies: {', '.join(pending)}.")
            is_checkpoint = task.checkpoint
            if not is_checkpoint and not task.currently_approved:
                raise Blocked(f"{task.task_id}: current authoritative readiness/review status is not Approved; Project Owner: ChatGPT must perform/re-record the Implementation Readiness or fix/review decision.")
            values = dict(status=observed, task="None" if is_checkpoint else task.task_id,
                          checkpoint=task.task_id if is_checkpoint else "None", dependency="Satisfied", contract=task.contract)
            if task.contract is None or not contract_exists(task.contract):
                return Decision("WAITING_FOR_TASK_CONTRACT", "Save/merge the approved contract before proceeding.",
                                reason=f"Missing contract for {task.task_id}.", **values)
            if is_checkpoint:
                action = f"Give {task.contract} to ChatGPT for the Phase 2 review; Project Owner/CI runs its required verification. Record the result in the Stage index."
            else:
                action = f"Next implementation candidate: {task.task_id}\nContract: {task.contract}\nGive this exact contract to Codex."
            return Decision(state, action, **values)

        for task in index.tasks:
            if task.kind.startswith(("DOC-", "BE-")) and not task.complete:
                return candidate(task, "BACKEND_PHASE_2_READY" if task.checkpoint else "TASK_READY")
        if frontend or frontend_phase:
            if "frontend" not in approvals:
                return Decision("OWNER_FRONTEND_APPROVAL_REQUIRED", "Repository owner: /approve frontend", observed,
                                checkpoint=backend_phase.task_id, dependency="Backend Phase 2 PASS")
            for task in index.tasks:
                if task.kind.startswith("FE-") and not task.complete:
                    return candidate(task, "FRONTEND_PHASE_2_READY" if task.checkpoint else "FRONTEND_TASK_READY")
        if not integration:
            raise Blocked("No required integration task is recorded; integration cannot be bypassed.")
        if "integration" not in approvals:
            return Decision("OWNER_INTEGRATION_APPROVAL_REQUIRED", "Repository owner: /approve integration", observed,
                            checkpoint=f"{backend_phase.task_id}, {frontend_phase.task_id}", dependency="Both Phase 2 checkpoints PASS")
        for task in integration:
            if not task.complete:
                return candidate(task, "INTEGRATION_TASK_READY")
        if "closure" not in approvals:
            return Decision("OWNER_CLOSURE_APPROVAL_REQUIRED", "Repository owner: /approve closure", observed, dependency="Integration PASS")
        if index.closure_id and (not index.closure_contract or not contract_exists(index.closure_contract)):
            return Decision("WAITING_FOR_TASK_CONTRACT", "Save/merge the Stage Closure Review contract before proceeding.",
                            observed, checkpoint=index.closure_id, dependency="Integration PASS", contract=index.closure_contract,
                            reason=f"Missing contract for {index.closure_id}.")
        return Decision("CLOSURE_REVIEW_READY", "ChatGPT Stage Closure Review may now be performed. Record the normal closure decision/bookkeeping separately.",
                        observed, checkpoint=index.closure_id or "None", dependency="Integration PASS", contract=index.closure_contract)
    except Blocked as error:
        return Decision("BLOCKED", "Resolve the reported ambiguity, then refresh.", observed, reason=str(error))


def validate_approvals(approvals):
    if (not isinstance(approvals, (list, set, frozenset, tuple))
            or any(not isinstance(gate, str) or gate not in GATES for gate in approvals)
            or len(approvals) != len(set(approvals))):
        raise Blocked("Invalid hidden orchestrator metadata: invalid approvals.")


def read_metadata(body, stage):
    matches = re.findall(r"<!-- TESTLABUZ_ORCHESTRATOR\s*\n(.*?)\n-->", body, re.S)
    if body.count(MARKER) != 1 or len(matches) != 1:
        raise Blocked("Invalid hidden orchestrator metadata: expected one marker.")

    def unique_keys(pairs):
        result = {}
        for name, value in pairs:
            if name in result:
                raise Blocked("Invalid hidden orchestrator metadata: duplicate JSON key.")
            result[name] = value
        return result

    try:
        metadata = json.loads(matches[0], object_pairs_hook=unique_keys)
    except (ValueError, RecursionError):
        raise Blocked("Invalid hidden orchestrator metadata: invalid JSON.") from None
    if (not isinstance(metadata, dict) or set(metadata) != {"stage", "approvals"}
            or type(metadata["stage"]) is not int or metadata["stage"] != stage
            or not isinstance(metadata["approvals"], list)):
        raise Blocked("Invalid hidden orchestrator metadata: unexpected fields or Stage.")
    validate_approvals(metadata["approvals"])
    return set(metadata["approvals"])


def apply_command(command, actor, owner, approvals, state=None):
    validate_approvals(approvals)
    updated = set(approvals)
    if command not in COMMANDS or command == "/status":
        return updated, None
    if actor != owner:
        return updated, "Denied: only the repository owner may approve or reject Stage gates."
    verb, gate = command.split()
    if verb == "/approve":
        if state != APPROVAL_STATES[gate]:
            return updated, f"Not applicable in current state: {command} requires {APPROVAL_STATES[gate]}."
        updated.add(gate)
    else:
        updated.discard(gate)
    return updated, f"{gate.capitalize()} approval {'granted' if verb == '/approve' else 'removed'}."


def render_body(stage, decision, approvals, sha, refreshed_at):
    validate_approvals(approvals)

    def display(value):
        # Plain escaped text prevents input Markdown/HTML, mentions, and links becoming UI instructions.
        escaped = html.escape(str(value), quote=False).replace("@", "&#64;")
        return re.sub(r"([\\`*_{}\[\]()#+.!|>~-])", r"\\\1", escaped)

    fields = (
        ("Stage", stage), ("Current state", decision.state),
        ("Authoritative Stage index path", index_path(stage)), ("Observed Stage status", decision.status),
        ("Current/next task", decision.task), ("Current/next checkpoint", decision.checkpoint),
        ("Dependency result", decision.dependency), ("Owner approvals already granted", ", ".join(sorted(approvals)) or "None"),
        ("Exact contract file path", decision.contract or "None"), ("Blocking/error reason", decision.reason),
    )
    body = "\n".join(f"**{label}:** {display(value)}  " for label, value in fields)
    body += "\n\n**Exact next action:**\n" + display(decision.action)
    body += "\n\n**Supported owner commands:**\n```text\n" + "\n".join(sorted(COMMANDS)) + "\n```"
    body += f"\n\n**Last refresh SHA/time:** {display(sha)} / {display(refreshed_at)}\n"
    body += f"\n<!-- {MARKER}\n" + json.dumps({"stage": stage, "approvals": sorted(approvals)}, separators=(",", ":")) + "\n-->"
    return body


def positive_id(value):
    if type(value) is not int or value <= 0:
        raise Blocked("Unsafe GitHub API response: invalid identifier.")
    return value


def login(record):
    if not isinstance(record, dict) or not isinstance(record.get("login"), str) or not record["login"]:
        raise Blocked("Unsafe GitHub API response: invalid user.")
    return record["login"]


def issue_record(record):
    if (not isinstance(record, dict) or not isinstance(record.get("title"), str)
            or record.get("state") not in ("open", "closed")
            or not isinstance(record.get("body"), (str, type(None)))):
        raise Blocked("Unsafe GitHub API response: invalid issue.")
    positive_id(record.get("number"))
    login(record.get("user"))
    return record


def comment_record(record):
    if not isinstance(record, dict) or not isinstance(record.get("body"), str):
        raise Blocked("Unsafe GitHub API response: invalid comment.")
    positive_id(record.get("id"))
    login(record.get("user"))
    for field in ("created_at", "updated_at"):
        timestamp = record.get(field)
        if not isinstance(timestamp, str) or not re.fullmatch(r"[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z", timestamp):
            raise Blocked("Unsafe GitHub API response: invalid comment timestamp.")
        try:
            datetime.strptime(timestamp, "%Y-%m-%dT%H:%M:%SZ")
        except ValueError:
            raise Blocked("Unsafe GitHub API response: invalid comment timestamp.") from None
    if record["updated_at"] < record["created_at"]:
        raise Blocked("Unsafe GitHub API response: comment update precedes creation.")
    return record


class NoRedirects(HTTPRedirectHandler):
    def redirect_request(self, request, file_pointer, code, message, headers, new_url):
        raise Blocked("GitHub API redirect refused.")


class GitHub:
    """Only fixed, repository-scoped issue endpoints; never follow response URLs."""

    def __init__(self, repository, token):
        if not REPOSITORY.fullmatch(repository) or repository.split("/")[1] in (".", ".."):
            raise Blocked("Invalid GITHUB_REPOSITORY.")
        if not token:
            raise Blocked("GITHUB_TOKEN is required.")
        self.owner = repository.split("/")[0]
        self.base = f"https://api.github.com/repos/{repository}"
        self.token = token
        self.opener = build_opener(NoRedirects())

    def request(self, method, endpoint, payload=None):
        if not re.fullmatch(r"/issues(?:/[1-9][0-9]*(?:/comments)?)?(?:\?(?:state=all&)?per_page=100&page=[1-9][0-9]*)?", endpoint):
            raise Blocked("Unsafe GitHub API endpoint refused.")
        allowed = (
            method == "GET" and payload is None,
            method == "POST" and endpoint == "/issues" and isinstance(payload, dict) and set(payload) == {"title", "body"},
            method == "POST" and re.fullmatch(r"/issues/[1-9][0-9]*/comments", endpoint) and isinstance(payload, dict) and set(payload) == {"body"},
            method == "PATCH" and re.fullmatch(r"/issues/[1-9][0-9]*", endpoint) and isinstance(payload, dict)
            and set(payload) in ({"body"}, {"body", "state"}) and payload.get("state", "closed") == "closed",
        )
        if not any(allowed):
            raise Blocked("GitHub API operation is outside the orchestrator boundary.")
        request = Request(self.base + endpoint, method=method,
                          data=None if payload is None else json.dumps(payload).encode("utf-8"),
                          headers={"Authorization": f"Bearer {self.token}", "Accept": "application/vnd.github+json",
                                   "Content-Type": "application/json", "X-GitHub-Api-Version": "2022-11-28",
                                   "User-Agent": "TestLabUz-Stage-Orchestrator"})
        try:
            with self.opener.open(request, timeout=30) as response:
                raw = response.read(8_000_001)
                if len(raw) > 8_000_000:
                    raise Blocked("Unsafe GitHub API response: payload too large.")
                return json.loads(raw)
        except HTTPError as error:
            raise Blocked(f"GitHub API request failed (HTTP {error.code}).") from None
        except (URLError, TimeoutError, OSError):
            raise Blocked("GitHub API request failed (transport error).") from None
        except (ValueError, RecursionError):
            raise Blocked("Unsafe GitHub API response: invalid JSON.") from None

    def pages(self, endpoint, state=False):
        records = []
        seen = set()
        for page in range(1, 1001):
            response = self.request("GET", f"{endpoint}?{'state=all&' if state else ''}per_page=100&page={page}")
            if not isinstance(response, list) or len(response) > 100:
                raise Blocked("Unsafe GitHub API response: invalid page.")
            for record in response:
                if not isinstance(record, dict):
                    raise Blocked("Unsafe GitHub API response: invalid record.")
                identity = positive_id(record.get("number" if state else "id"))
                if identity in seen:
                    raise Blocked("Unsafe GitHub API response: duplicate pagination record.")
                seen.add(identity)
                records.append(record)
            if len(response) < 100:
                return records
        raise Blocked("Unsafe GitHub API response: pagination limit exceeded.")

    def find_issue(self, stage):
        title = f"[Orchestrator] Stage {stage} Control"
        matches = []
        for record in self.pages("/issues", state=True):
            issue_record(record)
            if record["title"] == title and "pull_request" not in record:
                if login(record["user"]) not in (self.owner, BOT):
                    raise Blocked("Unsafe Stage Control issue: issue author is neither repository owner nor GitHub Actions.")
                matches.append(record)
        opened = [record for record in matches if record["state"] == "open"]
        if len(opened) > 1:
            raise Blocked("Multiple open Stage Control issues; resolve duplicates manually.")
        return opened[0] if opened else max(matches, key=lambda record: record["number"], default=None)

    def comments(self, number):
        return [comment_record(record) for record in self.pages(f"/issues/{positive_id(number)}/comments")]

    def create_issue(self, stage, body):
        title = f"[Orchestrator] Stage {stage} Control"
        record = issue_record(self.request("POST", "/issues", {"title": title, "body": body}))
        if record["title"] != title or record["state"] != "open" or login(record["user"]) != BOT:
            raise Blocked("Unsafe GitHub API response: created issue identity mismatch.")
        return record

    def update_issue(self, number, body, close=False):
        payload = {"body": body}
        if close:
            payload["state"] = "closed"
        record = issue_record(self.request("PATCH", f"/issues/{positive_id(number)}", payload))
        if record["number"] != number or (close and record["state"] != "closed"):
            raise Blocked("Unsafe GitHub API response: updated issue identity mismatch.")

    def add_comment(self, number, body):
        record = comment_record(self.request("POST", f"/issues/{positive_id(number)}/comments", {"body": body}))
        if login(record["user"]) != BOT or record["body"] != body or record["created_at"] != record["updated_at"]:
            raise Blocked("Unsafe GitHub API response: command comment mismatch.")
        return record


def receipt_body(stage, source_id, command, result, state):
    if result == "applied":
        verb, gate = command.split()
        message = f"{gate.capitalize()} approval {'granted' if verb == '/approve' else 'removed'}."
    elif result == "denied":
        message = "Denied: only the repository owner may approve or reject Stage gates."
    elif result == "superseded":
        message = "Not applicable in current state: a later owner command exists for this gate."
    else:
        message = f"Not applicable in current state: {state}."
    payload = {"stage": stage, "source_comment_id": source_id, "command": command, "result": result, "state": state}
    return (f"Stage {stage}; source comment {source_id}; command `{command}`.\n\n{message}\n\n"
            f"<!-- {RECEIPT_MARKER}\n{json.dumps(payload, separators=(',', ':'))}\n-->")


def read_receipt(comment, stage):
    if login(comment["user"]) != BOT or RECEIPT_MARKER not in comment["body"]:
        return None
    if comment["created_at"] != comment["updated_at"]:
        raise Blocked(f"Edited orchestrator receipt {comment['id']} cannot authorize approvals.")
    match = re.search(r"<!-- STAGE_CONTROL_RECEIPT\n(.*?)\n-->$", comment["body"], re.S)
    try:
        payload = json.loads(match[1]) if match else None
    except (ValueError, RecursionError):
        raise Blocked("Invalid orchestrator receipt JSON.") from None
    if (not isinstance(payload, dict) or set(payload) != {"stage", "source_comment_id", "command", "result", "state"}
            or type(payload["stage"]) is not int or payload["stage"] != stage
            or not isinstance(payload["command"], str) or payload["command"] not in COMMANDS - {"/status"}
            or not isinstance(payload["result"], str) or payload["result"] not in {"applied", "denied", "not_applicable", "superseded"}
            or not isinstance(payload["state"], str) or payload["state"] not in STATES):
        raise Blocked("Invalid orchestrator receipt fields.")
    positive_id(payload["source_comment_id"])
    if comment["body"] != receipt_body(stage, payload["source_comment_id"], payload["command"], payload["result"], payload["state"]):
        raise Blocked("Orchestrator receipt does not match its canonical command/result.")
    if payload["result"] == "applied" and payload["command"].startswith("/approve "):
        if payload["state"] != APPROVAL_STATES[payload["command"].split()[1]]:
            raise Blocked("Approval receipt was not recorded at its matching owner gate.")
    return payload


def reconstruct_approvals(comments, stage, owner):
    by_id = {}
    for comment in comments:
        comment_record(comment)
        if comment["id"] in by_id:
            raise Blocked("Unsafe GitHub API response: duplicate comment identifier.")
        by_id[comment["id"]] = comment
    receipts = {}
    for comment in sorted(comments, key=lambda item: item["id"]):
        payload = read_receipt(comment, stage)
        if payload is None:
            continue
        source_id = payload["source_comment_id"]
        source = by_id.get(source_id)
        if (source is None or source["body"].strip() != payload["command"]
                or source["created_at"] != source["updated_at"]
                or source_id >= comment["id"] or source["created_at"] > comment["created_at"]):
            raise Blocked(f"Receipt for source comment {source_id} has missing, edited, or mismatched command evidence.")
        if payload["result"] != "denied" and login(source["user"]) != owner:
            raise Blocked(f"Receipt for source comment {source_id} is not backed by the exact repository owner.")
        if source_id in receipts and receipts[source_id] != payload:
            raise Blocked(f"Conflicting orchestrator receipts for source comment {source_id}.")
        receipts[source_id] = payload
    approvals = set()
    for source_id, payload in sorted(receipts.items()):
        if payload["result"] == "applied":
            command = payload["command"]
            verb, gate = command.split()
            if verb == "/approve":
                approvals.add(gate)
            else:
                approvals.discard(gate)
    return approvals, receipts


def superseded_command(comments, receipts, source, owner):
    gate = source["body"].strip().split()[1]
    if any(source_id > source["id"] and payload["result"] == "applied" and payload["command"].endswith(" " + gate)
           for source_id, payload in receipts.items()):
        return True
    # An unprocessed rejection can prevent an older grant, but an inapplicable
    # future approval can never cancel an owner's valid rejection.
    return source["body"].strip().startswith("/approve ") and any(
        comment["id"] > source["id"] and login(comment["user"]) == owner
        and comment["created_at"] == comment["updated_at"]
        and comment["body"].strip() == "/reject " + gate for comment in comments
    )


def validate_pending_rejections(comments, receipts, approvals, source, owner):
    for gate in approvals:
        last_grant = max(source_id for source_id, payload in receipts.items()
                         if payload["result"] == "applied" and payload["command"] == "/approve " + gate)
        for comment in comments:
            if (comment["id"] > last_grant and comment["id"] not in receipts
                    and login(comment["user"]) == owner and comment["body"].strip() == "/reject " + gate
                    and comment["created_at"] == comment["updated_at"]
                    and (source is None or source["id"] != comment["id"])):
                raise Blocked(f"Owner rejection {comment['id']} has no valid receipt; process its created event before retaining {gate} approval.")


def validate_source_event(event, issue, comments):
    if event.get("action") != "created":
        raise Blocked("Only a created issue_comment event may originate an owner decision.")
    event_issue = issue_record(event.get("issue"))
    if issue is None or event_issue["number"] != issue["number"]:
        raise Blocked("Comment does not belong to the canonical Stage Control issue.")
    event_comment = comment_record(event.get("comment"))
    source = next((comment for comment in comments if comment["id"] == event_comment["id"]), None)
    if (source is None or any(source[field] != event_comment[field] for field in ("body", "created_at", "updated_at"))
            or login(source["user"]) != login(event_comment["user"])
            or source["created_at"] != source["updated_at"]):
        raise Blocked("Owner command source is missing, edited, or no longer matches its created event.")
    return source


def cache_matches_receipt_retry(cached, approvals, receipts, source, comments, owner):
    """Recover this owner's receipt write or missing rejection without unproven grants."""
    if (source is None or source["body"].strip() not in COMMANDS - {"/status"}
            or login(source["user"]) != owner or superseded_command(comments, receipts, source, owner)):
        return False
    payload = receipts.get(source["id"])
    if payload is None and source["body"].strip().startswith("/reject "):
        rejected, _ = apply_command(source["body"].strip(), owner, owner, approvals)
        return rejected == cached
    if payload is None or payload["result"] != "applied":
        return False
    recovered, _ = apply_command(payload["command"], owner, owner, cached, payload["state"])
    return recovered == approvals


def refresh_stage(api, root, stage, sha, refreshed_at, event=None):
    """Rebuild authority from unedited comments; persist receipts before their display cache."""
    stage = stage_number(stage)
    issue = api.find_issue(stage)
    body = (issue.get("body") or "") if issue else ""
    comments = api.comments(issue["number"]) if issue else []
    source = None
    try:
        approvals, receipts = reconstruct_approvals(comments, stage, api.owner)
        if event is not None:
            source = validate_source_event(event, issue, comments)
            if source["body"].strip() not in COMMANDS:
                return None
        command = source["body"].strip() if source else None
        denied = source is not None and command != "/status" and login(source["user"]) != api.owner
        # Unauthorized commands cannot change either approvals or the displayed state.
        if denied:
            if source["id"] not in receipts:
                api.add_comment(issue["number"], receipt_body(stage, source["id"], command, "denied", "BLOCKED"))
            return None
        validate_pending_rejections(comments, receipts, approvals, source, api.owner)
        cached = read_metadata(body, stage) if issue else set()
        if cached != approvals and not cache_matches_receipt_retry(cached, approvals, receipts, source, comments, api.owner):
            raise Blocked("Hidden approval cache disagrees with valid owner-command/bot-receipt evidence; repair the evidence or retry the exact receipt-first owner event.")
        path = local_path(root, index_path(stage))
        markdown = path.read_text(encoding="utf-8-sig") if path.is_file() else None

        def current_decision():
            decision = evaluate(stage, markdown, approvals, lambda contract: local_path(root, contract).is_file())
            if issue and issue["state"] == "closed" and decision.state != "STAGE_CLOSED":
                return Decision("BLOCKED", "Project Owner: reopen the existing Stage Control issue, then refresh.",
                                decision.status, reason="Control issue is closed but authoritative Stage closure is absent.")
            return decision

        decision = current_decision()
    except Blocked as error:
        if issue:
            # A disputed cache never grants authority, and is preserved for owner repair.
            prefix = "<!-- STAGE_CONTROL_ERROR -->\n"
            original = body.split("<!-- /STAGE_CONTROL_ERROR -->\n\n", 1)[-1] if body.startswith(prefix) else body
            blocked = prefix + "**Current state: BLOCKED**\n\n" + html.escape(str(error)) + "\n<!-- /STAGE_CONTROL_ERROR -->\n\n" + original
            api.update_issue(issue["number"], blocked)
        raise
    if source and command != "/status" and source["id"] not in receipts:
        if superseded_command(comments, receipts, source, api.owner):
            result = "superseded"
        elif command.startswith("/approve ") and decision.state != APPROVAL_STATES[command.split()[1]]:
            result = "not_applicable"
        else:
            result = "applied"
        recorded = api.add_comment(issue["number"], receipt_body(stage, source["id"], command, result, decision.state))
        approvals, receipts = reconstruct_approvals(comments + [recorded], stage, api.owner)
        decision = current_decision()
    generated = render_body(stage, decision, approvals, sha, refreshed_at)
    # A failed body write leaves the receipt authoritative; retrying the same event
    # can rebuild its cache without granting anything from the old issue marker.
    if issue is None:
        issue = api.create_issue(stage, generated)
        if decision.state == "STAGE_CLOSED":
            api.update_issue(issue["number"], generated, close=True)
    elif body != generated or (decision.state == "STAGE_CLOSED" and issue["state"] != "closed"):
        api.update_issue(issue["number"], generated, close=decision.state == "STAGE_CLOSED")
    return decision


def git_output(root, arguments):
    try:
        result = subprocess.run(["git", *arguments], cwd=root, stdout=subprocess.PIPE,
                                stderr=subprocess.PIPE, check=False)
    except OSError:
        raise Blocked("Git is unavailable for local event validation.") from None
    if result.returncode:
        raise Blocked("Local Git event validation failed.")
    try:
        return result.stdout.decode("utf-8")
    except UnicodeError:
        raise Blocked("Local Git output is not valid UTF-8.") from None


def changed_index_paths(root, before, after):
    if not isinstance(before, str) or not isinstance(after, str) or not SHA.fullmatch(before) or not SHA.fullmatch(after):
        raise Blocked("Invalid push revision.")
    if before == "0" * 40:
        arguments = ["ls-tree", "-r", "--name-only", "-z", after, "--", "tasks/"]
    else:
        arguments = ["diff", "--name-only", "--no-renames", "-z", before, after, "--", "tasks/"]
    return git_output(root, arguments).rstrip("\0").split("\0")


def event_stages(name, event, changed_paths=()):
    if not isinstance(event, dict):
        raise Blocked("Invalid GitHub event payload.")
    if name == "workflow_dispatch":
        inputs = event.get("inputs")
        if not isinstance(inputs, dict):
            raise Blocked("Invalid workflow_dispatch input.")
        return [stage_number(inputs.get("stage"))]
    if name == "push":
        if event.get("ref") != "refs/heads/main":
            return []
        stages = set()
        for path in changed_paths:
            match = INDEX_PATH.fullmatch(path)
            if match:
                stage = stage_number(int(match[1]))
                if path != index_path(stage):
                    raise Blocked("Invalid Stage index filename.")
                stages.add(stage)
        return sorted(stages)
    if name == "issue_comment":
        issue = event.get("issue")
        if not isinstance(issue, dict) or "pull_request" in issue or event.get("action") != "created":
            return []
        title = issue.get("title", "")
        match = CONTROL_TITLE.fullmatch(title) if isinstance(title, str) else None
        if not match:
            return []
        comment = comment_record(event.get("comment"))
        return [stage_number(match[1])] if comment["body"].strip() in COMMANDS else []
    if name == "pull_request_target":
        pull_request = event.get("pull_request")
        if not isinstance(pull_request, dict) or event.get("action") != "closed" or pull_request.get("merged") is not True:
            return []
        if not isinstance(pull_request.get("base"), dict) or pull_request["base"].get("ref") != "main":
            return []
        head = pull_request.get("head")
        if not isinstance(head, dict):
            raise Blocked("Invalid merged PR event.")
        values = (pull_request.get("title"), pull_request.get("body") or "", head.get("ref"))
        if any(not isinstance(value, str) for value in values):
            raise Blocked("Invalid merged PR event text.")
        return sorted({stage_number(int(match["stage"])) for value in values for match in TASK_MENTION.finditer(value)
                       if match["stage"] == f"{int(match['stage']):02d}"})
    raise Blocked("Unsupported GitHub event.")


def self_check():
    assert len(STATES) == 14
    assert len(COMMANDS) == 7
    assert GATES == ("frontend", "integration", "closure")
    assert index_path(8) == "tasks/STAGE_08_TASK_INDEX.md"
    for kind in ("DOC-001", "BE-001", "BE-PHASE-2", "FE-001", "FE-PHASE-2", "INT-001"):
        assert TASK_ID.fullmatch("S08-" + kind)
    for invalid in ("S8-BE-001", "S08-OTHER-001", "S08-BE-PHASE-3", "S08-BE-001-extra"):
        assert TASK_ID.fullmatch(invalid) is None
    fixture = """| Field | Value |
|---|---|
| Stage status | Approved |
| Order | Task ID | Depends on | Status | Contract file |
|---|---|---|---|---|
| 0 | S08-DOC-001 | None | Approved | tasks/S08-DOC-001.md |
"""
    # Separate metadata and task tables, just as in an index.
    fixture = fixture.replace("| Order |", "\n| Order |")
    parsed = parse_index(fixture, 8)
    assert parsed.approved and parsed.tasks[0].task_id == "S08-DOC-001"
    decision = evaluate(8, fixture, set(), lambda path: True)
    assert decision.state == "TASK_READY"
    body = render_body(8, decision, {"frontend"}, "a" * 40, "2026-01-01T00:00:00+00:00")
    assert read_metadata(body, 8) == {"frontend"}
    assert apply_command("/approve closure", "owner", "owner", set(), "OWNER_CLOSURE_APPROVAL_REQUIRED")[0] == {"closure"}
    assert apply_command("/approve closure", "owner", "owner", set(), "TASK_READY")[0] == set()
    print("Self-check PASS: constants, regexes, states, commands, parser, and metadata.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--self-check", action="store_true", help="Validate locally without network access")
    arguments = parser.parse_args()
    if arguments.self_check:
        self_check()
        return 0
    try:
        root = Path(__file__).resolve().parents[2]
        event_path = os.environ.get("GITHUB_EVENT_PATH")
        if not event_path:
            raise Blocked("GITHUB_EVENT_PATH is required.")
        event = json.loads(Path(event_path).read_text(encoding="utf-8"))
        if not isinstance(event, dict):
            raise Blocked("Invalid GitHub event payload.")
        name = os.environ.get("GITHUB_EVENT_NAME", "")
        sha = os.environ.get("GITHUB_SHA", "")
        if not SHA.fullmatch(sha):
            raise Blocked("Invalid GITHUB_SHA.")
        paths = changed_index_paths(root, event.get("before"), event.get("after")) if name == "push" else ()
        stages = event_stages(name, event, paths)
        if not stages:
            print("No applicable Stage refresh.")
            return 0
        api = GitHub(os.environ.get("GITHUB_REPOSITORY", ""), os.environ.get("GITHUB_TOKEN", ""))
        checkout_sha = git_output(root, ["rev-parse", "HEAD"]).strip()
        if not SHA.fullmatch(checkout_sha):
            raise Blocked("Invalid checkout revision.")
        refreshed_at = datetime.now(timezone.utc).isoformat(timespec="seconds")
        failed = False
        for stage in stages:
            try:
                decision = refresh_stage(api, root, stage, checkout_sha, refreshed_at, event if name == "issue_comment" else None)
                if decision:
                    print(f"Stage {stage}: {decision.state}")
                    if decision.state == "BLOCKED":
                        print(decision.reason)
                        failed = True
            except Blocked as error:
                print(f"Stage {stage}: BLOCKED — {error}", file=sys.stderr)
                failed = True
        return 1 if failed else 0
    except (OSError, UnicodeError, json.JSONDecodeError, RecursionError):
        print("BLOCKED: unable to read local orchestration input.", file=sys.stderr)
        return 1
    except Blocked as error:
        print(f"BLOCKED: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
