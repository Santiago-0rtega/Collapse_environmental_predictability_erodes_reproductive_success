from __future__ import annotations

from pathlib import Path


OUT = Path(r"C:\Users\zannt\OneDrive\Papers sub\Nature\Nature climate change\Revision\figure_table_pdf_audit.md")


REPORT = """# Figure, Table, and PDF Audit

Checked on 6 July 2026.

## Numbering Consistency

- Main display figures: Figure 1, Figure 2, and Figure 3 are captioned in `Figures.docx` and cited in the manuscript text.
- Extended Data figures: Extended Data Figs. 1-6 are captioned in `Extended Data Figs.docx` and cited from the manuscript/legend set. `brief_ms.docx` cites Extended Data Figs. 1, 2, 3, 4, 5, and 6.
- Supplementary tables: Supplementary Tables S1-S9 are present in `Supplementary material.docx` and match the manuscript/legend references.
- Main tables: no main-text tables were found.
- No figure/table numbering mismatches were found.

## Submission Metrics

- Revised title length: 80 characters, including spaces.
- Abstract length: 65 words.
- Main text length: approximately 1,688 words.
- Methods length: approximately 1,089 words before Methods references; approximately 1,760 words including Methods references.
- Legend length: approximately 590 words for the three main display figures; approximately 630 words for Extended Data figures.
- References: Methods references 25-48 are present. This implies 48 total references if main references 1-24 are present in the final submission file; verify the main-reference bibliography before submission because it was not visible in the extracted `brief_ms.docx` text.
- Display items: 3 main figures and 0 main tables.
- Extended Data/Supplementary items: 6 Extended Data figures and 9 Supplementary Tables.

## PDF Size Estimate

| PDF | Size (MiB) | Size (MB) | Pages |
|---|---:|---:|---:|
| fig1_5.pdf | 1.353 | 1.419 | 1 |
| Fig2.pdf | 0.591 | 0.620 | 1 |
| Fig3.pdf | 0.628 | 0.658 | 1 |
| Map_Isla_Isabel.pdf | 0.132 | 0.139 | 1 |
| panel_fig2_males_time.pdf | 0.474 | 0.497 | 1 |
| panel_fig3_males.pdf | 0.473 | 0.496 | 1 |
| SI_individual_mismatch_trajectories.pdf | 0.050 | 0.052 | 1 |
| **Total** | **3.701** | **3.881** | **7** |

## Editorial Follow-Up Flags

- `brief_ms.docx` contains a Code Availability statement, but a separate Data Availability heading was not found in text extraction.
- The revision tracker marks the repository DOI/Data Availability tasks as not started. Add or verify the final Data Availability statement and DOI/details before submission.
"""


def main():
    OUT.write_text(REPORT, encoding="utf-8")
    print(OUT)


if __name__ == "__main__":
    main()
