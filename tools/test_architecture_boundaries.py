"""Lightweight architecture boundary checks for Todorbit modularity.

Enforces dependency direction and contract purity for extracted boundaries,
specifically the calendar presentation contract and child-to-root prohibitions.
"""
from pathlib import Path
import re
import tempfile
import unittest
from urllib.parse import unquote, urlsplit

ROOT = Path(__file__).resolve().parents[1]

# Only tokenize the directive preamble, never Dart declarations/expressions.
# The small scanner handles nested comments and raw/escaped/triple strings;
# Dart's analyzer remains responsible for validating language syntax.
TOKEN_PATTERN = re.compile(
    r'\s+|//[^\r\n]*|\A\#![^\r\n]*|/\*'
    r'|r?(?:"""|\'\'\'|"|\')|[\w$]+|.', re.DOTALL
)
ESCAPE_PATTERN = re.compile(r'\\(?:u\{([0-9a-fA-F]+)\}|u([0-9a-fA-F]{4})|x([0-9a-fA-F]{2})|(.))', re.DOTALL)


def dart_header_tokens(source):
    position = 0
    while position < len(source):
        match = TOKEN_PATTERN.match(source, position)
        token = match.group()
        start = position
        position = match.end()
        if token.isspace() or token == '\ufeff' or token.startswith(('//', '#!')):
            continue
        if token == '/*':
            depth = 1
            for delimiter in re.finditer(r'/\*|\*/', source[position:]):
                depth += 1 if delimiter.group() == '/*' else -1
                if not depth:
                    position += delimiter.end()
                    break
            else:
                return  # Invalid Dart; leave the syntax error to the analyzer.
            continue
        raw = token.startswith('r') and token[1:2] in ('"', "'")
        quote = token[1:] if raw else token
        is_string = quote in ('"', "'", '"""', "'''")
        if is_string:
            content_start = position
            while position < len(source) and not source.startswith(quote, position):
                position += 2 if not raw and source[position] == '\\' else 1
            value = source[content_start:position]
            position += len(quote)
            if len(quote) == 3:
                value = re.sub(r'^\r?\n', '', value, count=1)
            if not raw:
                def decode_escape(escape):
                    code = next((group for group in escape.groups()[:3] if group), None)
                    return chr(int(code, 16)) if code else {
                        'n': '\n', 'r': '\r', 't': '\t', 'b': '\b', 'f': '\f', 'v': '\v',
                    }.get(escape[4], escape[4])
                value = ESCAPE_PATTERN.sub(decode_escape, value)
        else:
            value = token
        yield ('string' if is_string else 'token', value, source.count('\n', 0, start) + 1)


class Directive:
    def __init__(self, kind: str, uri: str, line: int):
        self.kind = kind
        self.uri = uri
        self.line = line

    def __repr__(self) -> str:
        return f"{self.kind} '{self.uri}' (line {self.line})"


def extract_directives(source: str) -> list[Directive]:
    """Extract all import/export URI branches from the library preamble."""
    directives = []
    tokens = iter(dart_header_tokens(source))
    current = next(tokens, None)
    while current is not None:
        _, value, line = current
        if value == '@':  # Metadata may precede a library or import/export.
            current = next(tokens, None)  # Annotation name (possibly qualified).
            current = next(tokens, None)
            while current and current[1] == '.':
                next(tokens, None)
                current = next(tokens, None)
            if current and current[1] == '(':
                depth = 1
                while depth and (current := next(tokens, None)):
                    if current[0] == 'token':
                        depth += (current[1] == '(') - (current[1] == ')')
                current = next(tokens, None)
            continue
        if value not in ('import', 'export', 'library', 'part'):
            break  # Nothing inside a declaration can be a library directive.
        kind = value
        parentheses = 0
        for token_kind, value, _ in tokens:
            if token_kind == 'token':
                if value == ';':
                    break
                parentheses += (value == '(') - (value == ')')
            elif kind in ('import', 'export') and parentheses == 0:
                directives.append(Directive(kind, value, line))
        current = next(tokens, None)
    return directives


def resolve_import_uri(source_file: Path, uri: str, repo_root: Path) -> str:
    """Resolve an import/export URI to a standardized repo-relative path or URI."""
    uri = unquote(uri)
    if uri.startswith('package:life_manager/'):
        resolved = (repo_root / 'lib' / uri[len('package:life_manager/'):]).resolve()
    elif urlsplit(uri).scheme:
        return uri
    else:
        resolved = (source_file.parent / uri).resolve()
    try:
        rel = resolved.relative_to(repo_root.resolve())
        return rel.as_posix()
    except ValueError:
        return resolved.as_posix()


def check_calendar_child_boundaries(child_path: Path, repo_root: Path = ROOT) -> list[str]:
    """Reject direct or transitive child-to-root edges through local libraries."""
    violations = []
    root_view_path = 'lib/features/calendar/calendar_view.dart'
    pending = [child_path]
    visited = set()
    while pending:
        path = pending.pop()
        if path in visited:
            continue
        visited.add(path)
        for d in extract_directives(path.read_text(encoding='utf-8')):
            resolved = resolve_import_uri(path, d.uri, repo_root)
            if resolved == root_view_path:
                violations.append(
                    f"{path.relative_to(repo_root).as_posix()}:{d.line}: Forbidden reverse dependency "
                    f"reachable from {child_path.relative_to(repo_root).as_posix()}: {d}. "
                    "Lower-level calendar components must depend on calendar_contracts.dart."
                )
            elif resolved.startswith('lib/') and (repo_root / resolved).is_file():
                pending.append(repo_root / resolved)
    return violations


def check_calendar_contracts_purity(contract_path: Path, repo_root: Path = ROOT) -> list[str]:
    """Ensure the calendar contract file is pure Dart with no UI, controller, or persistence dependencies."""
    violations = []
    source = contract_path.read_text(encoding='utf-8')
    directives = extract_directives(source)
    rel_path = contract_path.relative_to(repo_root).as_posix()

    for d in directives:
        uri = d.uri
        resolved = resolve_import_uri(contract_path, uri, repo_root)

        if resolved.startswith('package:flutter/') or resolved == 'dart:ui':
            violations.append(
                f"{rel_path}:{d.line}: Pure contract must not import Flutter: {d.kind} '{uri}'"
            )
        elif resolved.startswith('lib/app/'):
            violations.append(
                f"{rel_path}:{d.line}: Pure contract must not depend on app controller layer: {d.kind} '{uri}'"
            )
        elif resolved.startswith('lib/data/'):
            violations.append(
                f"{rel_path}:{d.line}: Pure contract must not depend on persistence/data layer: {d.kind} '{uri}'"
            )
        elif resolved.startswith('lib/features/'):
            violations.append(
                f"{rel_path}:{d.line}: Pure contract must not depend on feature UI implementations: {d.kind} '{uri}'"
            )

    return violations


class BoundaryCheckerFixtureTests(unittest.TestCase):
    """Test the boundary detection logic with synthetic fixtures to prevent false positives/negatives."""

    def check_fixture(self, source, *, contract=False, extra_files=None):
        with tempfile.TemporaryDirectory(prefix='todorbit-architecture-') as temporary:
            root = Path(temporary)
            path = root / 'lib/features/calendar/fixture.dart'
            path.parent.mkdir(parents=True)
            path.write_text(source, encoding='utf-8')
            for relative, content in (extra_files or {}).items():
                target = root / relative
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_text(content, encoding='utf-8')
            check = check_calendar_contracts_purity if contract else check_calendar_child_boundaries
            return check(path, root)

    def test_multiline_alias_and_conditional_import_export_branches(self):
        for kind in ('import', 'export'):
            with self.subTest(kind=kind):
                source = f'''{kind}
                  'calendar_contracts.dart'
                  if (dart.library.io == 'true') 'calendar_view.dart'
                  if (dart.library.html) 'package:life_manager/features/calendar/calendar_view.dart'
                  {'deferred as calendar' if kind == 'import' else 'show CalendarMode'};
                '''
                self.assertEqual(len(self.check_fixture(source)), 2)

    def test_nested_comments_and_raw_strings_do_not_hide_real_import(self):
        source = """/* outer /* inner */ ' */
        import r'calendar_view.dart';
        """
        self.assertEqual(len(self.check_fixture(source)), 1)

    def test_valid_body_strings_do_not_create_directives(self):
        source = r'''import 'calendar_contracts.dart';
        const text = r"\"; // import 'calendar_view.dart';
        const interpolated = "${"import 'calendar_view.dart';"}";
        const multiline = ''' + "'''escaped \\' quote\nimport 'calendar_view.dart';'''" + ''';
        '''
        self.assertEqual(self.check_fixture(source), [])

    def test_triple_quoted_and_escaped_uri(self):
        for uri in ("'''calendar_view.dart'''", "'''\ncalendar_view.dart'''", r"'calendar_\u0076iew.dart'",
                    r"'calendar_\x76iew.dart'", "'calendar_%76iew.dart'",
                    "'package:life_manager/features/calendar/../calendar/calendar_view.dart'"):
            with self.subTest(uri=uri):
                self.assertEqual(len(self.check_fixture(f'import {uri};')), 1)

    def test_metadata_library_comments_and_configuration_values_are_allowed(self):
        source = '''#!/usr/bin/env dart
        @Deprecated('import calendar_view.dart')
        library calendar;
        /* outer /* inner */ import 'calendar_view.dart'; */
        @pragma('test', {'label': 'import'})
        import
          'calendar_contracts.dart'
          if (dart.library.io == 'calendar_view.dart') 'calendar_config.dart'
          as config;
        export 'dart:core' show Object;
        '''
        self.assertEqual(
            [(d.kind, d.uri, d.line) for d in extract_directives(source)],
            [('import', 'calendar_contracts.dart', 6),
             ('import', 'calendar_config.dart', 6), ('export', 'dart:core', 10)],
        )
        self.assertEqual(self.check_fixture(source), [])
        self.assertEqual(len(self.check_fixture("\ufeffimport 'calendar_view.dart';")), 1)

    def test_transitive_search_handles_diamonds_and_cycles(self):
        self.assertEqual(self.check_fixture("import 'bridge.dart'; export 'other.dart';", extra_files={
            'lib/features/calendar/bridge.dart': "export 'other.dart';",
            'lib/features/calendar/other.dart': "import 'bridge.dart'; export 'dart:core';",
        }), [])

    def test_conditional_purity_uses_production_checker(self):
        for uri in ('package:flutter/material.dart', 'package:%66lutter/material.dart', 'dart:ui',
                    'package:life_manager/app/app_controller.dart',
                    '../../data/life_repository.dart', 'calendar_view.dart'):
            with self.subTest(uri=uri):
                source = f"export 'dart:core' if (dart.library.io == 'true') '{uri}';"
                self.assertEqual(len(self.check_fixture(source, contract=True)), 1)

    def test_normalized_domain_import_is_allowed_in_contract(self):
        self.assertEqual(self.check_fixture(
            "import 'package:life_manager/features/../domain/models.dart';", contract=True,
        ), [])

    def test_indirect_root_dependency_is_rejected(self):
        violations = self.check_fixture("import 'bridge.dart';", extra_files={
            'lib/features/calendar/bridge.dart': "export 'calendar_view.dart';",
        })
        self.assertEqual(len(violations), 1)
        self.assertIn('bridge.dart', violations[0])

    def test_fixture_detects_forbidden_relative_root_import(self):
        source = (
            "import 'calendar_contracts.dart';\n"
            "import 'calendar_view.dart';\n"
            "class DummyWidget {}\n"
        )
        violations = self.check_fixture(source)
        self.assertEqual(len(violations), 1)
        self.assertIn("calendar_view.dart", violations[0])

    def test_fixture_detects_forbidden_package_root_import(self):
        source = (
            "import 'package:life_manager/features/calendar/calendar_view.dart';\n"
            "class DummyWidget {}\n"
        )
        violations = self.check_fixture(source)
        self.assertEqual(len(violations), 1)

    def test_fixture_detects_forbidden_root_export(self):
        source = (
            "export 'calendar_view.dart';\n"
        )
        violations = self.check_fixture(source)
        self.assertEqual(len(violations), 1)

    def test_fixture_detects_forbidden_workspace_resource_dialog_import(self):
        with tempfile.TemporaryDirectory(prefix='todorbit-res-boundary-') as temporary:
            root = Path(temporary)
            feat = root / 'lib/features/contributors/test_file.dart'
            feat.parent.mkdir(parents=True)
            feat.write_text("import '../workspace/windows_resource_dialog.dart';", encoding='utf-8')
            violations = check_no_workspace_resource_dialog_imports('contributors', root)
            self.assertEqual(len(violations), 1)
            self.assertIn("Forbidden import of workspace/windows_resource_dialog.dart", violations[0])

    def test_fixture_detects_contract_impurities(self):
        source = (
            "import 'package:flutter/material.dart';\n"
            "import 'package:life_manager/app/app_controller.dart';\n"
            "import 'package:life_manager/data/life_repository.dart';\n"
            "import 'calendar_view.dart';\n"
            "enum CalendarMode { day, week, month }\n"
        )
        violations = self.check_fixture(source, contract=True)
        self.assertEqual(len(violations), 4)

    def test_comments_and_string_literals_do_not_trigger_false_positives(self):
        source = (
            "// import 'calendar_view.dart';\n"
            "/*\n"
            " * import 'calendar_view.dart';\n"
            " */\n"
            "const info = 'import calendar_view.dart here';\n"
            "const multi = '''\n"
            "import 'calendar_view.dart';\n"
            "''';\n"
            "void log() {\n"
            "  final str = \"import 'calendar_view.dart';\";\n"
            "}\n"
        )
        directives = extract_directives(source)
        self.assertEqual(directives, [])


class RealCalendarArchitectureBoundaryTests(unittest.TestCase):
    """Enforce architectural constraints against real project files."""

    def test_calendar_contracts_is_pure_dart(self):
        contract_path = ROOT / 'lib/features/calendar/calendar_contracts.dart'
        self.assertTrue(contract_path.exists(), f"Missing {contract_path}")
        violations = check_calendar_contracts_purity(contract_path)
        self.assertEqual(violations, [], "\n".join(violations))

    def test_calendar_month_view_does_not_import_root(self):
        month_view_path = ROOT / 'lib/features/calendar/calendar_month_view.dart'
        self.assertTrue(month_view_path.exists(), f"Missing {month_view_path}")
        violations = check_calendar_child_boundaries(month_view_path)
        self.assertEqual(violations, [], "\n".join(violations))

    def test_calendar_zoom_controller_does_not_import_root(self):
        zoom_path = ROOT / 'lib/features/calendar/calendar_zoom_controller.dart'
        self.assertTrue(zoom_path.exists(), f"Missing {zoom_path}")
        violations = check_calendar_child_boundaries(zoom_path)
        self.assertEqual(violations, [], "\n".join(violations))

    def test_calendar_view_exports_calendar_contracts(self):
        view_path = ROOT / 'lib/features/calendar/calendar_view.dart'
        self.assertTrue(view_path.exists(), f"Missing {view_path}")
        source = view_path.read_text(encoding='utf-8')
        directives = extract_directives(source)
        exported = [d.uri for d in directives if d.kind == 'export']
        self.assertIn('calendar_contracts.dart', exported,
                      "calendar_view.dart must re-export calendar_contracts.dart for caller compatibility")


def check_workspace_resource_dialog_reexport(repo_root: Path = ROOT) -> list[str]:
    reexport_path = repo_root / 'lib/features/workspace/windows_resource_dialog.dart'
    if not reexport_path.exists():
        return [f"Missing compatibility re-export {reexport_path}"]
    directives = extract_directives(reexport_path.read_text(encoding='utf-8'))
    exported = [d.uri for d in directives if d.kind == 'export']
    if not any('platform_resource_dialog.dart' in u for u in exported):
        return [f"{reexport_path}: Must re-export platform_resource_dialog.dart for backward compatibility"]
    return []


def check_no_workspace_resource_dialog_imports(feature_dir_name: str, repo_root: Path = ROOT) -> list[str]:
    violations = []
    target_dir = repo_root / 'lib/features' / feature_dir_name
    if not target_dir.exists():
        return violations
    for path in target_dir.rglob('*.dart'):
        directives = extract_directives(path.read_text(encoding='utf-8'))
        for d in directives:
            resolved = resolve_import_uri(path, d.uri, repo_root)
            if resolved == 'lib/features/workspace/windows_resource_dialog.dart':
                violations.append(
                    f"{path.relative_to(repo_root).as_posix()}:{d.line}: Forbidden import of "
                    f"workspace/windows_resource_dialog.dart: {d}. "
                    "Must import package:life_manager/platform/platform_resource_dialog.dart instead."
                )
    return violations


class RealPlatformResourceDialogBoundaryTests(unittest.TestCase):
    """Enforce ARCH-02 architectural constraints for platform resource dialog separation."""

    def test_platform_resource_dialog_exists(self):
        target = ROOT / 'lib/platform/platform_resource_dialog.dart'
        self.assertTrue(target.exists(), f"Missing {target}")

    def test_workspace_resource_dialog_reexports_platform_utility(self):
        violations = check_workspace_resource_dialog_reexport(ROOT)
        self.assertEqual(violations, [], "\n".join(violations))

    def test_contributors_does_not_import_workspace_resource_dialog(self):
        violations = check_no_workspace_resource_dialog_imports('contributors', ROOT)
        self.assertEqual(violations, [], "\n".join(violations))

    def test_settings_does_not_import_workspace_resource_dialog(self):
        violations = check_no_workspace_resource_dialog_imports('settings', ROOT)
        self.assertEqual(violations, [], "\n".join(violations))

    def test_support_does_not_import_workspace_resource_dialog(self):
        violations = check_no_workspace_resource_dialog_imports('support', ROOT)
        self.assertEqual(violations, [], "\n".join(violations))

    def test_shared_inbox_does_not_import_workspace_resource_dialog(self):
        violations = check_no_workspace_resource_dialog_imports('shared_inbox', ROOT)
        self.assertEqual(violations, [], "\n".join(violations))


if __name__ == '__main__':
    unittest.main()
