"""Turn the percent-format source (hospitality_revenue_analysis.py) into an executed Jupyter notebook.

Usage (from the notebooks/ folder):
    python build_notebook.py
"""
import re
from pathlib import Path

import nbformat
from nbconvert.preprocessors import ExecutePreprocessor

src = Path("hospitality_revenue_analysis.py").read_text(encoding="utf-8")
chunks = re.split(r"^# %%(.*)$", src, flags=re.M)

cells = []
# re.split returns [preamble, marker1, body1, marker2, body2, ...]
for marker, body in zip(chunks[1::2], chunks[2::2]):
    body = body.strip("\n")
    if "[markdown]" in marker:
        text = "\n".join(line[2:] if line.startswith("# ") else line.lstrip("#") for line in body.splitlines())
        cells.append(nbformat.v4.new_markdown_cell(text))
    else:
        cells.append(nbformat.v4.new_code_cell(body))

nb = nbformat.v4.new_notebook(cells=cells, metadata={"kernelspec": {"name": "python3", "display_name": "Python 3", "language": "python"}})
ExecutePreprocessor(timeout=900, kernel_name="python3").preprocess(nb, {"metadata": {"path": "."}})
nbformat.write(nb, "hospitality_revenue_analysis.ipynb")
print("Wrote and executed hospitality_revenue_analysis.ipynb with", len(cells), "cells")
