---
description: Run the weekly homelab check (health check, then version audit), check only
---

Follow `sop/weekly-check.md` from start to finish. Read it, and the two SOPs it links, before running anything.

- Check only: never run `maintenance.yml`, `site.yml`, Terraform, or any fix, even when a finding suggests one.
- If `ssh-add -l` doesn't list the RSA key, stop and ask me to run `! ssh-add ~/.ssh/id_rsa`.
- Finish with the summary path, both result lines, and the "Needs action" list.

$ARGUMENTS
