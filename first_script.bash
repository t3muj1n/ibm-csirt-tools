#!/usr/bin/env bash


#login section

ibmcloud_login () {
	ibmcloud login --sso
}
#login to the ibm cloud environment 
ibmcloud_login-bak () { 
	mypass='password';   #set to your password
	mylogin="email@host.com"  #usually your email addr.
	ibmcloud login -q -u "${mylogin}" -p "${mypass}" 
};
######################################################################

#get and set the resource group required to 

get_resource_group () { 
	target_resource="$(ibmcloud  resource groups --output json | jq .[].id | tr -d \")"
};

#sets the resource group, such as an object storage instance.
set_resource_group () { 
	ibmcloud target -g "${target_resource}"
};

#get the resource crn.
get_resource_crn () { 
	resource_crn="$(ibmcloud resource service-instances --output json |jq .[].crn | tr -d \" )"
};
get_resource_name () {
	resource_name="$(ibmcloud resource service-instances --output json | jq .[].name | tr -d \")"
};

get_service_instance_id () {
	service_instance_id="$(ibmcloud resource service-instance "${resource_name}" --output json | jq .[].id | tr -d \")"
};

list_all_buckets () { 
	ibmcloud cos list-buckets --ibm-service-instance-id "${service_instance_id}" --json
};

#get bucket crn from the resource group we set above
get_bucket_crn () {
	bucket_crn="$(ibmcloud resource service-keys --output json |jq .[].crn | tr -d \" )"
};
get_bucket_name () {
	bucket_name="$(ibmcloud resource service-keys --output json | jq .[].name | tr -d \")"
};

find_a_bucket () {
	ibmcloud cos get-bucket-location --bucket "${bucket_name}" --json |jq .LocationConstraint |tr -d \"
};

list_bucket_contents () {
	ibmcloud cos list-objects --bucket "${bucket_name}"
};

##############

list_objects_in_bucket () {
	ibmcloud cos list-objects --bucket "${bucket_name}" --json |jq .Contents[].Key
};

delete_existing_bucket () {
	ibmcloud cos delete-bucket --bucket "${bucket_name}" --force --json #--region REGION 
};

###############

Get_bucket_headers () { # determine if a bucket exists
	ibmcloud cos head-bucket --bucket "${bucket_name}" --json
};

get_object_headers () { # determine if a object exists
	object_name="${1}";
	ibmcloud cos head-object --bucket "${bucket_name}" --key "${object_name}" --json
};

###################

upload_object () {
	bucket_name="${1}";
	filepath="${2}";
	md5="${3}";
	ibmcloud cos put-object --bucket "${bucket_name}" --key "${md5}" --body "${filepath}" --json #--content-md5 "${md5}"
};

Download_an_object () {
	#
	ibmcloud cos get-object --bucket "${bucket_name}" --key "${object_name}" --json | jq .
};


###################

check_which_md5 () { 
	if which md5; then
		md5sum="$(which md5) -r" ;
	elif which md5sum; then 
		md5sum="$(which md5sum)" ;
	else echo "no md5sum found.";
		return 1; 
	fi;
};

#################################
generate_md5_for_file () {
	file="${1}";
	$md5sum "${file}" || return 1;
};


get_files_to_upload () {
	workingdirectory="${1}";
	get_bucket_name; #fills the variable ${bucket_name}"
	if ! [[ -d $workingdirectory ]]; then
		echo "usage:${0} directory";
		return 1;
	else
		cd "${workingdirectory}";
		workingdirectory="${PWD}"
		casefile="${workingdirectory##*/}"
		echo "case file is ${casefile}"
	fi
	if  [[ -f "${workingdirectory}/object_name.map" ]]; then 
		echo "object_name.map exist!"
		return 1;
	fi

	for file in "${workingdirectory}"/*; do
		mydate="$(date +%Y%m%d%H%M%S)";
		read -r md5 filepath <<< $(generate_md5_for_file "${file}");
		read etag <<< "$(upload_object "${bucket_name}" "${filepath}" "${casefile}/${md5}" | jq .ETag | tr -d \")"
		#add check to check md5 with returned md5
		#also add 'case' variable to upload_object
		echo "${mydate}, ${md5}, ${filepath}, ${etag}, "
		echo "${mydate}, ${md5}, ${filepath}, ${etag}, " >> "${workingdirectory}"/object_name.map
	done
	list_bucket_contents ;
};
#i need to figure out what to do with that object_name.map file.
#it is imporant since its the only way to map object names back to filenames.


###########################

filemap () { #for mapping object names back to file names.
	mapfile="${workingdirectory}/object_name.map";
	searchstring="${1}";
	grep "${searchstring}" "${mapfile}";
};

tmpstuff () { 
	# testing how to split lines from log file
	# so that i can map object names back to file names.

#20200416095900, 87f4d9d24602b90fb2aa6ea5db365c16, ../ibm-csirt/notes.txt, ""87f4d9d24602b90fb2aa6ea5db365c16"",
#[tem@tem-laptop-attlocal-net ibm-csirt]$ tmpstuff 87f4d9d24602b90fb2aa6ea5db365c16,
#20200416095900  87f4d9d24602b90fb2aa6ea5db365c16  ../ibm-csirt/notes.txt  ""87f4d9d24602b90fb2aa6ea5db365c16"", 

	echo "$(IFS=,; read -r one two three four <<< "$(filemap $1)" ; echo "$one $two $three $four")";
};

########################################

#temporary main function. 
#eventually i need to re visit this.
#it works for now.

do_main () {

	if ! ibmcloud_login; then
		return 1;
	fi
#	if ! get_resource_group; then 
#		return 1;
#	fi
target_resource='1579946910c64cf882a6d94a03c0af2d' 
#HAD TO ADD THIS TO MAKE THIS WORK WITH SSO CREDS.
#this is because there is more than 1 resource and more than 1 bucket.
#revisit this. i might just set an ENV variable to point directly to the bucket.
	if ! set_resource_group; then 
		return 1;
	fi
	if ! get_bucket_name; then 
		return 1;
	fi
	if ! check_which_md5; then 
		return 1;
	fi
	if ! get_files_to_upload "${1}"; then
		return 1;
	fi
};
#20200423141615, 87f4d9d24602b90fb2aa6ea5db365c16, /Users/mike/csirt/CASE-2020-1234-test/notes.txt, 87f4d9d24602b90fb2aa6ea5db365c16, 
#20200423141616, 87f4d9d24602b90fb2aa6ea5db365c16, /Users/mike/csirt/CASE-2020-1234-test/notes2.txt, 87f4d9d24602b90fb2aa6ea5db365c16, 
#OK

do_main "$@"

