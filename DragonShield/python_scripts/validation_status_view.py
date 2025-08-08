"""Render Asset Allocation table with validation status and deviation bars."""
from __future__ import annotations
from dataclasses import dataclass, field
from typing import List

STATUS_ICONS = {
    "compliant": "\U0001F7E2",  # green circle
    "warning": "\U0001F7E0",    # orange circle
    "error": "\U0001F534",      # red circle
}

@dataclass
class AllocationNode:
    name: str
    validation_status: str
    deviation_percent: float
    children: List["AllocationNode"] = field(default_factory=list)

    def worst_status(self) -> str:
        order = {"compliant": 0, "warning": 1, "error": 2}
        status = self.validation_status
        for child in self.children:
            child_status = child.worst_status()
            if order[child_status] > order[status]:
                status = child_status
        return status

    def bar(self) -> str:
        slots = 10
        filled = int(round(abs(self.deviation_percent) / 10))
        filled = max(0, min(slots, filled))
        return "[" + "■" * filled + "□" * (slots - filled) + "]"


def render_table(nodes: List[AllocationNode]) -> str:
    """Return an ASCII table representing allocation validation status."""
    order = {"compliant": 0, "warning": 1, "error": 2}
    portfolio_status = "compliant"
    for n in nodes:
        st = n.worst_status()
        if order[st] > order[portfolio_status]:
            portfolio_status = st

    lines: List[str] = []
    lines.append(f"Portfolio Validation: {STATUS_ICONS[portfolio_status]}")
    lines.append("")
    lines.append("\u250C" + "\u2500" * 56 + "\u2510")
    lines.append("\u2502 Class/Sub-Class               \u2502 St \u2502 %-Deviation Bar \u2502")
    lines.append("\u251C" + "\u2500" * 32 + "\u253C" + "\u2500" * 4 + "\u253C" + "\u2500" * 17 + "\u2524")
    for node in nodes:
        lines.extend(_render_node(node, prefix=""))
    lines.append("\u2514" + "\u2500" * 32 + "\u2534" + "\u2500" * 4 + "\u2534" + "\u2500" * 17 + "\u2518")
    return "\n".join(lines)


def _render_node(node: AllocationNode, prefix: str) -> List[str]:
    icon = STATUS_ICONS.get(node.validation_status, "")
    line = f"\u2502 {prefix}{node.name:<28} \u2502 {icon} \u2502 {node.bar():<15} \u2502"
    lines = [line]
    for child in node.children:
        child_prefix = prefix + "  \u2514─ " if not child.children else prefix + "  \u251C─ "
        lines.extend(_render_node(child, prefix=child_prefix))
    return lines

if __name__ == "__main__":  # simple demo
    demo = [
        AllocationNode(
            name="EQUITY", validation_status="compliant", deviation_percent=52,
            children=[
                AllocationNode("Single Stocks", "warning", 37),
                AllocationNode("Equity ETF", "error", 18),
            ],
        ),
        AllocationNode(
            name="FIXED INCOME", validation_status="error", deviation_percent=52,
            children=[
                AllocationNode("Government Bond", "error", 55),
                AllocationNode("Corporate Bond", "compliant", 19),
            ],
        ),
    ]
    print(render_table(demo))
