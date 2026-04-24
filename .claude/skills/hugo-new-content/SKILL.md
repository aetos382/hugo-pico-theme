---
name: hugo-new-content
description: Creates a new Hugo content file with proper front matter and directory structure by running `hugo new`. Use this skill whenever the user invokes `/hugo-new-content`, wants to create a new Hugo blog post or article, says "新しい記事を作って", "ブログ投稿を追加して", "create a new post", "add a new article", or similar content creation requests in a Hugo site context. Always use this skill — never create Hugo content files manually without it.
---

# Hugo New Content Skill

This skill creates a new Hugo content file by running `hugo new`, following the project's conventions for path layout and front matter.

## Step 1: Find the Hugo site root

**Do not run Step 2 in parallel with this step.** Determine `SITE_ROOT` first, then proceed.

Check in this order:
1. Current working directory — if it contains a `content/` directory and one of `hugo.toml`, `hugo.yaml`, `hugo.json`, `config.toml`, `config.yaml`, `config.json`, or `config/`, it is the site root.
2. If not, read `.claude/settings.json` and check each path listed under `additionalDirectories`. Use the first one that passes the same check.

Also verify the `hugo` CLI is available (`hugo version`).

If no valid Hugo site is found, show a clear error and stop. Set the found directory as `SITE_ROOT` for all subsequent steps.

## Step 2: Apply defaults from rules

Extension defaults should be set in `{SITE_ROOT}/CLAUDE.md`. Claude Code automatically loads CLAUDE.md from directories listed in `additionalDirectories`, injecting its content into the conversation context. Check the loaded CLAUDE.md content for key-value pairs.

Look for key-value pairs in the injected content (e.g., `extension: .adoc`, `- extension: .adoc`, `**extension**: .adoc` are all valid).

Built-in defaults (used when no rules content is found in context):
- `extension`: `.md`
- `section`: `posts`

## Step 3: Collect parameters

### Title
If the user provided a title as an argument (e.g., `/hugo-new-content "私の最初の記事"`), use it. Otherwise, ask:
> 記事のタイトルを入力してください:

### Extension
If the user provided `--ext .adoc` or similar, use it. Otherwise use the rules default or built-in default (`.md`). Supported values: `.md`, `.adoc`, `.html`.

### Section
If the user provided `--section blog` or similar, use it. Otherwise use the rules default or built-in default (`posts`). The section determines the content subdirectory (e.g., `content/posts/`, `content/blog/`).

## Step 4: Generate the slug

The slug is used for the directory name. Rules:
- If the title is in English (or other ASCII-compatible language), convert to kebab-case: lowercase, spaces → hyphens, remove special characters.
- If the title is in Japanese or another non-ASCII language, translate it to concise English first, then convert to kebab-case.
- Keep slugs short (3–6 words max). Drop articles (a, the, an) from the slug.

**Examples:**
- `"My First Post"` → `my-first-post`
- `"Hugo でブログを始める"` → `getting-started-with-hugo-blog`
- `"AsciiDoc の使い方"` → `how-to-use-asciidoc`

## Step 5: Build the content path

Use the current date (today's date from the system or the date in CLAUDE.md if provided):

```
content/{section}/{YYYY}/{MM}/{YYYY}-{MM}-{slug}/index{extension}
```

Where `{MM}` is zero-padded (e.g., `04`).

**Example:** Title "Hugo でブログを始める", date 2026-04-24, section `posts`, extension `.adoc`
→ `content/posts/2026/04/2026-04-getting-started-with-hugo-blog/index.adoc`

## Step 6: Check for matching archetype

Hugo picks the archetype automatically via `hugo new`, following this priority:

1. Site-level `archetypes/{section}{extension}` (e.g., `archetypes/posts.adoc`)
2. Site-level `archetypes/default{extension}`
3. Theme-provided archetype with the same extension

**Before proceeding, verify an archetype exists for the chosen extension.**

Collect archetype directories from two independent sources, then union the results.

**Source 1 — Hugo modules** (`hugo config mounts`):

Hugo resolves module dependencies transitively, so this covers all module-based themes in one step.

```bash
cd {SITE_ROOT} && hugo config mounts \
  | jq -rs '[.[] | select(.mounts[]? | .target == "archetypes")] | .[].dir'
```

**Source 2 — git submodule / classic themes** (breadth-first traversal of `theme` keys):

Hugo theme components can be nested: a theme's own config may reference further themes. Traverse them breadth-first until no new directories are found.

1. Start with a queue containing `{SITE_ROOT}` and an empty visited set.
2. For each directory in the queue:
   a. Read `hugo.toml` or `config/_default/hugo.toml` in that directory.
   b. Extract `themesDir` (default: `themes`) and `theme` (string or array — treat both uniformly as a list of names).
   c. **Ignore any theme name that looks like a module path** (contains `.` before the first `/`, e.g. `github.com/foo/bar`). These are handled by Source 1.
   d. For each remaining theme name, compute `candidate = {SITE_ROOT}/{themesDir}/{name}`. If that directory exists and has not been visited, add it to the queue and the visited set.
3. The visited set (excluding `{SITE_ROOT}` itself) gives the local theme directories.

Add `{theme_dir}/archetypes` for each discovered theme directory.

**Search all collected directories for a usable archetype:**

Hugo matches archetypes by both section/kind name AND extension. It looks for `archetypes/{section}{extension}` then `archetypes/default{extension}`. A `.md` archetype is NOT used as a fallback for a `.adoc` file.

```bash
find "{dir}/archetypes" -type f \( -name "{section}{extension}" -o -name "default{extension}" \) 2>/dev/null
```

**If found:** proceed silently.

**If not found:**

  ```
  警告: archetype が見つかりませんでした。
  確認したディレクトリ:
    - {dir}/archetypes/  (hugo config mounts)
    - {SITE_ROOT}/themes/{theme}/archetypes/  (hugo.toml theme キー)
    ...
  Hugo 組み込みの最小テンプレートで作成されます（カスタム front matter なし）。
  ```
  Ask the user: このまま続行しますか？ (y/n) — if no, stop.

You don't need to pass `--kind` explicitly — just run `hugo new` with the content path and Hugo resolves the archetype.

## Step 7: Run hugo new

Run from `SITE_ROOT`:

```bash
hugo new {content-path}
```

For example (with `SITE_ROOT=demo-site/`):
```bash
cd demo-site && hugo new content/posts/2026/04/2026-04-getting-started-with-hugo-blog/index.adoc
```

If the `hugo new` command fails, show the error output and stop.

## Step 8: Fix the title in the generated file

`hugo new` derives the title from the file path via the archetype template, so the generated title will differ from what the user provided — it typically includes the date prefix (e.g., `"2026 04 Getting Started With Hugo"` instead of `"Getting Started with Hugo"`). Always replace it with the actual user-provided title.

Read the generated file and locate the title field in the front matter:
- YAML (`---` blocks): `title: '...'` or `title: "..."`
- TOML (`+++` blocks): `title = '...'` or `title = "..."`

Replace the value with the user-provided title using the Edit tool. Preserve the quoting style already in the file.

**Example:**
Generated: `title: '2026 04 Getting Started With Hugo'`
→ Replace with: `title: 'Getting Started with Hugo'`

For Japanese titles, use the original Japanese string (not the English slug):
Generated: `title: '2026 04 How To Customize Hugo Theme'`
→ Replace with: `title: 'Hugo テーマのカスタマイズ方法'`

## Step 9: Report success

Show:
- The full path of the created file (relative to project root)
- The title
- The slug used
- Offer to open the file for editing

**Example output:**
```
✓ 記事を作成しました

ファイル: content/posts/2026/04/2026-04-getting-started-with-hugo-blog/index.adoc
タイトル: Hugo でブログを始める
スラグ:   getting-started-with-hugo-blog
```
