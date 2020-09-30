#!/bin/bash -ex

type=$1
if [ $type != 'ct' -a $type != 'plugin' ]; then
  echo "不支持$type的打包, 只支持[ct | plugin]"
  exit 1
fi

cd /edusoho

git config --global user.email "builder@edusoho.com"
git config --global user.name "builder"

if [[ $type = 'plugin' ]]; then
  #企培插件安装包
  plugin_code=$2
  plugin_version=$3
  edusoho_version=$4

  git pull
  git fetch --tags
  git checkout release/$edusoho_version

  git clone -b release/$plugin_version git@coding.codeages.work:corporate-training/${plugin_code}Plugin.git plugins/${plugin_code}Plugin

  #修改数据库连接配置
  if [ ! -f app/config/parameters.yml  ]; then
    cp app/config/parameters.yml.dist app/config/parameters.yml
  fi

  sed -i "s/\s*database_name.*/    database_name: edusoho_for_build/g" app/config/parameters.yml

  sed -i 's/\s*database_user.*/    database_user: root/g' app/config/parameters.yml

  sed -i 's/\s*database_password.*/    database_password:/g' app/config/parameters.yml

  #创建数据库用于编包
  service mysql start

  mysql -uroot -e "drop database if exists \`edusoho_for_build\`";

  mysql -uroot -e "create database \`edusoho_for_build\` DEFAULT CHARACTER SET utf8";

  #初始化数据
  mkdir app/data
  ./bin/phpmig migrate

  yarn
  npm run compile

  #copy seajs静态文件到web目录下
  app/console assets:install --symlink --relative

  pluginDirName="${plugin_code}Plugin"
  webPluginDirName="${pluginDirName,,}"

  #生成js语言包
  sed -i 's/translator\:      { fallback\: "%locale%", logging\: false }/translator\:/g' app/config/config.yml
  sed -i '/translator\:/a\        fallback: "%locale%"\n        logging: false\n        paths:\n            - '%kernel.root_dir%/../plugins/${pluginDirName}/Resources/translations'' app/config/config.yml
  rm -rf app/cache
  app/console trans:dump-js --code=$plugin_code

  if [ -d "plugins/${pluginDirName}/Resources/static-src/js/translations" ]; then
    cp -Rf plugins/${pluginDirName}/Resources/static-src/js/translations web/static-dist/${webPluginDirName}/js/translations
  fi

  #执行升级包打包命令
  app/console  --verbose build:plugin-app $plugin_code

  cd plugins/${plugin_code}Plugin
  #检查文件变更
  echo "<<<<<<<<<<Check File Changes With Git Diff>>>>>>>>>>"
  git diff --name-status

else
  #企培升级包
  from_version=$2
  to_version=$3

  #fetch release 代码
  git pull
  git fetch --tags
  git checkout release/$to_version

  preVerTag=`git tag --list | grep "ct-v$from_version"`
  if [ ! -n $preVerTag ]; then
    echo "tag ct-v$from_version 不存在!"
    exit 1
  fi

  # 拷贝配置文件
  if [ ! -f app/config/parameters.yml  ]; then
    cp app/config/parameters.yml.dist app/config/parameters.yml
  fi

  #升级脚本
  git clone git@coding.codeages.work:corporate-training/upgradescripts.git scripts

  #静态编译
  yarn
  npm run compile

  #copy seajs静态文件到web目录下
  app/console assets:install

  #生成js语言包
  app/console trans:dump-js

  #检查文件变更
  if [[ `git status --porcelain` ]]; then
    echo "<<<<<<<<<<Start Check File Changes With Git Diff>>>>>>>>>>"
    git diff --name-status
    echo "<<<<<<<<<<End Check File Changes With Git Diff>>>>>>>>>>"
    git add .
    git commit -m "feat: #`date +%y%m%d` save compile changes"
  else
    echo "compile result no file change"
  fi

  #执行升级包打包命令
  app/console --verbose corporate-training:upgrade-package $from_version $to_version --noninteractive
fi

rm -rf /tmp/*
mv /edusoho/build/* /tmp/