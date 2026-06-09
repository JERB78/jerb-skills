#!/usr/bin/env python3
"""
Forms Builder Pro — Rich Image Generator
=========================================

Generate PNG images for embedding in Google Forms as `addImageItem()` content.
Use this when a question needs richer explanation than plain text supports —
tables, comparison matrices, charts, numbered/bulleted lists with icons or colors.

Genera imágenes PNG para embedir en Google Forms via `addImageItem()`.
Usar cuando una pregunta necesita explicación más rica que solo texto —
tablas, matrices comparativas, charts, listas numeradas/con bullets con íconos o colores.

USAGE / USO:
    python generate_rich_image.py table --spec table_spec.json --output ./images/comparison.png
    python generate_rich_image.py chart --spec chart_spec.json --output ./images/trend.png
    python generate_rich_image.py list  --spec list_spec.json  --output ./images/steps.png

DEPENDENCIES / DEPENDENCIAS:
    pip install matplotlib pillow

The output PNGs go to a folder the user then uploads to their Google Drive,
copying each File ID into the Apps Script's CONFIG.IMAGE_IDS object.
Los PNGs de salida van a un folder que el user sube a Google Drive,
copiando cada File ID en el objeto CONFIG.IMAGE_IDS del Apps Script.

DESIGN NOTES / NOTAS DE DISEÑO:
- All outputs use a Claude Code-inspired aesthetic: clean, monochromatic base
  with strategic color accents, generous spacing, sans-serif typography.
- Width is 740px (Google Forms max image width) to avoid downscaling artifacts.
- Background is white (forms render on white) — transparency would look weird.
- Font: tries SF Pro / Inter / system sans-serif fallbacks.

- Todos los outputs usan estética inspirada en Claude Code: limpia, base monocromática
  con acentos de color estratégicos, espaciado generoso, tipografía sans-serif.
- Ancho 740px (max image width de Google Forms) para evitar downscaling.
- Fondo blanco (forms renderizan en blanco) — transparencia se vería raro.
- Font: intenta SF Pro / Inter / fallback sans-serif del sistema.
"""

import argparse
import json
import sys
from pathlib import Path

try:
    import matplotlib.pyplot as plt
    import matplotlib.patches as patches
    from matplotlib.patches import Rectangle, FancyBboxPatch
except ImportError:
    print("ERROR: matplotlib is required. Install: pip install matplotlib pillow", file=sys.stderr)
    sys.exit(1)

# ═══════════════════════════════════════════════════════════════════════════
# THEME / TEMA — Claude Code-inspired
# ═══════════════════════════════════════════════════════════════════════════

THEME = {
    "bg": "#ffffff",
    "text_primary": "#0f172a",      # slate-900
    "text_secondary": "#475569",    # slate-600
    "text_muted": "#94a3b8",        # slate-400
    "accent": "#0ea5e9",            # sky-500
    "accent_alt": "#8b5cf6",        # violet-500
    "success": "#10b981",           # emerald-500
    "warning": "#f59e0b",           # amber-500
    "danger": "#ef4444",            # red-500
    "border": "#e2e8f0",            # slate-200
    "header_bg": "#1e293b",         # slate-800
    "row_alt": "#f8fafc",           # slate-50
}

DEFAULT_WIDTH_PX = 740
DPI = 100  # 740px / 100dpi = 7.4 inches wide

FONT_FAMILY = ["SF Pro Text", "Inter", "Helvetica Neue", "Helvetica", "Arial", "sans-serif"]

plt.rcParams.update({
    "font.family": FONT_FAMILY,
    "axes.spines.top": False,
    "axes.spines.right": False,
    "axes.edgecolor": THEME["border"],
})


# ═══════════════════════════════════════════════════════════════════════════
# TABLE / TABLA — comparison matrix, feature grid, pricing table
# ═══════════════════════════════════════════════════════════════════════════

def generate_table(spec: dict, output_path: Path):
    """
    spec = {
      "title": "Comparación de planes",   # optional
      "headers": ["Feature", "Free", "Pro", "Enterprise"],
      "rows": [
        ["Storage", "5 GB", "100 GB", "Unlimited"],
        ["Users",   "1",    "5",      "Unlimited"],
        ["Support", "Email","Priority","Dedicated"],
        ...
      ],
      "highlight_column": 2,   # optional, 0-indexed column to highlight (accent color background)
      "highlight_row": null    # optional, 0-indexed row to highlight
    }
    """
    headers = spec["headers"]
    rows = spec["rows"]
    title = spec.get("title")
    highlight_col = spec.get("highlight_column")
    highlight_row = spec.get("highlight_row")

    n_cols = len(headers)
    n_rows = len(rows)

    # Calculate dimensions
    row_height = 0.5
    header_height = 0.7
    title_height = 0.6 if title else 0
    fig_height_inches = title_height + header_height + (n_rows * row_height) + 0.3
    fig_width_inches = DEFAULT_WIDTH_PX / DPI

    fig, ax = plt.subplots(figsize=(fig_width_inches, fig_height_inches), dpi=DPI)
    ax.set_xlim(0, n_cols)
    ax.set_ylim(0, n_rows + 1 + (1 if title else 0))
    ax.axis("off")
    fig.patch.set_facecolor(THEME["bg"])

    # Title
    current_y = n_rows + 1 + (1 if title else 0)
    if title:
        ax.text(
            n_cols / 2,
            current_y - 0.3,
            title,
            ha="center",
            va="top",
            fontsize=16,
            fontweight="bold",
            color=THEME["text_primary"]
        )
        current_y -= 1

    # Header row
    for col_idx, header in enumerate(headers):
        bg_color = THEME["accent"] if col_idx == highlight_col else THEME["header_bg"]
        rect = Rectangle(
            (col_idx, current_y - 1),
            1, 1,
            facecolor=bg_color,
            edgecolor=THEME["bg"],
            linewidth=1
        )
        ax.add_patch(rect)
        ax.text(
            col_idx + 0.5,
            current_y - 0.5,
            header,
            ha="center",
            va="center",
            fontsize=11,
            fontweight="bold",
            color="white"
        )
    current_y -= 1

    # Data rows
    for row_idx, row in enumerate(rows):
        is_alt = row_idx % 2 == 1
        is_highlighted_row = row_idx == highlight_row

        for col_idx, cell in enumerate(row):
            is_highlighted_col = col_idx == highlight_col

            if is_highlighted_row:
                bg = THEME["accent"] + "20"  # 20% opacity
            elif is_highlighted_col:
                bg = THEME["accent"] + "15"
            elif is_alt:
                bg = THEME["row_alt"]
            else:
                bg = THEME["bg"]

            rect = Rectangle(
                (col_idx, current_y - 1),
                1, 1,
                facecolor=bg,
                edgecolor=THEME["border"],
                linewidth=0.5
            )
            ax.add_patch(rect)
            ax.text(
                col_idx + 0.5,
                current_y - 0.5,
                str(cell),
                ha="center",
                va="center",
                fontsize=10,
                color=THEME["text_primary"]
            )
        current_y -= 1

    plt.tight_layout()
    plt.savefig(output_path, dpi=DPI, bbox_inches="tight", facecolor=THEME["bg"])
    plt.close(fig)
    print(f"✅ Table saved: {output_path}")


# ═══════════════════════════════════════════════════════════════════════════
# CHART / CHART — bar, donut, line for inline data viz
# ═══════════════════════════════════════════════════════════════════════════

def generate_chart(spec: dict, output_path: Path):
    """
    spec = {
      "title": "Cuál herramienta usás más",
      "type": "bar" | "donut" | "line",
      "data": {
        "labels": ["Claude", "ChatGPT", "Copilot", "Otro"],
        "values": [45, 30, 20, 5],
        "colors": null   # optional list of hex colors, else uses THEME palette
      },
      "x_label": "...",   # optional, line/bar only
      "y_label": "..."    # optional, line/bar only
    }
    """
    title = spec.get("title", "")
    chart_type = spec["type"]
    data = spec["data"]

    fig_width_inches = DEFAULT_WIDTH_PX / DPI
    fig, ax = plt.subplots(figsize=(fig_width_inches, 4.5), dpi=DPI)
    fig.patch.set_facecolor(THEME["bg"])

    labels = data["labels"]
    values = data["values"]
    colors = data.get("colors") or [
        THEME["accent"], THEME["accent_alt"], THEME["success"],
        THEME["warning"], THEME["danger"], THEME["text_secondary"]
    ][: len(labels)]

    if chart_type == "bar":
        bars = ax.bar(labels, values, color=colors)
        ax.set_title(title, fontsize=14, fontweight="bold", color=THEME["text_primary"], pad=20)
        ax.set_ylabel(spec.get("y_label", ""), color=THEME["text_secondary"])
        ax.set_xlabel(spec.get("x_label", ""), color=THEME["text_secondary"])
        ax.tick_params(colors=THEME["text_secondary"])
        ax.set_axisbelow(True)
        ax.grid(axis="y", color=THEME["border"], linewidth=0.5)
        # Add value labels on top of bars
        for bar, val in zip(bars, values):
            ax.text(
                bar.get_x() + bar.get_width() / 2,
                bar.get_height(),
                str(val),
                ha="center",
                va="bottom",
                color=THEME["text_primary"],
                fontsize=10,
                fontweight="bold"
            )

    elif chart_type == "donut":
        wedges, texts, autotexts = ax.pie(
            values,
            labels=labels,
            colors=colors,
            autopct="%1.0f%%",
            startangle=90,
            wedgeprops=dict(width=0.4, edgecolor=THEME["bg"], linewidth=2),
            textprops={"color": THEME["text_primary"], "fontsize": 10},
            pctdistance=0.82,
        )
        for autotext in autotexts:
            autotext.set_color("white")
            autotext.set_fontweight("bold")
        ax.set_title(title, fontsize=14, fontweight="bold", color=THEME["text_primary"], pad=20)
        ax.axis("equal")

    elif chart_type == "line":
        ax.plot(labels, values, color=THEME["accent"], linewidth=2.5, marker="o", markersize=6)
        ax.fill_between(range(len(labels)), values, alpha=0.15, color=THEME["accent"])
        ax.set_title(title, fontsize=14, fontweight="bold", color=THEME["text_primary"], pad=20)
        ax.set_ylabel(spec.get("y_label", ""), color=THEME["text_secondary"])
        ax.set_xlabel(spec.get("x_label", ""), color=THEME["text_secondary"])
        ax.tick_params(colors=THEME["text_secondary"])
        ax.set_axisbelow(True)
        ax.grid(axis="y", color=THEME["border"], linewidth=0.5)
        # Rotate x labels if many
        if len(labels) > 6:
            plt.setp(ax.get_xticklabels(), rotation=30, ha="right")

    else:
        raise ValueError(f"Unknown chart type: {chart_type}")

    plt.tight_layout()
    plt.savefig(output_path, dpi=DPI, bbox_inches="tight", facecolor=THEME["bg"])
    plt.close(fig)
    print(f"✅ Chart saved: {output_path}")


# ═══════════════════════════════════════════════════════════════════════════
# LIST / LISTA — numbered or bulleted with icons + descriptions
# ═══════════════════════════════════════════════════════════════════════════

def generate_list(spec: dict, output_path: Path):
    """
    spec = {
      "title": "Cómo se calcula tu seniority",      # optional
      "style": "numbered" | "bulleted" | "checklist",
      "items": [
        {"label": "Años de experiencia", "description": "Total years in industry, not just current role."},
        {"label": "Tipo de proyectos", "description": "Solo / small team / large team / leadership."},
        {"label": "Stack diversity",  "description": "1 stack = junior signal. 3+ stacks = senior signal."}
      ]
    }
    """
    title = spec.get("title")
    style = spec.get("style", "bulleted")
    items = spec["items"]

    n_items = len(items)
    item_height = 1.0
    title_height = 0.7 if title else 0
    fig_height_inches = title_height + (n_items * item_height) + 0.3
    fig_width_inches = DEFAULT_WIDTH_PX / DPI

    fig, ax = plt.subplots(figsize=(fig_width_inches, fig_height_inches), dpi=DPI)
    fig.patch.set_facecolor(THEME["bg"])
    ax.set_xlim(0, 10)
    ax.set_ylim(0, n_items + (1 if title else 0))
    ax.axis("off")

    current_y = n_items + (1 if title else 0)

    if title:
        ax.text(
            0,
            current_y - 0.3,
            title,
            ha="left",
            va="top",
            fontsize=16,
            fontweight="bold",
            color=THEME["text_primary"]
        )
        current_y -= 1

    for idx, item in enumerate(items):
        # Bullet/number
        if style == "numbered":
            marker = f"{idx + 1}."
            marker_color = THEME["accent"]
        elif style == "checklist":
            marker = "✓"
            marker_color = THEME["success"]
        else:  # bulleted
            marker = "●"
            marker_color = THEME["accent"]

        ax.text(
            0.2,
            current_y - 0.4,
            marker,
            ha="left",
            va="center",
            fontsize=14,
            fontweight="bold",
            color=marker_color
        )

        # Label
        label = item.get("label", "")
        ax.text(
            0.8,
            current_y - 0.3,
            label,
            ha="left",
            va="center",
            fontsize=12,
            fontweight="bold",
            color=THEME["text_primary"]
        )

        # Description (if present)
        desc = item.get("description")
        if desc:
            ax.text(
                0.8,
                current_y - 0.7,
                desc,
                ha="left",
                va="center",
                fontsize=10,
                color=THEME["text_secondary"]
            )

        current_y -= 1

    plt.tight_layout()
    plt.savefig(output_path, dpi=DPI, bbox_inches="tight", facecolor=THEME["bg"])
    plt.close(fig)
    print(f"✅ List saved: {output_path}")


# ═══════════════════════════════════════════════════════════════════════════
# CLI ENTRY POINT
# ═══════════════════════════════════════════════════════════════════════════

def main():
    parser = argparse.ArgumentParser(
        description="Generate rich content PNGs for Google Forms image items.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
    python generate_rich_image.py table --spec my_table.json --output ./images/comparison.png
    python generate_rich_image.py chart --spec my_chart.json --output ./images/distribution.png
    python generate_rich_image.py list  --spec my_list.json  --output ./images/steps.png
    python generate_rich_image.py --inline-table "Plan,Free,Pro|Storage,5GB,100GB|Users,1,5" --output ./quick.png
        """
    )

    parser.add_argument("type", choices=["table", "chart", "list"], help="Type of rich content to generate")
    parser.add_argument("--spec", type=Path, help="JSON spec file (see docstrings for format)")
    parser.add_argument("--output", type=Path, required=True, help="Output PNG path")
    parser.add_argument("--inline-table", type=str, help="Shortcut for tables: 'h1,h2,h3|r1c1,r1c2,r1c3|r2c1,r2c2,r2c3'")

    args = parser.parse_args()

    # Ensure output dir exists
    args.output.parent.mkdir(parents=True, exist_ok=True)

    # Load spec
    if args.inline_table and args.type == "table":
        rows = args.inline_table.split("|")
        spec = {
            "headers": rows[0].split(","),
            "rows": [r.split(",") for r in rows[1:]]
        }
    elif args.spec:
        spec = json.loads(args.spec.read_text(encoding="utf-8"))
    else:
        parser.error("Either --spec or --inline-table is required.")

    # Dispatch
    if args.type == "table":
        generate_table(spec, args.output)
    elif args.type == "chart":
        generate_chart(spec, args.output)
    elif args.type == "list":
        generate_list(spec, args.output)


if __name__ == "__main__":
    main()
