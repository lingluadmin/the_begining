#!/bin/bash

set -e

prj_path=$(cd $(dirname $0); pwd -P)
SCRIPTFILE=`basename $0`

devops_prj_path="$prj_path/devops"
prj_config_file=$devops_prj_path/auto-gen.manager.config
docker_code_root_dir=/9douyu
templates_dir="$prj_path/templates"

data_image=9douyu-data
local_data_image=busybox
php_image=9douyu-php
mysql_image=mysql:5.6
redis_image=redis:3.0.1
nginx_image=nginx:1.11
syslogng_image=balabit/syslog-ng
syslogng_container=syslog-ng

host_code_root_dir=$HOME/git/9douyu

function build_php() {
    docker build -t $php_image $prj_path/docker/php
}

function push_php() {
    push_image $php_image
}

function pull() {
    pull_image $php_image
    run_cmd "docker pull $mysql_image"
    run_cmd "docker pull $redis_image"
    run_cmd "docker pull $nginx_image"
    run_cmd "docker pull $syslogng_image"
}

function init_config_by_developer_name() {

    app=$developer_name-9douyu
    app_storage_dir=/opt/data/$app

    host_code_core_dir=$host_code_root_dir/9douyu-core
    host_code_module_dir=$host_code_root_dir/9douyu-module
    host_code_module_static_dir=$host_code_root_dir/9douyu-module-static
    host_code_service_dir=$host_code_root_dir/9douyu-service
    host_code_ception_dir=$host_code_root_dir/codecept

    mysql_data_dir=$app_storage_dir/mysql/data
    app_log_dir=$app_storage_dir/log
    app_php_storage_dir=$app_storage_dir/storage

    data_container=$app-data
    mysql_container=$app-mysql
    redis_container=$app-redis
    nginx_container_fpm=$app-nginx-fpm
    nginx_container_static=$app-nginx-static
    php_container=$app-php

    site_list_developer_config_key="site_list.$developer_name"

    nginx_docker_sites_fpm_conf_dir="$app_storage_dir/nginx-fpm-config"
    nginx_docker_sites_static_conf_dir="$app_storage_dir/nginx-static-config"

    local host_ip=$(docker0_ip)
    extra_kv_list="developer_name=$developer_name php_container=$php_container docker_code_root_dir=$docker_code_root_dir hostname=`hostname`"
    extra_kv_list="$extra_kv_list host_ip=$host_ip"
}

function load_config() {
    local host_ip=$(docker0_ip)
    http_port_fpm=$(read_kv_config "$prj_config_file" "http_port_fpm")
    http_port_static=$(read_kv_config "$prj_config_file" "http_port_static")
    mysql_port="$host_ip:$(read_kv_config "$prj_config_file" "mysql_port")"
}

function _build_config_for_developer() {
    local config_key="9douyu.vars.site_list.$developer_name"
    local template_file="$templates_dir/manager.config.template"
    local config_file_name="sites-config"
    local dst_file=$prj_config_file
    render_server_config $config_key $template_file $config_file_name $dst_file

    config_key="9douyu"
    template_file="$templates_dir/9douyu-dev.yaml.template"
    config_file_name="sites-config"
    dst_file="$prj_path/config/9douyu-dev.yaml"
    render_server_config $config_key $template_file $config_file_name $dst_file $extra_kv_list

    config_key="9douyu"
    template_file="$templates_dir/rsyslog.conf.template"
    config_file_name="sites-config"
    dst_file="$prj_path/tmp/rsyslog.conf"
    render_server_config $config_key $template_file $config_file_name $dst_file $extra_kv_list
}

function _build_config_for_project() {
    # generate config/9douyu-dev.yaml
    local config_key=''
    local template_file=''
    local config_file_name=''
    local config_file=''
    local dst_file=''

    config_key=$site_list_developer_config_key
    template_file="$templates_dir/create_db.sql.template" 
    config_file="$prj_path/config/9douyu-dev.yaml"
    dst_file="$prj_path/data/mysql-init/create_db.sql"
    render_local_config $config_key $template_file $config_file $dst_file $extra_kv_list

    config_key=$site_list_developer_config_key
    template_file="$templates_dir/wait-mysql.sh.template"
    config_file="$prj_path/config/9douyu-dev.yaml"
    dst_file="$prj_path/tmp/wait-mysql.sh"
    render_local_config $config_key $template_file $config_file $dst_file $extra_kv_list
    run_cmd "chmod +x $dst_file"

    config_key=$site_list_developer_config_key
    template_file="$templates_dir/import-init-data.sh.template" 
    config_file="$prj_path/config/9douyu-dev.yaml"
    dst_file="$prj_path/tmp/import-init-data.sh"
    render_local_config $config_key $template_file $config_file $dst_file $extra_kv_list

    config_key="mysql"
    template_file="$templates_dir/export-init-data.sh.template"
    config_file="$prj_path/config/export-init-data.yaml"
    dst_file="$prj_path/tmp/export-init-data.sh"
    render_local_config $config_key $template_file $config_file $dst_file $extra_kv_list

    config_key=$site_list_developer_config_key
    template_file="$templates_dir/crontab.template"
    config_file="$prj_path/config/9douyu-dev.yaml"
    dst_file="$prj_path/crontab/crontab"
    render_local_config $config_key $template_file $config_file $dst_file $extra_kv_list
    run_cmd "chmod +x $dst_file"

    config_key=$site_list_developer_config_key
    template_file="$templates_dir/nginx/fastcgi" 
    config_file="$prj_path/config/9douyu-dev.yaml"
    dst_file="$nginx_docker_sites_fpm_conf_dir/fastcgi"
    render_local_config $config_key $template_file $config_file $dst_file $extra_kv_list

    template_file="$templates_dir/nginx/9douyu.conf" 
    dst_file="$nginx_docker_sites_fpm_conf_dir/9douyu.conf"
    render_local_config $config_key $template_file $config_file $dst_file $extra_kv_list

    template_file="$templates_dir/nginx/9douyu-static.conf" 
    dst_file="$nginx_docker_sites_static_conf_dir/9douyu-static.conf"
    render_local_config $config_key $template_file $config_file $dst_file $extra_kv_list

}

function do_init() {
    ensure_dir "$host_code_root_dir"
    ensure_dir "$app_storage_dir"
    ensure_dir "$prj_path/tmp"
    ensure_dir "$nginx_docker_sites_fpm_conf_dir"
    ensure_dir "$nginx_docker_sites_static_conf_dir"
    _build_config_for_developer
    _build_config_for_project
}

source $devops_prj_path/base.sh

function build_code_config() {

    local config_key=site_list.$developer_name
    local config_file=$prj_path/config/9douyu-dev.yaml

    render_local_config $config_key $host_code_core_dir/.env.example $config_file $host_code_core_dir/.env
    render_local_config $config_key $host_code_module_dir/.env.example $config_file $host_code_module_dir/.env
    render_local_config $config_key $host_code_service_dir/.env.example $config_file $host_code_service_dir/.env
    #render_local_config $config_key $host_code_service_dir/.env.example $config_file $host_code_service_dir/.env
    render_local_config $config_key $templates_dir/acceptance.suite.yaml.template $config_file $host_code_ception_dir/tests/acceptance.suite.yml
    run_cmd "cp $templates_dir/Dockerfile $host_code_root_dir/"
    run_cmd "cp $templates_dir/dockerignore $host_code_root_dir/.dockerignore"
}

function download_code() {

    local vendor_dir=vendor

    if [ ! -d $host_code_core_dir ]; then
        run_cmd "cd $host_code_root_dir"
        run_cmd "git clone git@git.sunfund.com:root/9douyu-core.git $host_code_core_dir"
        run_cmd "cp $host_code_core_dir/config/cache.example $host_code_core_dir/config/cache.php"

        
        run_cmd "cd $host_code_core_dir"
        run_cmd "git clone git@git.sunfund.com:root/9douyu-core-vendor.git $vendor_dir"
    fi

    if [ ! -d $host_code_module_dir ]; then
        run_cmd "cd $host_code_root_dir"
        run_cmd "git clone git@git.sunfund.com:root/9douyu-module.git $host_code_module_dir"
        run_cmd "cp $host_code_module_dir/config/cache.example $host_code_module_dir/config/cache.php"
        run_cmd "cp $host_code_module_dir/config/oss.example $host_code_module_dir/config/oss.php"

        run_cmd "cd $host_code_module_dir"
        run_cmd "git clone git@git.sunfund.com:root/9douyu-module-vendor.git $vendor_dir"
    fi

    if [ ! -d $host_code_module_static_dir ]; then
        run_cmd "cd $host_code_root_dir"
        run_cmd "git clone git@git.sunfund.com:9douyu/9douyu-module-static.git $host_code_module_static_dir"
    fi

    if [ ! -d $host_code_service_dir ]; then
        run_cmd "cd $host_code_root_dir"
        run_cmd "git clone git@git.sunfund.com:root/9douyu-service.git $host_code_service_dir"

        run_cmd "cd $host_code_service_dir"
        run_cmd "git clone git@git.sunfund.com:root/9douyu-service-vendor.git $vendor_dir"
    fi
    
    if [ ! -d $host_code_ception_dir ]; then
        run_cmd "cd $host_code_root_dir"
        run_cmd "git clone git@git.sunfund.com:9douyu/codecept.git $host_code_ception_dir"
    fi
}

function pull_code() {
    local vendor_dir=vendor
    for dir in $host_code_core_dir $host_code_core_dir/$vendor_dir $host_code_module_dir  $host_code_module_dir/$vendor_dir $host_code_module_static_dir $host_code_service_dir $host_code_service_dir/$vendor_dir $host_code_ception_dir
    do
        run_cmd "cd $dir"
        run_cmd "git pull --ff-only"
    done
}

function run_data() {
    local args=''
    args="$args -v $host_code_root_dir:$docker_code_root_dir"
    run_cmd "docker run $args --name $data_container $local_data_image /bin/true"
}

function stop_data() {
    stop_container $data_container
}

function build_code_image() {
    docker build -t $data_image $host_code_root_dir
}

function push_code_image() {
    local version=test
    url=$DOCKER_DOMAIN/$data_image:$version
    run_cmd "docker tag $data_image $url"
    run_cmd "docker push $url"
}

function pull_code_image() {
    local version=test
    url=$DOCKER_DOMAIN/$data_image:$version
    run_cmd "docker pull $url"
    run_cmd "docker tag $url $data_image"
}

function stop_nginx() {
    stop_container $nginx_container_fpm
    stop_container $nginx_container_static
}

function restart_nginx() {
    stop_nginx
    run_nginx
}

function run_nginx() {
    _run_nginx_fpm
    _run_nginx_static
}

function _run_nginx_fpm() {

    local nginx_data_dir="$devops_prj_path/nginx-data"
    local nginx_log_path="$app_log_dir/nginx-fpm"
    local args=$1

    args="--restart=always"

    args="$args -p $http_port_fpm:80"
    # args="$args -p 80:80"

    # nginx config
    args="$args -v $nginx_data_dir/conf/nginx.conf:/etc/nginx/nginx.conf"

    # for the other sites
    args="$args -v $nginx_data_dir/conf/extra/:/etc/nginx/extra"

    # logs
    args="$args -v $nginx_log_path:/var/log/nginx"

    # generated nginx docker sites config
    args="$args -v $nginx_docker_sites_fpm_conf_dir:/etc/nginx/docker-sites"

    args="$args --link $php_container"

    args="$args --volumes-from $data_container"

    run_cmd "docker run -d $args --name $nginx_container_fpm $nginx_image"
}

function _run_nginx_static() {

    local nginx_data_dir="$devops_prj_path/nginx-data"
    local nginx_log_path="$app_log_dir/nginx-static"

    args="--restart=always"

    args="$args -p $http_port_static:80"

    # nginx config
    args="$args -v $nginx_data_dir/conf/nginx.conf:/etc/nginx/nginx.conf"

    # for the other sites
    args="$args -v $nginx_data_dir/conf/extra/:/etc/nginx/extra"

    # logs
    args="$args -v $nginx_log_path:/var/log/nginx"

    # generated nginx docker sites config
    args="$args -v $nginx_docker_sites_static_conf_dir:/etc/nginx/docker-sites"

    args="$args -v $host_code_root_dir:$docker_code_root_dir"

    run_cmd "docker run -d $args --name $nginx_container_static $nginx_image"
}

function _run_php_container() {

    local args='--restart=always'
    args="$args -v $prj_path/tmp/rsyslog.conf:/etc/rsyslog.d/rsyslog.conf"
    args="$args -v $app_log_dir/php:/var/log/php"
    args="$args -v $app_log_dir/crontab:/var/log/crontab"

    args="$args -v $prj_path/docker/php/conf/php-dev.ini:/usr/local/etc/php/php.ini"
    args="$args -v $prj_path/docker/php/conf/php-fpm.conf:/usr/local/etc/php-fpm.conf"

    ensure_dir "$app_php_storage_dir/core/logs"
    ensure_dir "$app_php_storage_dir/module/logs"
    ensure_dir "$app_php_storage_dir/module/framework/sessions"
    ensure_dir "$app_php_storage_dir/module/framework/cache"
    ensure_dir "$app_php_storage_dir/service/logs"

    args="$args -v $app_php_storage_dir/core:$docker_code_root_dir/9douyu-core/storage"
    args="$args -v $app_php_storage_dir/module:$docker_code_root_dir/9douyu-module/storage"
    args="$args -v $app_php_storage_dir/service:$docker_code_root_dir/9douyu-service/storage"

    args="$args -v $prj_path:$prj_path"
    args="$args -w $prj_path"

    args="$args --volumes-from $data_container"
    args="$args --link $redis_container"

    local cmd=$1
    run_cmd "docker run -d $args -h $php_container --name $php_container $php_image $cmd"
}

function _send_cmd_to_php() {
    local cmd=$1
    run_cmd "docker exec -i $(_open_tty) $php_container bash -c '$cmd'"
}

function _sudo_for_stroage() {
    run_cmd "docker run --rm -i $(_open_tty) -v $app_storage_dir:$app_storage_dir $nginx_image bash -c '$cmd'"
}

function run_php() {
    local cmd="bash manager.sh run_php_"
    _run_php_container "$cmd"
}

function stop_php() {
    stop_container $php_container
}

function run_php_() {
    run_cmd '/usr/sbin/rsyslogd'
    run_cmd 'bash crontab/start-crontab.sh'
    if [ -f /var/log/php/php-fpm-error.log ]; then
        run_cmd 'touch /var/log/php/php-fpm-error.log'
    fi
    if [ -f /var/log/php/php-fpm-slow ]; then
        run_cmd 'touch /var/log/php/php-fpm-slow.log'
    fi
    run_cmd 'chmod -R a+r /var/log/php/'
    run_cmd '/usr/local/sbin/php-fpm -R'
}

function _prepare_test_core() {
    local phpunit="$docker_code_root_dir/9douyu-core/vendor/bin/phpunit"
    local test_file='ExampleTest.php'
    local test_file_abs="$docker_code_root_dir/9douyu-core/tests/$test_file"
    local cmd="php $phpunit $test_file_abs"

    echo "$cmd"
}

function test_core() {
    local cmd=$(_prepare_test_core)
    
    echo 'Executing core unit tests...'
    _send_cmd_to_php "$cmd"
}

function _prepare_test_module() {
    local phpunit="$docker_code_root_dir/9douyu-module/vendor/bin/phpunit"
    local test_file='ExampleTest.php'
    local test_file_abs="$docker_code_root_dir/9douyu-module/tests/$test_file"
    local cmd="php $phpunit $test_file_abs"
    
    echo "$cmd"
}

function test_module() {
    local cmd=$(_prepare_test_module)

    echo 'Executing module unit tests...'
    _send_cmd_to_php "$cmd"
}

function _prepare_test_module_page(){
    
    local codecept_dir="$docker_code_root_dir/codecept"
    local cmd="cd $codecept_dir && php codecept.phar run"
    echo "$cmd"
}

function test_module_page(){
    local cmd=$(_prepare_test_module_page)    
    echo 'Executing module page tests...'
    _send_cmd_to_php "$cmd"
}

function test_all() {
    local core_test=$(_prepare_test_core)
    local module_test=$(_prepare_test_module)
    local module_page_test=$(_prepare_test_module_page)

    local cmd="$core_test; $module_test;$module_page_test"

    echo 'Executing all unit tests...'
    _send_cmd_to_php "$cmd"
}

function init_app_() {

    run_cmd "cd $docker_code_root_dir/9douyu-core"

    run_cmd "php artisan migrate --force"
    run_cmd "php artisan db:seed --force"

    run_cmd "cd $docker_code_root_dir/9douyu-module"
    run_cmd "php artisan migrate --force"
    run_cmd "php artisan db:seed --force"
    
    run_cmd "cd $docker_code_root_dir/9douyu-service"
    run_cmd "php artisan migrate --force"
    run_cmd "php artisan db:seed --force"
}

function init_app() {
    local cmd="cd $prj_path; bash manager.sh init_app_"
    _send_cmd_to_php "$cmd"
}

function gen_token() {
    _send_cmd_to_php "cd $docker_code_root_dir; php 9douyu-module/artisan AccessTokenCore"
    _send_cmd_to_php "cd $docker_code_root_dir; php 9douyu-module/artisan AccessTokenServer"
}

function to_php() {
    local cmd='bash'
    _send_cmd_to_php "cd $docker_code_root_dir; $cmd"
}

function dump_init_data() {
    local cmd='bash tmp/export-init-data.sh'
    _run_mysql_command_in_client "$cmd"
}

function to_mysql_env() {
    local cmd='bash'
    _run_mysql_command_in_client "$cmd"
}

function import_init_data() {
    local cmd='bash tmp/import-init-data.sh'
    _run_mysql_command_in_client "$cmd"
}

function delete_mysql() {
    stop_mysql
    local cmd="rm -rf $mysql_data_dir/mysql-data"
    _sudo_for_stroage "$cmd"
}

function run_mysql() {
    local args="--restart always"
    args="$args -v $mysql_data_dir/mysql-data:/var/lib/mysql"

    # auto import data
    args="$args -v $prj_path/data/mysql-init:/docker-entrypoint-initdb.d/"

    # config
    args="$args -v $prj_path/config/mysql/conf/:/etc/mysql/conf.d/"

    args="$args -v $prj_path/tmp/wait-mysql.sh:/tmp/wait-mysql.sh"
    args="$args -v $prj_path:$prj_path"
    args="$args -w $prj_path"

    # mysql port
    args="$args -p $mysql_port:3306"

    # do not use password
    args="$args -e MYSQL_ROOT_PASSWORD='' -e MYSQL_ALLOW_EMPTY_PASSWORD='yes'"
    run_cmd "docker run -d $args --name $mysql_container $mysql_image"

    _wait_mysql
}

function _wait_mysql() {
    local cmd="while ! mysqladmin ping -h 127.0.0.1 --silent; do sleep 1; done"
    _run_mysql_command_in_client "$cmd"
}

function to_mysql() {
    local cmd="mysql -h 127.0.0.1 -P 3306 -u root -p"
    _run_mysql_command_in_client "$cmd"
}

function _run_mysql_command_in_client() {
    local cmd=$1
    run_cmd "docker exec -i $(_open_tty) $mysql_container bash -c 'cd $prj_path; $cmd'"
}

function stop_mysql() {
    stop_container $mysql_container
}

function restart_mysql() {
    stop_mysql
    run_mysql
}

function run_redis() {
    local args="--restart always"
    # config
    args="$args -v $prj_path/config/redis/redis.conf:/usr/local/etc/redis/redis.conf"
    run_cmd "docker run -d $args --name $redis_container $redis_image"
}

function run_syslogng() {
    local args=''
    local log_path='/opt/data/syslog-ng'
    args="$args -v $log_path:/var/log"
    args="$args -p 514:514 -p 601:601/udp"
    args="$args -v $devops_prj_path/syslog-ng.conf:/etc/syslog-ng/conf.d/syslog-ng.conf"
    args="$args -v $prj_path/docker/php/sources.list:/etc/apt/sources.list"
    # args="$args --entrypoint bash"
    run_cmd "docker run -d $args --name $syslogng_container $syslogng_image"
}

function stop_syslogng() {
    stop_container $syslogng_container
}

function restart_syslogng() {
    stop_syslogng
    run_syslogng
}

function stop_redis() {
    stop_container $redis_container
}

function to_redis() {
    local cmd='redis-cli'
    run_cmd "docker exec -i $(_open_tty) $redis_container bash -c '$cmd'"
}

function _open_tty() {
    if [ "$cur_env" != 'test_env' ]; then
        echo '-t'
    else
        echo ''
    fi
}

function restart_redis() {
    stop_redis
    run_redis
}

function fix() {
    stop_nginx
    stop_php
    delete_mysql

    run_mysql
    run_php
    run_nginx
    init_app
}

function init_sql(){
    delete_mysql
    run_mysql
    init_app
    import_init_data
}


function _clean() {
    stop_nginx
    stop_php
    delete_mysql
    stop_redis
    stop_data
    run_cmd "rm -rf $devops_prj_path/auto-gen*"
    run_cmd "rm -rf $prj_path/tmp"
    local cmd="rm -rf $app_storage_dir/*"
    _sudo_for_stroage "$cmd"
}

function clean() {
    _clean
}

function clean_all() {
    _clean
    _rm_codes
}

function _rm_codes() {
    if [ -d $host_code_core_dir ]; then
        run_cmd "rm -rf $host_code_core_dir"
    fi
    
    if [ -d $host_code_module_dir ]; then
        run_cmd "rm -rf $host_code_module_dir"
    fi

    if [ -d $host_code_module_static_dir ]; then
        run_cmd "rm -rf $host_code_module_static_dir"
    fi

    if [ -d $host_code_service_dir ]; then
        run_cmd "rm -rf $host_code_service_dir"
    fi

    if [ -d $host_code_ception_dir ]; then
        run_cmd "rm -rf $host_code_ception_dir"
    fi
}

function new_egg() {

    run_mysql

    download_code
    build_code_config

    run_redis
    run_data
    run_php
    run_nginx

    init_app
    import_init_data
    gen_token
}

function help() {
	cat <<-EOF
    
    Usage: mamanger.sh [options]
            
        Valid options are:

            build_php
            push_php
            pull
            
            init
            
            clean
            clean_all               will also clean code

            new_egg
            
            build_code_config
            download_code
            pull_code

            build_code_image
            push_code_image
            pull_code_image

            run_data
            stop_data
            
            run_mysql
            to_mysql
            to_mysql_env
            stop_mysql
            restart_mysql
            delete_mysql

            run_redis
            to_redis
            stop_redis
            restart_redis

            run_nginx
            stop_nginx
            restart_nginx
            
            run_php
            run_php_
            to_php
            stop_php

            init_app
            init_app_
            dump_init_data
            
            init_sql

            import_init_data

            gen_token

            run_syslogng
            stop_syslogng
            restart_syslogng
            
            test_all
            test_core
            test_module
            test_module_page

            help                      show this help message and exit

EOF
}
ALL_COMMANDS="init clean clean_all new_egg download_code pull_code build_code_config run_mysql stop_mysql restart_mysql to_mysql delete_mysql dump_init_data import_init_data run_redis stop_redis to_redis restart_redis build_php push_php pull to_php run_php stop_php run_php_ init_app init_app_ gen_token to_mysql_env run_nginx stop_nginx restart_nginx run_syslogng stop_syslogng restart_syslogng fix run_data stop_data build_code_image push_code_image pull_code_image test_all
test_core test_module test_module_page init_sql"
list_contains ALL_COMMANDS "$action" || action=help
$action "$@"
