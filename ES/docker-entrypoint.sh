#!/bin/bash -ex

type=$1
if [ $type != 'es' -a $type != 'plugin' ]; then
  echo "不支持$type的打包, 只支持[es | plugin]"
  exit 1
fi

cd /edusoho

git config --global user.email "builder@edusoho.com"
git config --global user.name "builder"

if [[ $type = 'plugin' ]]; then
  #通用插件安装包
  plugin_code=$2
  plugin_version=$3
  edusoho_version=$4

  git pull
  git fetch --tags
  git checkout release/$edusoho_version
  git pull

  #克隆插件
  git clone -b release/$plugin_version git@coding.codeages.work:edusohoplugin/${plugin_code}.git plugins/${plugin_code}Plugin

  #修改数据库连接配置
  if [ ! -f app/config/parameters.yml ]; then
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

  #静态编译
  yarn
  npm run compile

  #copy seajs静态文件到web目录下
  app/console assets:install

  #拷贝翻译文件
  pluginDirName="${plugin_code}Plugin"
  webPluginDirName="${pluginDirName,,}"

  if [ -d "plugins/${pluginDirName}/Resources/translations" ]; then
    sed -i 's/translator\:      { fallback\: "%locale%", logging\: false }/translator\:/g' app/config/config.yml
    sed -i '/translator\:/a\        fallback: "%locale%"\n        logging: false\n        paths:\n            - '%kernel.root_dir%/../plugins/${pluginDirName}/Resources/translations'' app/config/config.yml

    rm -rf app/cache
    app/console trans:dump-js --code=$plugin_code
    if [ ! -d "web/static-dist/${webPluginDirName}/js/translations" ]; then
      mkdir -p web/static-dist/${webPluginDirName}/js
    fi

    if [ -d "plugins/${pluginDirName}/Resources/static-src/js/translations" ]; then
      cp -Rf plugins/${pluginDirName}/Resources/static-src/js/translations web/static-dist/${webPluginDirName}/js/translations
    fi
  fi

  #执行安装包打包命令
  app/console --verbose build:plugin-app $plugin_code

  cd plugins/${plugin_code}Plugin
  #检查文件变更
  echo "<<<<<<<<<<Check File Changes With Git Diff>>>>>>>>>>"
  git diff --name-status
else
  #通用升级包
  from_version=$2
  to_version=$3
  h5_version=$4

  git pull
  git fetch --tags
  git checkout release/$to_version
  git pull

  #判断上个Tag是否存在
  preVerTag=`git tag --list | grep "v$from_version"`
  if [ ! -n $preVerTag ]; then
    echo "tag v$from_version 不存在!"
    exit 1
  fi

  #生成配置文件
  if [ ! -f app/config/parameters.yml  ]; then
    cp app/config/parameters.yml.dist app/config/parameters.yml
  fi

  #克隆升级脚本
  git clone git@coding.codeages.work:edusoho/upgradescripts.git scripts
  echo $(tput setaf 2)pull the last version of repository from scripts command $(tput bold) git pull $(tput sgr 0)
  cd scripts
  git pull
  cd ..

  #copy seajs静态文件到web目录下
  app/console assets:install

  #生成js语言包
  app/console trans:dump-js

  echo "生成静态资源文件"

  # 生成h5静态资源文件
  h5repertory="edusoho-h5/index.html";
  if [ ! -f "$h5repertory" ]; then
    git clone git@coding.codeages.work:edusoho/edusoho-h5.git;
  fi
  # 打包edusoho-h5
  cd edusoho-h5;
  git pull;

  if [ '' == "$h5_version" ]; then
    git checkout master;
    git pull;
  else
    git checkout release/$h5_version;
    git pull;
  fi

  rm -rf node_modules;
  rm -rf dist/*;
  yarn install --production;
  npm run build;
  rm -rf ./../web/h5/*;
  cp -rf ./dist/* ./../web/h5/;
  cd ../
  echo "h5静态资源生成成功";

  # remove node modules folder and caches folder
  echo $(tput setaf 2)remove old node_modules and app/caches using  command  $(tput bold)rm -rf app/caches node_modules $(tput sgr 0)
  rm -rf app/caches node_modules

  #yarn install --production;
  yarn;

  #compile static resource file with webpack
  echo $(tput setaf 2)compile static resource file with webpack using command  $(tput bold)npm run compile$(tput sgr 0)
  npm run compile

  #检查文件变更
  if [[ `git status --porcelain` ]]; then
    echo "<<<<<<<<<<Start Check File Changes With Git Diff>>>>>>>>>>"
    git diff --name-status
    echo "<<<<<<<<<<End Check File Changes With Git Diff>>>>>>>>>>"
    git add .
    git commit -m "feat: #$(date +%Y%m%d) 保存已编译的静态资源"
  else
    echo "compile result no file change"
  fi

  # build package
  echo $(tput setaf 2) build package using command $(tput bold)app/console build:upgrade-package $from_version $to_version  $(tput sgr 0)
  app/console --verbose build:upgrade-package $from_version $to_version

  echo 'build package is completed'
  echo $(tput setaf 2)build package is completed$(tput sgr 0)
fi

rm -rf /tmp/*
mv /edusoho/build/* /tmp/