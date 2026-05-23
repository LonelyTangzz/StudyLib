"""sample.py — Harness Demo 的试验靶子

故意写得简单，方便用来：
- 让 Claude Edit/Write 它，触发 PostToolUse hook 写日志
- 让 code-explainer subagent 解释它
- 让 /changelog 命令在你改完它后生成条目
"""

from datetime import datetime


def greet(name: str = "World") -> str:
    """Return a time-aware greeting for `name`."""
    hour = datetime.now().hour
    if 5 <= hour < 12:
        salutation = "Good morning"
    elif 12 <= hour < 18:
        salutation = "Good afternoon"
    elif 18 <= hour < 23:
        salutation = "Good evening"
    else:
        salutation = "Hello, night owl"
    return f"{salutation}, {name}!"


if __name__ == "__main__":
    print(greet())
