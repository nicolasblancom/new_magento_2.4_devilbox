##
##
##
## Functions
##
##
##

# Gives welcome, short explanation, ask for action to continue
function welcome_continue_create_project {
    echo 
    echo "This script needs Devilbox installed in your system. For more information: https://devilbox.readthedocs.io/en/latest/getting-started/install-the-devilbox.html"
    echo
    echo "**IMPORTANT**: this script will delete your devilbox/.env file and the devilbox/cfg/php-ini-<version>/custom.ini file, make sure to backup those"
    echo 
    echo "-- sudo is needed, as the script needs to write in your /etc/hosts file"
    echo "-- the script will make <your-user-home-dir>/www-projects as your devilbox project directory"
    echo 
    echo "Instructions: just copy and paste the commands you are given when the script finishes"
    echo "a 'devilbox/_start.sh' file will be created so you can run containers again the same way"
    echo 
    
    read -p "Are you sure you want to continue? (y/n)" decision

    case "$decision" in
        y ) return 0 ;;
        n ) echo "...canceled by user..."; exit 1 ;;
        * ) echo "...incorrect option..."; exit 1 ;;
    esac
}


function check_dbox_dir {
    if [ ! -d $dbox_dir ]; then
        echo "Error: $dbox_dir does not exist..."
        exit 1
    fi
}

function check_dbox_www_dir {
    if [ ! -d $dbox_www_dir ]; then
        echo "Error: $dbox_www_dir does not exist..."
        exit 1
    fi
}

function check_dbox_env_file {
    if [ ! -f $dbox_env_file ]; then
        echo "Error: $dbox_env_file does not exist..."
        exit 1
    fi
}

function check_dbox {
    echo "01 ---> checking deviblox enviroment...";

    check_dbox_dir

    check_dbox_www_dir

    check_dbox_env_file
}


## creates .env file from env-example
function create_new_env_file {
    # TODO remove rm statement
        rm "$dbox_dir/.env" > /dev/null 2>&1

    if [ -f "$dbox_dir/.env" ]; then
        echo "Error: .env file already exists!! Delete it first"
        exit 1
    fi

    cp "$dbox_env_file" "$dbox_dir/.env"
    chown -R $MYUSER:$MYUSER "$dbox_dir/.env"

    echo "    -- new .env file created"
}

## Searchs inside the newly created .env file and injects a new line after the last match of the searched string
## parameters:  $1 string to search
##              $2 string to replace
function inject_env_option_after_last_option_match {
    tac $_file | awk '!p && /'"$1"'/{print "'$2'"; p=1} 1' | tac > tmp.txt && mv tmp.txt $_file

    echo "        -- $2"
}

## .env replaces for specific magento 2.4.1 version
function replaces_env_helpers {
    # TODO a better possible way to doing it is to search a "service" for example PHP_SERVER, delete the entire line and after it, just leave the line as we want (enabled or disabled and with the value we want)
    echo "    -- Options injected in .env file:"
    ## php
    inject_env_option_after_last_option_match "PHP_SERVER" $dbox_PHP_SERVER

    ## web server
    inject_env_option_after_last_option_match "HTTPD_SERVER" $dbox_HTTPD_SERVER

    ## database engine
    inject_env_option_after_last_option_match "MYSQL_SERVER" $dbox_MYSQL_SERVER

    ## redis
    inject_env_option_after_last_option_match "REDIS_SERVER" $dbox_REDIS_SERVER

    ## local fylesystem
    inject_env_option_after_last_option_match "HOST_PATH_HTTPD_DATADIR" $dbox_HOST_PATH_HTTPD_DATADIR
    
    ## disable php modules
    inject_env_option_after_last_option_match "PHP_MODULES_DISABLE" $dbox_PHP_MODULES_DISABLE
}

## makes necessary .env replaces depending on magento version
function replaces_env {
    _file="$dbox_dir/.env"
    
    if [ ! -f "$_file" ]; then
        echo "Error: no .env file found"
        exit 1
    fi

    # TODO: main refactor. At this point we have to know all specification in separate variables and pass them to a unique function. Variables should be all what is defined in replaces_env_2_4_1
    # To extend: provide proper values to variables once refactor done
    case "$magento_version" in
        2.4.1 ) replaces_env_helpers ;;
        2.4.2 ) replaces_env_helpers ;;
        * ) echo "Error ${FUNCNAME[0]}: magento version provided is not available in script yet!!!"; exit 1 ;;
    esac
}

## creates docker-compose.override.yml to enable additional containers in devilbox
## parameters:  $1 magento version string
##              $dbox_www_dir devilbox projects dir path
##              $project_name string asked to the user
function enable_additional_containers {
    if [ $# -eq 0 ]; then
        echo "Error ${FUNCNAME[0]}: you must provide a magento version parameter"

        exit 1
    fi

    # TODO: extract to variables.sh file
    _file_name="docker-compose.override.yml"
    _file_path="$dbox_dir/$_file_name"
    # TODO: main refactor. Extract in a function what magento version need what docker-compose.override file (from 2.4.0 and after it needs elastic container, but it is not needed a specific file for 2.4.0 and 2.4.1 and 2.4.2, etc)
    _origin_file_path="to_copy/docker-compose.override/$1/$_file_name"

    # TODO delete rm line
    rm $_file_path > /dev/null 2>&1

    if [ -f "$_file_path" ]; then
        echo "Error: $_file_path already exists! Delete it first"
        exit 1
    fi

    cp "$_origin_file_path" "$_file_path"
    chown -R $MYUSER:$MYUSER $_file_path

    echo "    -- $_file_path created"
}

## customizes php.ini by createing custom.ini inside devilbox config php files
## parameters:  $1 magento version string
function customize_php_ini {
    if [ $# -eq 0 ]; then
        echo "Error ${FUNCNAME[0]}: you must provide a magento version parameter"

        exit 1
    fi

    case "$1" in
        2.4.1 ) php_version=7.4 ;;
        2.4.2 ) php_version=7.4 ;;
        * ) echo "Error ${FUNCNAME[0]}: magento version provided is not available in script yet!!!"; exit 1 ;;
    esac

    _file_name="custom.ini"
    _file_path="$dbox_dir/cfg/php-ini-$php_version/$_file_name"
    _origin_file_path="to_copy/php.ini/$php_version/custom.ini"

    # TODO delete rm line
    rm $_file_path > /dev/null 2>&1

    if [ -f "$_file_path" ]; then
        echo "Error: $_file_path already exists! Delete it first"
        exit 1
    fi

    cp "$_origin_file_path" "$_file_path"
    chown -R $MYUSER:$MYUSER $_file_path

    echo "    -- $_file_path created"
}

## creates a _start.sh script to run devilbox with these customized settings
## parameters:  $1 magento version string
function create_start_dbox_script {
    if [ $# -eq 0 ]; then
        echo "Error ${FUNCNAME[0]}: you must provide a magento version parameter"

        exit 1
    fi

  # To extend: add more cases if the magento version is not covered correctly in the case
    case "$1" in
        2.4* ) start_magento_version=2.4 ;;
        * ) echo "Error ${FUNCNAME[0]}: magento version provided is not available in script yet!!!"; exit 1 ;;
    esac

    _file_name="_start.sh"
    _file_path="$dbox_dir/$_file_name"
    _origin_file_path="to_copy/start_script/$start_magento_version/$_file_name"

    # TODO delete rm line
    rm $_file_path > /dev/null 2>&1

    if [ -f "$_file_path" ]; then
        echo "Error: $_file_path already exists! Delete it first"
        exit 1
    fi

    cp "$_origin_file_path" "$_file_path"
    chown -R $MYUSER:$MYUSER $_file_path
    chmod +x $_file_path

    echo "    -- $_file_path created"
}


## Copies install script into devilibox project directories and makes replaces on it
function mageinstall_create_install_script {
    if [ $# -eq 0 ]; then
        echo "Error: You need to give 2 parameters: magento_version project_name"
        exit 1
    fi

    if [ -z "$2" ]; then
        echo "Error: You need to give second parameter project_name"
        exit 1
    fi

    if [ -z "$1" ]; then
        echo "Error: You need to give first parameter magento_version"
        exit 1
    fi

    magento_version=$1
    project_name=$2

    # copy script to project dir (from there we will run installation when entered in container)
    _file_name="install_magento.sh"
    _file_path="$dbox_www_dir/$project_name/$_file_name"
    _origin_file_path="to_copy/install_magento/$magento_version/$_file_name"

    cp "$_origin_file_path" "$_file_path"
    chown -R $MYUSER:$MYUSER $_file_path
    chmod +x $_file_path

    # copy auth.json with composer credential for magento repo in project dir (from 
    # there we have to copy to devilbox user home inside the container)
    _file_name2="auth.json"
    _file_path2="$dbox_www_dir/$project_name/$_file_name2"
    _origin_file_path2="to_copy/install_magento/$magento_version/$_file_name2"

    cp "$_origin_file_path2" "$_file_path2"
    chown -R $MYUSER:$MYUSER $_file_path2

    # replace in script database creation with project_name
    sed -i "s/##project_name##/$project_name/" $_file_path


    # replace in script download magento url with magento_version
    sed -i "s/##magento_version##/$magento_version/" $_file_path
}