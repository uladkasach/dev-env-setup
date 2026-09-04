
########################
## install fuzzy finder
#########################
https://github.com/junegunn/fzf

#########################
## install neovim
## ref: https://betterprogramming.pub/setting-up-neovim-for-web-development-in-2020-d800de3efacd
#########################
sudo add-apt-repository ppa:neovim-ppa/stable
sudo apt-get update
sudo apt-get install neovim

# install plugin manager; https://github.com/junegunn/vim-plug
sh -c 'curl -fLo "${XDG_DATA_HOME:-$HOME/.local/share}"/nvim/site/autoload/plug.vim --create-dirs \
       https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'

# create config file
mkdir ~/.config/nvim;
vim ~/.config/nvim/init.vim; # TODO: backup the config
vim ~/.config/nvim/coc-settings.json; # TODO: backup the config

# https://vimawesome.com/plugin/surround-vim
# https://vimawesome.com/plugin/fzf, https://github.com/junegunn/fzf.vim
apt-get install silversearcher-ag # to replace `ack`, somehow related to fzf, since `ag` considers gitignores (e.g. ignore node-modules)
# ```
# nnoremap <C-p> :FZF<CR>
# let g:fzf_action = {
  # \ 'ctrl-t': 'tab split',
  # \ 'ctrl-s': 'split',
  # \ 'ctrl-v': 'vsplit'
  # \}
# requires silversearcher-ag
# used to ignore gitignore files
# let $FZF_DEFAULT_COMMAND = 'ag -g ""'
# ```


# remap for going to definitions + etc
# ```
# Remap keys for gotos
# nmap <silent> gd <Plug>(coc-definition)
# nmap <silent> gy <Plug>(coc-type-definition)
# nmap <silent> gi <Plug>(coc-implementation)
# nmap <silent> gr <Plug>(coc-references)
# ```

# install required fonts for vim-devicons
wget https://github.com/ryanoasis/nerd-fonts/releases/download/v2.1.0/DejaVuSansMono.zip
unzip DejaVuSansMono.zip -d ~/.fonts
fc-cache -fv
# !: now actually update the terminal to use the font; # TODO: use a programatic terminal which we can config w/ code

# use nvim coc recommended config
https://github.com/neoclide/coc.nvim


# todo: map ctrl+s to save (& escape to normal mode, if applicable)
# https://stackoverflow.com/a/31932467/3068233

# ~/.vimrc
nnoremap <c-s> :w<CR> # normal mode: save
inoremap <c-s> <Esc>:w<CR>l # insert mode: escape to normal and save
vnoremap <c-s> <Esc>:w<CR> # visual mode: escape to normal and save

# ~/.zshrc
# enable control-s and control-q, by preventing their default action
stty start undef
stty stop undef
setopt noflowcontrol

# set relative line numbers
set relativenumber

# trigger autocomplete menu
inoremap <silent><expr> <c-space> coc#refresh()

# default tab to two spaces
filetype plugin indent on
# " On pressing tab, insert 2 spaces
# set expandtab
# " show existing tab with 2 spaces width
# set tabstop=2
# set softtabstop=2
# " when indenting with '>', use 2 spaces width
# set shiftwidth=2


# install easy dir to create dirs w/ files easily
Plug 'duggiefresh/vim-easydir'


# install the plugins
nvim +PlugInstall

# prettier
# https://github.com/neoclide/coc-prettier
