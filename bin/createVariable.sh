#!/bin/bash

# Set a lot of variable in the .env file and the docker-compose file
# root password for the database
# password for the mariadb user
# port for the frontend
# network address used by vm to communicate with the api




# Set dir variable to the script directory
dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# Load styles.sh
source "${dir}/styles.sh"

# .env file path
env_file="${dir}/../myapp/.env"
env_file_template="${dir}/resources/environment"

# docker-compose file path
docker_compose_file="${dir}/../docker-compose.yml"

# flag.conf file path
flag_file="${dir}/../vm_client/flag.conf"

# ansible password file path
ansible_password_file="${dir}/../ansible/secrets/ansible_passwd"

# Test if secrets directory exists
if [ ! -d "${dir}/../ansible/secrets" ]; then
    mkdir "${dir}/../ansible/secrets"
    if [ $? -ne 0 ]; then
        error "An error occured while creating the secrets directory"
    else 
        success "The secrets directory has been created"
    fi
fi

# Test if the myapp certs directory exists
if [ ! -d "${dir}/../myapp/certs" ]; then
    mkdir "${dir}/../myapp/certs"
    if [ $? -ne 0 ]; then
        error "An error occured while creating the certs directory"
    else 
        success "The certs directory has been created"
    fi
fi

# Test if app/.env file exists
cp $env_file_template $env_file
if [ $? -ne 0 ]; then
    error "An error occured while creating the .env file"
else 
    success "The .env file has been created"
fi


# Apply the changes to a file
createVariable() {
    operator="="
    # escape the special characters
    value=$(echo $2 | sed 's/[\*\.&]/\\&/g')
    # Test if the file exists
    if [ ! -f $3 ]; then
        error "The file $3 does not exist"
    fi
    # Test if the file is docker-compose file
    if [ $3 == $docker_compose_file ]; then
        operator=": "
    fi
    # Test if the variable is already set (with or without tabulation)
    if grep -q "^$1$operator" $3 || grep -q "^[[:space:]]*$1$operator" $3; then
        # Replace the value of the variable
        sed -i "s#^\([[:space:]]*\)$1[[:space:]]*$operator.*#\1$1$operator$value#" $3
    else
        # Add the variable to the file
        echo "$1$operator$value" >> $3
    fi
}

modifyVariableForDockerCompose() {
    # Test if the variable is already set (with or without tabulation)
    if grep -q "^$1: " $3 || grep -q "^[[:space:]]*$1: " $3; then
        # Replace the value of the variable
        sed -i "s#^\([[:space:]]*\)$1:[[:space:]]*.*#\1$1: $2#" $3
    else
        # Add the variable to the file
        echo "$1: $2" >> $3
    fi
}


title1 "Custom your environment and modify default passwords"
title2 "Answer the following questions to set the environment variables"
# Ask for the new db password
ask "Enter the new password for the database:"
password_db=$response
# Test if the password is not empty
if [ -z "$password_db" ]; then
    error "The password can't be empty"
fi

# Generate the mysql root password
mysql_root_password=$(openssl rand -base64 32)
# Test return code
if [ $? -ne 0 ]; then
    error "An error occured while generating the mysql root password"
else 
    success "The mysql root password has been also generated"
fi

# Generates ansible user password
ansible_user_password=$(openssl rand -base64 32)
# Test return code
if [ $? -ne 0 ]; then
    error "An error occured while generating the ansible user password"
else 
    success "The ansible user password has been also generated"
fi

echo "$ansible_user_password" > $ansible_password_file
if [ $? -ne 0 ]; then
    error "An error occured while saving the ansible user password"
else 
    success "The ansible user password has been saved in the ansible password file"
fi

ask "CTF frontend listenning port (default: 3000):"
frontend_port=$response
#test if the port is a number and if it is between 1 and 65535
if ! [[ $frontend_port =~ ^[0-9]+$ ]] || [ $frontend_port -lt 1 ] || [ $frontend_port -gt 65535 ]; then
    frontend_port=3000
fi


ask "Network address of the interface used by your vm to communicate with the api (default : 192.168.56.0/24):"
network_address=$response
#test if the network address is a valid ip address with a subnet mask
if ! [[ $network_address =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+$ ]]; then
    network_address="192.168.56.0/24"
    info "Invalid network address, using default value: $network_address"
fi

title2 "Setting the environment variables"
modifyVariableForDockerCompose "MYSQL_ROOT_PASSWORD" "$mysql_root_password" "$docker_compose_file"
if [ $? -ne 0 ]; then
    error "An error occured while setting the mysql root password"
else 
    success "The mysql root password has been set in the docker compose file"
fi

modifyVariableForDockerCompose "MARIADB_PASSWORD" "$password_db" "$docker_compose_file"
if [ $? -ne 0 ]; then
    error "An error occured while setting the mariadb password"
else 
    success "The mariadb password has been set in the docker compose file"
fi

createVariable "DB_PASSWORD" "$password_db" "$env_file"
if [ $? -ne 0 ]; then
    error "An error occured while setting the db password"
else 
    success "The db password has been set in the .env file"
fi

createVariable "PORT" "$frontend_port" "$env_file"
if [ $? -ne 0 ]; then
    error "An error occured while setting the frontend port"
else 
    success "The web server port has been set in the .env file"
fi

createVariable "CTF_SERVER" "https://ctf.local:$frontend_port" "$flag_file"
if [ $? -ne 0 ]; then
    error "An error occured while setting the frontend port"
else 
    success "The web server port has been set in the .env file"
fi

yq e ".services.app.ports[0] = \"$frontend_port:$frontend_port\"" -i docker-compose.yml
if [ $? -ne 0 ]; then
    error "An error occured while setting the frontend port in the docker-compose file"
else 
    success "The frontend port has been set in the docker-compose file"
fi

sed -i "s/^EXPOSE .*/EXPOSE $frontend_port/" Dockerfile    
if [ $? -ne 0 ]; then
    error "An error occured while setting the frontend port in the Dockerfile"
else 
    success "The frontend port has been set in the Dockerfile"
fi




createVariable "MACHINE_NETWORK" "$network_address" "$env_file"
if [ $? -ne 0 ]; then
    error "An error occured while setting the network address"
else 
    success "The VM network address has been set in the .env file"
fi



