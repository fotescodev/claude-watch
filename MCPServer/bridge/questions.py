"""
AskUserQuestion handler for the Claude Watch bridge server.

Special handling for `can_use_tool` where `tool_name == "AskUserQuestion"`.
Parses question structures from the CLI, extracts recommendations, transforms
them into a watch-friendly format, and constructs control_response messages
for approval or denial.

This is THE fix for the Phase 10 stdin injection problem: instead of trying
to inject answers into stdin, we use the native SDK protocol to return
`updatedInput` with pre-selected answers back to the CLI.

AskUserQuestion input shape:
    {
      "questions": [
        {
          "header": "DB",
          "question": "Which database should we use?",
          "options": [
            {"label": "PostgreSQL (Recommended)", "description": "Most popular"},
            {"label": "MySQL", "description": "Alternative option"},
          ],
          "multiSelect": false
        }
      ]
    }
"""
from __future__ import annotations

RECOMMENDED_SUFFIX = " (Recommended)"


def is_ask_user_question(tool_name: str) -> bool:
    """Return True if the tool_name is AskUserQuestion."""
    return tool_name == "AskUserQuestion"


def extract_recommendation(question: dict) -> str:
    """Extract the recommended option label from a single question.

    Scans the question's options for a label ending with "(Recommended)".
    If found, returns the label with the suffix stripped. If not found,
    returns the first option's label. If there are no options, returns "".

    Args:
        question: A single question dict with an "options" list.

    Returns:
        The recommended (or fallback first) option label, stripped of
        the "(Recommended)" suffix if present.
    """
    options = question.get("options", [])
    if not options:
        return ""

    for opt in options:
        label = opt.get("label", "")
        if label.endswith(RECOMMENDED_SUFFIX):
            return label[: -len(RECOMMENDED_SUFFIX)]

    # No explicit recommendation -- fall back to first option
    return options[0].get("label", "")


def extract_all_recommendations(input_data: dict) -> dict[str, str]:
    """Extract recommendations for every question in the payload.

    For each question in ``input_data["questions"]``, maps the question's
    ``header`` to the recommended option label (via :func:`extract_recommendation`).

    Args:
        input_data: The full AskUserQuestion tool input containing a
            ``questions`` list.

    Returns:
        A dict mapping each question's header to its recommended answer.
    """
    recommendations: dict[str, str] = {}
    for question in input_data.get("questions", []):
        header = question.get("header", "")
        recommendations[header] = extract_recommendation(question)
    return recommendations


def to_watch_question(request_id: str, input_data: dict) -> dict:
    """Transform an AskUserQuestion payload into a watch-friendly format.

    The watch has a tiny screen and limited interaction capabilities, so we
    distill the question down to a single recommended answer with minimal
    metadata.

    Args:
        request_id: The control_request request_id from the CLI.
        input_data: The full AskUserQuestion tool input.

    Returns:
        A dict suitable for the watch REST API / WebSocket push.
    """
    questions = input_data.get("questions", [])
    if not questions:
        return {
            "questionId": request_id,
            "question": "",
            "recommendedAnswer": "",
            "optionCount": 0,
            "allOptions": [],
            "header": "",
        }

    first = questions[0]
    options = first.get("options", [])

    return {
        "questionId": request_id,
        "question": first.get("question", ""),
        "recommendedAnswer": extract_recommendation(first),
        "optionCount": len(options),
        "allOptions": [opt.get("label", "") for opt in options],
        "header": first.get("header", ""),
    }


def build_approve_response(request_id: str, original_input: dict) -> dict:
    """Construct a control_response that approves an AskUserQuestion.

    The response includes ``updatedInput`` with an ``answers`` dict that maps
    each question header to its recommended option label. This lets the CLI
    proceed as if the user selected the recommended answer for every question.

    Args:
        request_id: The control_request request_id.
        original_input: The original AskUserQuestion tool input dict.

    Returns:
        A full ``control_response`` message dict ready to send to the CLI.
    """
    updated_input = {**original_input}
    updated_input["answers"] = extract_all_recommendations(original_input)

    return {
        "type": "control_response",
        "response": {
            "subtype": "success",
            "request_id": request_id,
            "response": {
                "behavior": "allow",
                "updatedInput": updated_input,
            },
        },
    }


def build_deny_response(request_id: str) -> dict:
    """Construct a control_response that denies an AskUserQuestion.

    When the watch user rejects a question, we defer it to the terminal so
    the developer can answer interactively on their Mac.

    Args:
        request_id: The control_request request_id.

    Returns:
        A full ``control_response`` message dict ready to send to the CLI.
    """
    return {
        "type": "control_response",
        "response": {
            "subtype": "success",
            "request_id": request_id,
            "response": {
                "behavior": "deny",
                "message": "Deferred to terminal by user",
            },
        },
    }
