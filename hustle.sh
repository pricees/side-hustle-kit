#
# a simple way to parse shell script arguments
# 
# please edit and use to your hearts content
# 

DOT_FILE=.env
RC_FILE=.hustlerc
. ./$DOT_FILE
. ./$RC_FILE

COMMAND=$1
FULL_COMMAND=$@
echo "\$COMMAND = $COMMAND"
echo "\$FULL_COMMAND = $FULL_COMMAND"
# SERVICE=""


bootstrap() {
# Install Docker
  if hash docker 2>/dev/null; then
    echo "Docker installed...OK"
  else
    echo "Docker install...NO"
    if [ "$OSTYPE" == "linux-gnu" ]; then
      read -p "Do you wish to install this docker?" yn
      case $yn in
        [Yy]* ) curl -sSL https://get.docker.com/ | sh
        [Nn]* ) exit;;
        * ) echo "Please answer yes or no.";;
      esac
    elif [[ "$OSTYPE" == "darwin"* ]]; then
      echo "You are on a Mac. Please download this image and install:"
      echo "https://download.docker.com/mac/stable/Docker.dmg"
            # Mac OSX
    fi
  fi

  # Install the side hustle kit script
  if hash hustle 2>/dev/null; then
    echo "SideHustleKit script 'hustle' installed...OK"
  else
    echo "SideHustleKit script 'hustle' installed...NO"
      read -p "Do you wish to download this script?" yn
      case $yn in
        [Yy]* ) 
          curl -sSL https://get.sidehustlekit.com/hustle -o hustle
          chmod +x hustle
        [Nn]* ) exit;;
        * ) echo "Please answer yes or no.";;
      esac
  fi
}

image() {
  if [ -z "$SERVICE" ]; then
    if [ "$(env)" == "production" ]; then
      prod_container
    else
      dev_container
    fi
  else
    echo "${SERVICE}_CONTAINER_NAME" | tr '[:lower:]' '[:upper:]'
  fi
}

command() {
  # The first arg
  echo $COMMAND
}

args() {
  # Drop the first arg
  echo "${@:2}"
}

fetch_command() {
  declare -A docker_compose=( 
      ["start"]="docker-compose up ${DAEMONIZE}"
      ["stop"]="docker-compose down"
      ["build"]="docker-compose build"
      ["remove"]=""
    )

  declare -A docker=( 
    ["start"]="docker run ${PORTS} ${LINK} ${DAEMONIZE} --name $(image) $(image)"
    ["stop"]="docker stop $(image)"
    ["build"]="docker build . --no-cache=true -t $(image)",
    ["remove"]="docker rm $(image)"
  )

  if [ -f ./docker-compose.yaml ]; then
    echo ${docker_compose["$1"]}
  else
    echo "${docker[$1]}"
  fi
}

debug_container() {
  print_and_exec "docker run -it --entrypoint=/bin/bash $(image) -s"
}

stop_container() {
  print_and_exec $(fetch_command "stop")
}

remove_container() {
  print_and_exec $(fetch_command "remove")
}

remove_image() {
  print_and_exec "docker rmi $(image)"
}

stop_and_remove_container() {
  stop_container && remove_container
}

start_container() {
  print_and_exec $(fetch_command "start")
}

restart_container() {
  stop_and_remove_container && start_container
}

# Prepend docker command to run command in container and execute it
exec_in_container() {
  local cmd="$@"
  echo "RUNNING: docker exec -i -t $(image) sh -c \"${cmd}\""
  docker exec -i -t $(image) sh -c "${cmd}"
}

print_and_exec() {
  echo $@
  $@
}

build_container() {
  print_and_exec $(fetch_command "build")
}

DB_PATH="/data/db"

env() {
  # ENVIRONMENT="dev"
  echo ${ENVIRONMENT:-"dev"}
}
shell_into_container() {
  exec_in_container '/bin/bash'
}

prod_container() {
  echo "$(dev_container)-prod"
}

dev_container() {
  echo $CONTAINER_NAME
}

usage() {
    echo "if this was a real script you would see something useful here"
    echo ""
    echo "./simple_args_parsing.sh"
    echo "\t-h --help"
    echo "\t--environment=$ENVIRONMENT"
    echo "\t--db-path=$DB_PATH"
    echo ""
}

# while [ "$1" != "" ]; do
#     PARAM=`echo $1 | awk -F= '{print $1}'`
#     VALUE=`echo $1 | awk -F= '{print $2}'`
#     case $PARAM in
#         -h | --help)
#             usage
#             exit
#             ;;
#         --environment)
#             ENVIRONMENT=$VALUE
#             ;;
#         --db-path)
#             DB_PATH=$VALUE
#             ;;
#         *)
#             echo "ERROR: unknown parameter \"$PARAM\""
#             usage
#             exit 1
#             ;;
#     esac
#     shift
# done

echo "ENVIRONMENT is $ENVIRONMENT";
echo "DB_PATH is $DB_PATH";

case $(command) in
  new)
    new_app
    exit
    ;;
  rebuild | build)
    build_container
    new_app
    exit
    ;;
  file-permissions-sync)
    new_app
    # exec_in_container(export USERID=#{Process.uid} && export GROUPID=#{Process.gid} && file-chown-sync)
    exit
    ;;
  run-hard | run)
    exec_in_container ${@:2}
    exit
    ;;
  container_run_regex)
    exec_in_container $FULL_COMMAND
    exit
    ;;
  debug)
    debug_container
    exit
    ;;
  shell)
    shell_into_container
    exit
    ;;
  restart | r)
    restart_container
    exit
    ;;
  start | s)
    start_container
    exit
    ;;
  stop)
    stop_container
    exit
    ;;
  rm)
    remove_container
    exit
    ;;
  pristine)
    stop_and_remove_container && remove_image
    exit
    ;;
  *)
    echo "\n\nERROR: hustle '$(command)' does not exist. Run 'hustle --help'"
    echo "\n\nDefault run syntax:\n\n\t#{container_run_regex}\n\n"
    echo "\n\nConfig:\n\n\t#{config.inspect}\n\n"
    echo "\n\nOptions:\n\n\t#{options.inspect}\n\n"
    exit 1
    ;;
esac

