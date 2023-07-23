
validate_set() {
  local VAR_NAME="$1"
  local VAR_VALUE="$2"
  echo -n "$VAR_NAME=$VAR_VALUE: "
  if [ -z "$VAR_VALUE" ]; then
    echo -e "\e[31mNOT SET!\e[0m"
    exit 1
  else echo -e "\e[32mOK\e[0m"; fi
}

validate_url() {
  VAR_NAME="$1"
  VAR_VALUE="$2"
  echo -n "$VAR_NAME=$VAR_VALUE: "
  if ! curl --output /dev/null --silent --head --fail "$VAR_VALUE"; then
    echo -e "\e[31mDOES NOT EXIST!\e[0m"
    exit 1
  else echo -e "\e[32mOK\e[0m"; fi
}

validate_git() {
  VAR_NAME="$1"
  VAR_VALUE="$2"
  VAR_BRANCH="$3"
  echo -n "$VAR_NAME @ $VAR_BRANCH=$VAR_VALUE @ $VAR_BRANCH: "
  git ls-remote --heads "${VAR_VALUE}" "${VAR_BRANCH}" | grep "${VAR_BRANCH}" >/dev/null
  if [ "$?" == "1" ]; then
    echo -e "\e[31mDOES NOT EXIST!\e[0m"
    exit 1
  else echo -e "\e[32mOK\e[0m"; fi
}