#!/usr/bin/env python3

import argparse
import csv
import json
from collections import defaultdict
from pathlib import Path

from openpyxl import Workbook
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

    headers = ["fusion_name"]
    for sample in samples:
        headers.extend([f"{sample}_Arriba", f"{sample}_STAR-Fusion"])
    sheet.append(headers)

    for fusion in fusions:
        row = [fusion]
        for sample in samples:
            row.extend([
                arriba_counts.get((fusion, sample)),
                starfusion_counts.get((fusion, sample)),
            ])
        sheet.append(row)

    sheet.freeze_panes = "B2"
    sheet.auto_filter.ref = f"A1:{get_column_letter(len(headers))}{max(sheet.max_row, 1)}"
    for column in sheet.columns:
        column_letter = column[0].column_letter
        width = max(len(str(cell.value or "")) for cell in column) + 2
        sheet.column_dimensions[column_letter].width = min(width, 40)

    workbook.save(args.output)


if __name__ == "__main__":
    main()
