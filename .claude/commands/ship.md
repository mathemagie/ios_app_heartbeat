---
description: Commit all changes and deploy to Vercel production
allowed-tools: Bash(git status:*), Bash(git diff:*), Bash(git add:*), Bash(git commit:*), Bash(git push:*), Bash(git branch:*), Bash(make deploy)
---

Commit the current working tree and deploy to Vercel production.

Steps:

1. Run `git status` and `git diff` (staged + unstaged) to see what changed.
2. Stage all changes with `git add -A`.
3. Write a Conventional Commit message that accurately summarizes the changes
   (e.g. `feat:`, `fix:`, `chore:`, `docs:`). End the message body with:

   ```
   Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
   ```

4. Commit. If on `main`, that's fine for this project (production is a manual deploy).
5. Push the commit to the remote with `git push`.
6. Run `make deploy` to push the current tree to Vercel production via `npx vercel --prod`.
7. Report the deployment URL from the `make deploy` output.

If there are no changes to commit, skip the commit and go straight to `make deploy`.
If `make deploy` fails (e.g. not authenticated), surface the error and suggest
`npx vercel login`.

$ARGUMENTS
