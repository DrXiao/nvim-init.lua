# nvim - init.lua
This repository contains my personal Neovim configuration written in Lua.

## Installation
Copy the 'init.lua' file to your Neovim configuration directory (usually `~/.config/nvim`).

Then, open your Neovim and use 'Packer' to install the plugins by running the following command:
```vim
:PackerSync
```

## Note
- For nvim-tree and earlier Nvim versions, a `compat-nvim-0.x` tag is necessary for compatibility. Therefore, the current configuration sets a 'compat-nvim-0.9' tag for nvim-tree.
- This configuration takes into account the integration of the following components:
  - [nvim-tree](https://github.com/nvim-tree/nvim-tree.lua)
  - [herdr](https://github.com/herdrdev/herdr)
