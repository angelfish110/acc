print_ss_() {
  local IFS=$' \t\n'
  local csw="charging_switch=\"${chargingSwitch[*]-}\""
  case "$csw" in
    *\ --*) echo "$csw";;
    *) printf "%s" "$csw"; echo " ($(print_auto))";;
  esac
  echo
}


set_prop() {

  local restartDaemon=false
  local two=

  case ${1-} in

    # set multiple properties
    *=*)
      . $defaultConfig
      . $config

      export "$@"

      [ .${mcc-${max_charging_current-x}} = .x ] \
        || set_ch_curr ${mcc:-${max_charging_current:--}} || :

      [ ".${mcv-${max_charging_voltage-x}}" = .x ] \
        || set_ch_volt "${mcv:-${max_charging_voltage:--}}" || :

      [ -z "${tl-}${temp_level-}" ] || set_temp_level ${tl:-$temp_level}
      echo "✅"
    ;;

    # reset config
    r|--reset)
      ! daemon_ctrl stop > /dev/null || restartDaemon=true
      cat $defaultConfig > $config
      [ .${2-} = .a ] && rm $dataDir/logs/write.log $dataDir/logs/ps-blacklist.log 2>/dev/null || :
      print_config_reset
      ! $restartDaemon || $TMPDIR/accd --init $config
      return 0
    ;;

    # print default config
    d|--print-default)
      . $defaultConfig
      two="${2//,/|}"
      . $execDir/print-config.sh ns | { grep -E "${two:-.}" | more; } || :
      return 0
    ;;

    # print current config
    p|--print)
      two="${2//,/|}"
      . $execDir/print-config.sh | { grep -E "${two:-.}" | more; } || :
      return 0
    ;;

    # set charging switch
    s|--charging*witch)
      IFS=$'\n'
      PS3="$(print_choice_prompt)"
      print_ss_
      . $execDir/select.sh
      select_ charging_switch $(print_auto; sort -u $TMPDIR/ch-switches; print_exit)
      [ ${charging_switch:-x} != $(print_exit) ] || exit 0
      [ ${charging_switch:-x} != $(print_auto) ] || charging_switch=
      case "${charging_switch:-x}" in
        "$(print_exit)") exit 0;;
        "$(print_auto)") charging_switch=;;
        */*)
          case "$charging_switch" in
            */*) charging_switch="$charging_switch --";;
          esac
        ;;
      esac
      unset IFS
    ;;

    # print switches
    s:|--charging*witch:)
      sort -u $TMPDIR/ch-switches
      return 0
    ;;

    # set charging current
    c|--current)
      set_ch_curr ${2-}
    ;;

    # set charging voltage
    v|--voltage)
      shift
      set_ch_volt "$@"
    ;;

    # set language
    l|--lang)
      IFS=$'\n'
      PS3="$(print_choice_prompt)"
      . $execDir/select.sh
      eval 'select_ _lang \
        $(for file in $(ls -1 $execDir/strings.sh $execDir/translations/*/strings.sh); do \
          sed -n 1p $file | sed "'s/# /- /p'" | grep -v "' .$language.'" | sort -u; \
        done; \
        print_exit)'
      lang=${_lang#*\(}
      [ $lang != $(print_exit) ] || exit 0
      lang=${lang%\)*}
      unset IFS
    ;;

    # print current config (full)
    *)
      if [ -f "${1:-//}" ]; then
        cat "$1" >> $config
        $TMPDIR/acca $config --set dummy=
      else
        . $execDir/print-config.sh | more
        return 0
      fi
    ;;

  esac

  # check whether a daemon restart is required (to restore defaults)
  if { [ ".${chargingSwitch[0]-x}" != .x ] \
    && [ ".${s-${charging_switch-x}}" != .x ]; } \
    || [ ".${cw-${current_workaround-x}}" != .x ]
  then
    ! daemon_ctrl stop || restartDaemon=true
  fi > /dev/null

  # update config.txt
  . $execDir/write-config.sh

  if $restartDaemon; then
    if [ ".${cw-${current_workaround-x}}" != .x ]; then
      $TMPDIR/accd --init $config
    else
      $TMPDIR/accd $config
    fi
  fi
}
