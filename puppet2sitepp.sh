#!/bin/bash

DEBUG=0

while getopts 'm:d' OPT; do
  case $OPT in
    m)  MODULEDIR=$OPTARG;;
    d)  DEBUG=1;;
    *)  JELP="yes";;
  esac
done 2>/dev/null

shift $(($OPTIND - 1))

if [ -z "${MODULEDIR}" ];
then
  echo "ERROR: moduledir is undefined"
  exit 1
fi

REALMODULEDIR=$(readlink -f ${MODULEDIR})

if [ ! -d "${REALMODULEDIR}" ];
then
  echo "ERROR: module path is not a directory"
  exit 1
fi

for i in $(find /etc/puppet/modules/*/manifests -iname \*pp);
do
  #puppet parser dump /etc/puppet/modules/tuned/manifests/profile/vmrule.pp | head -n1
  FUNCTION_TYPE=$(puppet parser dump $i 2>/dev/null| head -n1)

  if [ -z "${FUNCTION_TYPE}" ]
  then
    if [ "${DEBUG}" -eq 1 ];
    then
      (>&2 echo "ERROR parsing $i")
    fi
  fi

  DEFINE_NAME=$(echo "${FUNCTION_TYPE}" | head -n1 | grep -Eo "define [^ ]*" | awk '{ print $NF }')

  if [ -z "${DEFINE_NAME}" ];
  then
    if [ "${DEBUG}" -eq 1 ];
    then
      (>&2 echo "skipping ${FUNCTION_TYPE}")
    fi
  else
    #echo "create_resources(${DEFINE_NAME}, hiera_hash('', {}))"

    RESOURCE_ALIAS="$(grep puppet2sitepp $i | grep -Eo "@[^ ]*" | cut -f2 -d@)"

    if [ ! -z "${RESOURCE_ALIAS}" ];
    then

      AUTHOR=$(cat $(dirname $i)/$(echo $DEFINE_NAME | sed -e 's@::@/@g' -e 's@[^/]*/[^/]*@../@g')metadata.json | grep '"author"' | cut -f 2 -d: | grep -Eo '"[^"]*"' | cut -f 2 -d\")

      MODULE_NAME=$(echo ${DEFINE_NAME} | cut -f 1 -d:)

      if [ ! -z "${AUTHOR}" ] && [ ! -z "${MODULE_NAME}" ];
      then
        echo "#"
        echo "# ${AUTHOR}-${MODULE_NAME}"
        echo "#"
        echo ""
        echo "create_resources(${DEFINE_NAME}, hiera_hash('${RESOURCE_ALIAS}', {}))"
        echo ""
      fi
    fi
  fi

  
done
