from __future__ import annotations

import argparse
import datetime as dt
import os
import shutil
import tempfile
import zipfile
import xml.etree.ElementTree as ET
from pathlib import Path


W_NS = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
XML_NS = "http://www.w3.org/XML/1998/namespace"
ET.register_namespace("w", W_NS)


REPLACEMENTS = [
    (
        "But most studies focus on whether seasonal events are happening earlier or later on average, "
        "even though climate change may also make the seasonal signals animals use to time breeding less reliable5,6.",
        "But most studies focus on whether seasonal events are happening earlier or later on average, "
        "even though changing environmental conditions may also make the seasonal signals animals use to time breeding less reliable5,6.",
    ),
    (
        "Our results show that stable average timing can hide important ecological change and suggest that climate change "
        "can reduce reproduction not only by shifting seasonal timing, but also by making favourable conditions less reliable.",
        "Our results show that stable average timing can hide important ecological change and suggest that reduced seasonal "
        "reliability can be associated with lower reproduction even when average seasonal timing does not shift.",
    ),
    (
        "The paradox suggests that climate impacts may be missed when attention focuses only on changes in mean timing. "
        "We propose that climate change can erode demography not only by shifting when seasonal resources occur, "
        "but also by reducing how predictable those resources are from year to year.",
        "The paradox suggests that environmental effects on reproduction may be missed when attention focuses only on "
        "changes in mean timing. We propose that changes in seasonal predictability may be associated with reproductive "
        "decline, even when seasonal resources do not shift directionally.",
    ),
    (
        "Here, we test whether loss of environmental predictabilitycan explain demographic decline in blue-footed boobies",
        "Here, we test whether loss of environmental predictability is associated with declining reproductive performance in blue-footed boobies",
    ),
    (
        "(ii) breeding synchrony erodes as mismatch becomes more variable",
        "(ii) breeding synchrony weakens as mismatch becomes more variable",
    ),
    (
        "(iii) reduced synchrony translates into lower reproductive success.",
        "(iii) reduced synchrony is associated with lower reproductive success.",
    ),
    (
        "if year-to-year variability in bloom timing increases, breeding synchrony will weaken and reproductive success will decline even if mean bloom timing does not shift",
        "if year-to-year variability in bloom timing increases, this should be associated with weaker breeding synchrony and lower reproductive success even if mean bloom timing does not shift",
    ),
    (
        "Environmental unpredictability as a driver of demographic change",
        "Environmental unpredictability and reproductive change",
    ),
    (
        "As a result, synchrony weakened even though average timing remained unchanged, and reproductive performance declined and became less consistent",
        "In parallel, synchrony weakened even though average timing remained unchanged, and reproductive performance declined and became less consistent",
    ),
    (
        "demonstrating that synchrony can erode even without directional shifts in mean phenology",
        "showing that synchrony can weaken even without directional shifts in mean phenology",
    ),
    (
        "Where the timing of seasonal resources becomes less reliable, predictability can constrain the maintenance of synchrony with resource peaks",
        "Where the timing of seasonal resources becomes less reliable, lower predictability may constrain the maintenance of synchrony with resource peaks",
    ),
    (
        "Taken together, these results show that environmental change can affect demographic performance not only through shifts in mean timing but also through changes in the reliability of seasonal timing.",
        "Taken together, these results show that environmental change may be associated with reproductive performance not only through shifts in mean timing but also through changes in the reliability of seasonal timing.",
    ),
    (
        "our studyreveals a previously underappreciated dimension of climate impact in this system",
        "our study reveals a previously underappreciated dimension of environmental change in this system",
    ),
    (
        "pathways by which climate change erodes synchrony and demographic performance.",
        "pathways through which environmental change is associated with weakened synchrony and reproductive performance.",
    ),
]

COPYEDITS = [
    ("Thisis unexpected", "This is unexpected"),
    ("aligningoffspring", "aligning offspring"),
    ("assessed;most", "assessed; most"),
    ("affectshow", "affects how"),
    ("predictablethan", "predictable than"),
    ("predictabilitycan", "predictability can"),
    ("productivity,associated", "productivity, associated"),
    ("web17,18", "web 17,18"),
    ("thereforeanalysed", "therefore analysed"),
    ("studyreveals", "study reveals"),
]


def replace_in_text_nodes(nodes: list[ET.Element], old: str, new: str) -> int:
    count = 0
    while True:
        full_text = "".join(node.text or "" for node in nodes)
        start = full_text.find(old)
        if start == -1:
            return count
        end = start + len(old)
        cursor = 0
        touched = []
        for node in nodes:
            text = node.text or ""
            node_start = cursor
            node_end = cursor + len(text)
            if node_end > start and node_start < end:
                touched.append((node, text, node_start, node_end))
            cursor = node_end

        for idx, (node, text, node_start, node_end) in enumerate(touched):
            local_start = max(start - node_start, 0)
            local_end = min(end - node_start, len(text))
            if len(touched) == 1:
                node.text = text[:local_start] + new + text[local_end:]
            elif idx == 0:
                node.text = text[:local_start] + new
            elif idx == len(touched) - 1:
                node.text = text[local_end:]
            else:
                node.text = ""
            if node.text and (node.text[0].isspace() or node.text[-1].isspace()):
                node.set(f"{{{XML_NS}}}space", "preserve")
        count += 1


def patch_document_xml(xml_bytes: bytes) -> tuple[bytes, list[tuple[str, int]], list[str]]:
    root = ET.fromstring(xml_bytes)
    paragraphs = root.findall(f".//{{{W_NS}}}p")
    changes: list[tuple[str, int]] = []
    missed: list[str] = []
    for old, new in REPLACEMENTS + COPYEDITS:
        total = 0
        for paragraph in paragraphs:
            nodes = paragraph.findall(f".//{{{W_NS}}}t")
            if nodes:
                total += replace_in_text_nodes(nodes, old, new)
        changes.append((old[:80], total))
        if total == 0:
            missed.append(old)
    return ET.tostring(root, encoding="utf-8", xml_declaration=True), changes, missed


def patch_docx(path: Path) -> tuple[Path, list[tuple[str, int]], list[str]]:
    timestamp = dt.datetime.now().strftime("%Y%m%d_%H%M%S")
    backup = path.with_name(f"{path.stem}.backup_before_causal_softening_{timestamp}{path.suffix}")
    shutil.copy2(path, backup)

    with zipfile.ZipFile(path, "r") as zin:
        document_xml = zin.read("word/document.xml")
        patched_xml, changes, missed = patch_document_xml(document_xml)
        fd, tmp_name = tempfile.mkstemp(suffix=".docx", dir=str(path.parent))
        os.close(fd)
        tmp_path = Path(tmp_name)
        try:
            with zipfile.ZipFile(tmp_path, "w", compression=zipfile.ZIP_DEFLATED) as zout:
                for item in zin.infolist():
                    data = patched_xml if item.filename == "word/document.xml" else zin.read(item.filename)
                    zout.writestr(item, data)
            os.replace(tmp_path, path)
        finally:
            if tmp_path.exists():
                tmp_path.unlink()

    return backup, changes, missed


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("docx", type=Path)
    args = parser.parse_args()
    backup, changes, missed = patch_docx(args.docx)
    print(f"Backup: {backup}")
    for label, count in changes:
        print(f"{count:2d}  {label}")
    if missed:
        print("Missed replacements:")
        for item in missed:
            print(f"- {item}")


if __name__ == "__main__":
    main()
