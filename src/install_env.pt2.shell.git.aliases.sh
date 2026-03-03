#######################
## set git aliases
#######################
git config --global alias.lg "log --pretty=format:'%C(yellow)%h %Cred%ad %C(cyan)%an%Cgreen%d %Creset%s' --date=short" # more concise alt to git log
git config --global alias.root 'rev-parse --show-toplevel' # e.g., `cd $(git root)`
git config --global alias.recommit 'commit --amend --no-edit' # e.g., to update the last commit in place
git config --global alias.shove 'push origin HEAD --force-with-lease' # e.g., git push current branches commits, as long as we have all the commits already too

git config --global alias.release '!bash -c "source ~/.bash_aliases && git_alias_release \"\$@\"" --'
git config --global alias.tree '!bash -c "source ~/.bash_aliases && git_alias_tree \"\$@\"" --'
git config --global alias.grab '!bash -c "source ~/.bash_aliases && git_alias_grab \"\$@\"" --'
git config --global alias.graft '!bash -c "source ~/.bash_aliases && git_alias_graft \"\$@\"" --'
