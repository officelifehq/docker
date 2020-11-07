#!/bin/bash

set -Eeo pipefail
set -x

release=$1

_template() {
    sed -e 's/\\/\\\\/g' $1 | sed -E ':a;N;$!ba;s/\r{0,1}\n/%0A/g'
}

minVersion=0

variants="apache fpm fpm-alpine"
versions="$minVersion main"

declare -A php_version=(
    [default]='7.4'
)

declare -A install=(
    [default]=$(_template .templates/Dockerfile-install.template)
    [main]=$(_template .templates/Dockerfile-install-main.template)
)

declare -A cmd=(
    [apache]='apache2-foreground'
    [fpm]='php-fpm'
    [fpm-alpine]='php-fpm'
)

declare -A base=(
    [apache]='debian'
    [fpm]='debian'
    [fpm-alpine]='alpine'
)

declare -A document=(
    [apache]=$(_template .templates/Dockerfile-apache.template)
    [fpm]=''
    [fpm-alpine]=''
)

declare -A fetchDeps=(
    [debian]="gnupg"
    [alpine]="bzip2 gnupg"
)

label=$(_template .templates/Dockerfile-label.template)

echo Initialisation

apcu_version="$(
    git ls-remote --tags https://github.com/krakjoe/apcu.git \
        | cut -d/ -f3 \
        | grep -vE -- '-rc|-b' \
        | sed -E 's/^v//' \
        | sort -V \
        | tail -1
)"
echo "  APCu version: $apcu_version"

memcached_version="$(
    git ls-remote --tags https://github.com/php-memcached-dev/php-memcached.git \
        | cut -d/ -f3 \
        | grep -vE -- '-rc|-b' \
        | sed -E 's/^[rv]//' \
        | sort -V \
        | tail -1
)"
echo "  Memcached version: $memcached_version"

redis_version="$(
    git ls-remote --tags https://github.com/phpredis/phpredis.git \
        | cut -d/ -f3 \
        | grep -viE '[a-z]' \
        | tr -d '^{}' \
        | sort -V \
        | tail -1
)"
echo "  Redis version: $redis_version"

declare -A pecl_versions=(
    [APCu]="$apcu_version"
    [memcached]="$memcached_version"
    [redis]="$redis_version"
)

_githubapi() {
    if [ -n "${GITHUB_TOKEN:-}" ]; then
        curl -fsSL -H "Authorization: token $GITHUB_TOKEN" $1;
    else
        curl -fsSL $1;
    fi
}

if [ -z "$release" ]; then
  release="$(_githubapi 'https://api.github.com/repos/officelifehq/officelife/releases/latest' | jq -r '.tag_name')"
fi
echo "  OfficeLife version: $release"
commit="$(_githubapi 'https://api.github.com/repos/officelifehq/officelife/tags' | jq -r 'map(select(.name | contains ("'$release'"))) | .[].commit.sha')"
echo "  Commit: $commit"

head=$(_template .templates/Dockerfile-head.template)
foot=$(_template .templates/Dockerfile-foot.template)
extra=$(_template .templates/Dockerfile-extra.template)
install=$(_template .templates/Dockerfile-install.template)

for version in $versions; do
    for variant in $variants; do
        echo Generating $version/$variant variant...
        rm -rf $version/$variant
        mkdir -p $version/$variant
        basev=${base[$variant]}
        phpVersion=${php_version[$version]-${php_version[default]}}
        inst=${install[$version]-${install[default]}}
        fetchDep=${fetchDeps[$basev]}
        extra_install=$extra
        officelife_version=$release
        officelife_commit=$commit

        if [ "$version" == "main" ]; then
          extra_install="$extra_install%0A\
COPY officelife-\${OFFICELIFE_VERSION}.tar.bz2 ."
          officelife_version="main"
          officelife_commit=""
        fi

        template="Dockerfile-$basev.template"

        sed -e '
            s@&&@&&@;
            s@%%HEAD%%@'"$head"'@;
            s@%%FOOT%%@'"$foot"'@;
            s@%%EXTRA_INSTALL%%@'"$extra_install"'@;
            s@%%INSTALL%%@'"$inst"'@;
            s@%%PREINSTALL%%@'"$pre_install"'@;
            s@%%POSTINSTALL%%@'"$post_install"'@;
            s@%%FETCHDEPS%%@'"$fetchDep"'@;
            s@%%PRE%%@'"$pre"'@;
            s/%%VARIANT%%/'"$variant"'/;
            s/%%PHP_VERSION%%/'"$phpVersion"'/;
            s#%%LABEL%%#'"$label"'#;
            s/%%VERSION%%/'"$officelife_version"'/g;
            s/%%COMMIT%%/'"$officelife_commit"'/;
            s/%%CMD%%/'"${cmd[$variant]}"'/;
            s#%%APACHE_DOCUMENT%%#'"${document[$variant]}"'#;
            s/%%APCU_VERSION%%/'"${pecl_versions[APCu]}"'/;
            s/%%MEMCACHED_VERSION%%/'"${pecl_versions[memcached]}"'/;
            s/%%REDIS_VERSION%%/'"${pecl_versions[redis]}"'/;
        ' \
            -e "s/%0A/\n/g;" \
            $template > "$version/$variant/Dockerfile"
        
        for file in entrypoint cron queue; do
            cp docker-$file.sh $version/$variant/$file.sh
        done
    done
done
