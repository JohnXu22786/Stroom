#!/usr/bin/env python3
"""Run one Stroom-owned CI group and verify test ownership is complete."""

from __future__ import annotations

import argparse
import fnmatch
import re
import subprocess
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
TEST_ROOT = REPO_ROOT / "tests"

# These are product responsibilities. Paths under pages/, services/, widgets/,
# providers/, models/ and utils/ first belong to the feature they exercise.
FUNCTIONAL_SUITES: dict[str, tuple[str, ...]] = {
    "component-integrations": (
        "anki/**",
        "catcatch/**",
        "pages/catcatch_page_test.dart",
        "pages/browser_*_test.dart",
        "browser_page_test.dart",
        "providers/catcatch_provider_test.dart",
        "services/browser_cookie_service_test.dart",
        "utils/mermaid_templates_test.dart",
        "widgets/mermaid_render_widget*_test.dart",
        "pages/content/mermaid_*_test.dart",
        "pages/content/text_storage_page_mermaid_return_test.dart",
    ),
    "chat-ai-core": (
        "chat_*_test.dart",
        "assistant_test.dart",
        "assistant_send_resolution_test.dart",
        "reasoning_param*_test.dart",
        "custom_param*_test.dart",
        "find_effort_param_test.dart",
        "tool_call_serialization_test.dart",
        "models/*message*_test.dart",
        "models/*tool_call*_test.dart",
        "models/mcp*_test.dart",
        "models/reasoning_event_test.dart",
        "models/attachment_base64_test.dart",
        "services/*chat*_test.dart",
        "services/anthropic_provider_test.dart",
        "services/context_manager_test.dart",
        "services/mcp*_test.dart",
        "services/openai_file_service_test.dart",
        "services/http_tool_api_key_test.dart",
        "services/todo_tool_service_test.dart",
        "services/web_search_service_test.dart",
        "services/parse_stream_error_body_test.dart",
        "services/reasoning_param_type_test.dart",
        "services/dio_exception_handling_test.dart",
        "services/custom_param*_test.dart",
        "providers/conversation*_test.dart",
        "providers/chat*_test.dart",
        "providers/mcp*_test.dart",
        "providers/system_assistant_provider_test.dart",
        "providers/api_headers_test.dart",
        "providers/context_management_settings_test.dart",
        "providers/provider_config*_test.dart",
        "providers/provider_entries_legacy_effort_migration_test.dart",
        "providers/temporary_conversation_test.dart",
        "utils/model_order_test.dart",
    ),
    "chat-ai-ui": (
        "reasoning_section_animation_test.dart",
        "pages/assistant_pages_test.dart",
        "pages/chat/**",
        "pages/chat_page/**",
        "pages/settings/llm_*_test.dart",
        "pages/settings/provider_*_test.dart",
        "pages/settings/settings_page_system_assistant_test.dart",
        "pages/settings/topic_selection_page_test.dart",
        "widgets/conversations*_test.dart",
        "widgets/temporary_conversations_page_test.dart",
        "widgets/reasoning*_test.dart",
        "widgets/tool_call_card_test.dart",
        "widgets/message_attachment_preview_test.dart",
        "widgets/message_search_test.dart",
        "widgets/search_markdown_highlight_test.dart",
        "widgets/chat_file_picker*_test.dart",
        "widgets/mcp_*_test.dart",
    ),
    "files-data": (
        "data_*_test.dart",
        "services/attachment_storage_test.dart",
        "services/backup*_test.dart",
        "services/data_*_test.dart",
        "services/manifest*_test.dart",
        "services/snapshot_service_test.dart",
        "services/batch_rename_presets_test.dart",
        "providers/folder*_test.dart",
        "utils/atomic_file_test.dart",
        "utils/batch_rename*_test.dart",
        "utils/cross_tab_folder_isolation_test.dart",
        "utils/folder_path_utils_test.dart",
        "utils/*manifest*_test.dart",
        "utils/natural_sort_test.dart",
        "pages/backup_restore_page_test.dart",
        "pages/files_page*_test.dart",
        "pages/content/text_storage_shared_test.dart",
        "widgets/batch_rename*_test.dart",
        "widgets/file_manager*_test.dart",
        "widgets/folder_picker_dialog_test.dart",
        "widgets/selection_bottom_bar_test.dart",
    ),
    "media-processing": (
        "services/asr*_test.dart",
        "services/ocr*_test.dart",
        "providers/background_task_provider_test.dart",
        "providers/ocr*_test.dart",
        "providers/tts_save_cancellation_test.dart",
        "utils/ocr_diagnostics_test.dart",
        "utils/audio*_test.dart",
        "utils/ocr_image_payload_test.dart",
        "utils/image_send_compressor_test.dart",
        "utils/image_thumbnail_loader_test.dart",
        "utils/web_thumbnail_test.dart",
        "utils/record_models_test.dart",
        "pages/content/audio*_test.dart",
        "pages/content/extended_image_editor_page_test.dart",
        "pages/content/gallery_viewer_page_test.dart",
        "pages/content/image_editor_page_test.dart",
        "pages/content/ocr*_test.dart",
        "pages/content/media_preview_sheet_test.dart",
        "pages/settings/asr_page_test.dart",
        "pages/settings/ocr_model_config_page_test.dart",
        "pages/settings/tts_create_page_test.dart",
        "pages/asr_page_lifecycle_test.dart",
        "pages/ocr/ocr_shared_test.dart",
        "widgets/app_media_picker_dialog_test.dart",
        "widgets/album_preview_chip_test.dart",
        "widgets/image_preview_dialog_test.dart",
    ),
    "text-math": (
        "math_3d*_test.dart",
        "models/math*_test.dart",
        "utils/mhchem_syntax_test.dart",
        "widgets/code_block_source_widget_test.dart",
        "widgets/code_editor_field_test.dart",
        "widgets/html_code_block_widget_test.dart",
        "widgets/markdown_widgets_test.dart",
        "widgets/math*_test.dart",
        "pages/content/math_drawing_page_test.dart",
        "pages/content/text_preview_edit_page_test.dart",
    ),
    "tasks-workflow": (
        "task_flow/**",
        "pages/task_list_shared_test.dart",
        "pages/unified_task_list/file_opener_media_test.dart",
        "pages/unified_task_list/**",
        "widgets/unified_task_list_test.dart",
        "widgets/task_list_tabs_test.dart",
        "widgets/running_elapsed_label_test.dart",
    ),
    "application-shared": (
        "startup/**",
        "services/app_log_service_test.dart",
        "services/background_service_test.dart",
        "services/bundled_asset_licenses_test.dart",
        "services/connectivity_test_service_test.dart",
        "services/desktop_app_service_test.dart",
        "services/ios_continued_task_service_test.dart",
        "services/notification_service_test.dart",
        "providers/update_provider_test.dart",
        "utils/app_version_test.dart",
        "utils/byte_lru_cache_test.dart",
        "utils/duration_parser_test.dart",
        "utils/format_file_size_test.dart",
        "utils/http_utils_test.dart",
        "utils/pop_animation_test.dart",
        "utils/system_pick_utils_test.dart",
        "widgets/connectivity_test_dialog_test.dart",
        "widgets/quit_confirmation_dialog_test.dart",
        "widgets/tap_outside_unfocus_test.dart",
        "widgets/drag_sort_area_test.dart",
        "widgets/preview_chip_test.dart",
        "widgets/transform_stretch_overscroll_test.dart",
        "widgets/update_dialog_test.dart",
        "pages/application_quit_confirmation_test.dart",
        "pages/application_startup_update_test.dart",
        "pages/background_optimization_page_test.dart",
        "pages/home_page_short_screen_test.dart",
        "pages/home_status_counts_test.dart",
        "pages/log_viewer_page_test.dart",
        "pages/navigation_main_pages_test.dart",
        "pages/settings/settings_page_test.dart",
    ),
}

# Several product areas run together to share Flutter setup. UI checks run in
# their own groups, while functional ownership remains attached to each test.
FUNCTIONAL_TO_CI_GROUP: dict[str, str] = {
    "component-integrations": "component-integrations",
    "chat-ai-core": "chat-taskflow-core",
    "chat-ai-ui": "chat-ai-ui",
    "files-data": "files-data",
    "media-processing": "built-in-components",
    "text-math": "built-in-components",
    "tasks-workflow": "chat-taskflow-core",
    "application-shared": "application-shared",
}

CI_GROUPS: tuple[str, ...] = (
    "component-integrations",
    "built-in-components",
    "chat-taskflow-core",
    "files-data",
    "application-shared",
    "chat-ai-ui",
    "feature-ui",
)


def is_feature_ui_test(path: str) -> bool:
    """Route widget tests to UI jobs and leave logic tests with their feature."""
    source = (TEST_ROOT / path).read_text(encoding="utf-8")
    # `testWidgets` is also used by service tests that need Flutter's test
    # binding, so require an operation that actually builds or inspects UI.
    builds_or_operates_widgets = re.search(
        r"\b(?:pumpWidget|pumpAndSettle|pumpFrames)\s*\("
        r"|\bfind\.(?:text|by\w+|ancestor|descendant)\b"
        r"|\b(?:tester|t|widgetTester)\."
        r"(?:pump|tap|enterText|drag|longPress|scrollUntilVisible|ensureVisible|"
        r"widget|state|element|renderObject|sendKeyEvent|takeException)\s*\(",
        source,
    )
    # This test inspects the rendered Markdown spans directly without a
    # WidgetTester, so it is still a presentation test.
    renders_markdown = path == "widgets/search_markdown_highlight_test.dart"
    return builds_or_operates_widgets is not None or renders_markdown


def discover_and_validate() -> dict[str, list[str]]:
    files = sorted(
        path.relative_to(TEST_ROOT).as_posix()
        for path in TEST_ROOT.rglob("*_test.dart")
    )
    assignments: dict[str, list[str]] = {group: [] for group in CI_GROUPS}
    errors: list[str] = []

    unmapped_suites = set(FUNCTIONAL_SUITES) - set(FUNCTIONAL_TO_CI_GROUP)
    unknown_groups = set(FUNCTIONAL_TO_CI_GROUP.values()) - set(CI_GROUPS)
    if unmapped_suites:
        errors.append(f"functional suites missing CI groups: {sorted(unmapped_suites)}")
    if unknown_groups:
        errors.append(f"functional suites map to unknown CI groups: {sorted(unknown_groups)}")

    for path in files:
        matches = [
            suite
            for suite, patterns in FUNCTIONAL_SUITES.items()
            if any(fnmatch.fnmatchcase(path, pattern) for pattern in patterns)
        ]
        if len(matches) != 1:
            errors.append(
                f"{path}: expected one functional owner, matched {matches or 'none'}"
            )
            continue
        functional_suite = matches[0]
        is_ui_test = is_feature_ui_test(path)
        if functional_suite == "chat-ai-ui" and not is_ui_test:
            group = FUNCTIONAL_TO_CI_GROUP["chat-ai-core"]
        elif (
            functional_suite != "component-integrations"
            and is_ui_test
        ):
            group = (
                FUNCTIONAL_TO_CI_GROUP["chat-ai-ui"]
                if functional_suite == "chat-ai-ui"
                else "feature-ui"
            )
        else:
            group = FUNCTIONAL_TO_CI_GROUP[functional_suite]
        if group not in assignments:
            errors.append(f"{path}: missing CI group {group}")
            continue
        assignments[group].append(path)

    if errors:
        raise ValueError("Test suite ownership must be unique and complete:\n  " + "\n  ".join(errors))
    return assignments


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("group", nargs="?", choices=list(CI_GROUPS))
    parser.add_argument("--list", action="store_true", dest="list_groups")
    args = parser.parse_args()

    try:
        assignments = discover_and_validate()
    except ValueError as error:
        print(error, file=sys.stderr)
        return 1

    if args.list_groups:
        for group, files in assignments.items():
            print(f"{group}: {len(files)} test files")
        print(f"Total: {sum(map(len, assignments.values()))} test files")
        return 0

    if args.group is None:
        parser.error("provide a CI group or use --list")

    test_files = assignments[args.group]
    if not test_files:
        print(f"CI group {args.group} has no test files.", file=sys.stderr)
        return 1

    print(f"Running {args.group}: {len(test_files)} test files")
    return subprocess.run(
        ["flutter", "test", *(f"tests/{path}" for path in test_files)],
        cwd=REPO_ROOT,
        check=False,
    ).returncode


if __name__ == "__main__":
    raise SystemExit(main())
