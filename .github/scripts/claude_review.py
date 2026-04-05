import anthropic
import os
import sys

with open("diff.txt", "r") as f:
    diff = f.read()

if not diff.strip():
    print("Diff is empty — nothing to review.")
    sys.exit(0)

if len(diff) > 30000:
    diff = diff[:30000] + "\n\n[diff truncated — showing first 30 000 chars]"

client = anthropic.Anthropic(api_key=os.environ["ANTHROPIC_API_KEY"])

message = client.messages.create(
    model="claude-opus-4-6",
    max_tokens=2048,
    messages=[
        {
            "role": "user",
            "content": (
                "You are reviewing a Flutter/Dart pull request for **Mine Master**, "
                "a minesweeper puzzle game.\n\n"
                f"PR title: {os.environ['PR_TITLE']}\n\n"
                "Review the following git diff and provide concise, actionable feedback. Focus on:\n"
                "- Correctness and logic bugs\n"
                "- Flutter/Dart best practices (widget lifecycle, state management, dispose)\n"
                "- Performance concerns (unnecessary rebuilds, animation controllers not disposed)\n"
                "- Security issues\n"
                "- Missing edge cases\n\n"
                "Do NOT flag style nitpicks or suggest refactors beyond the scope of the PR.\n"
                "Format your response in markdown with a brief summary at the top, "
                "then specific comments grouped by file.\n"
                "If the changes look good, say so clearly.\n\n"
                f"```diff\n{diff}\n```"
            ),
        }
    ],
)

review = message.content[0].text

with open("review.md", "w") as f:
    f.write("## Claude Code Review\n\n")
    f.write(review)
    f.write("\n\n---\n*Reviewed by [Claude](https://claude.ai) via GitHub Actions*")

print("Review written to review.md")
