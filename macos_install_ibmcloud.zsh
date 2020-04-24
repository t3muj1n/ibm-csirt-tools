#!/usr/bin/env zsh

install_requirements () {}
	if ! which bash ; then 
		echo "bash is required. attempting to install with brew";
		brew install bash || return 1;
	fi
	if ! which jq ; then 
		echo "jq is required. attempting to install with brew.";
		brew install jq || return 1;
	fi
	if ! which curl ; then 
		echo "curl not installed. installing"
		brew install curl || return 1;
	fi
	if ! ibmcloud ; then 
		echo "ibmcloud not installed. attempting to install";
		if ! curl -sL https://ibm.biz/idt-installer | bash; then 
			echo "something went wrong trying to install ibmcloud"
			return 1;
		fi
	else
		echo "ibmcloud located. attempting to install ibm cloud-object-storage"
		if ! ibmcloud plugin install cloud-object-storage; then
			echo "something went wrong installing the plugin."
			return 1;
		fi
	fi
}
#execute the above function.
echo "this assumes that you have homebrew installed."
echo "if it is not uninstalled, please install it first"
install_requirements;
