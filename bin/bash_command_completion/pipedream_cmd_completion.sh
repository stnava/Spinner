#!bash
##############################################################################
# file: pipedream_cmd_completion.sh
# description: bash programmable command completion for the command 'pipedream'
# usage: include the following into your '.bash_profile' or '.bashrc'
#        source <path to Spinner root dir>/bin/bash_command_completion/...
#               ...pipedream_cmd_completion.sh
##############################################################################
pipedream_cmd_completion()
{
    # current word (possibly incomplete)
    local cur=${COMP_WORDS[COMP_CWORD]}
    # return array
    COMPREPLY=()
    if (($COMP_CWORD == 1)); then
	case "$cur" in
	    -* )
  	        # complete the word using predefined list of options
		COMPREPLY=($(compgen -W '-dicom2scalarimage -is_brain_in_image -compare_trainingimages_to_testimages' -- $cur));;
	    # will use more cases if needed in future
	    # * )
	esac
    fi
    return 0
}
complete -F pipedream_cmd_completion pipedream