---
name: feedback_commit_push
description: Always ask the user for confirmation before running git commit or git push in the Panorama project
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 71346a42-72c1-42bb-83e6-2209c1906cd7
---

Always ask for confirmation before running `git commit` or `git push`.

**Why:** User preference — they want to review what gets committed/pushed before it happens.

**How to apply:** After preparing a commit message, present it to the user and ask "Soll ich committen und pushen?" (or similar) before executing. Do not commit or push autonomously.
