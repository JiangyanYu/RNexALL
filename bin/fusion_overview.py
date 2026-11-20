#!/usr/bin/env python3

import argparse
import csv
import json
from collections import defaultdict
from pathlib import Path

from openpyxl import Workbook
from openpyxl.styles import Alignment, Font, PatternFill
from openpyxl.utils import get_column_letter


def read_filtered_table(path: Path, fusion_column: str, count_column: str) -> dict:
    counts = defaultdict(int)
    with path.open(newline="") as handle:
        reader = csv.DictReader(handle, delimiter="\t")
        required_columns = {fusion_column, count_column, "sample"}
        missing_columns = required_columns.difference(reader.fieldnames or [])
        if missing_columns:
            raise ValueError(f"{path} is missing required columns: {', '.join(sorted(missing_columns))}")

        for row in reader:
            fusion = row[fusion_column]
            sample = row["sample"]
            if fusion_column == "#FusionName":
                fusion = fusion.replace("--", "::")
            try:
                count = int(row[count_column])
            except (TypeError, ValueError) as error:
                raise ValueError(f"Invalid {count_column} for {fusion} in sample {sample}: {row[count_column]}") from error
            counts[(fusion, sample)] += count
    return counts


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--arriba", type=Path, required=True)
    parser.add_argument("--starfusion", type=Path, required=True)
    parser.add_argument("--samples", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    samples = list(dict.fromkeys(json.loads(args.samples.read_text())))
    arriba_counts = read_filtered_table(args.arriba, "fusions", "sum_split_reads")
    starfusion_counts = read_filtered_table(args.starfusion, "#FusionName", "JunctionReadCount")
    fusions = sorted({fusion for fusion, _ in arriba_counts} | {fusion for fusion, _ in starfusion_counts})

    workbook = Workbook()
    sheet = workbook.active
    sheet.title = "Fusion overview"

    sheet.cell(row=2, column=1, value="fusion_name")
    for sample_index, sample in enumerate(samples):
        arriba_column = 2 + sample_index * 2
        starfusion_column = arriba_column + 1
        sheet.merge_cells(
            start_row=1,
            start_column=arriba_column,
            end_row=1,
            end_column=starfusion_column,
        )
        sample_cell = sheet.cell(row=1, column=arriba_column, value=sample)
        sample_cell.alignment = Alignment(horizontal="center")
        sheet.cell(row=2, column=arriba_column, value="Arriba")
        sheet.cell(row=2, column=starfusion_column, value="STAR-Fusion")

    for fusion in fusions:
        row = [fusion]
        for sample in samples:
            row.extend([
                arriba_counts.get((fusion, sample)),
                starfusion_counts.get((fusion, sample)),
            ])
        sheet.append(row)

    matched_fill = PatternFill(fill_type="solid", fgColor="FFF2CC")
    matched_font = Font(bold=True)
    for fusion_index, fusion in enumerate(fusions, start=3):
        for sample_index, sample in enumerate(samples):
            arriba_key = (fusion, sample)
            starfusion_key = (fusion, sample)
            if arriba_key in arriba_counts and starfusion_key in starfusion_counts:
                arriba_cell = sheet.cell(row=fusion_index, column=2 + sample_index * 2)
                starfusion_cell = sheet.cell(row=fusion_index, column=3 + sample_index * 2)
                for cell in (arriba_cell, starfusion_cell):
                    cell.fill = matched_fill
                    cell.font = matched_font

    header_fill = PatternFill(fill_type="solid", fgColor="D9EAF7")
    for row in sheet.iter_rows(min_row=1, max_row=2):
        for cell in row:
            cell.font = Font(bold=True)
            cell.fill = header_fill
            cell.alignment = Alignment(horizontal="center")

    sheet.freeze_panes = "B3"
    sheet.auto_filter.ref = f"A2:{get_column_letter(1 + len(samples) * 2)}{max(sheet.max_row, 2)}"
    for column_index, column in enumerate(sheet.columns, start=1):
        column_letter = get_column_letter(column_index)
        width = max(len(str(cell.value or "")) for cell in column) + 2
        sheet.column_dimensions[column_letter].width = min(width, 40)

    workbook.save(args.output)


if __name__ == "__main__":
    main()
