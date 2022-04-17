#!/bin/bash

#=======================================================================#
# Copyright (C) 2020 - 2022 Dominik Willner <th33xitus@gmail.com>       #
#                                                                       #
# This file is part of KIAUH - Klipper Installation And Update Helper   #
# https://github.com/th33xitus/kiauh                                    #
#                                                                       #
# This file may be distributed under the terms of the GNU GPLv3 license #
#=======================================================================#

set -e

function init_flash_process(){
  local method

  ### step 1: check for required userhgroups (tty & dialout)
  check_usergroups

  top_border
  echo -e "|        ~~~~~~~~~~~~ [ Flash MCU ] ~~~~~~~~~~~~        |"
  hr
  echo -e "| Please select the flashing method to flash your MCU.  |"
  echo -e "| Make sure to only select a method your MCU supports.  |"
  echo -e "| Not all MCUs support both methods!                    |"
  hr
  blank_line
  echo -e "| 1) Regular flashing method                            |"
  echo -e "| 2) Updating via SD-Card Update                        |"
  blank_line
  back_help_footer
  while true; do
    read -p "${cyan}###### Please select:${white} " choice
    case "${choice}" in
      1)
        select_msg "Regular flashing method"
        method="regular"
        break;;
      2)
        select_msg "SD-Card Update"
        method="sdcard"
        break;;
      B|b)
        advanced_menu
        break;;
      H|h)
        clear && print_header
        show_flash_method_help
        break;;
      *)
        print_error "Invalid command!";;
    esac
  done

  ### step 2: select how the mcu is connected to the host
  select_mcu_connection
  ### step 3: select which detected mcu should be flashed
  select_mcu_id "${method}"
}

#================================================#
#=================== STEP 2 =====================#
#================================================#
function select_mcu_connection(){
  echo
  top_border
  echo -e "| ${yellow}Make sure to have the controller board connected now!${white} |"
  blank_line
  echo -e "| How is the controller board connected to the host?    |"
  echo -e "| 1) USB                                                |"
  echo -e "| 2) UART                                               |"
  bottom_border
  while true; do
    read -p "${cyan}###### Connection method:${white} " choice
    case "${choice}" in
      1)
        status_msg "Identifying MCU connected via USB ...\n"
        get_usb_id
        break;;
      2)
        status_msg "Identifying MCU possibly connected via UART ...\n"
        get_uart_id
        break;;
      *)
        error_msg "Invalid input!\n";;
    esac
  done

  if [[ "${#mcu_list[@]}" -lt 1 ]]; then
    warn_msg "No MCU found!"
    warn_msg "MCU not plugged in or not detectable!"
    echo
  else
    local i=1
    for mcu in "${mcu_list[@]}"; do
      mcu=$(echo "${mcu}" | rev | cut -d"/" -f1 | rev)
      echo -e " ● MCU #${i}: ${cyan}${mcu}${white}"
      i=$((i+1))
    done
    echo
  fi
}

#================================================#
#=================== STEP 3 =====================#
#================================================#
function select_mcu_id(){
  local i=0 sel_index=0 method=${1}
    top_border
    echo -e "|                   ${red}!!! ATTENTION !!!${white}                   |"
    hr
    echo -e "| Make sure, to select the correct MCU!                 |"
    echo -e "| ${red}ONLY flash a firmware created for the respective MCU!${white} |"
    bottom_border
    echo -e "${cyan}###### List of available MCU:${white}"
    ### list all mcus
    for mcu in "${mcu_list[@]}"; do
      i=$((i+1))
      mcu=$(echo "${mcu}" | rev | cut -d"/" -f1 | rev)
      echo -e " ● MCU #${i}: ${cyan}${mcu}${white}"
    done
    ### verify user input
    while [[ ! (${sel_index} =~ ^[1-9]+$) ]] || [ "${sel_index}" -gt "${i}" ]; do
      echo
      read -p "${cyan}###### Select MCU to flash:${white} " sel_index
      if [[ ! (${sel_index} =~ ^[1-9]+$) ]]; then
        error_msg "Invalid input!"
      elif [ "${sel_index}" -lt 1 ] || [ "${sel_index}" -gt "${i}" ]; then
        error_msg "Please select a number between 1 and ${i}!"
      fi
      mcu_index=$((sel_index - 1))
      selected_mcu_id="${mcu_list[${mcu_index}]}"
    done
    ### confirm selection
    while true; do
      echo -e "\n###### You selected:\n ● MCU #${sel_index}: ${selected_mcu_id}\n"
      read -p "${cyan}###### Continue? (Y/n):${white} " yn
      case "${yn}" in
        Y|y|Yes|yes|"")
          select_msg "Yes"
          status_msg "Flashing ${selected_mcu_id} ..."
          if [ "${method}" == "regular" ]; then
            log_info "Flashing device '${selected_mcu_id}' with method '${method}'"
            start_flash_mcu "${selected_mcu_id}"
          elif [ "${method}" == "sdcard" ]; then
            log_info "Flashing device '${selected_mcu_id}' with method '${method}'"
            start_flash_mcu_sd "${selected_mcu_id}"
          else
            error_msg "No flash method set! Aborting..."
            log_error "No flash method set!"
            return 1
          fi
          break;;
        N|n|No|no)
          select_msg "No"
          break;;
        *)
          print_error "Invalid command!";;
      esac
    done
}

function start_flash_mcu(){
  local device=${1}
  do_action_service "stop" "klipper"
  if make flash FLASH_DEVICE="${device}"; then
    ok_msg "Flashing successfull!"
  else
    warn_msg "Flashing failed!"
    warn_msg "Please read the console output above!"
  fi
  do_action_service "start" "klipper"
}

function start_flash_mcu_sd(){
  local i=0 board_list=() device=${1}
  local flash_script="${HOME}/klipper/scripts/flash-sdcard.sh"

  ### write each supported board to the array to make it selectable
  for board in $("${flash_script}" -l | tail -n +2); do
    board_list+=("${board}")
  done

  top_border
  echo -e "|  Please select the type of board that corresponds to  |"
  echo -e "|  the currently selected MCU ID you chose before.      |"
  blank_line
  echo -e "|  The following boards are currently supported:        |"
  hr
  ### display all supported boards to the user
  for board in "${board_list[@]}"; do
    if [ "${i}" -lt 10 ]; then
      printf "|  ${i}) %-50s|\n" "${board_list[${i}]}"
    else
      printf "|  ${i}) %-49s|\n" "${board_list[${i}]}"
    fi
    i=$((i + 1))
  done
  quit_footer

  ### make the user select one of the boards
  while true; do
    read -p "${cyan}###### Please select board type:${white} " choice
    if [ "${choice}" = "q" ] || [ "${choice}" = "Q" ]; then
      clear && advanced_menu && break
    elif [ "${choice}" -le ${#board_list[@]} ]; then
      selected_board="${board_list[${choice}]}"
      break
    else
      clear && print_header
      print_error "Invalid choice!"
      flash_mcu_sd
    fi
  done

  while true; do
    top_border
    echo -e "| If your board is flashed with firmware that connects  |"
    echo -e "| at a custom baud rate, please change it now.          |"
    blank_line
    echo -e "| If you are unsure, stick to the default 250000!       |"
    bottom_border
    echo -e "${cyan}###### Please set the baud rate:${white} "
    unset baud_rate
    while [[ ! ${baud_rate} =~ ^[0-9]+$ ]]; do
      read -e -i "250000" -e baud_rate
      selected_baud_rate=${baud_rate}
      break
    done
    break
  done

  ###flash process
  do_action_service "stop" "klipper"
  if "${flash_script}" -b "${selected_baud_rate}" "${device}" "${selected_board}"; then
    ok_msg "Flashing successfull!"
    log_info "Flash successfull!"
  else
    warn_msg "Flashing failed!"
    warn_msg "Please read the console output above!"
    log_error "Flash failed!"
  fi
  do_action_service "start" "klipper"
}

function build_fw(){
  local python_version
  if [ ! -d "${KLIPPER_DIR}" ] || [ ! -d "${KLIPPY_ENV}" ]; then
    print_error "Klipper not found!\n Cannot build firmware without Klipper!"
    return 1
  else
    cd "${KLIPPER_DIR}"
    status_msg "Initializing firmware build ..."
    dep=(build-essential dpkg-dev make)
    dependency_check "${dep[@]}"

    make clean && make menuconfig

    status_msg "Building firmware ..."
    python_version=$("${KLIPPY_ENV}"/bin/python --version 2>&1 | cut -d" " -f2 | cut -d"." -f1)
    [ "${python_version}" == "3" ] && make PYTHON=python3
    [ "${python_version}" == "2" ] && make
    ok_msg "Firmware built!"
  fi
}

#================================================#
#=================== HELPERS ====================#
#================================================#

function get_usb_id(){
  unset mcu_list
  sleep 1
  mcus=$(find /dev/serial/by-id/*)
  for mcu in ${mcus}; do
    mcu_list+=("${mcu}")
  done
}

function get_uart_id() {
  unset mcu_list
  sleep 1
  mcus=$(find /dev -maxdepth 1 -regextype posix-extended -regex "^\/dev\/tty[^0-9]+([0-9]+)?$")
  for mcu in ${mcus}; do
    mcu_list+=("${mcu}")
  done
}

function show_flash_method_help(){
  top_border
  echo -e "|     ~~~~~~~~ < ? > Help: Flash MCU < ? > ~~~~~~~~     |"
  hr
  echo -e "| ${cyan}Regular flashing method:${white}                              |"
  echo -e "| The default method to flash controller boards which   |"
  echo -e "| are connected and updated over USB and not by placing |"
  echo -e "| a compiled firmware file onto an internal SD-Card.    |"
  blank_line
  echo -e "| Common controllers that get flashed that way are:     |"
  echo -e "| - Arduino Mega 2560                                   |"
  echo -e "| - Fysetc F6 / S6 (used without a Display + SD-Slot)   |"
  blank_line
  echo -e "| ${cyan}Updating via SD-Card Update:${white}                          |"
  echo -e "| Many popular controller boards ship with a bootloader |"
  echo -e "| capable of updating the firmware via SD-Card.         |"
  echo -e "| Choose this method if your controller board supports  |"
  echo -e "| this way of updating. This method ONLY works for up-  |"
  echo -e "| grading firmware. The initial flashing procedure must |"
  echo -e "| be done manually per the instructions that apply to   |"
  echo -e "| your controller board.                                |"
  blank_line
  echo -e "| Common controllers that can be flashed that way are:  |"
  echo -e "| - BigTreeTech SKR 1.3 / 1.4 (Turbo) / E3 / Mini E3    |"
  echo -e "| - Fysetc F6 / S6 (used with a Display + SD-Slot)      |"
  echo -e "| - Fysetc Spider                                       |"
  blank_line
  back_footer
  while true; do
    read -p "${cyan}###### Please select:${white} " choice
    case "${choice}" in
      B|b)
        clear && print_header
        init_flash_process
        break;;
      *)
        print_error "Invalid command!";;
    esac
  done
}