# Godot LibGDX Texture Packer Atlas Importer

This addon adds an `EditorImportPlugin` to Godot to support the LibGDX Texture Packer atlas format.

## Installation

Simply [download](https://github.com/Rubonnek/godot-libgdx-texture-packer-atlas-importer/archive/refs/heads/main.zip) or clone this repository and copy the contents of the
`addons` folder to your own project's `addons` folder.

Then enable the plugin on the Project Settings.

## Usage

Pack the individual sprites using the [GDX Texture Packer GUI](https://github.com/crashinvaders/gdx-texture-packer-gui) and copy or move the exported spritesheet (`.png`) along with the associated atlas information file (`.atlas`) to the same folder within your Godot project.

This plugin will generate a `<spritesheet_filename>.sprites` folder within which you'll find the each `AtlasTexture` associated with the spritesheet.

## Benefits

The main benefits to use this tool are:

1. Packing texture will no longer require a restart from Godot.
2. [GDX Texture Packer GUI](https://github.com/crashinvaders/gdx-texture-packer-gui) itself provides an interface in which you can manage all your texture atlases separately which is great for bigger projects.

## License

[MIT License](LICENSE). Copyright (c) 2021 Wilson Enrique Alvarez Torres.
