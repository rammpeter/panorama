#meta

Silverbullet configuration for this LLM wiki, see [Library/Std/Config](https://docs.silverbullet.md/Library/Std/Config).

```space-lua
-- Show the navigation tree (space tree) open by default
config.set("view.defaults", {
  ["std.spaceTree"] = { open = true },
})

-- Fixed header on every page (set to the wiki title by /wiki-setup)
event.listen {
  name = "hooks:renderTopWidgets",
  run = function()
    return widget.markdownBlock("# Panorama & Oracle Performance")
  end
}
```

```space-lua
-- managed-by: configuration-manager
config.set("index.paragraph.all", true)
```
