# Rules for work on den

- At the start of each task, use the `using-agent-skills` skill to find the skills that apply. Then follow those skills.
- Before you start a task, look for open PRs, branches and worktrees for the same task. If you find stale work, continue it. Do not start again.
- Find the check command of the repo before you change code. Look in the magefile, the lefthook config, the package.json scripts and the CI workflows. Run the check before each commit.
- Do not push to main. Open a PR with a conventional-commit title.
- In a squash-merge body, wrap each line at 100 characters or less, or use an empty body.
- If the repo builds a container image, build the image and make sure that it passes before you ask for a review.
