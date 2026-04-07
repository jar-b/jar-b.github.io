# A Multi-Cursor Use Case with Helix

**2026-04-07**

---

I recently tried out [Helix](https://helix-editor.com/).
My highlights so far are:

- **Sensible defaults** - My `config.toml` is 10 lines.
- **Built-ins** - LSP, Treesitter, and modern themes with no setup.
- **Multi-cursor**

While reviewing a pull request about a week in I came across a test suite where all of the existing acceptance tests had a setup like this:

```go
    CheckDestroy: resource.ComposeAggregateTestCheckFunc(
        testAccCheckServerlessCacheDestroy(ctx, t),
    ),
```

A great use case for Helix's multi-cursor feature.
`resource.ComposeAggregateTestCheckFunc` is unnecessary here as only a single check is being performed and it can be passed to `CheckDestroy` directly. 
The diff I wanted across all test cases was.

```diff
-               CheckDestroy: resource.ComposeAggregateTestCheckFunc(
-                       testAccCheckServerlessCacheDestroy(ctx, t),
-               ),
+               CheckDestroy:             testAccCheckServerlessCacheDestroy(ctx, t),
```


With multi-cursor, this edit can be repeated in all 10+ places simultaneously.

- `%s` - Enter `select` mode
- `CheckDestroy<CR>` - Match all occurrences of `CheckDestroy`, initializing a cursor at each location
- Remove the unnecessary wrapper function

The nice bit about the "remove" step is that you can navigate up, down or edit character by character and the same change applies at each cursor.
It doesn't require a precise find/replace regular expression, just normal editing motions.

With years of vim keybinding muscle memory I am keeping Neovim as my primary editor for now, but Helix will be sticking around for use cases like this one.
