# BagCleaner runtime assets

This directory reserves a clear location for files that the installed `BagCleaner` addon may need at runtime. It is intentionally separate from the repository-level [`Assets/Screenshots`](../../Assets/Screenshots) directory, which is for GitHub documentation only.

## Layout

```text
Assets/
├── Icons/       Small addon symbols, buttons, and marker artwork
├── Images/      Larger static artwork, such as panels or splash images
└── Textures/    Reusable UI textures, borders, fills, and masks
```

The directories are placeholders today: the current Lua code uses Blizzard interface paths and does not ship custom BagCleaner runtime artwork.

## Naming

- Use lowercase `kebab-case`, for example `clean-button.tga` or `panel-border.blp`.
- Start filenames with a purpose, not a version or a screen resolution: `minimap-icon.tga`, not `icon-new-2.tga`.
- Keep a texture family together with a shared prefix, such as `panel-border-top.tga` and `panel-border-left.tga`.
- Do not use spaces, localized names, or ambiguous generic names such as `image.png`.

## Formats

Use **BLP** for the most native WoW runtime choice. **TGA** is also appropriate for simple UI textures and supports alpha channels. Use PNG only for GitHub documentation or as source artwork unless its use has been tested on the target Forever client. Keep runtime files reasonably small and use dimensions appropriate to their intended UI element.

## Referencing a texture from Lua

WoW texture paths use backslashes and are relative to the game installation. A runtime texture in this folder would normally be referenced like this:

```lua
texture:SetTexture("Interface\\AddOns\\BagCleaner\\Assets\\Textures\\panel-fill.tga")
```

For an icon, use the analogous `Assets\\Icons\\...` path. Match the exact filename and case committed to the addon directory.

## Packaging note

The current release builder intentionally packages only the TOC, files explicitly referenced by `BagCleaner.toc`, and the addon README/changelog. Therefore, adding a runtime asset here alone does **not** put it in the release ZIP. Add assets only alongside a deliberate, reviewed packaging change; do not add unused artwork or change the release pipeline merely to preserve empty folders.

## Runtime assets vs. documentation images

| Location | Audience | Included in current release ZIP |
| --- | --- | --- |
| `BagCleaner/Assets/` | The WoW client at addon runtime | No, unless the package manifest/build behavior is intentionally updated |
| `Assets/Screenshots/` | Readers of GitHub Markdown | No |
