# Forge commands

One step per heading. `gh` is for GitHub (checked against `gh` 2.103.2),
`glab` for GitLab. **The `glab` commands are untested**: they were checked
against `glab` 1.124.0's `--help` only, until a real GitLab run.

- Write every body or comment to a temporary file outside the repo (`mktemp`)
  and pass the file. Put titles in single quotes and keep `$` and backticks
  out of them.
- Every `gh` call names the repo (`--repo <owner>/<name>`), so a fork never
  targets its upstream.
- On GitLab say "merge request" and `!P`, not "PR" and `#P`.

Placeholders: `<owner>/<name>` (the GitHub repo from `origin`), `<path>` (the
GitLab project path; on a self-hosted host, the project's full `https://`
URL), `<host>`, `<N>` (the issue), `<P>` (the PR or merge request),
`<branch>`, `<base>`, `<title>`, `<terms>`, `<file>` (a file holding the
body), `<text>`, `<login>`.

## Detect

Read the remote, then parse it. No forge command is needed on GitHub.

```bash
git remote get-url origin
```

Parse rules:

- `git@<host>:<path>.git`, `ssh://git@<host>/<path>.git` and
  `https://<host>/<path>.git` (the `.git` is optional).
- `github.com` means GitHub, with `<path>` = `<owner>/<name>`. `gitlab.com`
  means GitLab.
- Any other host is GitLab only when `glab` is installed and
  `glab auth status --hostname <host>` exits 0; otherwise it is not a forge,
  and no forge CLI is called again.

For a host other than gitlab.com, exit 0 means `glab` knows it:

```bash
glab auth status --hostname <host>
```

Link forms: `https://github.com/<owner>/<name>/blob/<branch>/<file path>`
and `https://<host>/<path>/-/blob/<branch>/<file path>`.

## Login check

Check `command -v gh` first. On GitHub you are logged in when the active
entry's `state` is `success`; its `login` is you.

```bash
gh auth status --hostname github.com --json hosts
```

On GitLab, `username` in the second command's output is you.

```bash
glab auth status --hostname <host>
glab api user --hostname <host>
```

## Repo facts

Read the visibility, whether issues are enabled and the default branch. On
GitLab, `visibility` is public, internal or private, and internal counts as
public; the other fields are `issues_enabled` and `default_branch`.

```bash
gh repo view <owner>/<name> --json visibility,hasIssuesEnabled,defaultBranchRef
```

```bash
glab repo view <path> --output json
```

## Search

```bash
gh issue list --repo <owner>/<name> --state open --search '<terms>' --limit 3 --json number,title,assignees,url
```

```bash
glab issue list --repo <path> --search '<terms>' --per-page 3 --output json
```

## Create

```bash
gh issue create --repo <owner>/<name> --title '<title>' --body-file <file> --assignee @me
```

```bash
glab issue create --repo <path> --title '<title>' --description-file <file> --assignee <login> --yes
```

## Comment

```bash
gh issue comment <N> --repo <owner>/<name> --body-file <file>
```

```bash
glab issue note <N> --repo <path> --message "$(cat <file>)"
```

## Edit body

```bash
gh issue edit <N> --repo <owner>/<name> --body-file <file>
```

```bash
glab issue update <N> --repo <path> --description-file <file>
```

## View with comments

To look for markers on GitHub, use the second command, which prints the body
and then each comment. On GitLab, look for markers in the raw output.

```bash
gh issue view <N> --repo <owner>/<name> --json title,body,state,assignees,comments
gh issue view <N> --repo <owner>/<name> --json body,comments --jq '.body, .comments[].body'
```

```bash
glab issue view <N> --repo <path> --comments --output json
```

## Assign and unassign

```bash
gh issue edit <N> --repo <owner>/<name> --add-assignee @me
gh issue edit <N> --repo <owner>/<name> --remove-assignee @me
```

```bash
glab issue update <N> --repo <path> --assignee +<login>
glab issue update <N> --repo <path> --assignee -<login>
```

## Close with reason

On GitHub the reason is `completed` or `not planned`. GitLab has no close
reason: post the comment first, then close.

```bash
gh issue close <N> --repo <owner>/<name> --reason completed
gh issue close <N> --repo <owner>/<name> --reason 'not planned'
```

```bash
glab issue close <N> --repo <path>
```

## Draft PR create

Drop `--draft` for a regular PR.

```bash
gh pr create --repo <owner>/<name> --draft --base <base> --head <branch> --title '<title>' --body-file <file>
```

```bash
glab mr create --repo <path> --draft --source-branch <branch> --target-branch <base> --title '<title>' --description-file <file> --yes
```

## Find PR by branch

```bash
gh pr list --repo <owner>/<name> --head <branch> --state all --json number,url,state,isDraft,baseRefName
```

```bash
glab mr list --repo <path> --source-branch <branch> --all --output json
```

## Edit PR body

```bash
gh pr edit <P> --repo <owner>/<name> --body-file <file>
```

```bash
glab mr update <P> --repo <path> --description-file <file> --yes
```

## Mark ready

```bash
gh pr ready <P> --repo <owner>/<name>
```

```bash
glab mr update <P> --repo <path> --ready --yes
```

## Close PR

```bash
gh pr close <P> --repo <owner>/<name> --comment '<text>'
```

```bash
glab mr note create <P> --repo <path> --message '<text>'
glab mr close <P> --repo <path>
```

## PR state

On GitLab, `state` is opened, merged or closed; the other fields are `draft`
and `merge_commit_sha`.

```bash
gh pr view <P> --repo <owner>/<name> --json state,isDraft,mergeCommit,url
```

```bash
glab mr view <P> --repo <path> --output json
```

## Branch pushes

The same git commands on both forges. Never `--force`.

```bash
git push -u origin <branch>
git push origin --delete <branch>
```
