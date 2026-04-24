---
name: hugo-new-content
description: Creates a new Hugo content file with proper front matter and directory structure by running `hugo new`. Use this skill whenever the user invokes `/hugo-new-content`, wants to create a new Hugo blog post or article, says "新しい記事を作って", "ブログ投稿を追加して", "create a new post", "add a new article", or similar content creation requests in a Hugo site context. Always use this skill — never create Hugo content files manually without it.
---

# Hugo New Content Skill

This skill creates a new Hugo content file by running `hugo new`, following the project's conventions for path layout and front matter.

## Step 1: Validate environment

Check the current working directory is a Hugo site:
- Must contain a `content/` directory
- Must have one of: `hugo.toml`, `hugo.yaml`, `hugo.json`, `config.toml`, `config.yaml`, `config.json`, or a `config/` directory
- The `hugo` CLI must be available (`hugo version`)

If validation fails, show a clear error message and stop.

## Step 2: Load defaults from rules

Check for `.claude/rules/hugo-new-content.md` in the current working directory. If it exists, read it to find configured defaults. Look for lines like:

```
extension: .adoc
draft: false
```

The file is free-form Markdown, so extract key-value pairs flexibly (e.g., `extension: .adoc`, `- extension: .adoc`, `**extension**: .adoc` are all valid). Defaults from this file override the built-in defaults below.

Built-in defaults (used when no rules file exists or a value is not set):
- `extension`: `.md`

## Step 3: Collect parameters

### Title
If the user provided a title as an argument (e.g., `/hugo-new-content "私の最初の記事"`), use it. Otherwise, ask:
> 記事のタイトルを入力してください:

### Extension
If the user provided `--ext .adoc` or similar, use it. Otherwise use the rules default or built-in default (`.md`). Supported values: `.md`, `.adoc`, `.html`.

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
content/posts/{YYYY}/{MM}/{YYYY}-{MM}-{slug}/index{extension}
```

Where `{MM}` is zero-padded (e.g., `04`).

**Example:** Title "Hugo でブログを始める", date 2026-04-24, extension `.adoc`
→ `content/posts/2026/04/2026-04-getting-started-with-hugo-blog/index.adoc`

## Step 6: Select the archetype

Hugo picks the archetype automatically via `hugo new`. The priority is:

1. Site-level `archetypes/posts{extension}` (e.g., `archetypes/posts.md`)
2. Site-level `archetypes/default{extension}`
3. Theme-provided archetype (Hugo handles this automatically)

You don't need to pass `--kind` explicitly — just run `hugo new` with the content path and Hugo resolves the archetype.

## Step 7: Run hugo new

```bash
hugo new {content-path}
```

For example:
```bash
hugo new content/posts/2026/04/2026-04-getting-started-with-hugo-blog/index.adoc
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
