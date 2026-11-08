#!/usr/bin/env python3
"""Render the non-private synthetic OCR fixtures and write their manifest."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
from typing import Any

from PIL import Image, ImageDraw, ImageFont, __version__ as pillow_version


ROOT = Path(__file__).resolve().parent
WIDTH = 1000
HEIGHT = 1400
MARGIN = 80


CASES: list[dict[str, Any]] = [
    {
        "id": "mixed-zh-en-01",
        "categories": ["chinese", "english"],
        "lines": [
            "会议记录 / Meeting Notes",
            "日期：2025-01-01   Date: 2025-01-01",
            "开始时间 09:30   End time 10:15",
            "请在周五前回复。 Please reply by Friday.",
        ],
    },
    {
        "id": "mixed-zh-en-02",
        "categories": ["chinese", "english"],
        "lines": [
            "设备状态 / Device Status",
            "温度 Temperature: 21.5 C",
            "电量 Battery: 84 percent",
            "状态：正常   Status: Ready",
        ],
    },
    {
        "id": "english-paragraph-01",
        "categories": ["english"],
        "lines": [
            "Synthetic Field Report",
            "The north gate opened at 08:10.",
            "Two sample boxes arrived before noon.",
            "No action is required today.",
        ],
    },
    {
        "id": "dense-small-zh-01",
        "categories": ["chinese", "dense_small_text"],
        "font_size": 16,
        "lines": [
            "合成文本 01：第 1 项数量为 18，状态已核对。",
            "合成文本 02：第 2 项数量为 24，状态已核对。",
            "合成文本 03：第 3 项数量为 31，状态已核对。",
            "合成文本 04：第 4 项数量为 12，状态已核对。",
            "合成文本 05：第 5 项数量为 27，状态已核对。",
            "合成文本 06：第 6 项数量为 16，状态已核对。",
            "合成文本 07：第 7 项数量为 22，状态已核对。",
            "合成文本 08：第 8 项数量为 35，状态已核对。",
            "合成文本 09：第 9 项数量为 11，状态已核对。",
            "合成文本 10：第 10 项数量为 29，状态已核对。",
            "合成文本 11：第 11 项数量为 14，状态已核对。",
            "合成文本 12：第 12 项数量为 33，状态已核对。",
            "合成文本 13：第 13 项数量为 20，状态已核对。",
            "合成文本 14：第 14 项数量为 17，状态已核对。",
            "合成文本 15：第 15 项数量为 28，状态已核对。",
            "合成文本 16：第 16 项数量为 13，状态已核对。",
            "合成文本 17：第 17 项数量为 32，状态已核对。",
            "合成文本 18：第 18 项数量为 19，状态已核对。",
        ],
    },
    {
        "id": "dense-small-en-01",
        "categories": ["english", "dense_small_text"],
        "font_size": 16,
        "lines": [
            "Batch A  Item 01  Count 18  Checked",
            "Batch A  Item 02  Count 24  Checked",
            "Batch A  Item 03  Count 31  Checked",
            "Batch A  Item 04  Count 12  Checked",
            "Batch A  Item 05  Count 27  Checked",
            "Batch A  Item 06  Count 16  Checked",
            "Batch B  Item 07  Count 22  Checked",
            "Batch B  Item 08  Count 35  Checked",
            "Batch B  Item 09  Count 11  Checked",
            "Batch B  Item 10  Count 29  Checked",
            "Batch B  Item 11  Count 14  Checked",
            "Batch B  Item 12  Count 33  Checked",
            "Batch C  Item 13  Count 20  Checked",
            "Batch C  Item 14  Count 17  Checked",
            "Batch C  Item 15  Count 28  Checked",
            "Batch C  Item 16  Count 13  Checked",
            "Batch C  Item 17  Count 32  Checked",
            "Batch C  Item 18  Count 19  Checked",
        ],
    },
    {
        "id": "dense-small-mixed-01",
        "categories": ["chinese", "english", "dense_small_text"],
        "font_size": 16,
        "lines": [
            "序号 01  Code A-01  检查通过",
            "序号 02  Code A-02  检查通过",
            "序号 03  Code A-03  检查通过",
            "序号 04  Code A-04  检查通过",
            "序号 05  Code A-05  检查通过",
            "序号 06  Code A-06  检查通过",
            "序号 07  Code B-07  检查通过",
            "序号 08  Code B-08  检查通过",
            "序号 09  Code B-09  检查通过",
            "序号 10  Code B-10  检查通过",
            "序号 11  Code B-11  检查通过",
            "序号 12  Code B-12  检查通过",
            "序号 13  Code C-13  检查通过",
            "序号 14  Code C-14  检查通过",
            "序号 15  Code C-15  检查通过",
            "序号 16  Code C-16  检查通过",
            "序号 17  Code C-17  检查通过",
            "序号 18  Code C-18  检查通过",
        ],
    },
    {
        "id": "rotated-90-zh",
        "categories": ["chinese", "rotated"],
        "rotation": 90,
        "lines": [
            "仓库盘点",
            "日期：2025-02-01",
            "箱数：12",
            "结果：完成",
        ],
    },
    {
        "id": "rotated-minus-7-en",
        "categories": ["english", "rotated"],
        "rotation": -7,
        "lines": [
            "Rotated Sample",
            "Station: North",
            "Count: 42",
            "Result: Complete",
        ],
    },
    {
        "id": "columns-zh-01",
        "categories": ["chinese", "multi_column"],
        "columns": [
            ["左栏 A：收货时间 08:15", "左栏 B：箱数 12", "左栏 C：已检查"],
            ["右栏 A：负责人 甲", "右栏 B：状态 完成", "右栏 C：备注 无"],
        ],
    },
    {
        "id": "columns-en-01",
        "categories": ["english", "multi_column"],
        "columns": [
            ["Column A - Step 1", "Column A - Step 2", "Column A - Step 3"],
            ["Column B - Step 1", "Column B - Step 2", "Column B - Step 3"],
        ],
    },
    {
        "id": "columns-mixed-01",
        "categories": ["chinese", "english", "multi_column"],
        "columns": [
            ["左侧 Left 01：打开页面", "左侧 Left 02：选择文件"],
            ["右侧 Right 01: Review", "右侧 Right 02: Save"],
        ],
    },
    {
        "id": "table-zh-01",
        "categories": ["chinese", "table"],
        "title": "物品清单",
        "table": [
            ["品名", "数量", "单价"],
            ["笔记本", "2", "8.50"],
            ["文件夹", "1", "3.00"],
        ],
    },
    {
        "id": "table-en-01",
        "categories": ["english", "table"],
        "title": "Synthetic Order",
        "table": [
            ["Code", "Count", "Total"],
            ["P-12", "3", "15.00"],
            ["Q-07", "2", "8.00"],
        ],
    },
    {
        "id": "table-mixed-01",
        "categories": ["chinese", "english", "table"],
        "title": "库存 / Inventory",
        "table": [
            ["名称 Name", "数量 Qty"],
            ["纸张 Paper", "40"],
            ["墨水 Ink", "6"],
        ],
    },
    {
        "id": "formula-algebra-01",
        "categories": ["english", "formula"],
        "lines": ["Solve for x", "2x + 3 = 11", "Answer: x = 4"],
        "formula_text": "2x + 3 = 11",
    },
    {
        "id": "formula-calculus-01",
        "categories": ["english", "formula"],
        "lines": ["Area under curve", "∫_0^1 x^2 dx = 1/3"],
        "formula_text": "∫_0^1 x^2 dx = 1/3",
    },
    {
        "id": "formula-mixed-01",
        "categories": ["chinese", "english", "formula"],
        "lines": ["面积 Area", "A = πr²", "其中 r = 3"],
        "formula_text": "A = πr²",
    },
    {
        "id": "blank-white-01",
        "categories": ["blank"],
        "lines": [],
    },
    {
        "id": "blank-gray-02",
        "categories": ["blank"],
        "lines": [],
        "background": "#f7f7f7",
    },
    {
        "id": "low-contrast-zh-01",
        "categories": ["chinese", "low_contrast"],
        "ink": "#b5b5b5",
        "lines": ["低对比度测试", "合成文字 仅用于离线识别质量评估"],
    },
    {
        "id": "low-contrast-en-01",
        "categories": ["english", "low_contrast"],
        "ink": "#b5b5b5",
        "lines": ["Low Contrast Sample", "Synthetic text for offline evaluation."],
    },
    {
        "id": "low-contrast-mixed-01",
        "categories": ["chinese", "english", "low_contrast"],
        "ink": "#c0c0c0",
        "lines": ["状态 Status: 待复核", "数量 Count: 18"],
    },
    {
        "id": "short-english-01",
        "categories": ["english"],
        "lines": ["TOTAL: 7.25", "TAX: 0.50"],
    },
    {
        "id": "punctuation-zh-01",
        "categories": ["chinese"],
        "lines": ["注意：逗号，句号。冒号：括号（）", "编号 A-17 / B-08"],
    },
]


def _draw_lines(
    draw: ImageDraw.ImageDraw,
    lines: list[str],
    font: ImageFont.FreeTypeFont,
    color: str,
    *,
    x: int = MARGIN,
    y: int = 160,
    line_gap: int = 14,
) -> None:
    line_height = font.size + line_gap
    for index, line in enumerate(lines):
        draw.text((x, y + index * line_height), line, font=font, fill=color)


def _render_table(
    draw: ImageDraw.ImageDraw,
    rows: list[list[str]],
    font: ImageFont.FreeTypeFont,
    color: str,
) -> None:
    x0 = MARGIN
    y0 = 260
    table_width = WIDTH - MARGIN * 2
    row_height = 76
    columns = max(len(row) for row in rows)
    column_width = table_width // columns
    line_color = "#666666" if color != "#b5b5b5" else "#c8c8c8"
    for row_index, row in enumerate(rows):
        top = y0 + row_index * row_height
        for column_index in range(columns):
            left = x0 + column_index * column_width
            right = x0 + (column_index + 1) * column_width
            draw.rectangle(
                (left, top, right, top + row_height),
                outline=line_color,
                width=2,
            )
            if column_index < len(row):
                draw.text(
                    (left + 12, top + 16),
                    row[column_index],
                    font=font,
                    fill=color,
                )


def render_case(
    case: dict[str, Any], font_path: Path, image_path: Path
) -> dict[str, Any]:
    background = case.get("background", "#ffffff")
    ink = case.get("ink", "#1b1b1b")
    image = Image.new("RGB", (WIDTH, HEIGHT), background)
    draw = ImageDraw.Draw(image)
    font = ImageFont.truetype(str(font_path), case.get("font_size", 30))

    title = case.get("title")
    if title:
        draw.text((MARGIN, 120), title, font=font, fill=ink)

    columns = case.get("columns")
    table = case.get("table")
    if columns:
        left, right = columns
        column_font = ImageFont.truetype(str(font_path), case.get("font_size", 23))
        _draw_lines(draw, left, column_font, ink, x=MARGIN, y=200, line_gap=28)
        _draw_lines(
            draw,
            right,
            column_font,
            ink,
            x=WIDTH // 2 + 10,
            y=200,
            line_gap=28,
        )
        draw.line((WIDTH // 2, 180, WIDTH // 2, 980), fill="#dddddd", width=2)
        gold_lines = left + right
        reading_order = left + right
        table_text = None
    elif table:
        _render_table(draw, table, font, ink)
        table_text = "\n".join(" | ".join(row) for row in table)
        gold_lines = ([title] if title else []) + [
            " | ".join(row) for row in table
        ]
        reading_order = []
    else:
        lines = case.get("lines", [])
        font_size = case.get("font_size", 30)
        line_gap = 5 if font_size <= 16 else 14
        _draw_lines(draw, lines, font, ink, line_gap=line_gap)
        gold_lines = lines
        reading_order = []
        table_text = None

    formula_text = case.get("formula_text")
    if case.get("rotation") is not None:
        image = image.rotate(
            case["rotation"],
            expand=True,
            fillcolor=background,
            resample=Image.Resampling.BICUBIC,
        )

    image_path.parent.mkdir(parents=True, exist_ok=True)
    image.save(image_path, format="PNG", optimize=False, compress_level=9)
    image_bytes = image_path.read_bytes()
    width, height = image.size
    return {
        "id": case["id"],
        "image": image_path.relative_to(ROOT).as_posix(),
        "sha256": hashlib.sha256(image_bytes).hexdigest(),
        "width": width,
        "height": height,
        "categories": case["categories"],
        "gold_text": "\n".join(gold_lines),
        **({"reading_order": reading_order} if reading_order else {}),
        **({"table_text": table_text} if table_text is not None else {}),
        **({"formula_text": formula_text} if formula_text is not None else {}),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--font",
        type=Path,
        required=True,
        help="path to the exact Noto Sans CJK font used for deterministic rendering",
    )
    args = parser.parse_args()
    font_path = args.font.expanduser().resolve()
    if not font_path.is_file():
        parser.error(f"font file does not exist: {font_path}")

    cases = []
    for case in CASES:
        image_path = ROOT / "fixtures" / f"{case['id']}.png"
        cases.append(render_case(case, font_path, image_path))

    font_hash = hashlib.sha256(font_path.read_bytes()).hexdigest()
    manifest = {
        "schema_version": 1,
        "source": "synthetic_non_private",
        "rendering": {
            "generator": "generate_fixtures.py",
            "pillow_version": pillow_version,
            "font_filename": font_path.name,
            "font_sha256": font_hash,
            "canvas": [WIDTH, HEIGHT],
        },
        "fixtures": cases,
    }
    manifest_path = ROOT / "manifest.json"
    manifest_path.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"Rendered {len(cases)} synthetic OCR fixtures to {ROOT / 'fixtures'}")
    print(f"Manifest: {manifest_path}")
    print(f"Font SHA-256: {font_hash}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
