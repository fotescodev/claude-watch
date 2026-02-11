"""
Tests for the AskUserQuestion handler (Task A4).

Test IDs map to the spec in .claude/plans/sdk-url-agent-execution-spec.md:
  A4.1 — extract_recommendation with "(Recommended)" suffix
  A4.2 — build_approve_response updatedInput.answers correctness
  A4.3 — build_deny_response behavior and message
  A4.4 — Multi-question payload (3 questions, 3 recommendations)
  A4.5 — No recommended option falls back to first option label
  A4.6 — Empty options list returns ""
  A4.7 — to_watch_question format matches expected schema
  A4.8 — extract_all_recommendations with mixed recommended/non-recommended
"""
import pytest

from MCPServer.bridge.questions import (
    build_approve_response,
    build_deny_response,
    extract_all_recommendations,
    extract_recommendation,
    is_ask_user_question,
    to_watch_question,
)


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture
def single_question_input():
    """Standard single-question payload with one recommended option."""
    return {
        "questions": [
            {
                "header": "DB",
                "question": "Which database should we use?",
                "options": [
                    {"label": "PostgreSQL (Recommended)", "description": "Most popular, best for production"},
                    {"label": "MySQL", "description": "Alternative option"},
                    {"label": "SQLite", "description": "Lightweight, for dev only"},
                ],
                "multiSelect": False,
            }
        ]
    }


@pytest.fixture
def multi_question_input():
    """Three-question payload with different recommendations."""
    return {
        "questions": [
            {
                "header": "DB",
                "question": "Which database?",
                "options": [
                    {"label": "PostgreSQL (Recommended)", "description": "Best for production"},
                    {"label": "MySQL", "description": "Alternative"},
                ],
                "multiSelect": False,
            },
            {
                "header": "Auth",
                "question": "Which auth method?",
                "options": [
                    {"label": "OAuth2", "description": "Standard"},
                    {"label": "JWT (Recommended)", "description": "Lightweight tokens"},
                    {"label": "Session", "description": "Server-side sessions"},
                ],
                "multiSelect": False,
            },
            {
                "header": "Cache",
                "question": "Which cache layer?",
                "options": [
                    {"label": "Redis (Recommended)", "description": "Industry standard"},
                    {"label": "Memcached", "description": "Simple key-value"},
                ],
                "multiSelect": False,
            },
        ]
    }


@pytest.fixture
def no_recommended_input():
    """Question with options but none marked as recommended."""
    return {
        "questions": [
            {
                "header": "Framework",
                "question": "Which framework?",
                "options": [
                    {"label": "Alpha", "description": "First option"},
                    {"label": "Beta", "description": "Second option"},
                    {"label": "Gamma", "description": "Third option"},
                ],
                "multiSelect": False,
            }
        ]
    }


@pytest.fixture
def empty_options_input():
    """Question with an empty options list."""
    return {
        "questions": [
            {
                "header": "FreeText",
                "question": "What should we name the service?",
                "options": [],
                "multiSelect": False,
            }
        ]
    }


# ---------------------------------------------------------------------------
# TEST A4.1: extract_recommendation with "(Recommended)" suffix
# ---------------------------------------------------------------------------

class TestExtractRecommendation:
    def test_a4_1_recommended_suffix_stripped(self, single_question_input):
        """When an option ends with '(Recommended)', return label without the suffix."""
        question = single_question_input["questions"][0]
        result = extract_recommendation(question)
        assert result == "PostgreSQL"

    def test_a4_5_no_recommended_falls_back_to_first(self, no_recommended_input):
        """When no option has '(Recommended)', return the first option's label."""
        question = no_recommended_input["questions"][0]
        result = extract_recommendation(question)
        assert result == "Alpha"

    def test_a4_6_empty_options_returns_empty_string(self, empty_options_input):
        """When options list is empty, return empty string."""
        question = empty_options_input["questions"][0]
        result = extract_recommendation(question)
        assert result == ""

    def test_missing_options_key_returns_empty_string(self):
        """When the question has no 'options' key at all, return empty string."""
        question = {"header": "X", "question": "Something?"}
        result = extract_recommendation(question)
        assert result == ""

    def test_recommended_in_middle_of_list(self):
        """Recommended option can appear at any position in the list."""
        question = {
            "header": "Test",
            "question": "Pick one?",
            "options": [
                {"label": "First", "description": ""},
                {"label": "Second (Recommended)", "description": ""},
                {"label": "Third", "description": ""},
            ],
        }
        result = extract_recommendation(question)
        assert result == "Second"


# ---------------------------------------------------------------------------
# TEST A4.2: build_approve_response updatedInput.answers
# ---------------------------------------------------------------------------

class TestBuildApproveResponse:
    def test_a4_2_approve_response_has_correct_answers(self, single_question_input):
        """Approval response includes updatedInput.answers with header -> label mapping."""
        resp = build_approve_response("req-001", single_question_input)

        assert resp["type"] == "control_response"
        assert resp["response"]["subtype"] == "success"
        assert resp["response"]["request_id"] == "req-001"

        inner = resp["response"]["response"]
        assert inner["behavior"] == "allow"
        assert "updatedInput" in inner

        updated = inner["updatedInput"]
        assert updated["answers"] == {"DB": "PostgreSQL"}
        # Original questions preserved
        assert updated["questions"] == single_question_input["questions"]

    def test_a4_2_approve_preserves_original_input(self, single_question_input):
        """The original_input dict must not be mutated."""
        original_copy = {**single_question_input, "questions": list(single_question_input["questions"])}
        build_approve_response("req-002", single_question_input)
        # original_input should not have gained an "answers" key
        assert "answers" not in single_question_input


# ---------------------------------------------------------------------------
# TEST A4.3: build_deny_response
# ---------------------------------------------------------------------------

class TestBuildDenyResponse:
    def test_a4_3_deny_response_structure(self):
        """Deny response has behavior 'deny' and deferred-to-terminal message."""
        resp = build_deny_response("req-003")

        assert resp["type"] == "control_response"
        assert resp["response"]["subtype"] == "success"
        assert resp["response"]["request_id"] == "req-003"

        inner = resp["response"]["response"]
        assert inner["behavior"] == "deny"
        assert inner["message"] == "Deferred to terminal by user"

    def test_a4_3_deny_has_no_updated_input(self):
        """Deny response must not include updatedInput."""
        resp = build_deny_response("req-004")
        inner = resp["response"]["response"]
        assert "updatedInput" not in inner


# ---------------------------------------------------------------------------
# TEST A4.4: Multi-question payload
# ---------------------------------------------------------------------------

class TestMultiQuestion:
    def test_a4_4_multi_question_answers(self, multi_question_input):
        """Three questions each with different recommendations produce 3 answer entries."""
        resp = build_approve_response("req-005", multi_question_input)
        answers = resp["response"]["response"]["updatedInput"]["answers"]

        assert len(answers) == 3
        assert answers["DB"] == "PostgreSQL"
        assert answers["Auth"] == "JWT"
        assert answers["Cache"] == "Redis"

    def test_a4_4_multi_question_preserves_all_questions(self, multi_question_input):
        """All original questions are preserved in updatedInput."""
        resp = build_approve_response("req-006", multi_question_input)
        updated = resp["response"]["response"]["updatedInput"]
        assert len(updated["questions"]) == 3


# ---------------------------------------------------------------------------
# TEST A4.7: to_watch_question format
# ---------------------------------------------------------------------------

class TestToWatchQuestion:
    def test_a4_7_watch_question_schema(self, single_question_input):
        """to_watch_question output matches the expected schema."""
        result = to_watch_question("req-007", single_question_input)

        assert result["questionId"] == "req-007"
        assert result["question"] == "Which database should we use?"
        assert result["recommendedAnswer"] == "PostgreSQL"
        assert result["optionCount"] == 3
        assert result["allOptions"] == [
            "PostgreSQL (Recommended)",
            "MySQL",
            "SQLite",
        ]
        assert result["header"] == "DB"

    def test_a4_7_watch_question_has_all_required_keys(self, single_question_input):
        """Output contains exactly the expected keys."""
        result = to_watch_question("req-008", single_question_input)
        expected_keys = {"questionId", "question", "recommendedAnswer", "optionCount", "allOptions", "header"}
        assert set(result.keys()) == expected_keys

    def test_watch_question_empty_questions(self):
        """When the questions list is empty, return a safe empty structure."""
        result = to_watch_question("req-009", {"questions": []})
        assert result["questionId"] == "req-009"
        assert result["question"] == ""
        assert result["recommendedAnswer"] == ""
        assert result["optionCount"] == 0
        assert result["allOptions"] == []
        assert result["header"] == ""

    def test_watch_question_no_recommended(self, no_recommended_input):
        """to_watch_question falls back to first option when none is recommended."""
        result = to_watch_question("req-010", no_recommended_input)
        assert result["recommendedAnswer"] == "Alpha"
        assert result["optionCount"] == 3


# ---------------------------------------------------------------------------
# TEST A4.8: extract_all_recommendations with mixed recommended/non-recommended
# ---------------------------------------------------------------------------

class TestExtractAllRecommendations:
    def test_a4_8_mixed_recommendations(self):
        """Mix of questions: some with explicit recommendation, some without."""
        input_data = {
            "questions": [
                {
                    "header": "DB",
                    "question": "Which database?",
                    "options": [
                        {"label": "PostgreSQL (Recommended)", "description": ""},
                        {"label": "MySQL", "description": ""},
                    ],
                },
                {
                    "header": "Framework",
                    "question": "Which framework?",
                    "options": [
                        {"label": "Django", "description": ""},
                        {"label": "Flask", "description": ""},
                    ],
                },
                {
                    "header": "Deploy",
                    "question": "Where to deploy?",
                    "options": [
                        {"label": "AWS", "description": ""},
                        {"label": "GCP (Recommended)", "description": ""},
                    ],
                },
            ]
        }
        result = extract_all_recommendations(input_data)

        assert len(result) == 3
        # DB has explicit recommendation
        assert result["DB"] == "PostgreSQL"
        # Framework has no recommendation -> first option
        assert result["Framework"] == "Django"
        # Deploy has explicit recommendation
        assert result["Deploy"] == "GCP"

    def test_extract_all_empty_questions(self):
        """Empty questions list returns empty dict."""
        result = extract_all_recommendations({"questions": []})
        assert result == {}

    def test_extract_all_no_questions_key(self):
        """Missing 'questions' key returns empty dict."""
        result = extract_all_recommendations({})
        assert result == {}


# ---------------------------------------------------------------------------
# is_ask_user_question
# ---------------------------------------------------------------------------

class TestIsAskUserQuestion:
    def test_matches_exact_tool_name(self):
        assert is_ask_user_question("AskUserQuestion") is True

    def test_rejects_other_tool_names(self):
        assert is_ask_user_question("Bash") is False
        assert is_ask_user_question("Edit") is False
        assert is_ask_user_question("askuserquestion") is False
        assert is_ask_user_question("AskUserQuestion ") is False
        assert is_ask_user_question("") is False
