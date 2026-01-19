#!/usr/bin/env python3
"""
Security Scanner for Claude Watch

Scans the codebase for:
- Hardcoded secrets (API keys, passwords, tokens)
- Secrets logged in plaintext
- Permission bypass risks
- Command injection vulnerabilities

Usage:
    python scan_secrets.py --all-files --json
"""

import argparse
import json
import os
import re
import sys
from dataclasses import dataclass, field, asdict
from pathlib import Path
from typing import Optional


@dataclass
class SecurityFinding:
    """A security finding from the scan"""
    severity: str  # "critical", "high", "medium", "low", "info"
    category: str
    file: str
    line: int
    message: str
    match: str = ""
    remediation: str = ""


@dataclass
class ScanResult:
    """Result of the security scan"""
    status: str  # "pass", "fail"
    total_files_scanned: int
    findings: list[SecurityFinding] = field(default_factory=list)
    summary: dict = field(default_factory=dict)

    def to_dict(self):
        return {
            "status": self.status,
            "total_files_scanned": self.total_files_scanned,
            "findings": [asdict(f) for f in self.findings],
            "summary": self.summary
        }


# Patterns to detect hardcoded secrets
SECRET_PATTERNS = [
    # API Keys with actual values
    (r'(?i)(api[_-]?key|apikey)\s*[:=]\s*["\']([a-zA-Z0-9_\-]{20,})["\']', "Hardcoded API key"),
    (r'(?i)(secret[_-]?key|secretkey)\s*[:=]\s*["\']([a-zA-Z0-9_\-]{20,})["\']', "Hardcoded secret key"),
    (r'(?i)(password)\s*[:=]\s*["\']([^"\']+)["\']', "Hardcoded password"),
    (r'(?i)(token)\s*[:=]\s*["\']([a-zA-Z0-9_\-]{20,})["\']', "Hardcoded token"),

    # Anthropic-specific patterns
    (r'sk-ant-[a-zA-Z0-9\-_]{40,}', "Anthropic API key in source"),
    (r'anthropic[_-]?api[_-]?key\s*[:=]\s*["\']sk-[a-zA-Z0-9_\-]+["\']', "Anthropic API key hardcoded"),

    # AWS patterns
    (r'AKIA[0-9A-Z]{16}', "AWS Access Key ID"),
    (r'(?i)aws[_-]?secret[_-]?access[_-]?key\s*[:=]\s*["\']([a-zA-Z0-9/+=]{40})["\']', "AWS Secret Key"),

    # Generic private keys
    (r'-----BEGIN (RSA |EC |DSA |PRIVATE )?PRIVATE KEY-----', "Private key in source"),
    (r'-----BEGIN CERTIFICATE-----', "Certificate in source"),
]

# Patterns that indicate secrets being logged (must contain actual interpolation)
# Excludes: instruction text, masked/truncated values, documentation
SECRET_LOGGING_PATTERNS = [
    # Only flag if the actual value is being interpolated (not just mentioned in text)
    (r'console\.log\s*\([^)]*\$\{[^}]*(?:api[_-]?key|password|secret(?!s)|token)\}', "Secret value interpolated in log"),
    (r'print\s*\([^)]*\{[^}]*(?:api[_-]?key|password|secret(?!s)|token)\}', "Secret value interpolated in print"),
    (r'logger\.\w+\s*\(f["\'][^"\']*\{[^}]*(?:password|secret(?!s))\}', "Secret value in f-string log"),
]

# Permission bypass patterns to check are properly scoped
PERMISSION_BYPASS_PATTERNS = [
    (r'--dangerously-skip-permissions', "Permission bypass flag usage"),
    (r'--no-verify', "Git hook bypass"),
    (r'--force\s*(?:push)?', "Force operation"),
    (r'eval\s*\(', "Eval usage (potential code injection)"),
    (r'exec\s*\(', "Exec usage (potential code injection)"),
]

# Command injection patterns
COMMAND_INJECTION_PATTERNS = [
    (r'spawn\s*\(\s*[^,]+\s*,\s*\[[^\]]*\$\{', "Variable interpolation in spawn args"),
    (r'exec\s*\(\s*[`\'"]\s*\$\{', "Variable interpolation in exec"),
    (r'os\.system\s*\([^)]*\$', "Variable in os.system"),
    (r'subprocess\.\w+\s*\(\s*f["\']', "f-string in subprocess (potential injection)"),
]

# File extensions to scan
SCANNABLE_EXTENSIONS = {
    '.py', '.ts', '.tsx', '.js', '.jsx', '.sh', '.bash',
    '.env', '.toml', '.ini'
}

# Files/directories to skip
SKIP_PATTERNS = {
    'node_modules', '.git', 'dist', 'build', '.venv', 'venv',
    '__pycache__', '.wrangler', '.turbo', 'coverage',
    '__tests__', 'test', 'tests', 'spec', 'specs'
}

# Files to completely ignore (self-reference, docs, logs)
IGNORE_FILES = {
    'scan_secrets.py',  # This scanner itself
    'task_logs.json',
    'context.json',
    'implementation_plan.json',
    'build-progress.txt',
}


def should_scan_file(filepath: Path) -> bool:
    """Check if file should be scanned"""
    # Skip specific files (self, logs, etc.)
    if filepath.name in IGNORE_FILES:
        return False

    # Skip binary and non-relevant files
    if filepath.suffix not in SCANNABLE_EXTENSIONS:
        return False

    # Skip certain directories
    parts = filepath.parts
    for skip in SKIP_PATTERNS:
        if skip in parts:
            return False

    # Skip test files
    if 'test' in filepath.name.lower() or filepath.name.endswith('.test.ts'):
        return False

    return True


def scan_file(filepath: Path, patterns: list[tuple], category: str, severity: str) -> list[SecurityFinding]:
    """Scan a single file for patterns"""
    findings = []

    try:
        content = filepath.read_text(encoding='utf-8', errors='ignore')
        lines = content.splitlines()

        for line_num, line in enumerate(lines, 1):
            for pattern, message in patterns:
                matches = re.finditer(pattern, line, re.IGNORECASE)
                for match in matches:
                    # Skip test files for some patterns
                    if 'test' in str(filepath).lower() and severity != 'critical':
                        continue

                    # Skip documentation files
                    if filepath.suffix in {'.md', '.rst', '.txt'}:
                        continue

                    # Check for false positives (env var checks, not actual secrets)
                    if 'process.env' in line or 'os.environ' in line or 'os.getenv' in line:
                        if severity != 'critical':
                            continue

                    # Skip placeholder examples
                    if 'your-api-key' in line.lower() or 'example' in line.lower():
                        continue

                    findings.append(SecurityFinding(
                        severity=severity,
                        category=category,
                        file=str(filepath),
                        line=line_num,
                        message=message,
                        match=match.group(0)[:50] + ('...' if len(match.group(0)) > 50 else ''),
                    ))
    except Exception as e:
        pass  # Skip unreadable files

    return findings


def scan_for_secrets(root_dir: Path) -> list[SecurityFinding]:
    """Scan for hardcoded secrets"""
    findings = []
    for filepath in root_dir.rglob('*'):
        if filepath.is_file() and should_scan_file(filepath):
            findings.extend(scan_file(filepath, SECRET_PATTERNS, "secrets", "critical"))
    return findings


def scan_for_secret_logging(root_dir: Path) -> list[SecurityFinding]:
    """Scan for secrets being logged"""
    findings = []
    for filepath in root_dir.rglob('*'):
        if filepath.is_file() and should_scan_file(filepath):
            findings.extend(scan_file(filepath, SECRET_LOGGING_PATTERNS, "secret_logging", "high"))
    return findings


def scan_for_permission_bypass(root_dir: Path) -> list[SecurityFinding]:
    """Scan for permission bypass patterns"""
    findings = []

    # Files where permission bypass is expected
    expected_bypass_files = ['cc-watch.ts', 'ralph.sh', 'ralph-worker.sh']

    for filepath in root_dir.rglob('*'):
        if filepath.is_file() and should_scan_file(filepath):
            file_findings = scan_file(filepath, PERMISSION_BYPASS_PATTERNS, "permission_bypass", "info")
            # Upgrade severity for non-expected locations
            for finding in file_findings:
                if '--dangerously-skip-permissions' in finding.match:
                    # Check if this is in an expected file
                    if any(exp in filepath.name for exp in expected_bypass_files):
                        finding.message += " (expected - YOLO mode implementation)"
                    else:
                        finding.severity = "high"
                        finding.message += " (unexpected location)"
            findings.extend(file_findings)
    return findings


def scan_for_command_injection(root_dir: Path) -> list[SecurityFinding]:
    """Scan for command injection vulnerabilities"""
    findings = []
    for filepath in root_dir.rglob('*'):
        if filepath.is_file() and should_scan_file(filepath):
            findings.extend(scan_file(filepath, COMMAND_INJECTION_PATTERNS, "command_injection", "high"))
    return findings


def verify_api_key_not_logged(root_dir: Path) -> list[SecurityFinding]:
    """
    Specific check: Verify ANTHROPIC_API_KEY is not logged in plaintext
    This is a critical security requirement from the spec
    """
    findings = []

    # Patterns that would indicate the actual key value is being logged/printed
    # Excludes: existence checks, instruction text, pattern strings
    dangerous_patterns = [
        # JS/TS: console.log with the actual env value (not just checking if set)
        (r'console\.log\s*\([^)]*process\.env\.ANTHROPIC_API_KEY(?!\s*\?)', "API key value may be logged"),
        # Python: print with actual env value
        (r'print\s*\([^)]*os\.(?:environ|getenv)\s*\[["\']ANTHROPIC_API_KEY', "API key value may be logged"),
        # Shell: echo/log with unquoted variable expansion
        (r'echo\s+[^"\']*\$ANTHROPIC_API_KEY(?!["\'])', "API key value may be echoed"),
    ]

    for filepath in root_dir.rglob('*'):
        if filepath.is_file() and should_scan_file(filepath):
            try:
                content = filepath.read_text(encoding='utf-8', errors='ignore')
                lines = content.splitlines()

                for line_num, line in enumerate(lines, 1):
                    # Skip pattern definition lines (regex strings)
                    if "r'" in line or 'r"' in line:
                        continue
                    # Skip comments
                    stripped = line.strip()
                    if stripped.startswith('#') or stripped.startswith('//') or stripped.startswith('*'):
                        continue

                    for pattern, message in dangerous_patterns:
                        if re.search(pattern, line, re.IGNORECASE):
                            findings.append(SecurityFinding(
                                severity="critical",
                                category="api_key_exposure",
                                file=str(filepath),
                                line=line_num,
                                message=message,
                                match=line.strip()[:60],
                                remediation="Never log API key values. Only log that the key is set/unset."
                            ))
            except Exception:
                pass

    return findings


def verify_permission_bypass_scope(root_dir: Path) -> list[SecurityFinding]:
    """
    Specific check: Verify permission bypass is limited to ralph.sh execution only
    This is a critical security requirement from the spec
    """
    findings = []

    # Files where --dangerously-skip-permissions is expected (actual execution code)
    expected_locations = {
        'cc-watch.ts': 'YOLO mode for ralph execution',
        'ralph.sh': 'Autonomous task execution',
        'ralph-worker.sh': 'Parallel worker execution',
    }

    for filepath in root_dir.rglob('*'):
        if filepath.is_file() and should_scan_file(filepath):
            try:
                content = filepath.read_text(encoding='utf-8', errors='ignore')
                if '--dangerously-skip-permissions' in content:
                    filename = filepath.name

                    # Skip documentation, logs, test files, and pattern definitions
                    skip_suffixes = {'.md', '.json', '.yaml', '.yml', '.txt'}
                    if filepath.suffix in skip_suffixes:
                        continue
                    if 'test' in str(filepath).lower():
                        continue
                    if 'spec' in str(filepath).lower():
                        continue

                    if filename not in expected_locations:
                        findings.append(SecurityFinding(
                            severity="high",
                            category="permission_bypass_scope",
                            file=str(filepath),
                            line=0,
                            message=f"Permission bypass used in unexpected file",
                            remediation="Permission bypass should only be used in approved files: " +
                                       ", ".join(expected_locations.keys())
                        ))
            except Exception:
                pass

    return findings


def run_security_scan(root_dir: Path) -> ScanResult:
    """Run full security scan"""
    all_findings = []
    files_scanned = 0

    # Count files
    for filepath in root_dir.rglob('*'):
        if filepath.is_file() and should_scan_file(filepath):
            files_scanned += 1

    # Run all scans
    all_findings.extend(scan_for_secrets(root_dir))
    all_findings.extend(scan_for_secret_logging(root_dir))
    all_findings.extend(scan_for_permission_bypass(root_dir))
    all_findings.extend(scan_for_command_injection(root_dir))

    # Run specific verification checks
    all_findings.extend(verify_api_key_not_logged(root_dir))
    all_findings.extend(verify_permission_bypass_scope(root_dir))

    # Summarize
    summary = {
        "critical": len([f for f in all_findings if f.severity == "critical"]),
        "high": len([f for f in all_findings if f.severity == "high"]),
        "medium": len([f for f in all_findings if f.severity == "medium"]),
        "low": len([f for f in all_findings if f.severity == "low"]),
        "info": len([f for f in all_findings if f.severity == "info"]),
    }

    # Determine status - fail if any critical or high (non-expected) findings
    critical_or_high_issues = [
        f for f in all_findings
        if f.severity in ("critical", "high") and "(expected" not in f.message
    ]

    status = "fail" if critical_or_high_issues else "pass"

    return ScanResult(
        status=status,
        total_files_scanned=files_scanned,
        findings=all_findings,
        summary=summary
    )


def main():
    parser = argparse.ArgumentParser(description="Security scanner for Claude Watch")
    parser.add_argument("--all-files", action="store_true", help="Scan all files")
    parser.add_argument("--json", action="store_true", help="Output as JSON")
    parser.add_argument("--path", default=".", help="Root path to scan")
    args = parser.parse_args()

    root_dir = Path(args.path).resolve()

    if not root_dir.exists():
        print(f"Error: Path {root_dir} does not exist", file=sys.stderr)
        sys.exit(1)

    result = run_security_scan(root_dir)

    if args.json:
        print(json.dumps(result.to_dict(), indent=2))
    else:
        print(f"\nSecurity Scan Results")
        print(f"=" * 50)
        print(f"Status: {result.status.upper()}")
        print(f"Files scanned: {result.total_files_scanned}")
        print(f"\nSummary:")
        for severity, count in result.summary.items():
            if count > 0:
                print(f"  {severity}: {count}")

        if result.findings:
            print(f"\nFindings:")
            for f in result.findings:
                print(f"  [{f.severity.upper()}] {f.category}: {f.file}:{f.line}")
                print(f"    {f.message}")
                if f.match:
                    print(f"    Match: {f.match}")

    # Exit with non-zero if failed
    sys.exit(0 if result.status == "pass" else 1)


if __name__ == "__main__":
    main()
